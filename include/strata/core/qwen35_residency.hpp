// GPU-first residency policy for dense Qwen on memory-constrained PCs.
// Pure policy: no CUDA or OS dependencies, so it can be tested on hosted CI.
#pragma once
#include <algorithm>
#include <cstddef>
#include <cstdint>
#include <limits>

namespace strata::core {

inline constexpr std::size_t q35_mib = 1024ull * 1024ull;

struct Qwen35ResidencyPolicy {
    // These are intentionally not "fill all 4GB": Windows and other apps
    // need spare VRAM. Users can lower the cache cap independently.
    std::size_t keep_free_bytes = 1024ull * q35_mib;
    std::size_t reclaim_below_bytes = 768ull * q35_mib;
    std::size_t max_cache_bytes = 2048ull * q35_mib;
    std::size_t grow_per_step_bytes = 256ull * q35_mib;

    bool should_reclaim(std::size_t free_bytes, std::size_t cached_bytes) const {
        return cached_bytes > 0 && free_bytes < reclaim_below_bytes;
    }

    bool can_admit(std::size_t free_bytes, std::size_t weight_bytes,
                   std::size_t cached_bytes, std::size_t already_added) const {
        if (!weight_bytes || weight_bytes > free_bytes) return false;
        // Subtraction avoids unsigned overflow at large/invalid caller inputs.
        if (free_bytes - weight_bytes < keep_free_bytes) return false;
        if (cached_bytes > max_cache_bytes || weight_bytes > max_cache_bytes - cached_bytes) return false;
        return already_added == 0 || weight_bytes <= grow_per_step_bytes - std::min(grow_per_step_bytes, already_added);
    }

    std::size_t desired_cache(std::size_t free_bytes, std::size_t cached_bytes) const {
        // Current resident weights are reclaimable, but fixed GPU allocations are not.
        const std::size_t sum = free_bytes > std::numeric_limits<std::size_t>::max() - cached_bytes
                                    ? std::numeric_limits<std::size_t>::max()
                                    : free_bytes + cached_bytes;
        return std::min(max_cache_bytes, sum > keep_free_bytes ? sum - keep_free_bytes : 0);
    }
};

}  // namespace strata::core

// Compact per-vector attention cache for Strata's dense Qwen3.5 engine.
// This is a CPU reference implementation for correctness/unit tests.
// The CUDA path in q36_engine.cu has the same 256 signed bytes + float scale layout.
#pragma once

#include <algorithm>
#include <cmath>
#include <cstddef>
#include <cstdint>

namespace strata::core {

inline constexpr std::size_t kQwen35KvWidth = 256;

struct alignas(4) Qwen35KvRecordQ8 {
    std::int8_t codes[kQwen35KvWidth]{};
    float scale = 1.f;
};

static_assert(sizeof(Qwen35KvRecordQ8) == 260, "Unexpected Qwen35 KV record padding");
static_assert(offsetof(Qwen35KvRecordQ8, scale) == kQwen35KvWidth, "Unexpected Qwen35 KV scale offset");

// GPU storage for key+value of one attention session, excluding temporary buffers.
constexpr std::uint64_t qwen35_q8_cache_bytes(std::uint64_t layers, std::uint64_t kv_heads,
                                               std::uint64_t context) {
    return layers * kv_heads * context * 2u * sizeof(Qwen35KvRecordQ8);
}

constexpr std::uint64_t qwen35_f32_cache_bytes(std::uint64_t layers, std::uint64_t kv_heads,
                                               std::uint64_t context) {
    return layers * kv_heads * context * 2u * kQwen35KvWidth * sizeof(float);
}

// Symmetric int8 quantization: one scale for all 256 values (not per 64-value subgroup).
// Keep non-finite values out of inference inputs. CUDA mirrors nearby-even rounding.
inline Qwen35KvRecordQ8 qwen35_q8_encode(const float* values) {
    Qwen35KvRecordQ8 out{};
    float high = 0.f;
    for (std::size_t i = 0; i < kQwen35KvWidth; ++i)
        high = std::max(high, std::fabs(values[i]));
    out.scale = std::max(high / 127.f, 1e-12f);
    for (std::size_t i = 0; i < kQwen35KvWidth; ++i) {
        const long code = std::lrint(values[i] / out.scale);
        out.codes[i] = static_cast<std::int8_t>(std::clamp(code, -127L, 127L));
    }
    return out;
}

inline void qwen35_q8_decode(const Qwen35KvRecordQ8& record, float* values) {
    for (std::size_t i = 0; i < kQwen35KvWidth; ++i)
        values[i] = static_cast<float>(record.codes[i]) * record.scale;
}

} // namespace strata::core

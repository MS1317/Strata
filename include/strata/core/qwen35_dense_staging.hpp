// CPU side of Strata's GGUF-backed dense token embedding staging.
// Used by the CUDA engine and checked independently without a GPU.
#pragma once

#include <cstddef>
#include <cstdint>
#include <cstring>
#include <algorithm>

namespace strata::core {

// Invalid/padding token IDs select row zero. The caller replaces image-pad
// embeddings with actual image rows after decoding, as in the resident path.
inline bool qwen35_gather_embedding_rows(const std::uint8_t* table,
                                         std::size_t vocabulary,
                                         std::size_t row_bytes,
                                         const std::int32_t* ids,
                                         std::size_t count,
                                         std::uint8_t* output) {
    if (!table || !ids || !output || !vocabulary || !row_bytes) return false;
    for (std::size_t i = 0; i < count; ++i) {
        const std::int32_t token = ids[i];
        const std::size_t row = token >= 0 && (std::size_t) token < vocabulary
            ? (std::size_t) token : 0;
        std::memcpy(output + i * row_bytes, table + row * row_bytes, row_bytes);
    }
    return true;
}

constexpr std::size_t qwen35_head_tile_bytes(std::size_t rows,
                                            std::size_t bytes_per_row,
                                            std::size_t tile_rows = 4096) {
    return std::min(rows, tile_rows) * bytes_per_row;
}

} // namespace strata::core

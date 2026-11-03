#include "strata/core/qwen35_dense_staging.hpp"

#include <array>
#include <cstdint>
#include <cstdio>

int main() {
    constexpr std::size_t rows = 12, width = 37;
    std::array<std::uint8_t, rows * width> table{};
    for (std::size_t row = 0; row < rows; ++row)
        for (std::size_t col = 0; col < width; ++col)
            table[row * width + col] = (std::uint8_t) ((row * 19 + col * 7) & 255);

    const std::array<std::int32_t, 7> tokens{{3, 11, -1, 12, 0, -70, 7}};
    const std::array<std::size_t, 7> want{{3, 11, 0, 0, 0, 0, 7}};
    std::array<std::uint8_t, tokens.size() * width> gathered{};
    bool ok = strata::core::qwen35_gather_embedding_rows(
        table.data(), rows, width, tokens.data(), tokens.size(), gathered.data());
    for (std::size_t i = 0; i < tokens.size(); ++i)
        for (std::size_t j = 0; j < width; ++j)
            if (gathered[i * width + j] != table[want[i] * width + j]) ok = false;
    if (strata::core::qwen35_gather_embedding_rows(
            table.data(), rows, width, nullptr, tokens.size(), gathered.data()))
        ok = false;

    const bool tile = strata::core::qwen35_head_tile_bytes(250000, 2304) == 4096u * 2304u &&
                      strata::core::qwen35_head_tile_bytes(200, 2304) == 200u * 2304u;
    std::printf("GGUF embedding row gather: %s\n", ok ? "ok" : "FAILED");
    std::printf("Vocabulary head tile sizing: %s\n", tile ? "ok" : "FAILED");
    return ok && tile ? 0 : 1;
}

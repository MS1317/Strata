// CPU-only reference and memory accounting test for dense Qwen3.5 cache.
// No GPU, model weights or external downloads are required.
#include "strata/core/qwen35_kv_q8.hpp"

#include <array>
#include <cmath>
#include <cstdint>
#include <cstdio>
#include <random>

using namespace strata::core;

int main() {
    int errors = 0;
    auto verify = [&](const char* label, const std::array<float, kQwen35KvWidth>& src) {
        const Qwen35KvRecordQ8 compressed = qwen35_q8_encode(src.data());
        std::array<float, kQwen35KvWidth> output{};
        qwen35_q8_decode(compressed, output.data());
        bool ok = std::isfinite(compressed.scale) && compressed.scale > 0.f;
        for (std::size_t i = 0; i < src.size(); ++i) {
            if (compressed.codes[i] < -127 || compressed.codes[i] > 127 ||
                !std::isfinite(output[i]) ||
                std::fabs(src[i] - output[i]) > compressed.scale * 0.51f + 0.000001f)
                ok = false;
        }
        std::printf("Qwen35 KV Q8 %-22s %s\n", label, ok ? "ok" : "FAILED");
        if (!ok) ++errors;
    };

    std::array<float, kQwen35KvWidth> v{};
    verify("all zeros", v);

    for (std::size_t i = 0; i < v.size(); ++i) v[i] = i % 2 ? 1.5f : -1.5f;
    verify("alternating", v);

    for (std::size_t i = 0; i < v.size(); ++i)
        v[i] = (static_cast<float>(i) - 128.f) / 64.f;
    verify("linear range", v);

    std::mt19937 random(12345);
    std::uniform_real_distribution<float> values(-80.f, 80.f);
    for (int k = 0; k < 32; ++k) {
        for (float& x : v) x = values(random);
        verify("random range", v);
    }

    const std::uint64_t q8 = qwen35_q8_cache_bytes(8, 4, 65536);
    const std::uint64_t f32 = qwen35_f32_cache_bytes(8, 4, 65536);
    const bool sizes_ok = q8 == 1090519040ull && f32 == 4294967296ull && q8 < f32 / 3;
    std::printf("Qwen35 KV Q8 64K size          %s (Q8 %llu bytes, FP32 %llu bytes)\n",
                sizes_ok ? "ok" : "FAILED", (unsigned long long) q8, (unsigned long long) f32);
    if (!sizes_ok) ++errors;
    return errors ? 1 : 0;
}

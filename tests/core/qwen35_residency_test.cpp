#include "strata/core/qwen35_residency.hpp"
#include <cstdio>

int main() {
    using namespace strata::core;
    constexpr std::size_t M = q35_mib;
    Qwen35ResidencyPolicy p{};
    int failed = 0;
    auto check = [&](bool truth, const char* name) {
        std::printf("Qwen35 cache policy %-38s %s\n", name, truth ? "ok" : "FAILED");
        failed += !truth;
    };

    check(p.desired_cache(2800 * M, 0) == 1776 * M, "leave 1GB free at startup");
    check(p.can_admit(2800 * M, 400 * M, 0, 0), "admit first large tensor");
    check(!p.can_admit(1250 * M, 400 * M, 0, 0), "avoid stealing VRAM reserve");
    check(!p.can_admit(2800 * M, 500 * M, 1800 * M, 0), "never exceed 2GB cache cap");
    check(p.can_admit(2200 * M, 64 * M, 500 * M, 128 * M), "limited admission batches");
    check(!p.can_admit(2200 * M, 160 * M, 500 * M, 128 * M), "reject overly large growth");
    check(p.should_reclaim(500 * M, 1700 * M), "reclaim when other apps need VRAM");
    check(!p.should_reclaim(920 * M, 1700 * M), "avoid unnecessary cache churn");
    check(p.desired_cache(500 * M, 1200 * M) == 676 * M, "reclaim to keep 1GB free");
    check(p.desired_cache(0, 0) == 0, "no spare VRAM");
    check(!p.should_reclaim(100 * M, 0), "empty cache does not reclaim");
    p.max_cache_bytes = 0;
    check(!p.can_admit(3600 * M, 8 * M, 0, 0), "manual cap can disable cache");
    return failed ? 1 : 0;
}

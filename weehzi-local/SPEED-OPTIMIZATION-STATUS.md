# Speed optimization — Qwen3.5 9B on GTX 1650

## Priority

**Speed first at 4096-token context.** Do not attempt 32K/64K context expansion, automatic RAM/SSD caches, or stress the user's currently running workload during this step.

## Baseline

The existing GPU-first model is running on the user's PC, using roughly 2.8 GiB of the 4 GiB VRAM; approximately 1 GiB is reserved for other applications. One measured local API request generated 16 tokens at **1.6 tokens/sec** with prompt speed 14.4 tokens/sec. A separate 8-token CLI test measured **2.0 tokens/sec**. These numbers use different prompts and cannot be directly compared.

The 9B GGUF occupies ~5.68 GB. On 4 GB VRAM, several gigabytes of dense weights have to be transferred on every token. This makes transfers and per-matrix dispatch major potential bottlenecks.

## Optimization A — one-pass cached output projection

In `src/qwen35/q36_engine.cu`, if the output vocabulary weights already reside on the GPU, invoke `native_mmvq` **once** over the full head, writing directly into the existing logits buffer. Previously, even with the head resident, the engine processed its vocabulary in 4096-row tiles and launched/copy-assembled each tile. The direct fast path adds no GPU allocations, no CPU weight duplication and keeps the existing exact same weight representation.

**Fallback retained:** When head weights are not resident, use the original tiled implementation, including its small bounded GPU staging allocation. The fast path is part of the new experiment only, not the older running GPU-first executable.

## Build / safety

- CUDA 12.8 / sm_75 object compilation **passed** on GitHub for commit `8c229ad5`, run [41780090636](https://github.com/MS1317/Strata/actions/runs/41780090636).
- Hosted Windows build **PASSED**: [run 41780056705](https://github.com/MS1317/Strata/actions/runs/41780056705), commit `8c229ad5`. Executable-only artifact successfully downloaded and installed on the PC.
- Installed as **`strata-q36-head-fast.exe`**, next to both older working executables. Windows executed its usage/help output successfully without loading model weights. `weehzi-local/Install-Head-Fast.ps1 -RunId 41780056705` is available for reinstall/repair.
- Launch only when the existing Strata server has been stopped **by the user**: `Run-Strata-Weehzi-Head-Fast.cmd`.
- Existing resource safeguards remain: at least 7 GiB free RAM, at least 2300 MiB free VRAM before starting; 1024 MiB preferred VRAM reserve as GPU cache grows.

## Required before declaring success

1. Build the Windows executable and verify that it starts with `--help`, without loading model weights.
2. When safe and when the user stops the currently running server, run the **same exact model / token prompt** on original GPU-first and head-fast. Use `weehzi-local/Compare-Head-Fast.ps1 -Tokens 32` to automate the pair, with safety checks and logged results. Check tokens produced are identical; repeat at least three times if resources allow. Keep both input and settings identical.
3. Send a short real chat through the API; confirm that `content` is populated and response is correct. Record actual prompt and output speeds. Confirm free VRAM stays above the reserved budget.
4. If direct full-head kernel fails, **roll back immediately** to the existing `Run-Strata-Weehzi-GPU-First.cmd` rather than changing Weehzi or its application settings.
5. If speed gain is small, profile per-token copied bytes, time in CUDA weight transfers and time in GPU kernels; consider pinned-memory pipelining only with explicit buffer limits and correctness tests. NVIDIA documentation notes truly asynchronous host-to-device transfers need pinned host memory and separate streams to overlap with computation. Do **not** pin the whole 5.68GB model on this multitasking PC.

## Status

CUDA source compiles, Windows executable builds, downloads, and launches. **Real-world speed gain from this new output-head change has not yet been measured.** The original GPU-first server is still active on port 18084 and was not restarted. A concurrent second 9B model would compete for VRAM, so the comparison has intentionally not run. Do not claim improvement until a matched baseline on the PC is completed.

Recent existing GPU-first logs show approximately **92 GiB of additional staged model-weight transfers over 30 generated tokens** (cumulative totals of 60.40 GiB and 152.49 GiB across two successive calls); the transfer bottleneck is substantial. If the faster output head alone helps little, the next experiment should use bounded pinned-memory staging and overlap transfers with compute, not reserve all GPU VRAM or 20 GB of system RAM.

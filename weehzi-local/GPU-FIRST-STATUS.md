# GPU-first Strata for this Windows PC

**State (4 November 2026):** Source, CPU policy tests, CUDA compilation, hosted Windows build and on-PC **executable installation** are complete. The new GPU-first engine still needs real-model inference, memory-pressure and speed tests.

## Agreed behavior

- **1A — Other applications get priority.** If free VRAM falls too low, Strata releases *extra cached copies* of model weights. During idle time it checks every 2 seconds. During inference it checks at each forward step. No apps or services are closed.
- **2A — Speed before long context.** First measure Qwen3.5 9B at 4,096 tokens and compare against the original working binary. Only then work on larger contexts.
- **3A — Automatic memory use.** Cached GPU weights have a configurable ceiling and safety reserve, but Strata chooses how much to keep based on actual available VRAM.

## What changed

Qwen3.5 9B is dense: its layers are needed for almost every token. Storing a large enough selection of weights directly on the GPU saves repeated transfers. The cache keeps the output-vocabulary weights first, then the largest layer matrices. GPU kernels run as before; only where weights come from changes.

A matrix already cached on the GPU uses its resident pointer. An uncached matrix still uses the original single-matrix staging buffer, which is our correctness fallback. CUDA work and copies share a stream. Cache eviction synchronizes that stream before freeing GPU memory.

### Default GPU policy

| Item | Default |
| --- | ---: |
| Extra resident GPU model-weight cache maximum | 2,048 MiB |
| Desired free GPU memory remaining | 1,024 MiB |
| Release cached weights when free GPU memory drops below | 768 MiB |
| Max new cache filled on an ordinary forward step | about 256 MiB |
| Idle pressure check | every 2 seconds |

These are **additional model-weight cache limits**, not the total GPU utilization. Buffers, context memory, Windows and other apps already occupy VRAM. GPU capacity does not mean that all 4 GiB should be filled. No process can guarantee that an unrelated application's sudden allocation will always succeed; Strata prioritizes maintaining a substantial reserve.

The model remains stored in a GGUF memory-mapped file. Windows automatically uses spare RAM for mapped file pages and sends pages back to SSD when RAM is required elsewhere. **There is no new 20 GB RAM allocation**, no large pinned CPU copy of the model and no custom SSD swap system. That would risk the user's other applications. This is intentionally leaner than a generic three-tier cache.

Optional per-process overrides, for advanced troubleshooting: `STRATA_Q35_GPU_CACHE_MB` (0–2048; 0 disables cache) and `STRATA_Q35_GPU_KEEP_FREE_MB` (768–2048; default 1024). The normal launch scripts work without setting them.

## Current tested baseline (original executable)

- Qwen3.5 9B Q4 GGUF and tokenizer are already installed.
- The original `Run-Strata-Weehzi.cmd` successfully starts a 4K localhost server.
- Basic requests produced correct visible answers when thinking mode was disabled.
- Previously observed output speed: approximately **0.6–1.4 tokens/sec** with the uncached version. These are small, non-standardized tests, **not** a controlled benchmark.

The new GPU-first executable **launches** on the PC, and the configuration correctly points to it, but real 9B inference has **not** been run with this version. We do **not** claim any speed improvement yet.

## How to resume safely

1. Windows build **passed**: [GitHub Actions run #41775473477](https://github.com/MS1317/Strata/actions/runs/41775473477). Its 62 MB executable-only artifact was installed as `strata-q36-gpu-first.exe`. Windows verified it can launch and display its usage information. No model was loaded during this verification.
2. **The installation is already done.** The one-click `Install-Strata-Weehzi-GPU-First.cmd` remains available for repeat installation or repair if required; it does not overwrite the original executable. No additional download is needed now.

3. **When ready to test**, stop the *Strata terminal only* with Ctrl+C if it happens to be running. Do not stop any other apps, Wi-Fi or Tailscale. At the last check, port 18084 was unused.
4. Run `Run-Strata-Weehzi-GPU-First.cmd`. It checks free RAM (minimum 7 GiB), free GPU VRAM (minimum 2,300 MiB) and that port 18084 is unused before launching. A refusal to start is a useful safety outcome, not a reason to force it.
5. With the GPU-first server ready, run:

   ```powershell
   .\weehzi-local\Benchmark-Strata-Weehzi.ps1 -MaxTokens 16
   ```

6. Record visible answer correctness, prompt and generation speed, and the new `strata-q36 GPU cache` lines in `Strata-Weehzi-data\logs\strata-q36.log`. Repeat the **same** benchmark with the original launcher if desired. A speed test with an empty or incorrect answer is not a pass.

**Rollback:** Ctrl+C in the GPU-first terminal, then run the original `Run-Strata-Weehzi.cmd`. The original binary and model remain unchanged.

## Existing process safety

The previous server is deliberately **not restarted** by any source or script modification. The GPU-first code takes effect only when its own executable is explicitly launched. Longer-context tests, tool calling, performance tuning and any modifications to Weehzi are separate work.

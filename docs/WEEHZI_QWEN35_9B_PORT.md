# Weehzi local-model experiment — Strata + Qwen3.5 9B

**Status: experimental; real 9B inference is NOT proven working yet.**

This branch extends Strata for **one user's Windows PC**: Ryzen 5 4600H, 24 GB installed RAM, GTX 1650 with 4 GB VRAM.

## Confirmed goals and boundaries

- **Personal use only**, not a model server for other Weehzi users.
- **Balanced response speed and accuracy**. Successful Weehzi tool actions matter more than benchmark claims.
- **Protect existing applications**. Never close programs, stop services, change drivers, or force GPU memory oversubscription.
- **Model:** Qwen3.5 9B in GGUF Q4 quantization, to be verified against a concrete real checkpoint.
- **Context:** first 32K, target 64K, experimental 128K only if practical.
- Evaluate Weehzi's *real* provider request (system instructions, native and external tool schemas, skills, memory, chat history, tool outputs); do **not** count QA-worker `CLAUDE.md` as part of the model's prompt.
- Run just one inference request at once for initial validation.
- Weehzi and its QA worker repositories remain unchanged. Work is confined to `MS1317/Strata` branch `feat/qwen35-9b-long-context`.

## Foundation

This branch retains the unmerged dense-Qwen work from upstream PR [Niko1221/Strata#4845](https://github.com/Niko1221/Strata/pull/4845). The contributor's GTX 1650 test used a smaller dense model with a very short context, and should **not** be treated as a 9B/64K benchmark.

Synthetic GGUF header tests check the planned Qwen3.5 9B dimensions (32 layers, hidden size 4096, FFN 12288, 16 attention heads, 4 KV heads, 8 full-attention layers, 24 recurrent layers).

## Implemented

1. **GGUF-backed dense weights:** Quantized matrices stay in the mapped model file until used. A reusable GPU allocation stages one matrix at a time in stream order; CUDA graphs are disabled for this path. This avoids loading all 9B weights into VRAM. All matrix arithmetic still runs on the GPU, not the CPU.
2. **Bounded embeddings:** Instead of uploading the entire vocabulary embedding table, the engine copies only the requested token rows into a small GPU buffer and invokes the existing embedding decoder.
3. **Tiled output head:** The large vocabulary output matrix is processed in tiles of at most 4096 rows, with the output assembled before token selection. No full-head GPU allocation is required in streaming mode.
4. **Q8 attention history:** For streaming dense models, each 256-element key/value vector uses 256 signed bytes plus one 32-bit scale (260 bytes). The GPU writes and reads Q8 during decode, dequantizes to temporary FP16 buffers during prompt processing, and supports session-state copies. Resident MoE models retain their original FP32 cache.
5. **Protective GPU preflight:** The engine estimates context cache, staging, attention scratch and reserve before allocating, and refuses a configuration exceeding the GPU memory available at that moment. This is a conservative estimate, not a proof of safe allocation or a guaranteed peak.
6. **Reduced decode scratch:** Split-K attention scratch now holds at most eight simultaneous decode/verify rows (the actual consumer's maximum), instead of reserving room for 64. At 64K context with 16 attention heads, this reduces its main float32 partial buffer from about 256 MiB to about 32 MiB.
7. **Skip unnecessary MTP:** Optional draft-layer weights are not loaded in dense streaming mode unless explicitly requested.

### Conversation cache at 64K — Qwen3.5 9B (one session, eight attention layers)

| Cache | Approximate storage only |
| --- | ---: |
| Original FP32 | 4.00 GiB |
| Experimental per-vector Q8 | 1.016 GiB |

*The Q8 figure excludes the temporary FP16 buffers, attention scratch, dense weight staging, recurrent state and CUDA overhead.* This can still exceed the **free** VRAM of a 4 GB card once everything is added. The current preflight is intentionally willing to refuse 64K to protect other running applications.

## Verification completed

- GitHub-hosted **CPU-only** tests for synthetic Qwen3.5-9B metadata.
- GitHub-hosted **CPU-only** Q8 reference compression and 64K memory accounting test.
- GitHub-hosted **CPU-only** mapped-embedding row-gather and output-head tile-size test.
- GitHub-hosted **CUDA 12.8 object compilation** (`nvcc -std=c++20 -arch=sm_75`) has passed for the GPU-cache, embedding-staging and tiled-output-head implementation. Re-run it after later code changes and check the exact commit.

A passing CPU test and a successful CUDA object compilation do **not** establish inference correctness. No real 9B model has been downloaded or run.

## Still required (ordered)

1. **Compile the latest branch and link the whole engine.** Fix regressions before any real model testing.
2. **Validate the new GPU paths:** Start on a small/test GGUF without a long context. Compare output token-by-token and logits against a trusted llama.cpp reference with matching quantization and decoding settings. Include multiple turns and error/cancellation tests.
3. **Test Qwen3.5 9B at short context.** Check correct output, memory footprint, multi-step tool calls and stability. Avoid monopolizing the live PC; don't run if resource headroom is insufficient.
4. **Work upward: 16K → 32K → 64K → possibly 128K.** Measure actual task completion, throughput, time to first token, prefill time, KV cache, peak VRAM and available RAM.
5. **Tune speed:** Current file-backed weight copies and host embedding-row gathering prioritize correctness over speed. Evaluate safe layer residency, less copying, and cache quality only after accurate results.
6. **Connect via Weehzi's OpenAI-compatible provider** and run actual tool-heavy QA scenarios, using the full provider payload rather than a toy prompt.

## Do not do without a separate decision

- Modify Weehzi or Weehzi-QA-Worker.
- Download the multi-gigabyte GGUF to the active PC.
- Install or change CUDA/NVIDIA drivers.
- Stop or alter existing applications, network connections or background processes.
- Advertise Qwen3.5 9B / 64K as working until measured on the actual system.

The fork is public under upstream's MIT license. This is research-stage engine code, not a released local-model solution.

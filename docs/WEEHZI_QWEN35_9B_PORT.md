# Weehzi local-model prototype: Qwen3.5 9B on a GTX 1650

**Status:** experimental; not working 9B inference yet.

## Goal

Use a separate fork of Strata as an OpenAI-compatible **local model server** for Weehzi. The machine is a Ryzen 5 4600H (6C/12T), 24 GB installed RAM, NVIDIA GTX 1650 (4 GB VRAM), Windows.

- Model: Qwen3.5 9B, GGUF Q4_K_M initially (about 5.6 GB download; verify the exact file).
- First full Weehzi context target: 32K tokens.
- Main target: 64K tokens. 128K is a stretch experiment, not a performance promise.
- The model must receive Weehzi's *actual provider request*, including the real system prompt, tool definitions, memory, ongoing conversation and tool outputs.
- Do not mistake the QA worker's `CLAUDE.md` (instructions for its developer agent) for the prompt sent to the local model.
- One request at a time initially. Reliability and correct tool calls matter more than a synthetic tokens-per-second headline.

## What exists

This branch starts from upstream dense Qwen support proposed in Niko1221/Strata#4845, preserving contributor history. That work demonstrated Qwen 4B on a GTX 1650 but only with a short GPU-resident context.

The added 9B **header-only unit checks** cover the GGUF's 32 layers, hidden size 4096, FFN size 12288, 16 Q heads, 4 KV heads, 8 full-attention layers and 24 Gated DeltaNet layers.

A **GPU-memory preflight** now refuses a dense model whose packed weights plus a minimal reserve cannot fit the currently free VRAM. This prevents an avoidable partial-load crash; it does **not** provide CPU/GPU offloading.


## Confirmed project decisions (3 November 2026)

- **Personal use only:** run the local provider on the owner's Windows PC. No multi-user hosting or distribution work.
- **Balanced:** prefer acceptable response time and reliable tool choices over highest parameter count.
- **No interference:** don't stop services, close applications, modify NVIDIA drivers, or allocate enough RAM/VRAM to risk existing work. Use GitHub-hosted tests before any GPU benchmark.

## Implemented in this branch

- Merged the unmerged dense Qwen family work from upstream PR #4845 into the fork's feature-branch ancestry.
- Added synthetic Qwen3.5-9B GGUF geometry checks. **CPU-only GitHub Actions check passed**: https://github.com/MS1317/Strata/actions/runs/41572456482 . No actual model was downloaded or run.
- Experimental **file-backed matrix streaming**: the dense matrix tensors remain backed by GGUF memory mapping. A single reusable GPU staging allocation receives each matrix before its kernel reads it. All staging copies and GPU kernels use one CUDA stream to preserve ordering; CUDA graph capture is disabled in this mode. This is GPU computation with CPU/storage-backed weights, **not** native CPU matmul offloading.
- Dense model startup checks packed weights and selects streaming automatically when they cannot fit VRAM. It avoids optional MTP-layer loading in streaming mode unless requested.
- GPU preflight rejects contexts whose FP32 K/V cache plus staging and an allowance for buffers already exceed free VRAM. The threshold is conservative, **not** an exact allocator prediction.

## Known blocking limitation

The current Qwen35 engine stores K/V as float32 on the GPU. For Qwen3.5 9B's eight full-attention layers, this alone requires about **2 GiB at 32K** and **4 GiB at 64K**. Therefore **64K cannot work on this GTX 1650 until K/V cache storage is redesigned** (for example quantized or RAM-backed K/V). Streaming the model weights alone does not solve it.

Further required validation: CUDA compilation, startup on a small test GGUF, real Qwen3.5-9B token parity, repeated calls, long context quality, tool calls and measured latency. None have passed yet.

## Work remaining, in order

1. **Validate file-backed dense matrix staging.** The first implementation exists, but has not been CUDA-compiled or tested with a real GGUF. Verify every weight path, CUDA stream ordering, OOM handling and output correctness.
2. **Improve streaming performance.** The first version transfers one matrix at a time for correctness. Test selective GPU residency and overlap only after establishing a reliable baseline.
3. **Validate model correctness.** Compare small prompts and token sequences against llama.cpp with identical GGUF and decoding settings; test attention state and an untied output head. Check long output and a second request in the same chat.
4. **Add larger contexts.** Budget the recurrent state, attention KV cache, output buffers, model weights, Windows memory use and CPU/GPU transfers separately. Begin with a short smoke test; then 32K, 64K and optionally 128K. Try quantized KV only after correctness is established.
5. **Connect Weehzi via the existing OpenAI-compatible API.** Check streaming responses, native tool calls, error handling, compaction and sustained multistep agent sessions. Measure the actual request token count, not just base.md or `CLAUDE.md`.
6. **Benchmark on the target PC.** Report time to first token, prompt processing time, output tokens/sec, peak RAM, peak VRAM, pagefile use, tool-call accuracy and task success. Compare with llama.cpp on the exact same model and hardware.

## Boundaries

- No modifications to the Weehzi or QA-worker repositories as part of this Strata port.
- No model downloads, GPU driver updates, background services or interruption of existing applications without a separate decision.
- Do not claim 9B / 64K works until it passes real inference and Weehzi tool-call tests.
- Keep upstream Strata's main branch unchanged; all experimental changes belong to this fork/feature branch.

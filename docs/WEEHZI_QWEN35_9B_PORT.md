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

## Work remaining, in order

1. **Implement dense weight staging.** Currently `src/qwen35/q36_engine.cu` allocates every dense matrix with `cudaMalloc`. Plan each layer's GPU/RAM placement using real GGUF tensor sizes. Keep a bounded GPU staging area, upload a needed matrix/layer at execution time, and reuse the buffers. Never treat regular dense layers as MoE experts.
2. **Make streaming safe with inference scheduling.** Synchronize CUDA work before reusing staged memory; avoid stale CUDA graph pointers; make loading, cancellation and repeated calls safe. Start with a correctness-oriented slower path.
3. **Validate model correctness.** Compare small prompts and token sequences against llama.cpp with identical GGUF and decoding settings; test attention state and an untied output head. Check long output and a second request in the same chat.
4. **Add larger contexts.** Budget the recurrent state, attention KV cache, output buffers, model weights, Windows memory use and CPU/GPU transfers separately. Begin with a short smoke test; then 32K, 64K and optionally 128K. Try quantized KV only after correctness is established.
5. **Connect Weehzi via the existing OpenAI-compatible API.** Check streaming responses, native tool calls, error handling, compaction and sustained multistep agent sessions. Measure the actual request token count, not just base.md or `CLAUDE.md`.
6. **Benchmark on the target PC.** Report time to first token, prompt processing time, output tokens/sec, peak RAM, peak VRAM, pagefile use, tool-call accuracy and task success. Compare with llama.cpp on the exact same model and hardware.

## Boundaries

- No modifications to the Weehzi or QA-worker repositories as part of this Strata port.
- No model downloads, GPU driver updates, background services or interruption of existing applications without a separate decision.
- Do not claim 9B / 64K works until it passes real inference and Weehzi tool-call tests.
- Keep upstream Strata's main branch unchanged; all experimental changes belong to this fork/feature branch.

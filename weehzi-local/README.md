# Strata-Weehzi — Qwen3.5 4B (current local model)

This personal Windows experiment uses **Qwen3.5 4B Q4_K_M** on the GTX 1650. It replaces the previous 9B default because the 9B version spent too much time moving weights between memory and GPU.

## Main files

- Repository: `C:\Users\<WindowsUser>\Desktop\Dev\AI\Strata-Weehzi`
- **Current model**: `..\Strata-Weehzi-data\models\Qwen3.5-4B-Q4_K_M.gguf`
- New tokenizer: `..\Strata-Weehzi-data\qwen35-4b\tokenizer`
- Original executable: `weehzi-local\bin\strata-q36.exe`
- **Recommended GPU-first executable**: `weehzi-local\bin\strata-q36-gpu-first.exe`
- Optional output-head experiment: `weehzi-local\bin\strata-q36-head-fast.exe`
- Isolated Python: `.venv\Scripts\python.exe`
- Local API settings: `..\Strata-Weehzi-data\strata-weehzi.json`

Download source: `unsloth/Qwen3.5-4B-GGUF`, file `Qwen3.5-4B-Q4_K_M.gguf`, size **2,740,937,888 bytes**, official SHA-256 `00fe7986ff5f6b463e62455821146049db6f9313603938a70800d1fb69ef11a4`.

## Start the new 4B model

1. If still downloading, check progress with `Get-BitsTransfer -Name 'Strata-Weehzi Qwen3.5 4B'`.
2. Once the download says **Transferred**, run `powershell -NoProfile -ExecutionPolicy Bypass -File .\weehzi-local\Finalize-Model-Download.ps1`. This verifies the checksum before the GGUF can be used.
3. Run **`Run-Strata-Weehzi-GPU-First.cmd`** in the repository directory. It now defaults to **32K context (32,768 tokens)**. It checks free memory before starting and uses bounded GPU weight staging to avoid accidental VRAM exhaustion. If 32K cannot fit, run `Run-Strata-Weehzi-GPU-First.cmd -Context 16384` for **16K context**.
4. Open `http://127.0.0.1:18084/` for chat. To check status: `Check-Strata-Weehzi.cmd`.
5. To stop: **Ctrl+C inside the Strata terminal only**.

The local API is `http://127.0.0.1:18084/v1` with **model name `qwen3.5-4b-strata-weehzi`**. Any external client still configured for the old 9B model ID must be updated to that name.

Optional quick benchmark with the server already running:

```powershell
.\weehzi-local\Benchmark-Strata-Weehzi.ps1 -MaxTokens 32
```

Optional standalone matching-output comparison, only with the server stopped and ample free memory:

```powershell
.\weehzi-local\Compare-Head-Fast.ps1 -Tokens 32
```

## Confirmed replacement status

- Qwen3.5 4B Q4_K_M: downloaded, verified against its official SHA-256, and used successfully.
- Qwen3.5 4B tokenizer: extracted into a dedicated folder and passed 16 round-trip checks.
- Local server: successfully loaded model `qwen3.5-4b-strata-weehzi` and returned a correct normal chat response.
- Old 9B GGUF: **removed** after verification; the existing Strata executables and historical development logs are preserved.
- Temporary 4B test server: stopped cleanly. Start the regular launcher when you want to use it.

## Context length: 32K default, 16K fallback

The Strata engine already accepts `--max-context 32768`; no new GPU executable is required. Both `Prepare-Strata-Weehzi.ps1` and `Start-Strata-Weehzi.ps1` now default to `-Context 32768`, so the existing double-click launcher selects 32K on its next start.

**Important:** The currently running Strata process will keep the context size it was originally launched with (possibly 4K). No process is stopped or restarted just by changing these files. When ready, stop **only** Strata with Ctrl+C in its own terminal and launch it again. Verify the new value with `Check-Strata-Weehzi.cmd` or `http://127.0.0.1:18084/health`.

If 32K fails its GPU memory preflight, try:

```powershell
.\Run-Strata-Weehzi-GPU-First.cmd -Context 16384
```

This uses 16K, rather than trying to force 32K by taking memory from other applications.

The engine uses 8-bit compressed conversation cache. The 4K cache previously took about 0.06 GiB and the 32K cache is estimated around 0.5 GiB, plus additional temporary GPU buffers. **32K and 16K real-model sessions have not yet been validated;** the preflight safety check is not a performance guarantee. Long prompts may take substantially longer than short prompts.

## Protections and limits

- Only localhost can connect.
- The launcher checks at least 7 GiB free system RAM, 2300 MiB free GPU memory, and that the API port is unused; it never closes other applications.
- GPU-first uses adaptive model-weight caching (up to 2048 MiB extra), aiming for at least 1024 MiB free VRAM when possible. Windows handles RAM caching and SSD paging; Strata does not reserve 20 GB of RAM.
- No changes to drivers, CUDA installations, Wi-Fi, Tailscale, Weehzi source or existing services.
- The 9B GGUF was deleted on November 4, 2026 **after** 4B passed checksum, tokenizer round-trip checks, a 16-token native generation test, and a normal API chat response. Earlier 9B benchmark records remain available as project history.
- The 4B engine generated 16 tokens at **5.1 tokens/second** in a standalone CLI test. A separate API request answered "2 plus 2 equals 4" correctly at **2.9 tokens/second** (9 output tokens). These short tests are not a controlled quality benchmark.
- Weehzi tool use, sustained speed, and 32K/64K context remain **unverified**.

Development history: [GPU-FIRST-STATUS.md](GPU-FIRST-STATUS.md) and [SPEED-OPTIMIZATION-STATUS.md](SPEED-OPTIMIZATION-STATUS.md) document the earlier 9B experiments.

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
3. Run **`Run-Strata-Weehzi-GPU-First.cmd`** in the repository directory. It checks free memory before starting and forces bounded GPU weight staging to avoid accidental VRAM exhaustion. The first target remains **4K context**.
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

## Protections and limits

- Only localhost can connect.
- The launcher checks at least 7 GiB free system RAM, 2300 MiB free GPU memory, and that the API port is unused; it never closes other applications.
- GPU-first uses adaptive model-weight caching (up to 2048 MiB extra), aiming for at least 1024 MiB free VRAM when possible. Windows handles RAM caching and SSD paging; Strata does not reserve 20 GB of RAM.
- No changes to drivers, CUDA installations, Wi-Fi, Tailscale, Weehzi source or existing services.
- 9B checkpoint and earlier benchmark records are historical. The 9B GGUF is only deleted after 4B passes validation and is no longer needed by a running process.
- **Do not assume improved 4B speed or quality until a real 4B inference test succeeds.** Weehzi tool use and 32K/64K context are separate, unverified goals.

Development history: [GPU-FIRST-STATUS.md](GPU-FIRST-STATUS.md) and [SPEED-OPTIMIZATION-STATUS.md](SPEED-OPTIMIZATION-STATUS.md) document the earlier 9B experiments.

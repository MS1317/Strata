# Run experimental Strata / Qwen3.5 9B on this PC

This setup is **personal and experimental**. It lives separately from Weehzi.

## Files

- Repository: `C:\Users\manpr\Desktop\Dev\AI\Strata-Weehzi`
- Model: `C:\Users\manpr\Desktop\Dev\AI\Strata-Weehzi-data\models\Qwen3.5-9B-Q4_K_M.gguf`
- Windows executable: `weehzi-local\bin\strata-q36.exe`
- Virtual Python: `.venv\Scripts\python.exe`
- API configuration: `C:\Users\manpr\Desktop\Dev\AI\Strata-Weehzi-data\strata-weehzi.json`
- Engine/server log: `C:\Users\manpr\Desktop\Dev\AI\Strata-Weehzi-data\logs\strata-q36.log`

**Qwen3.5 GGUF**: `unsloth/Qwen3.5-9B-GGUF`, Q4_K_M, exact SHA256 `03b74727a860a56338e042c4420bb3f04b2fec5734175f4cb9fa853daf52b7e8`.

## Start and stop

1. Double-click `Run-Strata-Weehzi.cmd` at the repository root.
2. The first run verifies the already-downloaded model, extracts its tokenizer and prepares the local server settings. It starts with **4,096 context tokens**.
3. Leave the terminal open. Use `Check-Strata-Weehzi.cmd` in another window to check whether the server responds.
4. Press **Ctrl+C** in the **Strata terminal only** to shut it down. Do not close other applications.

Advanced: from Command Prompt in the repository, `Run-Strata-Weehzi.cmd -Context 8192` chooses 8K. Later, if tests and resource measurements support it, try `-Context 16384`, `32768` or `65536`.

The launcher **refuses to start** if there is less than 7 GiB available RAM or less than 2,300 MiB free VRAM, or if its local port is already taken. The C++ engine also estimates GPU memory before allocating. Those checks are safeguards, **not guarantees** against GPU load or slowdowns. Close no existing processes automatically.

## Connect Weehzi after successful inference testing

- API base URL: `http://127.0.0.1:18084/v1`
- Model ID: `qwen3.5-9b-strata-weehzi`
- API is bound to **localhost only**. It has no key because no other devices can connect.
- The server's OpenAI-compatible `/v1/chat/completions` route can be tested using `curl` or any compatible client.

Do **not** switch Weehzi's primary provider until this fork completes real-model token correctness tests and tool-calling tests. A source compile is not enough.

## What is and isn't ready

- Host-specific Python venv and dependencies: installed
- Windows engine: depends on the GitHub Actions build artifact; install only the build from the fork's feature branch
- Model: download through Windows BITS at low priority, then verify SHA256. The launcher calls `Finalize-Model-Download.ps1` for a completed transfer.
- Real Qwen3.5-9B answers: not yet verified
- 32K / 64K: engineering targets, not guaranteed running configurations

For download progress, in PowerShell:
```powershell
Get-BitsTransfer -Name 'Strata-Weehzi Qwen3.5 9B' |
  Select-Object JobState,BytesTransferred,BytesTotal
```

For an error, consult the terminal output and Strata log. A file ending in `.part` or `.bits` is incomplete and must not be used directly.

## Security and boundaries

The setup does not install CUDA development tools, alter NVIDIA drivers, stop existing services, change your Wi-Fi/Tailscale settings, or edit the Weehzi codebase. It only runs the isolated experimental Strata model when you explicitly launch it.

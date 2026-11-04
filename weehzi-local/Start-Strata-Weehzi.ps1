# Starts ONLY this experimental Qwen3.5 model server, in the current terminal.
# Ctrl+C ends the server. It does not stop other applications or services.
param(
    [ValidateSet(2048, 4096, 8192, 16384, 32768, 65536)]
    [int]$Context = 4096
)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$data = Join-Path (Split-Path -Parent $root) 'Strata-Weehzi-data'
$python = Join-Path $root '.venv\Scripts\python.exe'
$port = 18084

$ram = Get-CimInstance Win32_OperatingSystem
$freeRam = [int]($ram.FreePhysicalMemory / 1024) # KiB -> MiB
if ($freeRam -lt 7168) {
    throw "Not starting: only $freeRam MiB system RAM free (7 GiB required). Close no apps automatically."
}

$gpuText = @(& nvidia-smi --query-gpu=memory.free --format=csv,noheader)
if ($LASTEXITCODE -ne 0 -or !$gpuText) { throw 'Cannot read GPU free VRAM using nvidia-smi' }
$match = [regex]::Match([string]$gpuText[0], '^\s*(\d+)')
if (!$match.Success) { throw "Unexpected nvidia-smi output: $gpuText" }
$freeVram = [int]$match.Groups[1].Value
if ($freeVram -lt 2300) {
    throw "Not starting: only $freeVram MiB VRAM free (2300 MiB required). Other GPU work was left untouched."
}

# No port takeover; don't affect anything already listening on 18084.
$listener = Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue
if ($listener) { throw "Local port $port is already in use. Refusing to interrupt the existing service." }

Write-Host "Available: $freeRam MiB RAM, $freeVram MiB VRAM. Preparing $Context token context..."
& (Join-Path $PSScriptRoot 'Prepare-Strata-Weehzi.ps1') -Context $Context
if ($LASTEXITCODE -ne 0) { throw 'Setup failed' }
$config = Join-Path $data 'strata-weehzi.json'
Write-Host 'Launching experimental model in this terminal. Press Ctrl+C to stop.'
Write-Host "API: http://127.0.0.1:$port/v1 | Model: qwen3.5-9b-strata-weehzi"
Push-Location $root
try {
    & $python -m serve.server --engine strata --config $config --host 127.0.0.1 --port $port
    if ($LASTEXITCODE -ne 0) { throw "Strata server exited with code $LASTEXITCODE; check the log in $data\logs" }
} finally { Pop-Location }

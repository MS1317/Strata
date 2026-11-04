# Starts ONLY this experimental Qwen3.5 model server, in the current terminal.
# Ctrl+C ends the server. It does not stop other applications or services.
param(
    [ValidateSet(2048, 4096, 8192, 16384, 32768, 65536)]
    [int]$Context = 32768,
    [switch]$GpuFirst,
    [switch]$HeadFast
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

Write-Host "Available: $freeRam MiB RAM, $freeVram MiB VRAM. Preparing Qwen3.5 4B at $Context tokens..."
if ($Context -ge 32768) {
    Write-Host '32K context selected. The GPU memory preflight will refuse unsafe configurations.'
    Write-Host 'If memory is insufficient, retry with -Context 16384 (16K fallback).'
}
& (Join-Path $PSScriptRoot 'Prepare-Strata-Weehzi.ps1') -Context $Context -GpuFirst:$GpuFirst -HeadFast:$HeadFast
if ($LASTEXITCODE -ne 0) { throw 'Setup failed' }
$config = Join-Path $data 'strata-weehzi.json'
# 4B may fit as weights but not once its working memory and context are counted.
# Retain the bounded GPU-first cache and conservative VRAM preflight on all versions.
$env:STRATA_Q35_STREAM_DENSE = '1'
if ($GpuFirst -or $HeadFast) {
    # Adaptive model-weight caching. These set maximums, not a demand to fill VRAM.
    # The engine continuously preserves its free-VRAM reserve and can give weights back.
    if (-not $env:STRATA_Q35_GPU_CACHE_MB) { $env:STRATA_Q35_GPU_CACHE_MB = '2048' }
    if (-not $env:STRATA_Q35_GPU_KEEP_FREE_MB) { $env:STRATA_Q35_GPU_KEEP_FREE_MB = '1024' }
    Write-Host "GPU-first: adaptive GPU cache up to $env:STRATA_Q35_GPU_CACHE_MB MiB; "
    Write-Host "           preserve at least $env:STRATA_Q35_GPU_KEEP_FREE_MB MiB VRAM when possible."
} else {
    Write-Host 'Starting original working binary (the GPU-first build is opt-in).'
}
Write-Host 'Launching experimental model in this terminal. Press Ctrl+C to stop.'
Write-Host "API: http://127.0.0.1:$port/v1 | Model: qwen3.5-4b-strata-weehzi"
Push-Location $root
try {
    & $python -m serve.server --engine strata --config $config --host 127.0.0.1 --port $port
    if ($LASTEXITCODE -ne 0) { throw "Strata server exited with code $LASTEXITCODE; check the log in $data\logs" }
} finally { Pop-Location }

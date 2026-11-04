# Creates the isolated local Strata server configuration. Does not launch the GPU.
param(
    [ValidateSet(2048, 4096, 8192, 16384, 32768, 65536)]
    [int]$Context = 32768,
    [switch]$GpuFirst,
    [switch]$HeadFast
)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$data = Join-Path (Split-Path -Parent $root) 'Strata-Weehzi-data'
$model = Join-Path $data 'models\Qwen3.5-4B-Q4_K_M.gguf'
$stableEngine = Join-Path $root 'weehzi-local\bin\strata-q36.exe'
$gpuFirstEngine = Join-Path $root 'weehzi-local\bin\strata-q36-gpu-first.exe'
$headFastEngine = Join-Path $root 'weehzi-local\bin\strata-q36-head-fast.exe'
$engine = if ($HeadFast) { $headFastEngine } elseif ($GpuFirst) { $gpuFirstEngine } else { $stableEngine }
$python = Join-Path $root '.venv\Scripts\python.exe'
$tokenizerRoot = Join-Path $data 'qwen35-4b'
$tokenizer = Join-Path $tokenizerRoot 'tokenizer'
$config = Join-Path $data 'strata-weehzi.json'
$logDir = Join-Path $data 'logs'
$log = Join-Path $logDir 'strata-q36.log'

# Always validate before launching; refuse incomplete or corrupted downloads.
& (Join-Path $PSScriptRoot 'Finalize-Model-Download.ps1')
if (!(Test-Path -LiteralPath $model)) {
    throw "4B model is missing or unverified: $model"
}
if (!(Test-Path -LiteralPath $engine)) {
    throw "Strata Windows build is missing: $engine"
}
if (!(Test-Path -LiteralPath $python)) {
    throw "Isolated Python environment missing: $python"
}
New-Item -ItemType Directory -Force -Path $logDir | Out-Null
if (!(Test-Path (Join-Path $tokenizer 'vocab.json'))) {
    Write-Host 'Extracting Qwen3.5 4B tokenizer from its verified GGUF (one-time operation)...'
    Push-Location $root
    try {
        New-Item -ItemType Directory -Force -Path $tokenizerRoot | Out-Null
        & $python (Join-Path $root 'tools\strata_tokenizer.py') --gguf $model --out $tokenizerRoot --check
        if ($LASTEXITCODE -ne 0) { throw 'Tokenizer extraction/round-trip check failed' }
    } finally { Pop-Location }
}
$settings = [ordered]@{
    exe = $engine
    args = @('--native', $model, '--max-context', [string]$Context, '--chunk', '128', '--no-graph', '--batch', '1')
    cwd = $root
    tokenizer = $tokenizer
    model_name = 'qwen3.5-4b-strata-weehzi'
    host = '127.0.0.1'
    port = 18084
    log = $log
    lazy_load = $false
    api_key = ''
    reasoning_effort = 'none' # Emit normal content by default for OpenAI-compatible clients
    fit_max_tokens = $true
    sampling = @{temperature = 0.6; top_p = 0.95}
}
[IO.File]::WriteAllText($config, ($settings | ConvertTo-Json -Depth 8), [Text.UTF8Encoding]::new($false))
Write-Host "Strata 4B configuration ready: $config"
Write-Host "Version: $(if ($HeadFast) {'GPU-first, fast output head (experimental)'} elseif ($GpuFirst) {'GPU-first experimental'} else {'Original working build'})"
Write-Host "Context: $Context | Address: http://127.0.0.1:18084/v1"

# Creates the isolated local Strata server configuration. Does not launch the GPU.
param(
    [ValidateSet(2048, 4096, 8192, 16384, 32768, 65536)]
    [int]$Context = 4096
)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$data = Join-Path (Split-Path -Parent $root) 'Strata-Weehzi-data'
$model = Join-Path $data 'models\Qwen3.5-9B-Q4_K_M.gguf'
$engine = Join-Path $root 'weehzi-local\bin\strata-q36.exe'
$python = Join-Path $root '.venv\Scripts\python.exe'
$tokenizer = Join-Path $data 'tokenizer'
$config = Join-Path $data 'strata-weehzi.json'
$logDir = Join-Path $data 'logs'
$log = Join-Path $logDir 'strata-q36.log'

if (!(Test-Path -LiteralPath $model)) {
    & (Join-Path $PSScriptRoot 'Finalize-Model-Download.ps1')
}
if (!(Test-Path -LiteralPath $model)) {
    throw "Model is not downloaded and verified: $model"
}
if (!(Test-Path -LiteralPath $engine)) {
    throw "Strata Windows build is missing: $engine"
}
if (!(Test-Path -LiteralPath $python)) {
    throw "Isolated Python environment missing: $python"
}
New-Item -ItemType Directory -Force -Path $logDir | Out-Null
if (!(Test-Path (Join-Path $tokenizer 'vocab.json'))) {
    Write-Host 'Extracting Qwen3.5 tokenizer from the GGUF file (one-time operation)...'
    Push-Location $root
    try {
        & $python (Join-Path $root 'tools\strata_tokenizer.py') --gguf $model --out $data --check
        if ($LASTEXITCODE -ne 0) { throw 'Tokenizer extraction/round-trip check failed' }
    } finally { Pop-Location }
}
$settings = [ordered]@{
    exe = $engine
    args = @('--native', $model, '--max-context', [string]$Context, '--chunk', '128', '--no-graph', '--batch', '1')
    cwd = $root
    tokenizer = $tokenizer
    model_name = 'qwen3.5-9b-strata-weehzi'
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
Write-Host "Strata configuration ready: $config"
Write-Host "Context: $Context | Address: http://127.0.0.1:18084/v1"

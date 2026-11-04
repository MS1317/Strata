# Check the configured local Strata model without changing any running process.
$ErrorActionPreference = 'Stop'
$hostUrl = 'http://127.0.0.1:18084'
try {
    $health = Invoke-RestMethod -Uri "$hostUrl/health" -TimeoutSec 5
} catch {
    Write-Host 'Strata is not responding on port 18084.' -ForegroundColor Yellow
    Write-Host 'Start it using Run-Strata-Weehzi-GPU-First.cmd.'
    exit 1
}
Write-Host "Strata API: $hostUrl/v1"
Write-Host "Model: $($health.model)"
Write-Host "Loaded: $($health.loaded)"
$health | ConvertTo-Json -Depth 6
if ($health.model -ne 'qwen3.5-4b-strata-weehzi' -or !$health.loaded) {
    Write-Warning 'The Qwen3.5 4B model is not loaded. Check which Strata version was started.'
    exit 2
}
Write-Host 'Qwen3.5 4B is ready.' -ForegroundColor Green

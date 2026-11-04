$ErrorActionPreference = 'Stop'
$hostUrl = 'http://127.0.0.1:18084'
try {
    $health = Invoke-RestMethod -Uri "$hostUrl/health" -TimeoutSec 5
    Write-Host 'Strata is responding at:' -ForegroundColor Green
    Write-Host "$hostUrl/v1"
    $health | ConvertTo-Json -Depth 8
    exit 0
} catch {
    Write-Host 'Strata is not serving on port 18084.' -ForegroundColor Yellow
    Write-Host 'Start it using Run-Strata-Weehzi.cmd. The server runs in that terminal.'
    exit 1
}

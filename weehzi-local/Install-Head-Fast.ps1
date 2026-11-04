# Installs a new speed-test binary alongside both working Strata executables.
# Does not stop/restart any running process.
param(
    [Parameter(Mandatory=$true)][long]$RunId,
    [ValidateRange(1,8)][int]$Retries=4
)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$data = Join-Path (Split-Path -Parent $root) 'Strata-Weehzi-data'
$stage = Join-Path $data "installer\head-fast-$RunId"
$bin = Join-Path $PSScriptRoot 'bin'
$target = Join-Path $bin 'strata-q36-head-fast.exe'
New-Item -ItemType Directory -Force -Path $stage,$bin | Out-Null
$info = & gh run view $RunId --repo MS1317/Strata --json status,conclusion,workflowName
if ($LASTEXITCODE -ne 0) { throw "Cannot inspect build $RunId" }
$run = $info | ConvertFrom-Json
if ($run.status -ne 'completed' -or $run.conclusion -ne 'success' -or
    $run.workflowName -ne 'Weehzi Strata Windows GTX1650 build') {
    throw "The requested run is not a successful Strata Windows build."
}
$exe = Join-Path $stage 'strata-q36.exe'
if (!(Test-Path $exe) -or (Get-Item $exe).Length -lt 30000000) {
    for ($try = 1; $try -le $Retries; $try++) {
        Write-Host "Downloading experimental fast-head executable (attempt $try/$Retries)"
        & gh run download $RunId --repo MS1317/Strata --name Strata-Weehzi-Q36-executable-only --dir $stage
        if ($LASTEXITCODE -eq 0 -and (Test-Path $exe) -and (Get-Item $exe).Length -gt 30000000) { break }
        Remove-Item $exe -Force -ErrorAction SilentlyContinue
        if ($try -lt $Retries) { Start-Sleep -Seconds 5 }
    }
}
if (!(Test-Path $exe) -or (Get-Item $exe).Length -lt 30000000) {
    throw "Download incomplete. Your running executable was not changed."
}
$sourceHash = (Get-FileHash $exe -Algorithm SHA256).Hash
if ((Test-Path $target) -and ((Get-FileHash $target -Algorithm SHA256).Hash -eq $sourceHash)) {
    Write-Host 'Fast-head binary already installed.'
    return
}
Copy-Item -LiteralPath $exe -Destination $target -Force
if ((Get-FileHash $target -Algorithm SHA256).Hash -ne $sourceHash) { throw 'Installed executable hash mismatch.' }
Write-Host "Installed: $target"
Write-Host 'Older Strata binaries, CUDA DLLs, and running processes remain unchanged.'

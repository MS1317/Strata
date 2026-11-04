# Installs only the GPU-first executable into a second filename.
# Never replaces a running DLL/exe or restarts the server.
param(
    [Parameter(Mandatory=$true)]
    [long]$RunId,
    [ValidateRange(1,8)]
    [int]$Retries=4
)
$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
$data = Join-Path (Split-Path -Parent $repo) 'Strata-Weehzi-data'
$stage = Join-Path $data ("installer\gpu-first-" + $RunId)
$bin = Join-Path $PSScriptRoot 'bin'
$target = Join-Path $bin 'strata-q36-gpu-first.exe'
New-Item -ItemType Directory -Force -Path $stage,$bin | Out-Null

$metadata = & gh run view $RunId --repo MS1317/Strata --json status,conclusion,workflowName,headSha
if ($LASTEXITCODE -ne 0) { throw "Can't read GitHub run $RunId." }
$run = $metadata | ConvertFrom-Json
if ($run.status -ne 'completed' -or $run.conclusion -ne 'success' -or
    $run.workflowName -ne 'Weehzi Strata Windows GTX1650 build') {
    throw "GitHub Windows build $RunId is not a successful completed Strata build."
}
$artifact = 'Strata-Weehzi-Q36-executable-only'
$exe = Join-Path $stage 'strata-q36.exe'
if (!(Test-Path -LiteralPath $exe) -or (Get-Item $exe).Length -lt 30000000) {
    for ($n = 1; $n -le $Retries; $n++) {
        Write-Host "Downloading the new GPU-first executable (try $n of $Retries)..."
        & gh run download $RunId --repo MS1317/Strata --name $artifact --dir $stage
        if ($LASTEXITCODE -eq 0 -and (Test-Path -LiteralPath $exe) -and
            (Get-Item -LiteralPath $exe).Length -gt 30000000) { break }
        Remove-Item -LiteralPath $exe -Force -ErrorAction SilentlyContinue
        if ($n -lt $Retries) { Start-Sleep -Seconds 6 }
    }
}
if (!(Test-Path -LiteralPath $exe) -or (Get-Item $exe).Length -lt 30000000) {
    throw "Download did not finish. Retry the same command; your old executable is unchanged."
}
$hash = (Get-FileHash -LiteralPath $exe -Algorithm SHA256).Hash
if (Test-Path -LiteralPath $target) {
    $existing = (Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash
    if ($existing -eq $hash) {
        Write-Host "GPU-first executable already installed: $target"
        exit 0
    }
}
Copy-Item -LiteralPath $exe -Destination $target -Force -ErrorAction Stop
$installed = (Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash
if ($installed -ne $hash) { throw 'Installed executable failed checksum verification.' }
Write-Host "GPU-first executable installed: $target" -ForegroundColor Green
Write-Host 'Existing strata-q36.exe, DLLs and running model were not changed.'
Write-Host 'Use Run-Strata-Weehzi-GPU-First.cmd to try it when ready.'

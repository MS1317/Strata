# Download a successful GitHub Strata binary release as small artifacts, verify, extract.
# Never starts the GPU model or changes system network settings.
param(
    [long]$RunId = 41760219711,
    [ValidateRange(1,10)][int]$Retries = 4
)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$data = Join-Path (Split-Path -Parent $root) 'Strata-Weehzi-data'
$stage = Join-Path $data "installer\run-$RunId"
$bin = Join-Path $PSScriptRoot 'bin'
$archive = Join-Path $stage 'full.zip'
$extract = Join-Path $stage 'extracted'
New-Item -ItemType Directory -Path $stage -Force | Out-Null
if (!(Get-Command gh -ErrorAction SilentlyContinue)) {
    throw 'GitHub CLI (gh) is missing. Install/enable it before continuing.'
}

function Get-Artifact([string]$name, [string]$expected) {
    $dest = Join-Path $stage $name
    New-Item -ItemType Directory -Path $dest -Force | Out-Null
    $file = Join-Path $dest $expected
    $isPart = $expected -match '^part-([0-9]+)[.]bin$'
    $partNumber = if ($isPart) { [int]$Matches[1] } else { 0 }
    $mustBeFull = $isPart -and $partNumber -lt [int]$manifest.parts
    $expectedBytes = [long]$manifest.chunk_mib * 1MB
    if (Test-Path -LiteralPath $file) {
        $length = (Get-Item -LiteralPath $file).Length
        if ($length -gt 0 -and (!$mustBeFull -or $length -eq $expectedBytes)) {
            Write-Host "Already downloaded: $expected"
            return $file
        }
        Remove-Item -LiteralPath $file -Force
    }
    for ($try = 1; $try -le $Retries; $try++) {
        Write-Host "Downloading $name (attempt $try/$Retries)"
        & gh run download $RunId --repo MS1317/Strata --name $name --dir $dest
        if ($LASTEXITCODE -eq 0 -and (Test-Path -LiteralPath $file) -and
            (Get-Item -LiteralPath $file).Length -gt 0) {
            return $file
        }
        Remove-Item -LiteralPath $file -Force -ErrorAction SilentlyContinue
        if ($try -lt $Retries) { Start-Sleep -Seconds 5 }
    }
    throw "Could not download $name after $Retries attempts. Retry this script later."
}

$manifestPath = Get-Artifact 'Strata-Weehzi-Manifest' 'manifest.json'
$manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
if ($manifest.parts -lt 1 -or $manifest.parts -gt 12 -or
    !([string]$manifest.sha256 -match '^[0-9a-fA-F]{64}$')) {
    throw 'Invalid artifact manifest.'
}

$parts = @()
for ($i = 1; $i -le [int]$manifest.parts; $i++) {
    $file = 'part-{0:D2}.bin' -f $i
    $name = 'Strata-Weehzi-Part-{0:D2}' -f $i
    $parts += Get-Artifact $name $file
}
Write-Host "Assembling $($parts.Count) parts locally..."
if (Test-Path -LiteralPath $archive) { Remove-Item -LiteralPath $archive -Force }
$dest = [IO.File]::Create($archive)
try {
    foreach ($part in $parts) {
        $source = [IO.File]::OpenRead($part)
        try { $source.CopyTo($dest) } finally { $source.Dispose() }
    }
} finally { $dest.Dispose() }

$actual = (Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash.ToLowerInvariant()
if ($actual -ne [string]$manifest.sha256) {
    Remove-Item -LiteralPath $archive -Force -ErrorAction SilentlyContinue
    throw 'Downloaded archive failed checksum verification; no executable was installed.'
}

New-Item -ItemType Directory -Path $extract -Force | Out-Null
Expand-Archive -LiteralPath $archive -DestinationPath $extract -Force
$exe = Join-Path $extract 'strata-q36.exe'
if (!(Test-Path -LiteralPath $exe)) {
    throw 'Verified archive contained no strata-q36.exe. No binary installed.'
}
New-Item -ItemType Directory -Path $bin -Force | Out-Null
Copy-Item -Path (Join-Path $extract '*') -Destination $bin -Force -ErrorAction Stop
Write-Host "Strata binary is installed: $(Join-Path $bin 'strata-q36.exe')" -ForegroundColor Green
Write-Host 'The model has NOT been started. Use Run-Strata-Weehzi.cmd for a guarded smoke test.'

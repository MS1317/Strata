# Finish the low-priority Qwen3.5 4B GGUF transfer, verifying its original SHA-256.
# Does not delete the previous 9B model or stop any process.
$ErrorActionPreference = 'Stop'
$data = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'Strata-Weehzi-data'
$modelDir = Join-Path $data 'models'
$dest = Join-Path $modelDir 'Qwen3.5-4B-Q4_K_M.gguf'
$temp = $dest + '.bits'
$want = '00fe7986ff5f6b463e62455821146049db6f9313603938a70800d1fb69ef11a4'
$expectedBytes = 2740937888L

function Confirm-Model([string]$path) {
    if (!(Test-Path -LiteralPath $path)) { throw "Missing model file: $path" }
    $file = Get-Item -LiteralPath $path
    if ($file.Length -ne $expectedBytes) {
        throw "4B model size mismatch: $($file.Length) bytes, expected $expectedBytes. Not using incomplete file."
    }
    Write-Host 'Checking Qwen3.5 4B GGUF SHA-256...'
    $actual = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actual -ne $want) {
        throw "4B model checksum mismatch: $actual. Keeping original download for inspection."
    }
}

if (Test-Path -LiteralPath $dest) {
    Confirm-Model $dest
    Write-Host "Verified Qwen3.5 4B already present: $dest"
    return
}

Import-Module BitsTransfer -ErrorAction Stop
$jobs = @(Get-BitsTransfer -Name 'Strata-Weehzi Qwen3.5 4B' -ErrorAction SilentlyContinue)
if ($jobs.Count -ne 1) {
    throw 'Qwen3.5 4B transfer job not found. Do not use the old 9B download or an unverified partial file.'
}
$job = $jobs[0]
if ($job.JobState -eq 'Transferred') {
    Write-Host 'Completing Qwen3.5 4B download...'
    Complete-BitsTransfer -BitsJob $job
} elseif ($job.JobState -in @('Error', 'TransientError')) {
    throw "4B download state $($job.JobState): $($job.ErrorDescription)"
} else {
    $pct = if ($job.BytesTotal -gt 0 -and $job.BytesTotal -lt [uint64]::MaxValue) {
        [math]::Round(100 * $job.BytesTransferred / $job.BytesTotal, 1)
    } else { 0 }
    throw "Qwen3.5 4B still downloading ($pct%); current state $($job.JobState)."
}
Confirm-Model $temp
Move-Item -LiteralPath $temp -Destination $dest -ErrorAction Stop
Write-Host "Verified Qwen3.5 4B ready: $dest"

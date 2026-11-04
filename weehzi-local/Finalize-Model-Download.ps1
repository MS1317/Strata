# Finish the low-priority Windows BITS model transfer, checking the official SHA256.
# Only manages the explicitly named Strata-Weehzi download.
$ErrorActionPreference = 'Stop'
$data = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'Strata-Weehzi-data'
$modelDir = Join-Path $data 'models'
$dest = Join-Path $modelDir 'Qwen3.5-9B-Q4_K_M.gguf'
$temp = $dest + '.bits'
$oldPartial = $dest + '.part'
$want = '03b74727a860a56338e042c4420bb3f04b2fec5734175f4cb9fa853daf52b7e8'

if (Test-Path -LiteralPath $dest) {
    Write-Host "Model file is already present: $dest"
    return
}
Import-Module BitsTransfer -ErrorAction Stop
$jobs = @(Get-BitsTransfer -Name 'Strata-Weehzi Qwen3.5 9B' -ErrorAction SilentlyContinue)
if ($jobs.Count -ne 1) { throw 'No unique Strata-Weehzi model transfer found; see Check-Strata-Weehzi.cmd.' }
$job = $jobs[0]
if ($job.JobState -eq 'Transferred') {
    Write-Host 'Completing model transfer...'
    Complete-BitsTransfer -BitsJob $job
} elseif ($job.JobState -eq 'Error' -or $job.JobState -eq 'TransientError') {
    throw "Model transfer is in state $($job.JobState): $($job.ErrorDescription)"
} else {
    $pct = if ($job.BytesTotal -gt 0 -and $job.BytesTotal -lt [uint64]::MaxValue) {
        [math]::Round(100 * $job.BytesTransferred / $job.BytesTotal, 1)
    } else { 0 }
    throw "Qwen3.5 9B still downloading ($pct%). BITS state: $($job.JobState)."
}
if (!(Test-Path -LiteralPath $temp)) { throw "Transfer reported success, but file missing: $temp" }
Write-Host 'Verifying SHA256 checksum...'
$hash = (Get-FileHash -LiteralPath $temp -Algorithm SHA256).Hash.ToLowerInvariant()
if ($hash -ne $want) {
    throw "Model file checksum mismatch ($hash). Keeping the downloaded .bits file for inspection."
}
Move-Item -LiteralPath $temp -Destination $dest -ErrorAction Stop
if (Test-Path -LiteralPath $oldPartial) { Remove-Item -LiteralPath $oldPartial -Force }
Write-Host "Verified model ready: $dest"

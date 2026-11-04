# Compares installed GPU-first and fast-head builds on the SAME GGUF token prompt.
# Only runs when the existing Strata server is stopped and memory headroom is safe.
# No applications, services, drivers, or networking are changed.
param(
    [ValidateRange(8,64)][int]$Tokens = 32
)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$data = Join-Path (Split-Path -Parent $root) 'Strata-Weehzi-data'
$model = Join-Path $data 'models\Qwen3.5-9B-Q4_K_M.gguf'
$gpu = Join-Path $PSScriptRoot 'bin\strata-q36-gpu-first.exe'
$fast = Join-Path $PSScriptRoot 'bin\strata-q36-head-fast.exe'
$logs = Join-Path $data 'logs\speed-tests'
New-Item -ItemType Directory -Force -Path $logs | Out-Null
foreach ($file in @($model,$gpu,$fast)) {
    if (!(Test-Path -LiteralPath $file)) { throw "Missing: $file" }
}
if (Get-NetTCPConnection -LocalPort 18084 -State Listen -ErrorAction SilentlyContinue) {
    throw 'Strata is running. Stop ONLY its existing terminal with Ctrl+C before this standalone comparison.'
}
if (Get-Process -Name 'strata-q36*' -ErrorAction SilentlyContinue) {
    throw 'Another Strata executable is running. Refusing to compete for GPU resources.'
}
function Check-Headroom {
    $ram = [double] (Get-CimInstance Win32_OperatingSystem).FreePhysicalMemory / 1024
    $gpu = @(& nvidia-smi --query-gpu=memory.free --format=csv,noheader)
    if ($LASTEXITCODE -ne 0 -or !$gpu) { throw 'Cannot read GPU memory' }
    $available = [regex]::Match([string] $gpu[0], '^\s*(\d+)')
    if (!$available.Success) { throw 'Unexpected NVIDIA memory format' }
    $freeVram = [int] $available.Groups[1].Value
    if ($ram -lt 10240 -or $freeVram -lt 3200) {
        throw "Not enough free memory for an isolated test: $([int]$ram) MB RAM, $freeVram MB GPU. Existing apps remain untouched."
    }
}
function Run-Variant([string]$name, [string]$exe) {
    Check-Headroom
    $out = Join-Path $logs "$name.stdout.txt"
    $err = Join-Path $logs "$name.stderr.txt"
    Remove-Item -LiteralPath $out,$err -Force -ErrorAction SilentlyContinue
    Write-Host "Testing ${name}: $Tokens tokens, ctx 4096..."
    $process = Start-Process -FilePath $exe -ArgumentList @(
        '--native', $model, '--max-context', '4096', '--chunk', '128',
        '--no-graph', '--tokens', '198', '--n', [string]$Tokens
    ) -NoNewWindow -PassThru -RedirectStandardOutput $out -RedirectStandardError $err
    if (!$process.WaitForExit(180000)) {
        $process.Kill()
        throw "$name exceeded a 3-minute safety timeout. Stopped only its own test process."
    }
    if ($process.ExitCode -ne 0) {
        throw "$name exited with code $($process.ExitCode). Read $err; other programs are unaffected."
    }
    $stdout = Get-Content $out -Raw
    $stderr = Get-Content $err -Raw
    $generated = [regex]::Match($stdout, '(?m)^gen:\s*([0-9 ]+)\s*$')
    $timing = [regex]::Match($stderr, '(\d+) generated in ([\d.]+) ms \(([\d.]+) tok/s\)')
    if (!$generated.Success -or !$timing.Success) {
        throw "Missing token output or speed measurements in $name logs."
    }
    return [PSCustomObject]@{
        Variant=$name
        Tokens=($generated.Groups[1].Value.Trim() -replace '\s+',' ')
        Generated=[int]$timing.Groups[1].Value
        Milliseconds=[double]$timing.Groups[2].Value
        TokensPerSecond=[double]$timing.Groups[3].Value
    }
}
$env:STRATA_Q35_GPU_CACHE_MB='2048'
$env:STRATA_Q35_GPU_KEEP_FREE_MB='1024'
$reference = Run-Variant 'gpu-first' $gpu
$experiment = Run-Variant 'head-fast' $fast
Write-Host ''
$reference,$experiment | Select-Object Variant,Generated,Milliseconds,TokensPerSecond | Format-Table -AutoSize
if ($reference.Tokens -ne $experiment.Tokens) {
    Write-Warning 'MODEL OUTPUT DIFFERED. Treat the fast-head experiment as a failed correctness check.'
    exit 1
}
$gain = 100.0 * ($experiment.TokensPerSecond / [math]::Max(0.01,$reference.TokensPerSecond) - 1)
Write-Host ('Output matched exactly. Speed difference: {0:+0.0;-0.0;0.0}%' -f $gain)
Write-Host "Logs saved in $logs"
Write-Host 'The test executables exited; no server was started or left running.'

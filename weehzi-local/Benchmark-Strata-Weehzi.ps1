# User-triggered minimal benchmark. Never starts, restarts or stops a server.
param(
    [ValidateRange(1,64)][int]$MaxTokens = 16
)
$ErrorActionPreference = 'Stop'
$uri = 'http://127.0.0.1:18084'
$health = Invoke-RestMethod -Uri "$uri/health" -TimeoutSec 5
if ($health.status -ne 'ok' -or !$health.loaded) {
    throw "Strata is not loaded at $uri. Start it yourself when your PC has enough memory."
}
$body = @{
    model = 'qwen3.5-4b-strata-weehzi'
    messages = @(@{role='user';content='In one sentence, explain what a laptop does.'})
    max_tokens = $MaxTokens
    temperature = 0
    reasoning_effort = 'none'
    stream = $false
} | ConvertTo-Json -Depth 7 -Compress
$sw = [Diagnostics.Stopwatch]::StartNew()
$response = Invoke-RestMethod -Method Post -Uri "$uri/v1/chat/completions" -TimeoutSec 120 -ContentType 'application/json' -Body $body
$sw.Stop()
Write-Host "Model: $($health.model)"
Write-Host ("Total seconds: {0:N2}" -f $sw.Elapsed.TotalSeconds)
Write-Host ("Prompt speed: {0:N2} tokens/second" -f $response.timings.prompt_per_second)
Write-Host ("Answer speed: {0:N2} tokens/second" -f $response.timings.predicted_per_second)
Write-Host ("Answer tokens: {0}" -f $response.usage.completion_tokens)
Write-Host "Answer: $($response.choices[0].message.content)"
if (!$response.choices[0].message.content) {
    Write-Warning 'No visible answer; check whether thinking mode was disabled.'
}

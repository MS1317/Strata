@echo off
setlocal
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0weehzi-local\Install-GPU-First.ps1" -RunId 41775473477
if errorlevel 1 (
  echo.
  echo The hosted build may still be running or the network could have timed out.
  echo No changes were made to your running Strata version. Retry this installer later.
  pause
)
endlocal

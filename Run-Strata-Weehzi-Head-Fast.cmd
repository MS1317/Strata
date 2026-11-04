@echo off
setlocal
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0weehzi-local\Start-Strata-Weehzi.ps1" -HeadFast %*
if errorlevel 1 (
  echo.
  echo Fast-head Strata did not start; the earlier GPU-first build remains unchanged.
  pause
)
endlocal

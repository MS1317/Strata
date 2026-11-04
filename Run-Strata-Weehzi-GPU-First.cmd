@echo off
setlocal
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0weehzi-local\Start-Strata-Weehzi.ps1" -GpuFirst %*
if errorlevel 1 (
  echo.
  echo GPU-first Strata did not start. Details above. Original build remains available.
  pause
)
endlocal

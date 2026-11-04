@echo off
setlocal
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0weehzi-local\Start-Strata-Weehzi.ps1" %*
if errorlevel 1 (
  echo.
  echo Strata did not start. The details are shown above.
  pause
)
endlocal

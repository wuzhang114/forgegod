@echo off
setlocal
cd /d "%~dp0"

if not exist "gradlew.bat" (
  echo [ForgeGod] gradlew.bat was not found. Please keep this script in forgegod-mod.
  pause
  exit /b 1
)

echo [ForgeGod] Starting the isolated Forge 1.20.1 development client...
echo [ForgeGod] The client uses this project's run directory, not your PCL save.
echo [ForgeGod] DEEPSEEK_API_KEY is read from the current system environment if configured.
call gradlew.bat runClient
set "EXIT_CODE=%ERRORLEVEL%"

if not "%EXIT_CODE%"=="0" (
  echo.
  echo [ForgeGod] Test client exited with code %EXIT_CODE%.
  pause
)
exit /b %EXIT_CODE%

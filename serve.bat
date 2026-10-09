@echo off
setlocal
set "DIR=%~dp0"
if not exist "%DIR%serve.py" (
  echo [ERROR] serve.py not found in the same folder as this script.
  echo Please keep serve.py together with serve.bat.
  pause
  exit /b 1
)
where python >nul 2>nul
if errorlevel 1 (
  echo [ERROR] python not found. Install Python 3.8+ and add it to PATH.
  pause
  exit /b 1
)
echo Starting local server...
echo Open this URL in your browser: http://localhost:8000
echo Press Ctrl+C to stop. Closing this window also stops the server.
python "%DIR%serve.py"
pause

@echo off
REM ============================================================================
REM  以 file:// 方式打开默写助手，并让离线语音（Kokoro / Piper）真正可用。
REM
REM  原因：ONNX Runtime 的 wasm 后端会动态 import() 它的 .mjs 模块，而 Chrome /
REM  Edge 在 file:// 下默认把这类脚本视为"跨源"而拦截（报 about:blank / no
REM  available backend）。必须带 --allow-file-access-from-files 启动浏览器才能解开。
REM  直接双击 index.html 必然失败，请用本文件启动。
REM
REM  备选（最稳）：直接运行 serve.bat 起本地服务器，访问 http://localhost:8000
REM ============================================================================
setlocal

set "APP=%~dp0"
if "%APP:~-1%"=="\" set "APP=%APP:~0,-1%"
set "PROFILE=%APP%\chrome-file-profile"
set "FURL=file:///%APP:\=/%/index.html"

set "CHROME="
if exist "%ProgramFiles%\Google\Chrome\Application\chrome.exe" set "CHROME=%ProgramFiles%\Google\Chrome\Application\chrome.exe"
if not defined CHROME if exist "%ProgramFiles(x86)%\Google\Chrome\Application\chrome.exe" set "CHROME=%ProgramFiles(x86)%\Google\Chrome\Application\chrome.exe"
if not defined CHROME if exist "%ProgramFiles%\Microsoft\Edge\Application\msedge.exe" set "CHROME=%ProgramFiles%\Microsoft\Edge\Application\msedge.exe"
if not defined CHROME if exist "%ProgramFiles(x86)%\Microsoft\Edge\Application\msedge.exe" set "CHROME=%ProgramFiles(x86)%\Microsoft\Edge\Application\msedge.exe"
if not defined CHROME for /f "delims=" %%i in ('where chrome 2^>nul') do (if not defined CHROME set "CHROME=%%i")
if not defined CHROME for /f "delims=" %%i in ('where msedge 2^>nul') do (if not defined CHROME set "CHROME=%%i")

if not defined CHROME (
  echo 未找到 Chrome 或 Edge，请先安装浏览器。
  echo 安装后也可手动运行下面这条命令（把路径改成你的 index.html 位置）：
  echo   chrome --allow-file-access-from-files "%FURL%"
  pause
  exit /b 1
)

echo 正在以"允许本地文件访问"方式启动浏览器（离线语音需要此参数）...
echo 页面：%FURL%
start "" "%CHROME%" --allow-file-access-from-files --user-data-dir="%PROFILE%" --no-first-run "%FURL%"

endlocal

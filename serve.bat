@echo off
setlocal enabledelayedexpansion
set "DIR=%~dp0"
if not exist "%DIR%serve.py" (
  echo [错误] 未找到同目录下的 serve.py，请确认本文件与 serve.py 放在一起。
  pause
  exit /b 1
)
where python >nul 2>nul
if errorlevel 1 (
  echo [错误] 未找到 python，请先安装 Python 3.8+ 并加入系统 PATH。
  pause
  exit /b 1
)
echo 正在启动本地服务器...
echo 请在浏览器打开： http://localhost:8000
echo （按 Ctrl+C 停止；直接关闭此窗口也会停止服务器）
python "%DIR%serve.py"
pause

@echo off
chcp 65001 >nul
cd /d %~dp0
echo 正在启动本地服务器（http://localhost:8000）...
start "" python serve.py
timeout /t 2 >nul
start "" http://localhost:8000
echo 浏览器已打开。关闭此窗口或按 Ctrl+C 可停止服务器。
echo 说明：本脚本仅用于本地 Windows 一键启动；NAS 部署请用您自己的静态服务器（注意带尾斜杠访问）。
pause

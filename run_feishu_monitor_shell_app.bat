@echo off
setlocal
set ROOT=%~dp0
cd /d "%ROOT%tools\feishu_monitor_shell_app"
flutter run -d windows

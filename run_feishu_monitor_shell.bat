@echo off
setlocal
set ROOT=%~dp0
cd /d "%ROOT%tools\feishu_monitor_shell"
dart run bin/feishu_monitor_shell.dart --port 18766 --token wukong-feishu-shell-dev --state-file "%ROOT%.runtime\feishu_monitor_shell\status.json"

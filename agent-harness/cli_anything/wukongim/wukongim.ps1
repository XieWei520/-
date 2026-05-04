#!/usr/bin/env pwsh
# WuKongIM CLI PowerShell Wrapper
# Usage: .\wukongim.ps1 auth login -u username -p password
#
# Tip: Add this to your PowerShell profile for easy access:
#   Set-Alias wukongim "& '$PSCommandPath'"

$ScriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$PythonScript = Join-Path $ScriptPath "wukongim_cli.py"

& python $PythonScript $args

param(
  [string]$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path,
  [string]$OutputDirectory = '',
  [string]$RemoteHost = 'ubuntu@42.194.218.158',
  [string]$RemoteSourceRoot = '/opt/wukongim-prod/src',
  [switch]$SkipRemote
)

$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($OutputDirectory)) {
  $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
  $OutputDirectory = Join-Path $ProjectRoot "build\phase5-preflight\$stamp"
}

New-Item -ItemType Directory -Force -Path $OutputDirectory | Out-Null
$EvidencePath = Join-Path $OutputDirectory 'server_sql_gate.txt'

function Add-Evidence {
  param([Parameter(Mandatory = $true)][string]$Line)
  $Line | Add-Content -Path $EvidencePath -Encoding UTF8
}

function Quote-Bash {
  param([Parameter(Mandatory = $true)][string]$Value)
  $single = [string][char]39
  $double = [string][char]34
  $replacement = $single + $double + $single + $double + $single
  return $single + $Value.Replace($single, $replacement) + $single
}

function Invoke-RemoteBash {
  param([Parameter(Mandatory = $true)][string]$Script)
  ssh $RemoteHost "bash -lc $(Quote-Bash -Value $Script)"
}

"## server_sql_gate" | Set-Content -Path $EvidencePath -Encoding UTF8
Add-Evidence "## started: $(Get-Date -Format o)"
Add-Evidence "remote_host=$RemoteHost"
Add-Evidence "remote_source_root=$RemoteSourceRoot"
# Contract marker: this read-only gate scans Go fmt.Sprintf SQL construction.

if ($SkipRemote) {
  Add-Evidence 'SKIP: remote SQL gate skipped by -SkipRemote.'
  Add-Evidence '## exit: 0'
  exit 0
}

$remoteRoot = Quote-Bash -Value $RemoteSourceRoot
$remoteScript = @"
set -euo pipefail
root=$remoteRoot
if [ ! -d "`$root" ]; then
  echo "SQL_GATE_ERROR remote source root missing: `$root"
  exit 1
fi
python3 - <<'PY'
import os
import re
import sys
from pathlib import Path

root = Path(os.environ.get('PHASE5_SQL_ROOT', ''))

risk_patterns = [
    ('SQL_RISK_FMT_SPRINTF', re.compile(r'fmt\.Sprintf\([^\n]*(select|insert|update|delete|where|from)\b', re.I)),
    ('SQL_RISK_STRING_CONCAT_LEFT', re.compile(r'"[^"\n]*(select|insert|update|delete|where|from)\b[^"\n]*"\s*\+', re.I)),
    ('SQL_RISK_STRING_CONCAT_RIGHT', re.compile(r'\+\s*"[^"\n]*(select|insert|update|delete|where|from)\b[^"\n]*"', re.I)),
    ('SQL_RISK_DYNAMIC_EXEC', re.compile(r'\b(db|tx|conn)\.(Exec|Query|QueryRow|Raw)\s*\(\s*(sql|query|stmt|where)\b', re.I)),
]

skip_dirs = {'.git', 'vendor', 'tmp', 'node_modules'}
findings = []
for path in root.rglob('*.go'):
    if any(part in skip_dirs for part in path.parts):
        continue
    try:
        lines = path.read_text(encoding='utf-8', errors='replace').splitlines()
    except OSError as exc:
        findings.append(('SQL_RISK_READ_ERROR', path, 0, str(exc)))
        continue
    for index, line in enumerate(lines, start=1):
        stripped = line.strip()
        if not stripped or stripped.startswith('//'):
            continue
        for code, pattern in risk_patterns:
            if pattern.search(stripped):
                findings.append((code, path, index, stripped[:240]))

for code, path, line, text in findings[:200]:
    print(f'{code} {path}:{line}: {text}')
if len(findings) > 200:
    print(f'SQL_RISK_TRUNCATED additional_findings={len(findings) - 200}')

slow_needles = (
    'slow_query_log',
    'long_query_time',
    'slow-query',
    'slow query',
    'slowlog',
    '100ms',
    '0.1s',
    '200ms',
    '0.2s',
)
slow_hits = []
for suffix in ('.go', '.yaml', '.yml', '.toml', '.env', '.conf', '.md', '.sql'):
    for path in root.rglob(f'*{suffix}'):
        if any(part in skip_dirs for part in path.parts):
            continue
        try:
            text = path.read_text(encoding='utf-8', errors='replace')
        except OSError:
            continue
        lower = text.lower()
        if any(needle in lower for needle in slow_needles):
            slow_hits.append(path)

for path in slow_hits[:80]:
    print(f'SLOW_QUERY_EVIDENCE {path}')
if len(slow_hits) > 80:
    print(f'SLOW_QUERY_EVIDENCE_TRUNCATED additional_hits={len(slow_hits) - 80}')

if findings:
    print(f'SQL_GATE_FAIL high_risk_findings={len(findings)}')
    sys.exit(1)
if not slow_hits:
    print('SQL_GATE_FAIL missing slow-query evidence: expected slow_query_log, long_query_time, slow-query, or <=200ms threshold evidence')
    sys.exit(1)
print(f'SQL_GATE_PASS slow_query_evidence={len(slow_hits)}')
PY
"@

$remoteScript = "export PHASE5_SQL_ROOT=$remoteRoot`n" + $remoteScript

$previousErrorActionPreference = $ErrorActionPreference
try {
  $ErrorActionPreference = 'Continue'
  $remoteExitCode = 1
  & {
    Invoke-RemoteBash -Script $remoteScript
    $script:remoteExitCode = $LASTEXITCODE
  } 2>&1 | ForEach-Object {
    $text = $_.ToString()
    $text
    Add-Evidence $text
  }
  $exitCode = $remoteExitCode
} catch {
  Add-Evidence "SQL_GATE_ERROR $($_.Exception.Message)"
  $exitCode = 1
} finally {
  $ErrorActionPreference = $previousErrorActionPreference
}

Add-Evidence "## exit: $exitCode"
Add-Evidence "## finished: $(Get-Date -Format o)"
exit $exitCode


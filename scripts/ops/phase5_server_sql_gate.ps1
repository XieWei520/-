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
  $Script | ssh $RemoteHost 'bash -s'
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

$pythonProbe = @'
import os
import re
import sys
from pathlib import Path

root = Path(os.environ.get('PHASE5_SQL_ROOT', ''))

SQL_RISK_SQL_LITERAL = 'SQL_RISK_SQL_LITERAL'
SQL_RISK_STRING_CONCAT = 'SQL_RISK_STRING_CONCAT'
SQL_RISK_DYNAMIC_EXEC = 'SQL_RISK_DYNAMIC_EXEC'

SQL_CONTEXT_RE = re.compile(
    r'(?:'
    r'\.\s*(?:Exec|Query|QueryRow|Raw|Select|InsertBySql|UpdateBySql|DeleteBySql)\s*\('
    r'|\bfmt\.Sprintf\s*\('
    r'|\b(?:sql|query|stmt|selectSql|builder)\b'
    r')',
    re.I,
)
DB_SINK_RE = re.compile(
    r'\.\s*(?:Exec|Query|QueryRow|Raw|Select|InsertBySql|UpdateBySql|DeleteBySql)\s*\(',
    re.I,
)
SQL_VAR_RE = re.compile(r'\b(?:sql|query|stmt|selectSql|builder|whereClause|orderBy)\b', re.I)
ALLOWLIST_MARKER = 'phase5-sql-allow'

SQL_SHAPE_PATTERNS = (
    re.compile(r'\bselect\b[\s\S]+\bfrom\b', re.I),
    re.compile(r'\binsert\b[\s\S]+\binto\b', re.I),
    re.compile(r'\bupdate\b[\s\S]+\bset\b', re.I),
    re.compile(r'\bdelete\b[\s\S]+\bfrom\b', re.I),
    re.compile(r'\bwhere\b[\s\S]*(?:=|\bin\b|\blike\b|\bbetween\b|\bis\b)', re.I),
    re.compile(r'\bjoin\b[\s\S]+\bon\b', re.I),
    re.compile(r'\bon\s+duplicate\s+key\b', re.I),
    re.compile(r'\bgroup\s+by\b|\border\s+by\b|\blimit\s+\?', re.I),
)


def decode_go_escaped(value):
    try:
        return bytes(value, 'utf-8').decode('unicode_escape')
    except UnicodeDecodeError:
        return value


def extract_go_string_literals(line):
    literals = []
    index = 0
    length = len(line)
    while index < length:
        char = line[index]
        if char == '`':
            end = line.find('`', index + 1)
            if end == -1:
                break
            literals.append(line[index + 1:end])
            index = end + 1
            continue
        if char == '"':
            index += 1
            buffer = []
            while index < length:
                char = line[index]
                if char == '\\' and index + 1 < length:
                    buffer.append(line[index:index + 2])
                    index += 2
                    continue
                if char == '"':
                    break
                buffer.append(char)
                index += 1
            literals.append(decode_go_escaped(''.join(buffer)))
        index += 1
    return literals


def looks_like_sql(text):
    normalized = re.sub(r'\s+', ' ', text).strip()
    if not normalized:
        return False
    lowered = normalized.lower()
    if lowered.startswith(('http://', 'https://', '/', './', '../')):
        return False
    if not re.search(r'\b(select|insert|update|delete|where|join|from|on duplicate key)\b', lowered):
        return False
    return any(pattern.search(normalized) for pattern in SQL_SHAPE_PATTERNS)


def is_db_context(line):
    return bool(SQL_CONTEXT_RE.search(line))


def is_dynamic_sql_build(line):
    if re.search(r'\bfmt\.Sprintf\s*\(', line):
        return True
    if '+' in line:
        return True
    if re.search(r'\b(?:strings\.Join|bytes\.Buffer|strings\.Builder)\b', line):
        return True
    return False


def sink_uses_sql_variable(line):
    sink_match = DB_SINK_RE.search(line)
    if not sink_match:
        return False
    argument_tail = line[sink_match.end():]
    first_arg = argument_tail.split(',', 1)[0].strip()
    return bool(SQL_VAR_RE.search(first_arg)) and not first_arg.startswith(('"', '`'))


def has_allowlist_marker(lines, index):
    current = index - 1
    for candidate in range(max(0, current - 2), current + 1):
        if ALLOWLIST_MARKER in lines[candidate]:
            return True
    return False

skip_dirs = {
    '.git',
    'vendor',
    'tmp',
    'node_modules',
    'data',
    'logs',
    'backup',
    'backups',
    'testutil',
}
findings = []
for path in root.rglob('*.go'):
    if any(part in skip_dirs for part in path.parts):
        continue
    if path.name.endswith('_test.go'):
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
        if has_allowlist_marker(lines, index):
            continue
        literals = extract_go_string_literals(stripped)
        sql_literals = [literal for literal in literals if looks_like_sql(literal)]
        if sql_literals and is_db_context(stripped) and is_dynamic_sql_build(stripped):
            findings.append((SQL_RISK_SQL_LITERAL, path, index, stripped[:240]))
            continue
        if sql_literals and is_db_context(stripped) and '+' in stripped:
            findings.append((SQL_RISK_STRING_CONCAT, path, index, stripped[:240]))
            continue
        if sink_uses_sql_variable(stripped):
            findings.append((SQL_RISK_DYNAMIC_EXEC, path, index, stripped[:240]))

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
for suffix in ('.go', '.yaml', '.yml', '.toml', '.env', '.conf', '.cnf', '.md', '.sql'):
    for path in root.rglob(f'*{suffix}'):
        if any(part in skip_dirs for part in path.parts):
            continue
        if path.name.endswith('_test.go'):
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
'@

$pythonProbeB64 = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($pythonProbe))
$remoteRoot = Quote-Bash -Value $RemoteSourceRoot
$remoteProbe = Quote-Bash -Value $pythonProbeB64
$pythonRunner = 'import base64, os; exec(compile(base64.b64decode(os.environ["PHASE5_SQL_PROBE_B64"]).decode("utf-8"), "<phase5_sql_gate>", "exec"))'
$remotePythonRunner = Quote-Bash -Value $pythonRunner
$remoteScript = @"
set -euo pipefail
export PHASE5_SQL_ROOT=$remoteRoot
export PHASE5_SQL_PROBE_B64=$remoteProbe
if [ ! -d "`$PHASE5_SQL_ROOT" ]; then
  echo "SQL_GATE_ERROR remote source root missing: `$PHASE5_SQL_ROOT"
  exit 1
fi
python3 -c $remotePythonRunner
"@

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


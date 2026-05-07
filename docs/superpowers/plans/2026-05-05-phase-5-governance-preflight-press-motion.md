# Phase 5 Governance Preflight and Press Motion Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a read-only server SQL/slow-query gate, a one-command Phase 5 release preflight, and a token-governed 0.92x send-button press micro-interaction.

**Architecture:** Keep production server access read-only and orchestrate checks from Windows PowerShell scripts in `scripts/ops`. The strict release preflight creates per-gate evidence files and delegates SQL scanning to a focused SQL gate script. The Flutter send button keeps its current widget boundary but resolves press duration through `ChatMotionDurations.pressedScale` and locks the exact pressed scale in widget tests.

**Tech Stack:** PowerShell, SSH, remote Bash/Python read-only probes, Docker Compose/Nginx CLI checks, Flutter/Dart widget tests, `flutter_test`, Git worktrees.

---

## Worktree and Branch

- Worktree: `C:\Users\COLORFUL\Desktop\WuKong\.worktrees\phase-5-governance-preflight-press-motion`
- Branch: `codex/phase-5-governance-preflight-press-motion`
- Run every command below from the worktree root unless explicitly stated otherwise.

## Spec Boundary

This plan implements the approved design in:

`C:\Users\COLORFUL\Desktop\WuKong\.worktrees\phase-5-governance-preflight-press-motion\docs\superpowers\specs\2026-05-05-phase-5-governance-preflight-press-motion-design.md`

In scope:

- `scripts/ops/phase5_server_sql_gate.ps1`
- `scripts/ops/phase5_release_preflight.ps1`
- script contract tests under `test/scripts/ops/`
- update `docs/production/phase-5-release-preflight.md`
- exact send-button `0.92` press-scale regression and token-based duration

Out of scope:

- direct mutation of `/opt/wukongim-prod/src` on the production host
- container restarts/reloads/deploys
- fixing Go SQL findings in the remote backend checkout
- broader chat composer redesign

## File Structure

### New Files

- `scripts/ops/phase5_server_sql_gate.ps1`
  - Runs a read-only remote scan of the Go backend checkout for risky SQL construction patterns and slow-query evidence.
- `scripts/ops/phase5_release_preflight.ps1`
  - Runs local Flutter gates and remote production gates, captures one evidence file per gate, and fails on any required failure.
- `test/scripts/ops/phase5_governance_preflight_test.dart`
  - Contract tests for both new PowerShell scripts and release runbook wiring.

### Existing Files To Modify

- `lib/modules/chat/chat_page_shell.dart`
  - Import `ChatMotionDurations` and use `ChatMotionDurations.pressedScale.resolve(...)` for the send button `AnimatedScale` duration.
- `test/modules/chat/chat_page_scene_flow_test.dart`
  - Tighten the send-button motion test to assert exact scale and token duration.
- `docs/production/phase-5-release-preflight.md`
  - Replace the current manual Phase 5 gate instructions with the new one-command preflight plus evidence expectations.

---

## Task 1: Add Failing Script Contract Tests

**Files:**
- Create: `test/scripts/ops/phase5_governance_preflight_test.dart`

- [ ] **Step 1: Write the failing tests**

Create `test/scripts/ops/phase5_governance_preflight_test.dart` with this content:

```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('server SQL gate scans remote Go SQL risks and slow-query evidence', () {
    final script = File('scripts/ops/phase5_server_sql_gate.ps1');

    expect(script.existsSync(), isTrue);

    final content = script.readAsStringSync();
    expect(content, contains('RemoteHost'));
    expect(content, contains('ubuntu@42.194.218.158'));
    expect(content, contains('RemoteSourceRoot'));
    expect(content, contains('/opt/wukongim-prod/src'));
    expect(content, contains('server_sql_gate.txt'));
    expect(content, contains('Invoke-RemoteBash'));
    expect(content, contains('fmt.Sprintf'));
    expect(content, contains('SQL_RISK'));
    expect(content, contains('slow-query'));
    expect(content, contains('long_query_time'));
    expect(content, contains('slow_query_log'));
    expect(content, contains('exit 1'));
  });

  test('release preflight captures every Phase 5 required gate', () {
    final script = File('scripts/ops/phase5_release_preflight.ps1');

    expect(script.existsSync(), isTrue);

    final content = script.readAsStringSync();
    expect(content, contains('build\\phase5-preflight'));
    expect(content, contains('Invoke-Gate'));
    expect(content, contains('flutter analyze'));
    expect(content, contains('test/scripts/ops/phase5_governance_preflight_test.dart'));
    expect(content, contains('test/modules/chat/chat_page_scene_flow_test.dart'));
    expect(content, contains('docker compose config'));
    expect(content, contains('nginx -t'));
    expect(content, contains('scripts/smoke_test.py --base-url http://127.0.0.1 --timeout 10'));
    expect(content, contains('remote_public_web_smoke'));
    expect(content, contains('remote_websocket_handshake'));
    expect(content, contains('phase5_server_sql_gate.ps1'));
    expect(content, contains('failed-gates'));
    expect(content, contains('exit 1'));
  });

  test('release preflight runbook points operators at the one-key gate', () {
    final doc = File('docs/production/phase-5-release-preflight.md');

    expect(doc.existsSync(), isTrue);

    final content = doc.readAsStringSync();
    expect(content, contains('phase5_release_preflight.ps1'));
    expect(content, contains('phase5_server_sql_gate.ps1'));
    expect(content, contains('build/phase5-preflight'));
    expect(content, contains('server_sql_gate.txt'));
  });
}
```

- [ ] **Step 2: Run the tests to verify RED**

Run:

```powershell
flutter test test/scripts/ops/phase5_governance_preflight_test.dart
```

Expected: FAIL because `scripts/ops/phase5_server_sql_gate.ps1`, `scripts/ops/phase5_release_preflight.ps1`, and the new runbook references do not exist yet.

- [ ] **Step 3: Commit the failing test**

```powershell
git add test/scripts/ops/phase5_governance_preflight_test.dart
git commit -m "test: lock phase 5 governance preflight contracts"
```

---

## Task 2: Implement the Server SQL and Slow-Query Gate

**Files:**
- Create: `scripts/ops/phase5_server_sql_gate.ps1`
- Test: `test/scripts/ops/phase5_governance_preflight_test.dart`

- [ ] **Step 1: Create the SQL gate script**

Create `scripts/ops/phase5_server_sql_gate.ps1` with this behavior:

```powershell
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
if not root:
    root = Path('$RemoteSourceRoot')

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

try {
  Invoke-RemoteBash -Script $remoteScript 2>&1 | Tee-Object -FilePath $EvidencePath -Append
  $exitCode = $LASTEXITCODE
} catch {
  Add-Evidence "SQL_GATE_ERROR $($_.Exception.Message)"
  $exitCode = 1
}

Add-Evidence "## exit: $exitCode"
Add-Evidence "## finished: $(Get-Date -Format o)"
exit $exitCode
```

While implementing, keep the literal strings asserted by the test: `Invoke-RemoteBash`, `fmt.Sprintf`, `SQL_RISK`, `slow-query`, `long_query_time`, `slow_query_log`, `server_sql_gate.txt`, and `exit 1`.

- [ ] **Step 2: Run the contract test to verify GREEN for SQL script wiring**

Run:

```powershell
flutter test test/scripts/ops/phase5_governance_preflight_test.dart --plain-name "server SQL gate"
```

Expected: PASS for the server SQL gate test. Other tests in the file may still fail until the preflight script and docs are added.

- [ ] **Step 3: Syntax-check PowerShell parsing**

Run:

```powershell
$null = [System.Management.Automation.Language.Parser]::ParseFile('scripts/ops/phase5_server_sql_gate.ps1', [ref]$null, [ref]$null)
```

Expected: command exits 0 with no parser errors.

- [ ] **Step 4: Commit**

```powershell
git add scripts/ops/phase5_server_sql_gate.ps1 test/scripts/ops/phase5_governance_preflight_test.dart
git commit -m "feat: add phase 5 server sql gate"
```

---

## Task 3: Implement One-Key Phase 5 Release Preflight

**Files:**
- Create: `scripts/ops/phase5_release_preflight.ps1`
- Test: `test/scripts/ops/phase5_governance_preflight_test.dart`

- [ ] **Step 1: Create the release preflight script**

Create `scripts/ops/phase5_release_preflight.ps1` with these concrete elements:

```powershell
param(
  [string]$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path,
  [string]$OutputDirectory = '',
  [string]$RemoteHost = 'ubuntu@42.194.218.158',
  [string]$RemoteRoot = '/opt/wukongim-prod/src/deploy/production',
  [string]$RemoteSourceRoot = '/opt/wukongim-prod/src',
  [switch]$SkipRemote
)

$ErrorActionPreference = 'Continue'
$FailedGates = New-Object System.Collections.Generic.List[string]

if ([string]::IsNullOrWhiteSpace($OutputDirectory)) {
  $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
  $OutputDirectory = Join-Path $ProjectRoot "build\phase5-preflight\$stamp"
}

New-Item -ItemType Directory -Force -Path $OutputDirectory | Out-Null
Set-Location $ProjectRoot

function Quote-Bash {
  param([Parameter(Mandatory = $true)][string]$Value)
  $single = [string][char]39
  $double = [string][char]34
  $replacement = $single + $double + $single + $double + $single
  return $single + $Value.Replace($single, $replacement) + $single
}

function Invoke-Gate {
  param(
    [Parameter(Mandatory = $true)][string]$Name,
    [Parameter(Mandatory = $true)][scriptblock]$Command
  )

  $target = Join-Path $OutputDirectory "$Name.txt"
  "## $Name" | Set-Content -Path $target -Encoding UTF8
  "## started: $(Get-Date -Format o)" | Add-Content -Path $target -Encoding UTF8
  $exitCode = 0
  try {
    & $Command 2>&1 | Tee-Object -FilePath $target -Append
    $exitCode = if ($null -eq $LASTEXITCODE) { 0 } else { $LASTEXITCODE }
  } catch {
    "## error: $($_.Exception.Message)" | Add-Content -Path $target -Encoding UTF8
    $exitCode = 1
  }
  "## exit: $exitCode" | Add-Content -Path $target -Encoding UTF8
  "## finished: $(Get-Date -Format o)" | Add-Content -Path $target -Encoding UTF8
  if ($exitCode -ne 0) {
    $FailedGates.Add($Name) | Out-Null
  }
}

Invoke-Gate -Name 'local_git_status' -Command { git status --short --branch }
Invoke-Gate -Name 'flutter_analyze' -Command { flutter analyze }
Invoke-Gate -Name 'flutter_phase5_tests' -Command {
  flutter test `
    test/scripts/ops/phase5_governance_preflight_test.dart `
    test/scripts/ops/collect_im_performance_baseline_test.dart `
    test/modules/chat/chat_page_scene_flow_test.dart --plain-name "send button uses compact motion states for composer feedback"
}

if (!$SkipRemote) {
  Invoke-Gate -Name 'remote_docker_compose_config' -Command {
    $remoteRootArg = Quote-Bash -Value $RemoteRoot
    ssh $RemoteHost "bash -lc $(Quote-Bash -Value "cd $remoteRootArg && docker compose config >/tmp/wukongim-phase5-compose.yml && test -s /tmp/wukongim-phase5-compose.yml")"
  }
  Invoke-Gate -Name 'remote_nginx_syntax' -Command {
    ssh $RemoteHost "docker exec wukongim-prod-nginx nginx -t"
  }
  Invoke-Gate -Name 'remote_smoke_test' -Command {
    $remoteRootArg = Quote-Bash -Value $RemoteRoot
    ssh $RemoteHost "bash -lc $(Quote-Bash -Value "cd $remoteRootArg && python3 scripts/smoke_test.py --base-url http://127.0.0.1 --timeout 10")"
  }
  Invoke-Gate -Name 'remote_public_web_smoke' -Command {
    $remoteRootArg = Quote-Bash -Value $RemoteRoot
    $remoteCommand = @"
set -e
cd $remoteRootArg
public_domain=\`$(grep -E '^PUBLIC_DOMAIN=' .env | head -n1 | cut -d= -f2- | tr -d '"')
test -n "\`$public_domain"
curl -k -fsSI "https://\`$public_domain/index.html" | sed -n '1,16p'
curl -k -fsSI "https://\`$public_domain/flutter_bootstrap.js" | sed -n '1,16p'
curl -k -fsSI "https://\`$public_domain/wk_pwa_service_worker.js" | sed -n '1,16p'
curl -k -fsSI "https://\`$public_domain/manifest.json" | sed -n '1,16p'
"@
    ssh $RemoteHost "bash -lc $(Quote-Bash -Value $remoteCommand)"
  }
  Invoke-Gate -Name 'remote_websocket_handshake' -Command {
    $remoteRootArg = Quote-Bash -Value $RemoteRoot
    $remoteCommand = @"
set -e
cd $remoteRootArg
public_domain=\`$(grep -E '^PUBLIC_DOMAIN=' .env | head -n1 | cut -d= -f2- | tr -d '"')
test -n "\`$public_domain"
response_file=\`$(mktemp)
curl_status=0
curl -k --http1.1 --max-time 8 -i \
  -H 'Connection: Upgrade' \
  -H 'Upgrade: websocket' \
  -H 'Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==' \
  -H 'Sec-WebSocket-Version: 13' \
  "https://\`$public_domain/ws" > "\`$response_file" 2>&1 || curl_status=\`$?
sed -n '1,24p' "\`$response_file"
grep -q '101 Switching Protocols' "\`$response_file"
rm -f "\`$response_file"
if [ "\`$curl_status" -ne 0 ] && [ "\`$curl_status" -ne 52 ]; then
  exit "\`$curl_status"
fi
"@
    ssh $RemoteHost "bash -lc $(Quote-Bash -Value $remoteCommand)"
  }
  Invoke-Gate -Name 'server_sql_gate' -Command {
    powershell -NoProfile -ExecutionPolicy Bypass `
      -File (Join-Path $ProjectRoot 'scripts/ops/phase5_server_sql_gate.ps1') `
      -ProjectRoot $ProjectRoot `
      -OutputDirectory $OutputDirectory `
      -RemoteHost $RemoteHost `
      -RemoteSourceRoot $RemoteSourceRoot
  }
} else {
  Invoke-Gate -Name 'remote_gates_skipped' -Command { 'Remote gates skipped by -SkipRemote.' }
}

$summaryPath = Join-Path $OutputDirectory 'failed-gates.txt'
if ($FailedGates.Count -gt 0) {
  $FailedGates | Set-Content -Path $summaryPath -Encoding UTF8
  "Phase 5 preflight failed. Evidence: $OutputDirectory"
  "failed-gates: $($FailedGates -join ', ')"
  exit 1
}

'PASS' | Set-Content -Path $summaryPath -Encoding UTF8
"Phase 5 preflight passed. Evidence: $OutputDirectory"
exit 0
```

- [ ] **Step 2: Run the contract test to verify GREEN for preflight script wiring**

Run:

```powershell
flutter test test/scripts/ops/phase5_governance_preflight_test.dart --plain-name "release preflight captures"
```

Expected: PASS for the preflight script test. The runbook test may still fail until docs are updated.

- [ ] **Step 3: Syntax-check PowerShell parsing**

Run:

```powershell
$null = [System.Management.Automation.Language.Parser]::ParseFile('scripts/ops/phase5_release_preflight.ps1', [ref]$null, [ref]$null)
```

Expected: command exits 0 with no parser errors.

- [ ] **Step 4: Run local-only preflight smoke**

Run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/ops/phase5_release_preflight.ps1 -SkipRemote -OutputDirectory build/phase5-preflight/local-contract
```

Expected: exit 0. Evidence directory includes `local_git_status.txt`, `flutter_analyze.txt`, `flutter_phase5_tests.txt`, `remote_gates_skipped.txt`, and `failed-gates.txt` containing `PASS`.

- [ ] **Step 5: Commit**

```powershell
git add scripts/ops/phase5_release_preflight.ps1 test/scripts/ops/phase5_governance_preflight_test.dart
git commit -m "feat: add phase 5 release preflight gate"
```

---

## Task 4: Update Phase 5 Release Preflight Runbook

**Files:**
- Modify: `docs/production/phase-5-release-preflight.md`
- Test: `test/scripts/ops/phase5_governance_preflight_test.dart`

- [ ] **Step 1: Rewrite the runbook around the one-key command**

Replace `docs/production/phase-5-release-preflight.md` with this content:

```markdown
# Phase 5 Release Preflight

This runbook is the Phase 5 quality gate for production releases. A release is not ready if the one-key preflight fails or if any required evidence file is missing.

## One-key command

Run from the repository root:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/ops/phase5_release_preflight.ps1
```

For local script verification without production SSH probes:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/ops/phase5_release_preflight.ps1 -SkipRemote
```

The command writes evidence to:

```text
build/phase5-preflight/<timestamp>/
```

## Required local evidence

The evidence directory must include:

- `local_git_status.txt`
- `flutter_analyze.txt`
- `flutter_phase5_tests.txt`

`flutter_analyze.txt` must show `No issues found!` and `flutter_phase5_tests.txt` must show `All tests passed!`.

## Required remote production evidence

Current production host context: `ubuntu@42.194.218.158`.

The evidence directory must include:

- `remote_docker_compose_config.txt`
- `remote_nginx_syntax.txt`
- `remote_smoke_test.txt`
- `remote_public_web_smoke.txt`
- `remote_websocket_handshake.txt`
- `server_sql_gate.txt`

The `server_sql_gate.txt` file is produced by:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/ops/phase5_server_sql_gate.ps1
```

It is a read-only SQL/slow-query gate against `/opt/wukongim-prod/src`. It blocks release on high-risk SQL construction findings or missing slow-query evidence.

## Failure handling

- Analyzer failure blocks merge and release.
- Flutter Phase 5 test failure blocks merge and release.
- Docker Compose config failure blocks production deploy.
- Nginx syntax failure blocks production deploy.
- Smoke or websocket failure blocks production deploy until a fresh passing preflight directory is captured.
- SQL gate failure blocks production deploy until findings are triaged in the backend source or the gate is intentionally adjusted with reviewed evidence.
- The script writes `failed-gates.txt`; if it contains anything other than `PASS`, the release is blocked.

## Safety boundary

The Phase 5 preflight is read-only. It must not restart containers, reload Nginx, mutate backend files, or deploy artifacts.
```

- [ ] **Step 2: Run the runbook contract test**

Run:

```powershell
flutter test test/scripts/ops/phase5_governance_preflight_test.dart --plain-name "release preflight runbook"
```

Expected: PASS.

- [ ] **Step 3: Run all script contract tests**

Run:

```powershell
flutter test test/scripts/ops/phase5_governance_preflight_test.dart
```

Expected: All tests passed.

- [ ] **Step 4: Commit**

```powershell
git add docs/production/phase-5-release-preflight.md test/scripts/ops/phase5_governance_preflight_test.dart
git commit -m "docs: document phase 5 one-key preflight"
```

---

## Task 5: Tighten Send Button PressedScale Tests and Implementation

**Files:**
- Modify: `test/modules/chat/chat_page_scene_flow_test.dart`
- Modify: `lib/modules/chat/chat_page_shell.dart`

- [ ] **Step 1: Write the failing exact motion assertions**

In `test/modules/chat/chat_page_scene_flow_test.dart`, add this import near the other package imports:

```dart
import 'package:wukong_im_app/core/motion/chat_motion.dart';
```

Then update the existing test named `send button uses compact motion states for composer feedback` so the motion assertions become exact:

```dart
    expect(motionFinder, findsOneWidget);
    final disabledMotion = tester.widget<AnimatedScale>(motionFinder);
    expect(disabledMotion.scale, 0.88);
    expect(disabledMotion.duration, ChatMotionDurations.pressedScale.value);

    final input = find.byKey(const ValueKey<String>('chat-input-field'));
    await tester.enterText(input, 'micro interaction');
    await tester.pumpAndSettle();
    final enabledMotion = tester.widget<AnimatedScale>(motionFinder);
    expect(enabledMotion.scale, 1.0);
    expect(enabledMotion.duration, ChatMotionDurations.pressedScale.value);

    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey<String>('chat-send-button'))),
    );
    await tester.pump();
    expect(tester.widget<AnimatedScale>(motionFinder).scale, 0.92);
    await gesture.up();
    await tester.pump();
    expect(tester.widget<AnimatedScale>(motionFinder).scale, 1.0);
```

- [ ] **Step 2: Run the test to verify RED**

Run:

```powershell
flutter test test/modules/chat/chat_page_scene_flow_test.dart --plain-name "send button uses compact motion states for composer feedback"
```

Expected: FAIL because the current `AnimatedScale.duration` is still `140ms`, not `ChatMotionDurations.pressedScale.value` (`120ms`).

- [ ] **Step 3: Implement token-based duration**

In `lib/modules/chat/chat_page_shell.dart`, add this import with the other core imports:

```dart
import '../../core/motion/chat_motion.dart';
```

Then replace the current hard-coded send-button scale duration:

```dart
        duration: reduceMotion
            ? Duration.zero
            : const Duration(milliseconds: 140),
```

with:

```dart
        duration: ChatMotionDurations.pressedScale.resolve(
          disableAnimations: reduceMotion,
        ),
```

Keep the existing scale values:

```dart
final scale = widget.enabled ? (_pressed ? 0.92 : 1.0) : 0.88;
```

- [ ] **Step 4: Run the focused test to verify GREEN**

Run:

```powershell
flutter test test/modules/chat/chat_page_scene_flow_test.dart --plain-name "send button uses compact motion states for composer feedback"
```

Expected: All tests passed.

- [ ] **Step 5: Commit**

```powershell
git add lib/modules/chat/chat_page_shell.dart test/modules/chat/chat_page_scene_flow_test.dart
git commit -m "fix: use pressed scale motion token for chat send button"
```

---

## Task 6: Final Verification and Remote Read-Only Preflight

**Files:**
- No source changes expected. Restore generated platform registrant files if Flutter commands touch them.

- [ ] **Step 1: Run focused tests**

```powershell
flutter test `
  test/scripts/ops/phase5_governance_preflight_test.dart `
  test/scripts/ops/collect_im_performance_baseline_test.dart `
  test/modules/chat/chat_page_scene_flow_test.dart --plain-name "send button uses compact motion states for composer feedback"
```

Expected: All tests passed.

- [ ] **Step 2: Run targeted analyzer**

```powershell
flutter analyze `
  lib/modules/chat/chat_page_shell.dart `
  test/modules/chat/chat_page_scene_flow_test.dart `
  test/scripts/ops/phase5_governance_preflight_test.dart
```

Expected: `No issues found!`.

- [ ] **Step 3: Run local-only preflight**

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/ops/phase5_release_preflight.ps1 -SkipRemote -OutputDirectory build/phase5-preflight/local-final
```

Expected: exit 0 and `build/phase5-preflight/local-final/failed-gates.txt` contains `PASS`.

- [ ] **Step 4: Run remote SQL gate read-only if SSH is available**

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/ops/phase5_server_sql_gate.ps1 -OutputDirectory build/phase5-preflight/remote-sql-final
```

Expected: exit 0 if the remote backend has no high-risk SQL findings and slow-query evidence exists. If it exits non-zero, do not hide it; report the findings from `build/phase5-preflight/remote-sql-final/server_sql_gate.txt` as backend follow-up evidence.

- [ ] **Step 5: Run full remote one-key preflight if SSH remains available**

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/ops/phase5_release_preflight.ps1 -OutputDirectory build/phase5-preflight/remote-final
```

Expected: exit 0 only if every remote read-only release gate passes. If it exits non-zero because the new SQL gate finds backend issues, keep the script implementation complete and report the blocked gate honestly.

- [ ] **Step 6: Restore generated plugin registrant files if dirty**

```powershell
git restore -- `
  linux/flutter/generated_plugin_registrant.cc `
  linux/flutter/generated_plugin_registrant.h `
  linux/flutter/generated_plugins.cmake `
  macos/Flutter/GeneratedPluginRegistrant.swift `
  windows/flutter/generated_plugin_registrant.cc `
  windows/flutter/generated_plugin_registrant.h `
  windows/flutter/generated_plugins.cmake
```

- [ ] **Step 7: Confirm clean status**

```powershell
git status --short --branch
```

Expected: clean branch status after all commits, or only intentionally untracked evidence under ignored `build/`.

---

## Plan Self-Review

- Spec coverage:
  - SQL/slow-query gate: Task 1 and Task 2.
  - One-key docker-compose/Nginx/smoke/websocket preflight: Task 1 and Task 3.
  - Runbook update: Task 4.
  - Send button exact `0.92` and `pressedScale`: Task 5.
  - Verification and honest remote evidence: Task 6.
- Placeholder scan: no implementation step uses TBD/TODO/fill-in language.
- Type/signature consistency:
  - PowerShell parameters are consistent across scripts: `ProjectRoot`, `OutputDirectory`, `RemoteHost`, `RemoteRoot`, `RemoteSourceRoot`, `SkipRemote`.
  - Evidence filenames match test assertions and runbook references.
  - Flutter test imports and implementation both use `ChatMotionDurations.pressedScale`.

# P0 IM Stop-Bleed Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove P0 production risks in the IM release path by fixing HTTPS release validation, secret-log detection, coturn TLS/DTLS readiness, and pending-call fallback polling.

**Architecture:** Keep the Flutter application behavior unchanged except for call fallback scheduling. Add local operation scripts and tests, patch production validation scripts on the remote host, repair coturn config with timestamped backup, and capture remote verification in a durable report.

**Tech Stack:** Flutter/Dart, PowerShell/Pester-style source assertions, Python 3 stdlib `unittest`, Bash, Docker Compose, coturn `turnutils_*`, SSH to `ubuntu@42.194.218.158`.

---

## File Structure

### Local workspace files

- Modify: `C:\Users\COLORFUL\Desktop\WuKong\lib\modules\video_call\call_coordinator.dart`
- Modify: `C:\Users\COLORFUL\Desktop\WuKong\test\modules\video_call\call_runtime_recovery_test.dart`
- Modify: `C:\Users\COLORFUL\Desktop\WuKong\scripts\ops\remote_redeploy.sh`
- Create: `C:\Users\COLORFUL\Desktop\WuKong\scripts\ops\tests\remote_redeploy_release_gate.Tests.ps1`
- Create: `C:\Users\COLORFUL\Desktop\WuKong\scripts\ops\secret_log_scan.py`
- Create: `C:\Users\COLORFUL\Desktop\WuKong\scripts\ops\tests\test_secret_log_scan.py`
- Create: `C:\Users\COLORFUL\Desktop\WuKong\scripts\ops\coturn_tls_probe.sh`
- Create: `C:\Users\COLORFUL\Desktop\WuKong\docs\production\2026-05-02-p0-stop-bleed-verification.md`

### Remote production files

- Modify on `ubuntu@42.194.218.158`: `/opt/wukongim-prod/src/deploy/production/scripts/smoke_test.py`
- Modify on `ubuntu@42.194.218.158`: `/opt/wukongim-prod/src/deploy/production/scripts/perf_probe.py`
- Modify on `ubuntu@42.194.218.158`: `/opt/wukongim-prod/src/deploy/production/scripts/test_perf_probe.py`
- Create on `ubuntu@42.194.218.158`: `/opt/wukongim-prod/src/deploy/production/scripts/test_smoke_test.py`
- Modify on `ubuntu@42.194.218.158`: `/opt/wukongim-prod/src/deploy/production/config/turnserver.conf.tpl`
- Modify on `ubuntu@42.194.218.158`: `/opt/wukongim-prod/src/deploy/production/rendered/turnserver.conf`
- Modify on `ubuntu@42.194.218.158`: `/opt/wukongim-prod/src/deploy/production/docker-compose.yaml`
- Create on `ubuntu@42.194.218.158`: `/opt/wukongim-prod/src/deploy/production/rendered/coturn-certs/`

---

### Task 0: Create an isolated implementation worktree before touching code

**Files:**
- Use existing repo: `C:\Users\COLORFUL\Desktop\WuKong`
- Create worktree: `C:\Users\COLORFUL\.config\superpowers\worktrees\WuKong\p0-im-stop-bleed`

- [ ] **Step 1: Create a clean worktree from the current committed design baseline**

```powershell
git -C C:\Users\COLORFUL\Desktop\WuKong worktree add `
  C:\Users\COLORFUL\.config\superpowers\worktrees\WuKong\p0-im-stop-bleed `
  -b codex/p0-im-stop-bleed
```

Expected: command succeeds and creates branch `codex/p0-im-stop-bleed` without copying unrelated staged changes from the main workspace.

- [ ] **Step 2: Verify the worktree starts clean**

```powershell
git -C C:\Users\COLORFUL\.config\superpowers\worktrees\WuKong\p0-im-stop-bleed status --short
```

Expected: no output.

- [ ] **Step 3: Run a focused baseline test**

```powershell
flutter test C:\Users\COLORFUL\.config\superpowers\worktrees\WuKong\p0-im-stop-bleed\test\modules\video_call\call_runtime_recovery_test.dart
```

Expected: PASS. If it fails, record the failure and stop before implementation.

---

### Task 1: Make pending-call fallback degradation-only by default

**Files:**
- Modify: `C:\Users\COLORFUL\.config\superpowers\worktrees\WuKong\p0-im-stop-bleed\test\modules\video_call\call_runtime_recovery_test.dart`
- Modify: `C:\Users\COLORFUL\.config\superpowers\worktrees\WuKong\p0-im-stop-bleed\lib\modules\video_call\call_coordinator.dart`

- [ ] **Step 1: Write the failing fallback-default tests**

In `call_runtime_recovery_test.dart`, replace the test named `default safety polling interval is short enough for incoming rings` with:

```dart
test('defaults to degradation-only polling with the approved backoff schedule', () {
  final loop = PendingCallRecoveryLoop(
    callStore: CallStore(machine: const CallStateMachine()),
    fetchPendingCalls: ({required fallback}) async => <CallRoom>[],
    currentUidReader: () => 'u_self',
  );
  addTearDown(loop.stop);

  expect(loop.enableSafetyPolling, isFalse);
  expect(loop.degradedThreshold, const Duration(seconds: 6));
  expect(loop.backoffSchedule, <Duration>[
    Duration(seconds: 2),
    Duration(seconds: 5),
    Duration(seconds: 15),
    Duration(seconds: 30),
    Duration(seconds: 60),
  ]);
});
```

Then replace the test named `pulls pending invites by safety polling when app is foreground` with:

```dart
test('does not poll by default until the gateway is degraded', () async {
  final store = CallStore(machine: const CallStateMachine());
  addTearDown(store.dispose);

  var fetchCount = 0;
  final loop = PendingCallRecoveryLoop(
    callStore: store,
    fetchPendingCalls: ({required fallback}) async {
      fetchCount++;
      expect(fallback, isTrue);
      return <CallRoom>[
        CallRoom(
          roomId: 'room_pending_01',
          callerUid: 'u_peer',
          calleeUid: 'u_self',
          callType: CallType.video,
          status: CallRoomStatus.pending,
          callerName: 'Peer',
        ),
      ];
    },
    currentUidReader: () => 'u_self',
    degradedThreshold: Duration.zero,
    backoffSchedule: const <Duration>[Duration(milliseconds: 1)],
    delay: (_) => Completer<void>().future,
  );
  addTearDown(loop.stop);

  loop.setGatewayDegradationReader((_) => false);
  loop.start();

  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);

  expect(fetchCount, 0);
  expect(store.state.isActive, isFalse);

  loop.setGatewayDegradationReader((_) => true);

  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);

  expect(fetchCount, 1);
  expect(store.state.roomId, 'room_pending_01');
  expect(store.state.status, CallLifecycleStatus.invited);
});
```

- [ ] **Step 2: Run the focused test and verify RED**

```powershell
flutter test C:\Users\COLORFUL\.config\superpowers\worktrees\WuKong\p0-im-stop-bleed\test\modules\video_call\call_runtime_recovery_test.dart
```

Expected: FAIL because `enableSafetyPolling` still defaults to `true` and the default backoff schedule is still `2s, 4s, 8s, 15s`.

- [ ] **Step 3: Implement the minimal default change**

In `call_coordinator.dart`, update the `PendingCallRecoveryLoop` constructor defaults to:

```dart
    this.enableSafetyPolling = false,
    this.degradedThreshold = const Duration(seconds: 6),
    this.safetyPollingInterval = const Duration(seconds: 2),
    List<Duration> backoffSchedule = const <Duration>[
      Duration(seconds: 2),
      Duration(seconds: 5),
      Duration(seconds: 15),
      Duration(seconds: 30),
      Duration(seconds: 60),
    ],
```

Do not remove `safetyPollingInterval`; it remains a compatibility override for explicit emergency/safety polling.

- [ ] **Step 4: Run the focused test and verify GREEN**

```powershell
flutter test C:\Users\COLORFUL\.config\superpowers\worktrees\WuKong\p0-im-stop-bleed\test\modules\video_call\call_runtime_recovery_test.dart
```

Expected: PASS.

- [ ] **Step 5: Commit Task 1**

```powershell
git -C C:\Users\COLORFUL\.config\superpowers\worktrees\WuKong\p0-im-stop-bleed add `
  lib/modules/video_call/call_coordinator.dart `
  test/modules/video_call/call_runtime_recovery_test.dart

git -C C:\Users\COLORFUL\.config\superpowers\worktrees\WuKong\p0-im-stop-bleed commit `
  -m "fix: gate pending call fallback behind degradation"
```

Expected: commit succeeds.

---

### Task 2: Protect local remote redeploy smoke/perf gates from HTTP defaults

**Files:**
- Modify: `C:\Users\COLORFUL\.config\superpowers\worktrees\WuKong\p0-im-stop-bleed\scripts\ops\remote_redeploy.sh`
- Create: `C:\Users\COLORFUL\.config\superpowers\worktrees\WuKong\p0-im-stop-bleed\scripts\ops\tests\remote_redeploy_release_gate.Tests.ps1`

- [ ] **Step 1: Write the failing source assertion test**

Create `remote_redeploy_release_gate.Tests.ps1`:

```powershell
$scriptPath = Join-Path $PSScriptRoot '..\remote_redeploy.sh'

Describe 'remote_redeploy.sh release probes' {
  It 'does not hard-code loopback HTTP for production smoke and perf probes' {
    $content = Get-Content -Path $scriptPath -Raw

    $content | Should Match 'RELEASE_BASE_URL'
    $content | Should Match 'TSDD_BASE_URL'
    $content | Should Match 'ALLOW_HTTP_RELEASE_PROBES'
    $content | Should Not Match 'smoke_test\.py --base-url http://127\.0\.0\.1'
    $content | Should Not Match 'perf_probe\.py --base-url http://127\.0\.0\.1'
  }
}
```

- [ ] **Step 2: Run the Pester test and verify RED**

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -Command "Invoke-Pester -Script C:\Users\COLORFUL\.config\superpowers\worktrees\WuKong\p0-im-stop-bleed\scripts\ops\tests\remote_redeploy_release_gate.Tests.ps1"
```

Expected: FAIL because `remote_redeploy.sh` still invokes smoke/perf with `--base-url http://127.0.0.1`.

- [ ] **Step 3: Add release base URL resolution and HTTP guard**

In `remote_redeploy.sh`, after `BACKUP_DIR="${REMOTE_ROOT}/backups/releases"`, insert:

```bash
RELEASE_BASE_URL="${RELEASE_BASE_URL:-}"
ALLOW_HTTP_RELEASE_PROBES="${ALLOW_HTTP_RELEASE_PROBES:-0}"

resolve_release_base_url() {
  if [[ -n "${RELEASE_BASE_URL}" ]]; then
    printf '%s\n' "${RELEASE_BASE_URL%/}"
    return 0
  fi

  local env_base_url=""
  env_base_url="$(grep -E '^TSDD_BASE_URL=' "${ENV_FILE}" 2>/dev/null | tail -1 | cut -d= -f2- || true)"
  if [[ -n "${env_base_url}" ]]; then
    printf '%s\n' "${env_base_url%/}"
    return 0
  fi

  printf '%s\n' 'https://infoequity.qingyunshe.top'
}

assert_release_base_url_safe() {
  local base_url="$1"
  if [[ "${base_url}" == http://* && "${ALLOW_HTTP_RELEASE_PROBES}" != "1" ]]; then
    cat >&2 <<EOF
Refusing production release probes over HTTP: ${base_url}
Use RELEASE_BASE_URL=https://infoequity.qingyunshe.top or set ALLOW_HTTP_RELEASE_PROBES=1 only for an explicit local-only diagnostic.
EOF
    return 1
  fi
}
```

Then replace the smoke/perf block with:

```bash
RELEASE_BASE_URL="$(resolve_release_base_url)"
assert_release_base_url_safe "${RELEASE_BASE_URL}"

echo "== smoke (${RELEASE_BASE_URL}) =="
python3 scripts/smoke_test.py --base-url "${RELEASE_BASE_URL}" --timeout 10

echo "== perf (${RELEASE_BASE_URL}) =="
python3 scripts/perf_probe.py --base-url "${RELEASE_BASE_URL}" --samples 20 --timeout 10
```

- [ ] **Step 4: Run the Pester test and verify GREEN**

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -Command "Invoke-Pester -Script C:\Users\COLORFUL\.config\superpowers\worktrees\WuKong\p0-im-stop-bleed\scripts\ops\tests\remote_redeploy_release_gate.Tests.ps1"
```

Expected: PASS.

- [ ] **Step 5: Run Bash syntax check**

```powershell
bash -n C:\Users\COLORFUL\.config\superpowers\worktrees\WuKong\p0-im-stop-bleed\scripts\ops\remote_redeploy.sh
```

Expected: no output and exit code 0.

- [ ] **Step 6: Commit Task 2**

```powershell
git -C C:\Users\COLORFUL\.config\superpowers\worktrees\WuKong\p0-im-stop-bleed add `
  scripts/ops/remote_redeploy.sh `
  scripts/ops/tests/remote_redeploy_release_gate.Tests.ps1

git -C C:\Users\COLORFUL\.config\superpowers\worktrees\WuKong\p0-im-stop-bleed commit `
  -m "fix: use https release probes in remote redeploy"
```

Expected: commit succeeds.

---

### Task 3: Add a redacting sensitive-log scanner

**Files:**
- Create: `C:\Users\COLORFUL\.config\superpowers\worktrees\WuKong\p0-im-stop-bleed\scripts\ops\secret_log_scan.py`
- Create: `C:\Users\COLORFUL\.config\superpowers\worktrees\WuKong\p0-im-stop-bleed\scripts\ops\tests\test_secret_log_scan.py`

- [ ] **Step 1: Write the failing Python unittest**

Create `test_secret_log_scan.py`:

```python
#!/usr/bin/env python3
from __future__ import annotations

import sys
import unittest
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(SCRIPT_DIR))

from secret_log_scan import scan_text  # noqa: E402


class SecretLogScanTests(unittest.TestCase):
    def test_detects_act_token_without_printing_raw_value(self) -> None:
        raw_token = "2571b1659ff3498daa462b30365bfd63"
        text = (
            'wukongim-1 | {"msg":"token verify fail",'
            f'"uid":"u1","actToken":"{raw_token}"}'
        )

        result = scan_text(text, source="wukongim")

        self.assertEqual(result.finding_count, 1)
        self.assertIn("actToken", result.redacted_report)
        self.assertIn("<redacted>", result.redacted_report)
        self.assertNotIn(raw_token, result.redacted_report)

    def test_ignores_safe_token_metadata(self) -> None:
        text = "auth_token_verify_failed uid=u1 token_empty=false token_hash=abcdef12 phase=im_connect"

        result = scan_text(text, source="tsdd-api")

        self.assertEqual(result.finding_count, 0)
        self.assertEqual(result.redacted_report, "")


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run the unittest and verify RED**

```powershell
python C:\Users\COLORFUL\.config\superpowers\worktrees\WuKong\p0-im-stop-bleed\scripts\ops\tests\test_secret_log_scan.py
```

Expected: FAIL with `ModuleNotFoundError: No module named 'secret_log_scan'`.

- [ ] **Step 3: Implement the scanner**

Create `secret_log_scan.py`:

```python
#!/usr/bin/env python3
from __future__ import annotations

import argparse
import re
import sys
from dataclasses import dataclass
from pathlib import Path

DANGEROUS_FIELD_PATTERN = re.compile(
    r'(?P<field>actToken|expectToken|password|secret|Authorization|api[_-]?key|api[_-]?secret|credential|token)'
    r'(?P<sep>["\']?\s*[:=]\s*["\']?)'
    r'(?P<value>[^\s,"\';}]+)',
    re.IGNORECASE,
)

SAFE_TOKEN_METADATA_PATTERN = re.compile(
    r'\b(token_empty|token_hash|token_length|token_len|token_sha256|token_sha256_prefix)\b',
    re.IGNORECASE,
)


@dataclass(frozen=True)
class ScanResult:
    finding_count: int
    redacted_report: str


def _looks_like_safe_metadata(line: str, match: re.Match[str]) -> bool:
    field = match.group("field").lower()
    if field != "token":
        return False
    return bool(SAFE_TOKEN_METADATA_PATTERN.search(line))


def _redact_line(line: str) -> str:
    def replace(match: re.Match[str]) -> str:
        return f"{match.group('field')}{match.group('sep')}<redacted>"

    return DANGEROUS_FIELD_PATTERN.sub(replace, line)


def scan_text(text: str, *, source: str = "stdin") -> ScanResult:
    findings: list[str] = []
    for line_number, line in enumerate(text.splitlines(), start=1):
        matches = list(DANGEROUS_FIELD_PATTERN.finditer(line))
        actionable = [m for m in matches if not _looks_like_safe_metadata(line, m)]
        if not actionable:
            continue
        fields = ",".join(sorted({m.group("field") for m in actionable}))
        findings.append(
            f"{source}:{line_number}: fields={fields} sample={_redact_line(line)}"
        )
    return ScanResult(
        finding_count=len(findings),
        redacted_report="\n".join(findings),
    )


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Scan logs for raw secret fields while redacting values."
    )
    parser.add_argument("paths", nargs="*", help="Log files to scan. Reads stdin when omitted.")
    parser.add_argument("--source", default="stdin", help="Source label used for stdin scans.")
    return parser.parse_args(argv)


def main(argv: list[str]) -> int:
    args = parse_args(argv)
    combined_findings: list[str] = []
    finding_count = 0

    if args.paths:
        for raw_path in args.paths:
            path = Path(raw_path)
            text = path.read_text(encoding="utf-8", errors="replace")
            result = scan_text(text, source=str(path))
            finding_count += result.finding_count
            if result.redacted_report:
                combined_findings.append(result.redacted_report)
    else:
        result = scan_text(sys.stdin.read(), source=args.source)
        finding_count += result.finding_count
        if result.redacted_report:
            combined_findings.append(result.redacted_report)

    if combined_findings:
        print("\n".join(combined_findings))
    return 1 if finding_count else 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
```

- [ ] **Step 4: Run the unittest and verify GREEN**

```powershell
python C:\Users\COLORFUL\.config\superpowers\worktrees\WuKong\p0-im-stop-bleed\scripts\ops\tests\test_secret_log_scan.py
```

Expected: PASS.

- [ ] **Step 5: Run a local sample scan**

```powershell
'{"actToken":"2571b1659ff3498daa462b30365bfd63"}' | python C:\Users\COLORFUL\.config\superpowers\worktrees\WuKong\p0-im-stop-bleed\scripts\ops\secret_log_scan.py --source sample
```

Expected: exit code 1, output contains `actToken` and `<redacted>`, and does not contain `2571b1659ff3498daa462b30365bfd63`.

- [ ] **Step 6: Commit Task 3**

```powershell
git -C C:\Users\COLORFUL\.config\superpowers\worktrees\WuKong\p0-im-stop-bleed add `
  scripts/ops/secret_log_scan.py `
  scripts/ops/tests/test_secret_log_scan.py

git -C C:\Users\COLORFUL\.config\superpowers\worktrees\WuKong\p0-im-stop-bleed commit `
  -m "test: add secret log scanner"
```

Expected: commit succeeds.

---

### Task 4: Add a coturn TLS/STUN/TURN probe wrapper

**Files:**
- Create: `C:\Users\COLORFUL\.config\superpowers\worktrees\WuKong\p0-im-stop-bleed\scripts\ops\coturn_tls_probe.sh`

- [ ] **Step 1: Write the probe script**

Create `coturn_tls_probe.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

COMPOSE_DIR="${1:-/opt/wukongim-prod/src/deploy/production}"
TURN_HOST="${TURN_HOST:-127.0.0.1}"
TURN_REALM="${TURN_REALM:-infoequity.qingyunshe.top}"
TURN_USER="${TURN_USER:-codex-turn-probe}"
TURN_PASSWORD="${TURN_PASSWORD:-codex-turn-probe-pass}"

cd "${COMPOSE_DIR}"

echo "== coturn container identity =="
docker compose --env-file .env exec -T coturn sh -lc 'id; test -r /etc/coturn/certs/fullchain.pem && echo CERT_READABLE || echo CERT_NOT_READABLE; test -r /etc/coturn/certs/privkey.pem && echo PRIVKEY_READABLE || echo PRIVKEY_NOT_READABLE'

echo "== coturn recent TLS/config warnings =="
docker compose --env-file .env logs --tail=200 coturn 2>/dev/null \
  | grep -Ei 'bad configuration|cannot find private key|cannot start TLS|DTLS|TLS|WARNING|ERROR' \
  | sed -E 's/(static-auth-secret|realm|user|password|secret|key)([^[:space:]]*)[=:][^[:space:]]+/\1\2=<redacted>/Ig' \
  || true

echo "== STUN 3478 probe =="
docker compose --env-file .env exec -T coturn turnutils_stunclient "${TURN_HOST}" 3478

echo "== TURN UDP 3478 probe =="
docker compose --env-file .env exec -T coturn turnutils_uclient \
  -u "${TURN_USER}" -w "${TURN_PASSWORD}" -r "${TURN_REALM}" \
  -y "${TURN_HOST}" 3478 || true

echo "== TURNS 5349 TLS handshake probe =="
docker compose --env-file .env exec -T coturn sh -lc \
  "printf '' | openssl s_client -connect ${TURN_HOST}:5349 -servername ${TURN_REALM} -brief 2>/dev/null | head -20"
```

- [ ] **Step 2: Run Bash syntax check**

```powershell
bash -n C:\Users\COLORFUL\.config\superpowers\worktrees\WuKong\p0-im-stop-bleed\scripts\ops\coturn_tls_probe.sh
```

Expected: no output and exit code 0.

- [ ] **Step 3: Commit Task 4**

```powershell
git -C C:\Users\COLORFUL\.config\superpowers\worktrees\WuKong\p0-im-stop-bleed add scripts/ops/coturn_tls_probe.sh

git -C C:\Users\COLORFUL\.config\superpowers\worktrees\WuKong\p0-im-stop-bleed commit `
  -m "chore: add coturn tls probe"
```

Expected: commit succeeds.

---

### Task 5: Patch remote smoke/perf scripts with URL guards and 308 guidance

**Files:**
- Remote modify: `/opt/wukongim-prod/src/deploy/production/scripts/smoke_test.py`
- Remote modify: `/opt/wukongim-prod/src/deploy/production/scripts/perf_probe.py`
- Remote modify: `/opt/wukongim-prod/src/deploy/production/scripts/test_perf_probe.py`
- Remote create: `/opt/wukongim-prod/src/deploy/production/scripts/test_smoke_test.py`

- [ ] **Step 1: Back up remote scripts**

```powershell
ssh ubuntu@42.194.218.158 'set -eu; cd /opt/wukongim-prod/src/deploy/production; ts=$(date +%Y%m%d%H%M%S); backup=/home/ubuntu/wukong-deploy-backups/p0-stop-bleed-$ts; mkdir -p $backup/scripts; cp scripts/smoke_test.py scripts/perf_probe.py scripts/test_perf_probe.py $backup/scripts/; printf "%s\n" $backup'
```

Expected: prints a backup directory under `/home/ubuntu/wukong-deploy-backups/`.

- [ ] **Step 2: Add failing remote smoke tests**

Create `/opt/wukongim-prod/src/deploy/production/scripts/test_smoke_test.py`:

```python
#!/usr/bin/env python3
from __future__ import annotations

import unittest

from smoke_test import explain_http_base_url, validate_base_url


class SmokeBaseUrlTests(unittest.TestCase):
    def test_rejects_http_public_release_url_by_default(self) -> None:
        with self.assertRaisesRegex(ValueError, "Use HTTPS"):
            validate_base_url("http://infoequity.qingyunshe.top", allow_http=False)

    def test_allows_http_loopback_only_when_explicitly_allowed(self) -> None:
        self.assertEqual(
            validate_base_url("http://127.0.0.1", allow_http=True),
            "http://127.0.0.1",
        )

    def test_explains_https_equivalent(self) -> None:
        self.assertIn(
            "https://infoequity.qingyunshe.top",
            explain_http_base_url("http://infoequity.qingyunshe.top"),
        )


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 3: Add failing remote perf tests**

Append this method to `scripts/test_perf_probe.py` inside `class PerfProbeTests(unittest.TestCase):`:

```python
    def test_rejects_http_public_release_url_by_default(self) -> None:
        from perf_probe import explain_http_base_url, validate_base_url

        with self.assertRaisesRegex(ValueError, "Use HTTPS"):
            validate_base_url("http://infoequity.qingyunshe.top", allow_http=False)

        self.assertIn(
            "https://infoequity.qingyunshe.top",
            explain_http_base_url("http://infoequity.qingyunshe.top"),
        )
```

- [ ] **Step 4: Run remote tests and verify RED**

```powershell
ssh ubuntu@42.194.218.158 "cd /opt/wukongim-prod/src/deploy/production/scripts && python3 test_smoke_test.py && python3 test_perf_probe.py"
```

Expected: FAIL because `explain_http_base_url` and `validate_base_url` do not exist yet.

- [ ] **Step 5: Implement URL helpers in both smoke/perf scripts**

In both `smoke_test.py` and `perf_probe.py`, add:

```python
from urllib.parse import urlparse, urlunparse
```

Add after `default_base_url`:

```python
def explain_http_base_url(base_url: str) -> str:
    parsed = urlparse(base_url)
    https_url = urlunparse(("https", parsed.netloc, parsed.path.rstrip("/"), "", "", ""))
    return (
        f"Production release probes must use HTTPS. Refusing HTTP base URL: {base_url}. "
        f"Use HTTPS instead: {https_url}"
    )


def _is_loopback_host(hostname: str | None) -> bool:
    return (hostname or "").lower() in {"127.0.0.1", "localhost", "::1"}


def validate_base_url(base_url: str, *, allow_http: bool = False) -> str:
    normalized = base_url.rstrip("/")
    parsed = urlparse(normalized)
    if parsed.scheme not in {"http", "https"} or not parsed.netloc:
        raise ValueError(f"Invalid --base-url: {base_url}")
    if parsed.scheme == "http" and not allow_http:
        raise ValueError(explain_http_base_url(normalized))
    if parsed.scheme == "http" and allow_http and not _is_loopback_host(parsed.hostname):
        raise ValueError(explain_http_base_url(normalized))
    return normalized
```

Add this parser option in both scripts:

```python
    parser.add_argument(
        "--allow-http-base-url",
        action="store_true",
        help="Allow HTTP only for explicit loopback diagnostics; production release probes should use HTTPS.",
    )
```

Add this at the start of `main()` in both scripts immediately after `args = parse_args()`:

```python
    args.base_url = validate_base_url(
        args.base_url,
        allow_http=args.allow_http_base_url,
    )
```

Replace the `except error.HTTPError as exc:` body in both scripts with:

```python
    except error.HTTPError as exc:
        raw = exc.read().decode("utf-8", errors="replace")
        if exc.code == 308:
            location = exc.headers.get("Location", "")
            raise RuntimeError(
                f"{method.upper()} {path} received HTTP 308 redirect to {location}. "
                f"Use an HTTPS --base-url such as https://infoequity.qingyunshe.top."
            ) from exc
        raise RuntimeError(f"{method.upper()} {path} failed with HTTP {exc.code}: {raw}") from exc
```

- [ ] **Step 6: Run remote tests and verify GREEN**

```powershell
ssh ubuntu@42.194.218.158 "cd /opt/wukongim-prod/src/deploy/production/scripts && python3 test_smoke_test.py && python3 test_perf_probe.py"
```

Expected: PASS.

- [ ] **Step 7: Run HTTPS smoke and short perf probes**

```powershell
ssh ubuntu@42.194.218.158 "cd /opt/wukongim-prod/src/deploy/production && python3 scripts/smoke_test.py --base-url https://infoequity.qingyunshe.top --timeout 10 && python3 scripts/perf_probe.py --base-url https://infoequity.qingyunshe.top --samples 3 --concurrency 1 --timeout 10"
```

Expected: smoke succeeds and perf prints latency summary. If the API returns a business failure unrelated to URL validation, capture sanitized output and stop before coturn changes.

---

### Task 6: Repair remote coturn TLS/DTLS configuration safely

**Files:**
- Remote modify: `/opt/wukongim-prod/src/deploy/production/config/turnserver.conf.tpl`
- Remote modify: `/opt/wukongim-prod/src/deploy/production/rendered/turnserver.conf`
- Remote modify: `/opt/wukongim-prod/src/deploy/production/docker-compose.yaml`
- Remote create: `/opt/wukongim-prod/src/deploy/production/rendered/coturn-certs/`

- [ ] **Step 1: Capture pre-change coturn failures with redaction**

```powershell
ssh ubuntu@42.194.218.158 "cd /opt/wukongim-prod/src/deploy/production && docker compose --env-file .env logs --tail=200 coturn 2>/dev/null | grep -Ei 'Bad configuration format|cannot find private key|cannot start TLS|WARNING|ERROR' | sed -E 's/(static-auth-secret|realm|user|password|secret|key)([^[:space:]]*)[=:][^[:space:]]+/\1\2=<redacted>/Ig' || true"
```

Expected: output includes current `Bad configuration format: no-loopback-peers` and private-key/TLS warning evidence.

- [ ] **Step 2: Back up coturn config and compose files**

```powershell
ssh ubuntu@42.194.218.158 'set -eu; cd /opt/wukongim-prod/src/deploy/production; ts=$(date +%Y%m%d%H%M%S); backup=/home/ubuntu/wukong-deploy-backups/p0-stop-bleed-$ts; mkdir -p $backup; cp docker-compose.yaml $backup/; cp config/turnserver.conf.tpl $backup/; cp rendered/turnserver.conf $backup/; printf "%s\n" $backup'
```

Expected: prints backup directory.

- [ ] **Step 3: Create coturn-readable certificate copies without printing secret content**

```powershell
ssh ubuntu@42.194.218.158 'set -eu; cd /opt/wukongim-prod/src/deploy/production; . ./.env; install -d -m 0750 rendered/coturn-certs; sudo cp "$NGINX_SSL_CERT_PATH" rendered/coturn-certs/fullchain.pem; sudo cp "$NGINX_SSL_KEY_PATH" rendered/coturn-certs/privkey.pem; sudo chown root:65534 rendered/coturn-certs/fullchain.pem rendered/coturn-certs/privkey.pem; sudo chmod 0640 rendered/coturn-certs/fullchain.pem rendered/coturn-certs/privkey.pem; ls -l rendered/coturn-certs/fullchain.pem rendered/coturn-certs/privkey.pem | sed -E "s/(privkey.pem).*/\1 <metadata-redacted>/"'
```

Expected: metadata shows files exist; private key content is not printed.

- [ ] **Step 4: Remove unsupported no-loopback-peers from template and rendered config**

```powershell
ssh ubuntu@42.194.218.158 "set -eu; cd /opt/wukongim-prod/src/deploy/production; python3 - <<'PY'
from pathlib import Path
for raw in ['config/turnserver.conf.tpl', 'rendered/turnserver.conf']:
    path = Path(raw)
    lines = path.read_text(encoding='utf-8').splitlines()
    next_lines = [line for line in lines if line.strip() != 'no-loopback-peers']
    path.write_text('\n'.join(next_lines) + '\n', encoding='utf-8')
PY
! grep -RIn '^no-loopback-peers$' config/turnserver.conf.tpl rendered/turnserver.conf"
```

Expected: no `no-loopback-peers` lines remain.

- [ ] **Step 5: Point coturn compose mounts at readable cert copies**

```powershell
ssh ubuntu@42.194.218.158 "set -eu; cd /opt/wukongim-prod/src/deploy/production; python3 - <<'PY'
from pathlib import Path
path = Path('docker-compose.yaml')
text = path.read_text(encoding='utf-8')
text = text.replace('${NGINX_SSL_CERT_PATH}:/etc/coturn/certs/fullchain.pem:ro', './rendered/coturn-certs/fullchain.pem:/etc/coturn/certs/fullchain.pem:ro')
text = text.replace('${NGINX_SSL_KEY_PATH}:/etc/coturn/certs/privkey.pem:ro', './rendered/coturn-certs/privkey.pem:/etc/coturn/certs/privkey.pem:ro')
path.write_text(text, encoding='utf-8')
PY
grep -n 'coturn-certs' docker-compose.yaml"
```

Expected: compose coturn volume block references `./rendered/coturn-certs/fullchain.pem` and `./rendered/coturn-certs/privkey.pem`.

- [ ] **Step 6: Validate compose config before restart**

```powershell
ssh ubuntu@42.194.218.158 "cd /opt/wukongim-prod/src/deploy/production && docker compose --env-file .env config >/tmp/p0-stop-bleed-compose.yaml && echo COMPOSE_CONFIG_OK"
```

Expected: `COMPOSE_CONFIG_OK`.

- [ ] **Step 7: Restart coturn only**

```powershell
ssh ubuntu@42.194.218.158 "cd /opt/wukongim-prod/src/deploy/production && docker compose --env-file .env up -d --no-deps coturn && sleep 5 && docker compose --env-file .env ps coturn"
```

Expected: coturn container is `Up`.

- [ ] **Step 8: Verify coturn can read cert/key and warnings are gone**

```powershell
ssh ubuntu@42.194.218.158 "cd /opt/wukongim-prod/src/deploy/production && docker compose --env-file .env exec -T coturn sh -lc 'id; test -r /etc/coturn/certs/fullchain.pem && echo CERT_READABLE; test -r /etc/coturn/certs/privkey.pem && echo PRIVKEY_READABLE' && docker compose --env-file .env logs --tail=120 coturn 2>/dev/null | grep -Ei 'Bad configuration format|cannot find private key|cannot start TLS' && exit 1 || echo COTURN_WARNINGS_CLEARED"
```

Expected: includes `CERT_READABLE`, `PRIVKEY_READABLE`, and `COTURN_WARNINGS_CLEARED`.

- [ ] **Step 9: Run connectivity probes**

```powershell
scp C:\Users\COLORFUL\.config\superpowers\worktrees\WuKong\p0-im-stop-bleed\scripts\ops\coturn_tls_probe.sh ubuntu@42.194.218.158:/tmp/coturn_tls_probe.sh
ssh ubuntu@42.194.218.158 "chmod +x /tmp/coturn_tls_probe.sh && /tmp/coturn_tls_probe.sh /opt/wukongim-prod/src/deploy/production"
```

Expected: STUN succeeds, TURNS TLS handshake prints protocol/cipher summary, and TURN UDP probe prints an explicit result. If TURN auth fails because no static test user is configured, record it as auth-specific rather than TLS-specific.

---

### Task 7: Run remote secret scan and write verification report

**Files:**
- Create: `C:\Users\COLORFUL\.config\superpowers\worktrees\WuKong\p0-im-stop-bleed\docs\production\2026-05-02-p0-stop-bleed-verification.md`

- [ ] **Step 1: Run scanner against remote logs**

```powershell
ssh ubuntu@42.194.218.158 'cd /opt/wukongim-prod/src/deploy/production && for svc in tsdd-api callgateway wukongim; do echo == $svc ==; docker compose --env-file .env logs --tail=1000 $svc 2>/dev/null; done' | python C:\Users\COLORFUL\.config\superpowers\worktrees\WuKong\p0-im-stop-bleed\scripts\ops\secret_log_scan.py --source remote-docker-logs
```

Expected: exit code 1 while the upstream WuKongIM image still emits raw `actToken`; output is redacted and contains no raw token value.

- [ ] **Step 2: Create verification report**

Create `2026-05-02-p0-stop-bleed-verification.md` with exact sanitized command outputs:

```markdown
# P0 IM Stop-Bleed Verification Report

> Date: 2026-05-02
> Host: ubuntu@42.194.218.158
> Scope: release validation, secret-log scan, coturn TLS/DTLS, pending-call fallback defaults.

## Local Flutter Verification

- `flutter test test/modules/video_call/call_runtime_recovery_test.dart`: PASS

## Local Script Verification

- `remote_redeploy_release_gate.Tests.ps1`: PASS
- `test_secret_log_scan.py`: PASS
- `bash -n scripts/ops/remote_redeploy.sh`: PASS
- `bash -n scripts/ops/coturn_tls_probe.sh`: PASS

## Remote Release Validation

- `python3 scripts/test_smoke_test.py`: PASS
- `python3 scripts/test_perf_probe.py`: PASS
- HTTPS smoke result: PASS
- HTTPS perf result: PASS

## Remote coturn Verification

- Backup directory: record the exact `/home/ubuntu/wukong-deploy-backups/p0-stop-bleed-*` path printed by Task 6 Step 2.
- Compose config: PASS
- coturn cert readability: PASS
- coturn warning scan: PASS
- STUN 3478: PASS
- TURN UDP 3478: recorded result
- TURNS 5349 TLS: PASS

## Remote Secret Log Scan

- `tsdd-api`: no raw secret findings in scanned tail
- `callgateway`: no raw secret findings in scanned tail
- `wukongim`: FAIL - upstream image still emits `actToken=<redacted>` in historical/current logs

## Remaining P0 Risk

WuKongIM official image `registry.cn-shanghai.aliyuncs.com/wukongim/wukongim:v2` still emits raw `actToken` on token verification failures. This Flutter repository cannot directly patch that binary image. Until the image/source path is remediated, release gates should run `scripts/ops/secret_log_scan.py` and treat new raw secret findings as release-blocking.

## Rollback Notes

- coturn rollback: restore backed-up `docker-compose.yaml`, `turnserver.conf.tpl`, and `rendered/turnserver.conf`, then run `docker compose --env-file .env up -d --no-deps coturn`.
- script rollback: restore backed-up `smoke_test.py`, `perf_probe.py`, and tests from the backup directory.
```

- [ ] **Step 3: Commit Task 7**

```powershell
git -C C:\Users\COLORFUL\.config\superpowers\worktrees\WuKong\p0-im-stop-bleed add docs/production/2026-05-02-p0-stop-bleed-verification.md

git -C C:\Users\COLORFUL\.config\superpowers\worktrees\WuKong\p0-im-stop-bleed commit `
  -m "docs: record p0 stop bleed verification"
```

Expected: commit succeeds.

---

### Task 8: Final verification and integration readiness

**Files:**
- Verify all files changed in `C:\Users\COLORFUL\.config\superpowers\worktrees\WuKong\p0-im-stop-bleed`.

- [ ] **Step 1: Run focused Flutter verification**

```powershell
flutter test C:\Users\COLORFUL\.config\superpowers\worktrees\WuKong\p0-im-stop-bleed\test\modules\video_call\call_runtime_recovery_test.dart
```

Expected: PASS.

- [ ] **Step 2: Run script verification**

```powershell
python C:\Users\COLORFUL\.config\superpowers\worktrees\WuKong\p0-im-stop-bleed\scripts\ops\tests\test_secret_log_scan.py
bash -n C:\Users\COLORFUL\.config\superpowers\worktrees\WuKong\p0-im-stop-bleed\scripts\ops\remote_redeploy.sh
bash -n C:\Users\COLORFUL\.config\superpowers\worktrees\WuKong\p0-im-stop-bleed\scripts\ops\coturn_tls_probe.sh
powershell -NoProfile -ExecutionPolicy Bypass -Command "Invoke-Pester -Script C:\Users\COLORFUL\.config\superpowers\worktrees\WuKong\p0-im-stop-bleed\scripts\ops\tests\remote_redeploy_release_gate.Tests.ps1"
```

Expected: all PASS or no-output syntax success.

- [ ] **Step 3: Run analyzer on touched Dart file**

```powershell
flutter analyze C:\Users\COLORFUL\.config\superpowers\worktrees\WuKong\p0-im-stop-bleed\lib\modules\video_call\call_coordinator.dart
```

Expected: PASS or only clearly pre-existing analyzer issues unrelated to `call_coordinator.dart`.

- [ ] **Step 4: Inspect git status and log**

```powershell
git -C C:\Users\COLORFUL\.config\superpowers\worktrees\WuKong\p0-im-stop-bleed status --short
git -C C:\Users\COLORFUL\.config\superpowers\worktrees\WuKong\p0-im-stop-bleed log --oneline -5
```

Expected: no uncommitted local work; recent commits correspond to Tasks 1, 2, 3, 4, and 7.

- [ ] **Step 5: Prepare merge or PR handoff**

Do not merge into `C:\Users\COLORFUL\Desktop\WuKong` until the user chooses an integration path, because the main workspace has unrelated staged changes. Report the worktree path and commit list.

---

## Self-Review

- Spec coverage:
  - HTTPS release validation: Tasks 2 and 5.
  - Secret-log detection/redaction: Tasks 3 and 7.
  - coturn TLS/DTLS and unsupported config warning: Tasks 4 and 6.
  - Pending-call fallback degradation-only behavior: Task 1.
  - Backup, verification, and rollback documentation: Tasks 6 and 7.

- Placeholder scan:
  - No unresolved placeholder markers or vague edge-case steps are present.
  - Each code-changing task includes concrete code or exact commands.

- Type consistency:
  - Dart tests use existing `PendingCallRecoveryLoop`, `CallStore`, `CallStateMachine`, `CallRoom`, `CallType`, and `CallLifecycleStatus` names.
  - Python helpers `explain_http_base_url` and `validate_base_url` are defined identically in `smoke_test.py` and `perf_probe.py`.
  - The local scanner exports `scan_text`, which the unittest imports directly.

## Execution Handoff

Plan complete and saved to `C:\Users\COLORFUL\Desktop\WuKong\docs\superpowers\plans\2026-05-02-p0-im-stop-bleed.md`.

**Two execution options:**

**1. Subagent-Driven (recommended)** - I dispatch a fresh subagent per task, review between tasks, fast iteration

**2. Inline Execution** - Execute tasks in this session using executing-plans, batch execution with checkpoints

**Which approach?**

# DingTalk Windows Host PoC

Standalone Windows-native PoC for hosting DingTalk desktop, probing structured UI sources, and exposing loopback diagnostics.

## Lifecycle Verification

Run from repository root:

```powershell
tools\dingtalk_windows_host\Verify-HostLifecycle.ps1 -DotnetPath "$env:TEMP\codex-dotnet-8\dotnet.exe"
```

To verify launcher readiness without setting a global environment variable:

```powershell
tools\dingtalk_windows_host\Verify-HostLifecycle.ps1 `
  -DotnetPath "$env:TEMP\codex-dotnet-8\dotnet.exe" `
  -DingTalkLauncherPath "E:\Apply\DingDing\DingtalkLauncher.exe"
```

To explicitly invoke the launcher during lifecycle verification, add `-LaunchDingTalk`:

```powershell
tools\dingtalk_windows_host\Verify-HostLifecycle.ps1 `
  -DotnetPath "$env:TEMP\codex-dotnet-8\dotnet.exe" `
  -DingTalkLauncherPath "E:\Apply\DingDing\DingtalkLauncher.exe" `
  -LaunchDingTalk
```

To explicitly ask the host to restore/foreground the best DingTalk window candidate, add `-RestoreDingTalkWindow`:

```powershell
tools\dingtalk_windows_host\Verify-HostLifecycle.ps1 `
  -DotnetPath "$env:TEMP\codex-dotnet-8\dotnet.exe" `
  -DingTalkLauncherPath "E:\Apply\DingDing\DingtalkLauncher.exe" `
  -LaunchDingTalk `
  -RestoreDingTalkWindow
```

To enable explicit DingTalk launch from the WPF button or `/control/launch-dingtalk`, set:

```powershell
$env:DINGTALK_HOST_LAUNCHER = "E:\Apply\DingDing\DingtalkLauncher.exe"
```

The host does not auto-restart DingTalk. Launch is only triggered by the operator button or explicit loopback API call.

For a low-latency DevTools/DOM experiment, optionally set a local remote-debugging port before explicitly launching DingTalk:

```powershell
$env:DINGTALK_HOST_REMOTE_DEBUGGING_PORT = "9222"
```

This is disabled by default. The host still only probes `/json/version` and verifies loopback ownership; it does not fetch page targets, cookies, storage, or DOM content in the current PoC.

When validating whether DingTalk honors Chromium DevTools flags, prefer launching the real executable instead of the outer launcher:

```powershell
tools\dingtalk_windows_host\Verify-HostLifecycle.ps1 `
  -DotnetPath "$env:TEMP\codex-dotnet-8\dotnet.exe" `
  -DingTalkLauncherPath "E:\Apply\DingDing\main\current\DingTalk.exe" `
  -RemoteDebuggingPort 9222 `
  -LaunchDingTalk
```

The current tested DingTalk build propagates `--remote-debugging-port=9222` into DingTalk process metadata, but `127.0.0.1:9222` does not listen. The structured-source probe reports any DingTalk-owned loopback listeners it checked with `/json/version`; those listeners are not treated as DevTools unless the version endpoint succeeds and ownership is DingTalk.

For a lower-risk UIA experiment before enabling OCR, explicitly restart DingTalk with Chromium renderer accessibility:

```powershell
tools\dingtalk_windows_host\Verify-HostLifecycle.ps1 `
  -DotnetPath "$env:TEMP\codex-dotnet-8\dotnet.exe" `
  -DingTalkLauncherPath "E:\Apply\DingDing\DingtalkLauncher.exe" `
  -EnableRendererAccessibility `
  -RestartDingTalk `
  -RestoreDingTalkWindow
```

This adds `--force-renderer-accessibility` only when explicitly requested. Verify `/diagnostics/uia-message-surface` exposes actual message text before relying on UIA forwarding.

Check launcher readiness without launching DingTalk:

```powershell
Invoke-RestMethod -Uri "http://127.0.0.1:17651/diagnostics/launcher" -Headers @{ "X-DingTalk-Host-Token" = "local-dev-token" }
```

Check local structured-source candidates without reading message content:

```powershell
Invoke-RestMethod -Uri "http://127.0.0.1:17651/diagnostics/local-structured-sources?limit=30" -Headers @{ "X-DingTalk-Host-Token" = "local-dev-token" }
```

Check local structured-source schema/key metadata without reading message values:

```powershell
Invoke-RestMethod -Uri "http://127.0.0.1:17651/diagnostics/local-structured-source-inspection?limit=12&itemLimit=20" -Headers @{ "X-DingTalk-Host-Token" = "local-dev-token" }
```

Check local structured-source content shape without returning message values:

```powershell
Invoke-RestMethod -Uri "http://127.0.0.1:17651/diagnostics/local-structured-content-shape?limit=12&itemLimit=20&sampleLimit=5" -Headers @{ "X-DingTalk-Host-Token" = "local-dev-token" }
```

The script:
- builds the WPF host app
- starts the host process
- calls `/control/start`
- checks `/status`, `/diagnostics/launcher`, `/diagnostics/structured-sources`, `/diagnostics/devtools-targets`, `/diagnostics/local-structured-sources`, `/diagnostics/local-structured-source-inspection`, `/diagnostics/local-structured-content-shape`, `/diagnostics/window-state`, `/diagnostics/conversations`, and `/conversation-triggers/recent`
- includes the first 20 `/diagnostics/uia-snapshot` rows so operators can see whether the hosted HWND exposes a useful UIA tree
- calls `/control/stop`
- verifies `runtime/window-attachment.json` is cleared after stop

Expected successful output is JSON. `journalExistsAfterStop` must be `false`.

`conversationCount` and `triggerSnapshotCount` may be `0` on current DingTalk builds because the chat/conversation UIA tree is not always exposed after native window hosting. That is a runtime limitation, not a lifecycle failure.

`windowHealth` is the primary attachment diagnostic. `Ready` means a visible candidate is available, `HiddenWorkspaceOnly` means DingTalk only exposed the hidden Qt workspace fallback, and `BlockedByDialog` means an update/restart/login dialog should be closed before capture.

`windowCandidateDecisions` explains why the first candidates were accepted or rejected, using stable reasons such as `ToolWindow`, `TooSmall`, `Hidden`, `Disabled`, and `UnsupportedClass`. Use this before changing window locator rules.

`windowRejectionReasonCounts` summarizes all candidates, not just the first few shown in `windowCandidateDecisions`.

`structuredSourceSignals` shows the low-latency source status. On the current tested DingTalk build, UIA and embedded Chromium windows are visible; explicit remote debugging launch metadata can be detected, but the requested DevTools port is not listening, so DevTools/DOM remains unproven. OCR remains disabled by default.

`localStructuredSourceCandidates` is a metadata-only reconnaissance path for the current recommended direction: UIA remains the low-latency trigger, while local structured DingTalk cache/log files are inspected only by path, size, timestamp, and coarse type. The host does not read message content, SQLite rows, LevelDB values, log lines, cookies, or credentials from this endpoint.

`localStructuredSourceInspections` performs schema/key-only inspection on candidates. SQLite inspection reads table and column names only; JSON inspection reads object property names only; LevelDB inspection reads file groups only. It skips log and media content because those can contain message payloads.

`localStructuredContentShapes` is the next gated diagnostic for low-latency local parsing. For standard SQLite files it may sample candidate columns, but the response only includes table names, field roles, counts, min/max lengths, and SHA256 hashes of sampled values. It does not return message text, sender names, conversation names, row values, cookies, or credentials. For LevelDB it returns keyword counts only, not key/value payloads. `NotReadable` on a `.db` file usually means the file is encrypted, compressed, or otherwise not a standard SQLite database.

To enable the local OCR fallback with Tesseract, configure an offline command. Example:

```powershell
tools\dingtalk_windows_host\Verify-HostLifecycle.ps1 `
  -DotnetPath "$env:TEMP\codex-dotnet-8\dotnet.exe" `
  -DingTalkLauncherPath "E:\Apply\DingDing\DingtalkLauncher.exe" `
  -OcrCommand "C:\Program Files\Tesseract-OCR\tesseract.exe" `
  -OcrArguments "{image} stdout -l chi_sim+eng --psm 6" `
  -OcrEnvironment "TESSDATA_PREFIX=C:\Users\COLORFUL\Desktop\WuKong\tools\dingtalk_windows_host\runtime\tessdata"
```

OCR is still a fallback. The host first tries UIA/structured paths, then cropped chat-area OCR, and `/events/forwardable-recent` continues to exclude screenshot visual-change diagnostics.

## Boundaries

- Do not enable OCR by default.
- Do not expose DingTalk cookies, credentials, local database row values, local cache values, or log lines. Metadata-only file discovery and value-hash-only content shape probing are allowed for diagnostics.
- Do not integrate this host into the WuKong IM runtime until the loopback contract is stable.

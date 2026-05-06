# Feishu Web Group Forwarding MVP Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the first real forwarding loop: a paired Windows Agent opens Feishu Web in an isolated Chromium profile, observes new messages from one configured Feishu group, reports them to the cloud, and the cloud forwards text/link messages to one WuKong IM group.

**Architecture:** Extend the current Monitor control plane instead of adding a parallel system. The Flutter Feishu monitor center triggers local Agent CLI actions; the Dart Agent controls Chromium through a dedicated `chromium-profile` under the Agent store; the cloud Monitor API stores routes, browser status, observed messages, events, and performs final dedupe plus WuKong IM group delivery through the existing server `SendMessage` path.

**Tech Stack:** Flutter/Dart, standalone Dart CLI, Chromium automation through Dart `puppeteer`, `crypto`, `dart:io`, Dio, `flutter_test`, Dart `test`, Go backend module in TangSengDaoDaoServer, MySQL migration SQL, Docker Compose production deployment, TDD, token-redacted logs.

---

## Scope

This plan implements the MVP from:

`C:\Users\COLORFUL\Desktop\WuKong\.worktrees\feishu-agent-pairing-heartbeat-design\docs\superpowers\specs\2026-05-07-feishu-web-group-forwarding-mvp-design.md`

In scope:

- Agent-local Chromium persistent profile under `%APPDATA%\InfoEquity\FeishuMonitorAgent\chromium-profile`.
- CLI commands: `browser-login`, `browser-status`, `clear-browser-profile`, `listen --once`.
- Agent API calls: pull assigned routes, report browser status, report observed messages.
- Local dedupe cache for observed messages.
- Conservative Feishu Web adapter for visible text/link/image-placeholder messages.
- Flutter page controls for opening login, checking status, clearing login state, and testing one listen run.
- Mock server support for the new endpoints.
- Production Go backend patch for route storage, browser status, observed messages, dedupe, event logs, stats, and text forwarding to WuKong IM groups.

Out of scope:

- Full file, voice, video, and image binary forwarding.
- Multiple Feishu accounts or multiple concurrent Chromium instances.
- Strict incognito mode.
- Reading the user's default Chrome or Edge profile.
- Bypassing Feishu verification, CAPTCHA, or risk controls.

## File structure

### Flutter/Dart repository

- Modify: `tools/feishu_monitor_agent/pubspec.yaml`
  - Add `puppeteer`, `crypto`, and `path`.
- Modify: `tools/feishu_monitor_agent/lib/src/agent_models.dart`
  - Add browser status, route, observed-message, and API response models.
- Modify: `tools/feishu_monitor_agent/lib/src/agent_api.dart`
  - Add `fetchAssignedRoutes`, `reportBrowserStatus`, and `reportObservedMessage`.
- Modify: `tools/feishu_monitor_agent/lib/src/heartbeat_runner.dart`
  - Add Agent API interface methods used by the new runners.
- Modify: `tools/feishu_monitor_agent/lib/src/agent_cli.dart`
  - Add new commands and dependency injection points.
- Create: `tools/feishu_monitor_agent/lib/src/browser_profile.dart`
  - Profile/runtime path calculation and safe profile deletion.
- Create: `tools/feishu_monitor_agent/lib/src/browser_controller.dart`
  - Chromium launch/status abstraction using Dart `puppeteer`.
- Create: `tools/feishu_monitor_agent/lib/src/feishu_web_adapter.dart`
  - Feishu Web status detection, group navigation, and visible message extraction helpers.
- Create: `tools/feishu_monitor_agent/lib/src/message_dedupe_store.dart`
  - Local recent-message hash persistence.
- Create: `tools/feishu_monitor_agent/lib/src/listen_runner.dart`
  - Pull routes, observe messages, dedupe locally, report to cloud.
- Modify: `tools/monitor_mock_server/lib/src/mock_monitor_server.dart`
  - Add routes, browser status, observed messages, dedupe, and forwarding-event simulation.
- Modify: `lib/modules/monitor/monitor_models.dart`
  - Add `MonitorBrowserStatus`.
- Modify: `lib/service/api/monitor_api.dart`
  - Add `fetchBrowserStatus`.
- Modify: `lib/modules/monitor/monitor_repository.dart`
  - Load browser status with the Feishu snapshot.
- Modify: `lib/modules/monitor/monitor_local_agent_binder.dart`
  - Add local Agent action methods for browser login/status/clear/listen.
- Modify: `lib/modules/monitor/feishu_monitor_center_page.dart`
  - Add browser status card and buttons.

### Production Go backend

- Create local patch snapshot:
  - `docs/production/monitor-cloud-backend-patch-20260507/modules_monitor/sql/monitor-20260507-01.sql`
- Modify local patch snapshot:
  - `docs/production/monitor-cloud-backend-patch-20260507/modules_monitor/model.go`
  - `docs/production/monitor-cloud-backend-patch-20260507/modules_monitor/db.go`
  - `docs/production/monitor-cloud-backend-patch-20260507/modules_monitor/api.go`
  - `docs/production/monitor-cloud-backend-patch-20260507/modules_monitor/api_test.go`
- Apply equivalent files to remote:
  - `/opt/wukongim-prod/src/modules/monitor/`

---

## Task 1: Add Agent model contracts

**Files:**
- Modify: `tools/feishu_monitor_agent/lib/src/agent_models.dart`
- Test: `tools/feishu_monitor_agent/test/agent_models_test.dart`

- [ ] **Step 1: Write failing model tests**

Append tests to `tools/feishu_monitor_agent/test/agent_models_test.dart` for:

```dart
test('AgentMonitorRoute parses cloud route payload', () {
  final route = AgentMonitorRoute.fromJson(const <String, dynamic>{
    'route_id': 'route_1',
    'platform': 'feishu',
    'connector_type': 'feishu_web_group',
    'route_type': 'feishu_web_group_to_wukong_im_group',
    'source': <String, dynamic>{'chat_name': '飞书新闻群'},
    'destination': <String, dynamic>{
      'type': 'wukong_im_group',
      'group_no': 'group_1',
      'group_name': '悟空 IM 新闻群',
    },
    'message_policy': <String, dynamic>{
      'include_text': true,
      'include_links': true,
      'include_images': false,
      'include_files': false,
    },
  });

  expect(route.routeId, 'route_1');
  expect(route.sourceChatName, '飞书新闻群');
  expect(route.destinationGroupNo, 'group_1');
  expect(route.includeText, isTrue);
  expect(route.includeImages, isFalse);
});

test('BrowserStatusReportRequest serializes without secrets', () {
  const request = BrowserStatusReportRequest(
    agentId: 'agent_1',
    platform: 'feishu',
    browser: 'chromium',
    profileMode: 'isolated_persistent',
    loginStatus: BrowserLoginStatus.loggedIn,
    observedAt: '2026-05-07T10:00:00Z',
    errorMessage: '',
  );

  expect(request.toJson(), containsPair('login_status', 'logged_in'));
  expect(request.toString(), isNot(contains('secret-token')));
});

test('ObservedMessageRequest builds stable JSON payload', () {
  const request = ObservedMessageRequest(
    agentId: 'agent_1',
    routeId: 'route_1',
    sourcePlatform: 'feishu',
    sourceChatName: '飞书新闻群',
    sourceMessageId: 'hash_1',
    messageType: 'text',
    content: '新闻正文',
    sourceCreatedAt: '2026-05-07T10:00:00Z',
    observedAt: '2026-05-07T10:00:05Z',
  );

  expect(request.toJson(), containsPair('source_message_id', 'hash_1'));
  expect(request.toJson(), containsPair('content', '新闻正文'));
});
```

- [ ] **Step 2: Run the focused test and confirm red**

Run:

```powershell
cd tools/feishu_monitor_agent
dart test test/agent_models_test.dart
cd ..\..
```

Expected: FAIL because model classes do not exist yet.

- [ ] **Step 3: Implement models**

In `tools/feishu_monitor_agent/lib/src/agent_models.dart`, add:

```dart
enum BrowserLoginStatus {
  loggedIn('logged_in'),
  loginRequired('login_required'),
  browserError('browser_error'),
  unknown('unknown');

  const BrowserLoginStatus(this.apiValue);
  final String apiValue;

  static BrowserLoginStatus parse(dynamic value) {
    switch (_string(value).trim()) {
      case 'logged_in':
        return BrowserLoginStatus.loggedIn;
      case 'login_required':
        return BrowserLoginStatus.loginRequired;
      case 'browser_error':
        return BrowserLoginStatus.browserError;
      default:
        return BrowserLoginStatus.unknown;
    }
  }
}

class BrowserStatusReportRequest {
  const BrowserStatusReportRequest({
    required this.agentId,
    required this.platform,
    required this.browser,
    required this.profileMode,
    required this.loginStatus,
    required this.observedAt,
    required this.errorMessage,
  });

  final String agentId;
  final String platform;
  final String browser;
  final String profileMode;
  final BrowserLoginStatus loginStatus;
  final String observedAt;
  final String errorMessage;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'agent_id': agentId.trim(),
        'platform': platform.trim(),
        'browser': browser.trim(),
        'profile_mode': profileMode.trim(),
        'login_status': loginStatus.apiValue,
        'observed_at': observedAt.trim(),
        'error_message': errorMessage.trim(),
      };
}

class AgentMonitorRoute {
  const AgentMonitorRoute({
    required this.routeId,
    required this.platform,
    required this.connectorType,
    required this.routeType,
    required this.sourceChatName,
    required this.destinationType,
    required this.destinationGroupNo,
    required this.destinationGroupName,
    required this.includeText,
    required this.includeLinks,
    required this.includeImages,
    required this.includeFiles,
  });

  final String routeId;
  final String platform;
  final String connectorType;
  final String routeType;
  final String sourceChatName;
  final String destinationType;
  final String destinationGroupNo;
  final String destinationGroupName;
  final bool includeText;
  final bool includeLinks;
  final bool includeImages;
  final bool includeFiles;

  factory AgentMonitorRoute.fromJson(Map<String, dynamic> json) {
    final source = _map(json['source']);
    final destination = _map(json['destination']);
    final policy = _map(json['message_policy']);
    return AgentMonitorRoute(
      routeId: _string(json['route_id'] ?? json['id']),
      platform: _string(json['platform'], fallback: 'feishu'),
      connectorType: _string(json['connector_type']),
      routeType: _string(json['route_type']),
      sourceChatName: _string(source['chat_name'] ?? json['source_name']),
      destinationType: _string(destination['type'], fallback: 'wukong_im_group'),
      destinationGroupNo: _string(destination['group_no']),
      destinationGroupName: _string(destination['group_name']),
      includeText: _bool(policy['include_text'], fallback: true),
      includeLinks: _bool(policy['include_links'], fallback: true),
      includeImages: _bool(policy['include_images']),
      includeFiles: _bool(policy['include_files']),
    );
  }
}

class ObservedMessageRequest {
  const ObservedMessageRequest({
    required this.agentId,
    required this.routeId,
    required this.sourcePlatform,
    required this.sourceChatName,
    required this.sourceMessageId,
    required this.messageType,
    required this.content,
    required this.sourceCreatedAt,
    required this.observedAt,
  });

  final String agentId;
  final String routeId;
  final String sourcePlatform;
  final String sourceChatName;
  final String sourceMessageId;
  final String messageType;
  final String content;
  final String sourceCreatedAt;
  final String observedAt;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'agent_id': agentId.trim(),
        'route_id': routeId.trim(),
        'source_platform': sourcePlatform.trim(),
        'source_chat_name': sourceChatName.trim(),
        'source_message_id': sourceMessageId.trim(),
        'message_type': messageType.trim(),
        'content': content.trim(),
        'source_created_at': sourceCreatedAt.trim(),
        'observed_at': observedAt.trim(),
      };
}

class ObservedMessageResponse {
  const ObservedMessageResponse({
    required this.accepted,
    required this.duplicate,
    required this.forwardStatus,
    required this.messageId,
  });

  final bool accepted;
  final bool duplicate;
  final String forwardStatus;
  final String messageId;

  factory ObservedMessageResponse.fromJson(Map<String, dynamic> json) {
    return ObservedMessageResponse(
      accepted: _bool(json['accepted']),
      duplicate: _bool(json['duplicate']),
      forwardStatus: _string(json['forward_status']),
      messageId: _string(json['message_id']),
    );
  }
}
```

Add helper functions if absent:

```dart
Map<String, dynamic> _map(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return <String, dynamic>{};
}

bool _bool(dynamic value, {bool fallback = false}) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  final text = value?.toString().trim().toLowerCase() ?? '';
  if (text == 'true' || text == '1') return true;
  if (text == 'false' || text == '0') return false;
  return fallback;
}
```

- [ ] **Step 4: Run focused test and confirm green**

Run:

```powershell
cd tools/feishu_monitor_agent
dart test test/agent_models_test.dart
cd ..\..
```

Expected: PASS.

- [ ] **Step 5: Commit**

```powershell
git add tools/feishu_monitor_agent/lib/src/agent_models.dart tools/feishu_monitor_agent/test/agent_models_test.dart
git commit -m "feat: add feishu agent monitoring contracts"
```

---

## Task 2: Add Agent API methods

**Files:**
- Modify: `tools/feishu_monitor_agent/lib/src/agent_api.dart`
- Modify: `tools/feishu_monitor_agent/lib/src/heartbeat_runner.dart`
- Test: `tools/feishu_monitor_agent/test/agent_api_test.dart`

- [ ] **Step 1: Write failing API tests**

Add tests to `tools/feishu_monitor_agent/test/agent_api_test.dart` covering:

```dart
final routes = await api.fetchAssignedRoutes(agentToken: 'secret-token');
expect(routes.single.routeId, 'route_1');

await api.reportBrowserStatus(
  agentToken: 'secret-token',
  request: const BrowserStatusReportRequest(
    agentId: 'agent_1',
    platform: 'feishu',
    browser: 'chromium',
    profileMode: 'isolated_persistent',
    loginStatus: BrowserLoginStatus.loggedIn,
    observedAt: '2026-05-07T10:00:00Z',
    errorMessage: '',
  ),
);

final response = await api.reportObservedMessage(
  agentToken: 'secret-token',
  request: const ObservedMessageRequest(
    agentId: 'agent_1',
    routeId: 'route_1',
    sourcePlatform: 'feishu',
    sourceChatName: '飞书新闻群',
    sourceMessageId: 'hash_1',
    messageType: 'text',
    content: '新闻正文',
    sourceCreatedAt: '2026-05-07T10:00:00Z',
    observedAt: '2026-05-07T10:00:05Z',
  ),
);
expect(response.forwardStatus, 'forwarded');
```

Update the test HTTP server to respond to:

- `GET /v1/monitor/agents/me/routes`
- `POST /v1/monitor/agents/browser-status`
- `POST /v1/monitor/messages/observed`

- [ ] **Step 2: Run focused test and confirm red**

```powershell
cd tools/feishu_monitor_agent
dart test test/agent_api_test.dart
cd ..\..
```

Expected: FAIL because API methods are missing.

- [ ] **Step 3: Extend `AgentApiLike`**

In `tools/feishu_monitor_agent/lib/src/heartbeat_runner.dart`, add:

```dart
Future<List<AgentMonitorRoute>> fetchAssignedRoutes({
  required String agentToken,
});

Future<void> reportBrowserStatus({
  required String agentToken,
  required BrowserStatusReportRequest request,
});

Future<ObservedMessageResponse> reportObservedMessage({
  required String agentToken,
  required ObservedMessageRequest request,
});
```

- [ ] **Step 4: Implement API methods**

In `tools/feishu_monitor_agent/lib/src/agent_api.dart`, add:

```dart
Future<List<AgentMonitorRoute>> fetchAssignedRoutes({
  required String agentToken,
}) async {
  final json = await _getJson(
    '/v1/monitor/agents/me/routes',
    bearerToken: agentToken,
  );
  final data = json['data'];
  if (data is List) {
    return data
        .whereType<Map>()
        .map((item) => AgentMonitorRoute.fromJson(Map<String, dynamic>.from(item)))
        .toList(growable: false);
  }
  return const <AgentMonitorRoute>[];
}

Future<void> reportBrowserStatus({
  required String agentToken,
  required BrowserStatusReportRequest request,
}) async {
  await _postJson(
    '/v1/monitor/agents/browser-status',
    body: request.toJson(),
    bearerToken: agentToken,
  );
}

Future<ObservedMessageResponse> reportObservedMessage({
  required String agentToken,
  required ObservedMessageRequest request,
}) async {
  final json = await _postJson(
    '/v1/monitor/messages/observed',
    body: request.toJson(),
    bearerToken: agentToken,
  );
  return ObservedMessageResponse.fromJson(_dataObject(json));
}
```

Add `_getJson` mirroring `_postJson`, but using `_client.getUrl(uri)`.

- [ ] **Step 5: Run focused test and confirm green**

```powershell
cd tools/feishu_monitor_agent
dart test test/agent_api_test.dart
cd ..\..
```

Expected: PASS.

- [ ] **Step 6: Commit**

```powershell
git add tools/feishu_monitor_agent/lib/src/agent_api.dart tools/feishu_monitor_agent/lib/src/heartbeat_runner.dart tools/feishu_monitor_agent/test/agent_api_test.dart
git commit -m "feat: add feishu agent monitor api calls"
```

---

## Task 3: Add Agent browser profile store

**Files:**
- Create: `tools/feishu_monitor_agent/lib/src/browser_profile.dart`
- Test: `tools/feishu_monitor_agent/test/browser_profile_test.dart`

- [ ] **Step 1: Write failing profile tests**

Create `tools/feishu_monitor_agent/test/browser_profile_test.dart` with tests verifying:

- `profileDir` ends with `chromium-profile`.
- `runtimeDir` ends with `runtime`.
- `clearProfile()` deletes only `chromium-profile`.
- `agent_config.json` remains after clear.

- [ ] **Step 2: Run and confirm red**

```powershell
cd tools/feishu_monitor_agent
dart test test/browser_profile_test.dart
cd ..\..
```

Expected: FAIL.

- [ ] **Step 3: Implement profile paths**

Create `tools/feishu_monitor_agent/lib/src/browser_profile.dart`:

```dart
import 'dart:io';

class BrowserProfilePaths {
  BrowserProfilePaths(this.storeDir);

  final String storeDir;

  Directory get profileDir =>
      Directory('$storeDir${Platform.pathSeparator}chromium-profile');

  Directory get runtimeDir =>
      Directory('$storeDir${Platform.pathSeparator}runtime');

  File get lastBrowserStatusFile => File(
        '${runtimeDir.path}${Platform.pathSeparator}last-browser-status.json',
      );

  File get dedupeCacheFile => File(
        '${runtimeDir.path}${Platform.pathSeparator}dedupe-cache.json',
      );
}

class BrowserProfileCleaner {
  const BrowserProfileCleaner(this.paths);

  final BrowserProfilePaths paths;

  Future<void> clearProfile() async {
    final profile = paths.profileDir;
    if (await profile.exists()) {
      await profile.delete(recursive: true);
    }
  }
}
```

- [ ] **Step 4: Run and confirm green**

```powershell
cd tools/feishu_monitor_agent
dart test test/browser_profile_test.dart
cd ..\..
```

Expected: PASS.

- [ ] **Step 5: Commit**

```powershell
git add tools/feishu_monitor_agent/lib/src/browser_profile.dart tools/feishu_monitor_agent/test/browser_profile_test.dart
git commit -m "feat: add feishu chromium profile store"
```

---

## Task 4: Add Chromium controller and Feishu Web adapter

**Files:**
- Modify: `tools/feishu_monitor_agent/pubspec.yaml`
- Create: `tools/feishu_monitor_agent/lib/src/browser_controller.dart`
- Create: `tools/feishu_monitor_agent/lib/src/feishu_web_adapter.dart`
- Test: `tools/feishu_monitor_agent/test/feishu_web_adapter_test.dart`

- [ ] **Step 1: Add dependencies**

Modify `tools/feishu_monitor_agent/pubspec.yaml`:

```yaml
dependencies:
  crypto: ^3.0.6
  path: ^1.9.1
  puppeteer: ^3.22.0
```

Run:

```powershell
cd tools/feishu_monitor_agent
dart pub get
cd ..\..
```

Expected: lockfile updates. If `puppeteer` resolves to a different compatible version, keep the lockfile result.

- [ ] **Step 2: Write adapter tests**

Create `tools/feishu_monitor_agent/test/feishu_web_adapter_test.dart`:

```dart
import 'package:feishu_monitor_agent/src/agent_models.dart';
import 'package:feishu_monitor_agent/src/feishu_web_adapter.dart';
import 'package:test/test.dart';

void main() {
  group('FeishuWebAdapter helpers', () {
    test('classifies logged in text', () {
      expect(
        FeishuWebDomClassifier.classifyText('消息 工作台 云文档 飞书'),
        BrowserLoginStatus.loggedIn,
      );
    });

    test('classifies login required text', () {
      expect(
        FeishuWebDomClassifier.classifyText('扫码登录 请使用飞书扫码'),
        BrowserLoginStatus.loginRequired,
      );
    });

    test('normalizes observed message text and hash', () {
      final message = FeishuObservedMessage.fromRaw(
        routeId: 'route_1',
        sourceChatName: '飞书新闻群',
        rawId: '',
        messageType: 'text',
        content: '  新闻正文\n\n新闻正文  ',
        observedAt: '2026-05-07T10:00:05Z',
        domOrder: 7,
      );

      expect(message.content, '新闻正文 新闻正文');
      expect(message.sourceMessageId, startsWith('feishu_web_'));
    });
  });
}
```

- [ ] **Step 3: Implement adapter helpers**

Create `tools/feishu_monitor_agent/lib/src/feishu_web_adapter.dart` with:

- `FeishuWebDomClassifier.classifyText(String text)`
- `FeishuObservedMessage.fromRaw(...)`
- SHA-256 hash source id fallback using `routeId`, `sourceChatName`, normalized content, timestamp, and DOM order.

- [ ] **Step 4: Implement browser controller**

Create `tools/feishu_monitor_agent/lib/src/browser_controller.dart`:

```dart
abstract class BrowserControllerLike {
  Future<BrowserLoginStatus> openLogin({required bool keepOpen});
  Future<BrowserLoginStatus> checkStatus();
  Future<List<FeishuObservedMessage>> observeRoute({
    required AgentMonitorRoute route,
    required String observedAt,
  });
  Future<void> close();
}
```

Implement `PuppeteerBrowserController` with these rules:

- Launch Chromium with `headless: false` for `openLogin`.
- Launch Chromium with `headless: true` for `browser-status` and `listen --once`.
- Always pass `userDataDir: paths.profileDir.path`.
- Never read default Chrome/Edge profile.
- Navigate to `https://www.feishu.cn/messenger/`.
- Classify login status from `document.body.innerText`.
- For route observation, use conservative selectors:
  - `[data-message-id]`
  - `[data-testid*="message"]`
  - `.message`
  - `[class*="message"]`
- Return the last 20 visible non-empty text rows.

If the installed Dart `puppeteer` API names differ, adapt only `PuppeteerBrowserController`; keep `BrowserControllerLike` stable for tests.

- [ ] **Step 5: Run tests and analyzer**

```powershell
cd tools/feishu_monitor_agent
dart test test/feishu_web_adapter_test.dart
dart analyze lib/src/browser_controller.dart lib/src/feishu_web_adapter.dart
cd ..\..
```

Expected: PASS.

- [ ] **Step 6: Commit**

```powershell
git add tools/feishu_monitor_agent/pubspec.yaml tools/feishu_monitor_agent/pubspec.lock tools/feishu_monitor_agent/lib/src/browser_controller.dart tools/feishu_monitor_agent/lib/src/feishu_web_adapter.dart tools/feishu_monitor_agent/test/feishu_web_adapter_test.dart
git commit -m "feat: add feishu chromium browser controller"
```

---

## Task 5: Add local dedupe store and listen runner

**Files:**
- Create: `tools/feishu_monitor_agent/lib/src/message_dedupe_store.dart`
- Create: `tools/feishu_monitor_agent/lib/src/listen_runner.dart`
- Test: `tools/feishu_monitor_agent/test/message_dedupe_store_test.dart`
- Test: `tools/feishu_monitor_agent/test/listen_runner_test.dart`

- [ ] **Step 1: Write dedupe store test**

Create a test proving:

- First `markIfNew('a')` returns true.
- Second `markIfNew('a')` returns false.
- When `maxEntries` is 2 and ids `a,b,c` are added, reloaded store forgets `a` but remembers `b,c`.

- [ ] **Step 2: Implement dedupe store**

Create `MessageDedupeStore` with:

```dart
Future<bool> markIfNew(String id)
```

It stores a JSON array in `runtime/dedupe-cache.json`, trims to `maxEntries`, and returns false for empty ids.

- [ ] **Step 3: Write listen runner test with fakes**

Create a fake `AgentApiLike` returning one `AgentMonitorRoute`, a fake `BrowserControllerLike` returning one `FeishuObservedMessage`, and assert:

- First `runOnce(config)` reports one message.
- Second `runOnce(config)` reports zero messages.
- Reported content is `新闻正文`.

- [ ] **Step 4: Implement `ListenRunner`**

Create `tools/feishu_monitor_agent/lib/src/listen_runner.dart`:

```dart
class ListenRunResult {
  const ListenRunResult({
    required this.routeCount,
    required this.observedCount,
    required this.reportedCount,
  });

  final int routeCount;
  final int observedCount;
  final int reportedCount;
}
```

Implement `ListenRunner.runOnce(AgentConfig config)`:

1. Check browser status.
2. Report browser status to cloud.
3. If not logged in, return zero counts.
4. Fetch assigned routes.
5. Observe each route.
6. Locally dedupe with key `routeId:sourceMessageId`.
7. Report new messages.
8. Return counts.

- [ ] **Step 5: Run focused tests**

```powershell
cd tools/feishu_monitor_agent
dart test test/message_dedupe_store_test.dart test/listen_runner_test.dart
cd ..\..
```

Expected: PASS.

- [ ] **Step 6: Commit**

```powershell
git add tools/feishu_monitor_agent/lib/src/message_dedupe_store.dart tools/feishu_monitor_agent/lib/src/listen_runner.dart tools/feishu_monitor_agent/test/message_dedupe_store_test.dart tools/feishu_monitor_agent/test/listen_runner_test.dart
git commit -m "feat: add feishu listen runner dedupe"
```

---

## Task 6: Add Agent CLI commands

**Files:**
- Modify: `tools/feishu_monitor_agent/lib/src/agent_cli.dart`
- Modify: `tools/feishu_monitor_agent/test/agent_cli_test.dart`

- [ ] **Step 1: Add failing CLI tests**

Add tests for:

- `browser-status --store-dir <dir>` prints `飞书已登录` and does not print token.
- `clear-browser-profile --store-dir <dir>` deletes profile but keeps `agent_config.json`.
- `listen --once --store-dir <dir>` prints `监听完成`.

Use dependency injection:

```dart
browserFactory: (_) => _FakeBrowserController(BrowserLoginStatus.loggedIn)
```

- [ ] **Step 2: Extend CLI injection**

In `agent_cli.dart`, add:

```dart
typedef BrowserControllerFactory = BrowserControllerLike Function(
  BrowserProfilePaths paths,
);
```

Add `BrowserControllerFactory? browserFactory` to `runAgentCli`.

- [ ] **Step 3: Implement commands**

Add commands:

- `browser-login`
- `browser-status`
- `clear-browser-profile`
- `listen`

Behavior:

- Missing config returns exit code `66`.
- `browser-login` opens Chromium login and prints `已打开 Chromium 飞书登录窗口，请扫码登录。`
- `browser-status` reports status to cloud and prints one friendly Chinese line.
- `clear-browser-profile` clears only the Chromium profile and reports `login_required`.
- `listen --once` runs `ListenRunner` and prints `监听完成：规则 X 条，观察 Y 条，上报 Z 条。`

- [ ] **Step 4: Run CLI tests**

```powershell
cd tools/feishu_monitor_agent
dart test test/agent_cli_test.dart
cd ..\..
```

Expected: PASS.

- [ ] **Step 5: Commit**

```powershell
git add tools/feishu_monitor_agent/lib/src/agent_cli.dart tools/feishu_monitor_agent/test/agent_cli_test.dart
git commit -m "feat: add feishu agent browser cli commands"
```

---

## Task 7: Add Flutter local Agent action runner methods

**Files:**
- Modify: `lib/modules/monitor/monitor_local_agent_binder.dart`
- Modify: `test/modules/monitor/monitor_local_agent_binder_test.dart`

- [ ] **Step 1: Write failing tests**

Add tests proving these methods invoke the expected CLI commands:

- `openBrowserLogin()` -> `browser-login`
- `checkBrowserStatus()` -> `browser-status`
- `clearBrowserProfile()` -> `clear-browser-profile`
- `listenOnce()` -> `listen --once`

- [ ] **Step 2: Implement action methods**

In `MonitorLocalAgentBinder`, add:

```dart
typedef LocalAgentActionResult = LocalAgentBindResult;
```

Add phase enum values:

```dart
browserLogin, browserStatus, clearBrowserProfile, listen
```

Add methods:

```dart
Future<LocalAgentActionResult> openBrowserLogin({String? storeDir})
Future<LocalAgentActionResult> checkBrowserStatus({String? storeDir})
Future<LocalAgentActionResult> clearBrowserProfile({String? storeDir})
Future<LocalAgentActionResult> listenOnce({String? storeDir})
```

All methods should call one shared private `_runAgentAction(...)` that:

- Rejects non-Windows with a Chinese message.
- Runs `dart run bin/feishu_monitor_agent.dart <command> ... --store-dir <storeDir>`.
- Uses `_agentWorkingDirectory()`.
- Sanitizes stdout/stderr with existing `_sanitizeOutput`.

- [ ] **Step 3: Run tests**

```powershell
flutter test test/modules/monitor/monitor_local_agent_binder_test.dart
```

Expected: PASS.

- [ ] **Step 4: Commit**

```powershell
git add lib/modules/monitor/monitor_local_agent_binder.dart test/modules/monitor/monitor_local_agent_binder_test.dart
git commit -m "feat: add feishu local agent browser actions"
```

---

## Task 8: Add Flutter browser status contract

**Files:**
- Modify: `lib/modules/monitor/monitor_models.dart`
- Modify: `lib/service/api/monitor_api.dart`
- Modify: `lib/modules/monitor/monitor_repository.dart`
- Modify: `test/service/api/monitor_api_test.dart`

- [ ] **Step 1: Add failing API test**

Add test:

```dart
test('fetchBrowserStatus maps Feishu browser status', () async {
  adapter.payload = const <String, dynamic>{
    'code': 0,
    'data': <String, dynamic>{
      'browser': 'chromium',
      'profile_mode': 'isolated_persistent',
      'login_status': 'logged_in',
      'observed_at': '2026-05-07T10:00:00Z',
      'error_message': '',
    },
  };

  final status = await MonitorApi.instance.fetchBrowserStatus(
    platform: MonitorPlatform.feishu,
  );

  expect(adapter.lastPath, '/v1/monitor/platforms/feishu/browser-status');
  expect(status.loginStatus, MonitorBrowserLoginStatus.loggedIn);
});
```

- [ ] **Step 2: Implement `MonitorBrowserStatus`**

Add `MonitorBrowserLoginStatus` enum and `MonitorBrowserStatus` class with labels:

- `已登录`
- `需要登录`
- `浏览器异常`
- `未检测`

Add optional field to `FeishuMonitorSnapshot`:

```dart
this.browserStatus = MonitorBrowserStatus.empty,
```

- [ ] **Step 3: Add API and repository loading**

Add `MonitorApi.fetchBrowserStatus({required MonitorPlatform platform})`.

Update `MonitorRepository.loadFeishuSnapshot()` to fetch it together with stats, agents, routes, and logs.

- [ ] **Step 4: Run tests**

```powershell
flutter test test/service/api/monitor_api_test.dart test/modules/monitor/monitor_models_test.dart
```

Expected: PASS.

- [ ] **Step 5: Commit**

```powershell
git add lib/modules/monitor/monitor_models.dart lib/service/api/monitor_api.dart lib/modules/monitor/monitor_repository.dart test/service/api/monitor_api_test.dart
git commit -m "feat: add feishu browser status contract"
```

---

## Task 9: Add browser controls to Feishu monitor center

**Files:**
- Modify: `lib/modules/monitor/feishu_monitor_center_page.dart`
- Modify: `test/modules/monitor/feishu_monitor_center_page_test.dart`

- [ ] **Step 1: Add widget callbacks**

Add:

```dart
typedef LocalAgentAction = Future<LocalAgentActionResult> Function();
```

Constructor fields:

- `onOpenBrowserLogin`
- `onCheckBrowserStatus`
- `onClearBrowserProfile`
- `onListenOnce`

- [ ] **Step 2: Add action state and helpers**

Add `_isRunningBrowserAction`.

Add `_runBrowserAction(LocalAgentAction action)`:

1. Set busy.
2. Await action.
3. Show snackbar.
4. Refresh page.
5. Clear busy.

- [ ] **Step 3: Add `_BrowserStatusCard`**

Display:

- Browser: Chromium
- Environment: 专属隔离环境
- Login status
- Last observed time
- Last error

Buttons:

- `打开飞书登录`
- `检查登录状态`
- `测试监听一次`
- `清除飞书登录`

Use keys:

- `feishu-monitor-open-browser-login`
- `feishu-monitor-check-browser-status`
- `feishu-monitor-listen-once`
- `feishu-monitor-clear-browser-profile`

- [ ] **Step 4: Add widget tests**

Test that:

- Card appears when Agent exists.
- `登录状态：已登录` appears.
- Each button calls the matching callback once.
- Buttons use the existing aligned action button styles.

- [ ] **Step 5: Run widget tests**

```powershell
flutter test test/modules/monitor/feishu_monitor_center_page_test.dart
```

Expected: PASS.

- [ ] **Step 6: Commit**

```powershell
git add lib/modules/monitor/feishu_monitor_center_page.dart test/modules/monitor/feishu_monitor_center_page_test.dart
git commit -m "feat: add feishu browser controls"
```

---

## Task 10: Extend mock server

**Files:**
- Modify: `tools/monitor_mock_server/lib/src/mock_monitor_server.dart`
- Modify: `tools/monitor_mock_server/test/mock_monitor_server_test.dart`

- [ ] **Step 1: Add tests**

Add one full mock flow test:

1. Create pairing code.
2. Pair Agent.
3. Create route through `POST /v1/monitor/routes`.
4. Agent pulls `GET /v1/monitor/agents/me/routes`.
5. Agent posts browser status.
6. Agent posts observed message.
7. Same observed message returns duplicate.
8. Events include a forwarded event.

- [ ] **Step 2: Implement mock endpoints**

Add handlers:

- `POST /v1/monitor/routes`
- `GET /v1/monitor/agents/me/routes`
- `POST /v1/monitor/agents/browser-status`
- `GET /v1/monitor/platforms/feishu/browser-status`
- `POST /v1/monitor/messages/observed`

Use in-memory `_routes`, `_browserStatuses`, and `_observedKeys`.

- [ ] **Step 3: Run tests**

```powershell
cd tools/monitor_mock_server
dart test
cd ..\..
```

Expected: PASS.

- [ ] **Step 4: Commit**

```powershell
git add tools/monitor_mock_server/lib/src/mock_monitor_server.dart tools/monitor_mock_server/test/mock_monitor_server_test.dart
git commit -m "feat: extend monitor mock server for feishu messages"
```

---

## Task 11: Add production backend patch

**Files:**
- Create/modify: `docs/production/monitor-cloud-backend-patch-20260507/`
- Apply to remote: `/opt/wukongim-prod/src/modules/monitor/`

- [ ] **Step 1: Create local patch snapshot**

Run:

```powershell
Copy-Item -Path docs\production\monitor-cloud-backend-patch-20260506 -Destination docs\production\monitor-cloud-backend-patch-20260507 -Recurse -Force
```

- [ ] **Step 2: Add migration SQL**

Create:

`docs/production/monitor-cloud-backend-patch-20260507/modules_monitor/sql/monitor-20260507-01.sql`

Tables:

- `monitor_route`
- `monitor_agent_browser_status`
- `monitor_observed_message`

Required unique indexes:

- `monitor_route(route_id)`
- `monitor_agent_browser_status(agent_id, platform)`
- `monitor_observed_message(route_id, source_message_id)`

- [ ] **Step 3: Extend Go models and DB**

In patch snapshot `model.go`, add:

- `routeModel`
- `browserStatusModel`
- `observedMessageModel`
- `createRouteReq`
- `browserStatusReq`
- `observedMessageReq`

In patch snapshot `db.go`, add:

- `insertRoute`
- `queryRoutes`
- `queryRunningRoutesForAgent`
- `queryRouteByID`
- `updateRouteStatus`
- `upsertBrowserStatus`
- `queryLatestBrowserStatus`
- `insertObservedMessage`
- `queryObservedMessageByRouteSource`
- `markObservedMessageForwarded`
- `markObservedMessageForwardFailed`
- `updateRouteForwardSuccess`
- `updateRouteLastError`

Use `formatDBTime(now)` for timestamp writes.

- [ ] **Step 4: Extend Go API**

In patch snapshot `api.go`, add console routes:

```go
auth.POST("/routes", a.createRoute)
auth.PUT("/routes/:route_id/status", a.updateRouteStatus)
auth.GET("/platforms/feishu/browser-status", a.feishuBrowserStatus)
```

Add Agent bearer routes:

```go
agent.GET("/agents/me/routes", a.agentRoutes)
agent.POST("/agents/browser-status", a.agentBrowserStatus)
agent.POST("/messages/observed", a.observedMessage)
```

`observedMessage` must:

1. Validate Agent bearer token.
2. Validate `agent_id` matches token owner.
3. Load route and validate same UID.
4. Dedupe by `(route_id, source_message_id)`.
5. Insert observed message if new.
6. Forward text/link to WuKong IM group using `ctx.SendMessage`.
7. Mark forwarded/failed.
8. Insert monitor event.

- [ ] **Step 5: Add backend tests**

Extend patch snapshot `api_test.go` to cover:

- create route
- pull Agent routes
- browser status post/get
- observed message post
- duplicate observed message
- events list

- [ ] **Step 6: Apply remote patch with backup**

Run:

```powershell
ssh ubuntu@42.194.218.158 "set -e; ts=$(date +%Y%m%d-%H%M%S); backup=/home/ubuntu/wukong-deploy-backups/monitor-forwarding-$ts; mkdir -p $backup; tar -C /opt/wukongim-prod -czf $backup/src-before-monitor-forwarding.tar.gz src; echo $backup"
scp -r docs\production\monitor-cloud-backend-patch-20260507\modules_monitor\* ubuntu@42.194.218.158:/opt/wukongim-prod/src/modules/monitor/
```

- [ ] **Step 7: Test remote backend**

```powershell
ssh ubuntu@42.194.218.158 "cd /opt/wukongim-prod/src && gofmt -w modules/monitor && go test ./modules/monitor ./modules/common ./modules/robot"
```

Expected: PASS.

- [ ] **Step 8: Deploy remote backend**

```powershell
ssh ubuntu@42.194.218.158 "cd /opt/wukongim-prod/src/deploy/production && docker compose -f docker-compose.yaml build tsdd-api && docker compose -f docker-compose.yaml up -d tsdd-api"
```

Expected: API container restarts successfully.

- [ ] **Step 9: Commit patch snapshot**

```powershell
git add docs/production/monitor-cloud-backend-patch-20260507
git commit -m "docs: add feishu forwarding backend patch"
```

---

## Task 12: Verification

**Files:**
- Modify only touched files if verification fails.

- [ ] **Step 1: Run Flutter monitor tests**

```powershell
flutter test test/modules/monitor/monitor_local_agent_binder_test.dart test/modules/monitor/feishu_monitor_center_page_test.dart test/service/api/monitor_api_test.dart
```

Expected: PASS.

- [ ] **Step 2: Run Agent tests and analyzer**

```powershell
cd tools/feishu_monitor_agent
dart test
dart analyze
cd ..\..
```

Expected: PASS.

- [ ] **Step 3: Run mock server tests and analyzer**

```powershell
cd tools/monitor_mock_server
dart test
dart analyze
cd ..\..
```

Expected: PASS.

- [ ] **Step 4: Run focused Flutter analyzer**

```powershell
flutter analyze lib/modules/monitor/monitor_local_agent_binder.dart lib/modules/monitor/feishu_monitor_center_page.dart lib/modules/monitor/monitor_models.dart lib/service/api/monitor_api.dart
```

Expected: no issues.

- [ ] **Step 5: Run manual Windows Agent Chromium login smoke**

```powershell
cd tools/feishu_monitor_agent
dart run bin/feishu_monitor_agent.dart browser-login
```

Expected:

- Chromium opens.
- It does not use the user's default Chrome/Edge profile.
- Feishu login or messenger page appears.
- After scanning, closing, and reopening, login state is retained.

- [ ] **Step 6: Run manual browser status**

```powershell
cd tools/feishu_monitor_agent
dart run bin/feishu_monitor_agent.dart browser-status
cd ..\..
```

Expected output includes `飞书已登录` after scan login.

- [ ] **Step 7: Run cloud one-shot listen**

In the Flutter Windows app:

1. Enter 飞书信息监控中心.
2. Confirm Windows Agent online.
3. Click `打开飞书登录` and scan if needed.
4. Create a rule with one Feishu group name and one WuKong IM group.
5. Send one text message in that Feishu group.
6. Click `测试监听一次`.

Expected:

- The WuKong IM group receives the text message.
- Page logs show observed and forwarded events.
- Re-clicking `测试监听一次` does not duplicate the same message.

- [ ] **Step 8: Commit verification fixes if needed**

```powershell
git add lib/modules/monitor lib/service/api/monitor_api.dart test/modules/monitor test/service/api tools/feishu_monitor_agent tools/monitor_mock_server docs/production/monitor-cloud-backend-patch-20260507
git commit -m "fix: stabilize feishu forwarding mvp"
```

---

## Self-review checklist

- Spec coverage:
  - Chromium dedicated profile: Tasks 3, 4, 6, 7, 9, and 12.
  - No default browser profile usage: Task 4 uses only Agent store `userDataDir`.
  - Browser login/status/clear actions: Tasks 6, 7, and 9.
  - Agent pulls routes and listens once: Tasks 2, 5, 6, 10, and 11.
  - Local dedupe and cloud dedupe: Tasks 5, 10, and 11.
  - Cloud forwarding to WuKong IM group: Task 11.
  - Management center logs/status: Tasks 8, 9, 10, and 11.
  - Token redaction: new outputs print statuses and counts only.
- Placeholder scan:
  - No `TBD`, `TODO`, or unfinished placeholder sections remain.
  - Each code-changing task includes exact target files and concrete method names or snippets.
  - Verification commands and expected outcomes are listed.
- Type consistency:
  - Browser status API value is `logged_in`, `login_required`, `browser_error`, or `unknown`.
  - Browser profile mode is `isolated_persistent`.
  - Agent route type is `feishu_web_group_to_wukong_im_group`.
  - Agent capability remains `feishu_web_group`.
  - Message type is `text`, `link`, or `image_placeholder`.

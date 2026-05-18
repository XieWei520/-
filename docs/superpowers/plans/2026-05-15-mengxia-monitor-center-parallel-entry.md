# Mengxia Monitor Center Parallel Entry Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a `萌侠信息转发中心` entry beside the existing Feishu entry on the `系统管理` page, while implementing Mengxia monitoring on top of the shared local-monitor architecture and enforcing absolute incognito behavior for every Mengxia runtime launch.

**Architecture:** Keep the management page UX simple and parallel: Feishu and Mengxia remain separate visible cards. Under the hood, extract a shared monitor-center scaffold so Feishu and Mengxia can reuse common status, route, diagnostics, and control sections while keeping provider-specific shell clients, models, settings keys, and runtime behavior. Mengxia gets a new shell app that speaks the existing neutral `local_monitor` loopback contract but always starts in a fresh session and requires manual login on every launch.

**Tech Stack:** Flutter/Dart app code, existing `local_monitor` neutral abstractions, existing Feishu monitor module as reference, new Mengxia-specific Flutter Windows shell app, existing `tools/local_monitor_shell_core` loopback HTTP/SSE contract, WuKong internal message delivery through `ChatSceneGateway`.

---

## File Structure

### Shared app-side monitor-center surface

- `lib/modules/monitor_center/monitor_center_page_scaffold.dart`
  - New shared page shell for status, routes, diagnostics, and runtime controls.
- `lib/modules/monitor_center/monitor_center_section_models.dart`
  - Shared view models / section DTOs consumed by both providers.
- `lib/modules/monitor_center/monitor_center_status_section.dart`
  - Shared status overview section.
- `lib/modules/monitor_center/monitor_center_routes_section.dart`
  - Shared route list and route actions section.
- `lib/modules/monitor_center/monitor_center_logs_section.dart`
  - Shared recent events / diagnostics section.
- `lib/modules/monitor_center/monitor_center_controls_section.dart`
  - Shared start/stop/reload/manual-login guidance section.

### Management page entry wiring

- `lib/modules/vip/vip_management_page.dart`
  - Add the Mengxia entry beside Feishu and keep both visible.

### Feishu migration onto shared scaffold

- `lib/modules/feishu_monitor/feishu_monitor_center_page.dart`
  - Retain Feishu behavior but switch the page composition to shared monitor-center sections where possible.

### Mengxia provider app-side module

- `lib/modules/mengxia_monitor/mengxia_monitor_center_page.dart`
  - New provider page wrapper for the shared scaffold.
- `lib/modules/mengxia_monitor/mengxia_monitor_forwarding_service.dart`
  - Provider-specific routes, settings keys, relay identity, and forwarding behavior.
- `lib/modules/mengxia_monitor/mengxia_monitor_auto_forward_runner.dart`
  - Provider-specific runner using `local_monitor_runner.dart`.
- `lib/modules/mengxia_monitor/mengxia_monitor_shell_client.dart`
  - Provider-specific wrapper around the neutral shell client.
- `lib/modules/mengxia_monitor/mengxia_monitor_shell_models.dart`
  - Provider-specific typed status/event models built from the neutral shell models.
- `lib/modules/mengxia_monitor/mengxia_monitor_worker_config.dart`
  - Optional worker config placeholder kept provider-local even if Mengxia starts single-worker.
- `lib/modules/mengxia_monitor/mengxia_monitor_launch_service.dart`
  - Runtime launch contract for manual-login shell startup and shutdown handling.

### App bootstrap

- `lib/app/app.dart`
  - Wire Mengxia auto-forward startup behavior without regressing Feishu startup behavior.

### Mengxia shell runtime

- `tools/mengxia_monitor_shell_app/pubspec.yaml`
  - New shell app package config.
- `tools/mengxia_monitor_shell_app/lib/main.dart`
  - WebView runtime bootstrap, fresh-session startup, loopback server wiring, runtime controls, and shutdown cleanup.
- `tools/mengxia_monitor_shell_app/lib/src/mengxia_page_observer.dart`
  - Provider-specific page observation scripts.
- `tools/mengxia_monitor_shell_app/lib/src/mengxia_page_probe.dart`
  - Provider-specific DOM probing / source-conversation extraction.
- `tools/mengxia_monitor_shell_app/lib/src/mengxia_network_capture.dart`
  - Provider-specific normalized network capture event model.
- `tools/mengxia_monitor_shell_app/lib/src/mengxia_network_capture_bridge.dart`
  - WebView/native bridge for network capture callbacks.
- `tools/mengxia_monitor_shell_app/lib/src/mengxia_network_capture_parser.dart`
  - Parse Mengxia request/response payloads into candidate events.
- `tools/mengxia_monitor_shell_app/lib/src/mengxia_runtime_snapshot_mapper.dart`
  - Convert page/network observations into neutral shell snapshots and recent normalized events.
- `tools/mengxia_monitor_shell_app/lib/src/mengxia_incognito_runtime.dart`
  - Fresh-session directory creation, cleanup, and hard guarantees around no persistent reusable session.
- `tools/mengxia_monitor_shell_app/test/*`
  - Shell runtime, parsing, snapshot mapping, and incognito cleanup coverage.

### Shared neutral pieces reused directly

- `lib/modules/local_monitor/local_monitor_forwarding.dart`
  - Reuse existing neutral relay identity and sender instead of re-inventing them.
- `lib/modules/local_monitor/local_monitor_runner.dart`
  - Reuse startup-event split and dedupe helpers for the Mengxia runner.
- `lib/modules/local_monitor/local_monitor_shell_client.dart`
  - Reuse shell loopback access.
- `lib/modules/local_monitor/local_monitor_shell_models.dart`
  - Reuse normalized shell contract.
- `tools/local_monitor_shell_core/lib/src/*`
  - Reuse existing HTTP/SSE/store/event bus contract.

### Tests

- `test/modules/monitor_center/monitor_center_page_scaffold_test.dart`
  - New shared scaffold tests.
- `test/modules/mengxia_monitor/mengxia_monitor_forwarding_service_test.dart`
  - New provider forwarding tests.
- `test/modules/mengxia_monitor/mengxia_monitor_auto_forward_runner_test.dart`
  - New provider runner tests.
- `test/modules/mengxia_monitor/mengxia_monitor_shell_client_test.dart`
  - New provider shell client/model tests.
- `test/modules/mengxia_monitor/mengxia_monitor_center_page_test.dart`
  - New provider widget tests.
- `test/modules/vip/vip_management_page_test.dart`
  - Add management-page parallel entry assertions.

## Dependency Order

1. Shared monitor-center scaffold extraction
2. Management-page parallel entry wiring
3. Feishu migration onto the shared scaffold without behavior changes
4. Mengxia forwarding/settings shell on the app side
5. Mengxia shell loopback runtime with strict incognito lifecycle
6. Mengxia source observation and normalized event generation
7. Mengxia page integration, runtime controls, and auto-forward startup
8. Cross-provider regression verification

## Task List

### Task 1: Add the Management-Page Parallel Mengxia Entry

**Files:**
- Modify: `lib/modules/vip/vip_management_page.dart`
- Create: `test/modules/vip/vip_management_page_test.dart`

- [ ] **Step 1: Write the failing management-page widget test**

Create `test/modules/vip/vip_management_page_test.dart` with:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/modules/vip/vip_management_page.dart';

void main() {
  testWidgets('management page shows both feishu and mengxia monitor entries', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: VipManagementPage(),
      ),
    );

    expect(find.byKey(const ValueKey('management-center-feishu')), findsOneWidget);
    expect(find.byKey(const ValueKey('management-center-mengxia')), findsOneWidget);
    expect(find.text('萌侠信息转发中心'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run the test to verify RED**

Run:

```powershell
cd C:\Users\COLORFUL\Desktop\WuKong
flutter test test/modules/vip/vip_management_page_test.dart -r compact
```

Expected: FAIL because the Mengxia card key/text does not exist yet.

- [ ] **Step 3: Add the new parallel management entry**

Update `lib/modules/vip/vip_management_page.dart` to add a new card beside Feishu:

```dart
void _openMengxiaCenter(BuildContext context) {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => MengxiaMonitorCenterPage(),
    ),
  );
}
```

Add the new card block:

```dart
_ManagementCenterCard(
  key: const ValueKey('management-center-mengxia'),
  title: '萌侠信息转发中心',
  description: '人工登录萌侠后实时监控指定源会话，并转发到悟空内部目标群。',
  status: '第一阶段',
  icon: Icons.hub_rounded,
  enabled: true,
  onTap: () => _openMengxiaCenter(context),
),
```

Also add the import:

```dart
import '../mengxia_monitor/mengxia_monitor_center_page.dart';
```

- [ ] **Step 4: Run the test to verify GREEN**

Run:

```powershell
cd C:\Users\COLORFUL\Desktop\WuKong
flutter test test/modules/vip/vip_management_page_test.dart -r compact
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/modules/vip/vip_management_page.dart test/modules/vip/vip_management_page_test.dart
git commit -m "feat: add mengxia monitor entry to management page"
```

### Task 2: Extract a Shared Monitor-Center Scaffold

**Files:**
- Create: `lib/modules/monitor_center/monitor_center_section_models.dart`
- Create: `lib/modules/monitor_center/monitor_center_page_scaffold.dart`
- Create: `lib/modules/monitor_center/monitor_center_status_section.dart`
- Create: `lib/modules/monitor_center/monitor_center_routes_section.dart`
- Create: `lib/modules/monitor_center/monitor_center_logs_section.dart`
- Create: `lib/modules/monitor_center/monitor_center_controls_section.dart`
- Create: `test/modules/monitor_center/monitor_center_page_scaffold_test.dart`

- [ ] **Step 1: Write the failing scaffold test**

Create `test/modules/monitor_center/monitor_center_page_scaffold_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/modules/monitor_center/monitor_center_page_scaffold.dart';
import 'package:wukong_im_app/modules/monitor_center/monitor_center_section_models.dart';

void main() {
  testWidgets('shared scaffold renders core monitor sections', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MonitorCenterPageScaffold(
          title: 'Test Center',
          status: const MonitorCenterStatusViewData(
            shellState: 'online',
            loginState: 'logged_in',
            captureState: 'running',
            summaryLines: <String>['ok'],
          ),
          routesSection: const MonitorCenterRoutesViewData(
            emptyHint: 'no routes',
            routeLines: <String>['route-a'],
          ),
          logsSection: const MonitorCenterLogsViewData(
            logLines: <String>['log-a'],
          ),
          controlsSection: const MonitorCenterControlsViewData(
            startLabel: '启动',
            stopLabel: '停止',
            reloadLabel: '重载',
            loginHint: 'manual login required',
          ),
        ),
      ),
    );

    expect(find.text('Test Center'), findsOneWidget);
    expect(find.text('manual login required'), findsOneWidget);
    expect(find.text('route-a'), findsOneWidget);
    expect(find.text('log-a'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run the test to verify RED**

Run:

```powershell
cd C:\Users\COLORFUL\Desktop\WuKong
flutter test test/modules/monitor_center/monitor_center_page_scaffold_test.dart -r compact
```

Expected: FAIL because the shared scaffold files do not exist yet.

- [ ] **Step 3: Implement the minimal shared scaffold**

Create `lib/modules/monitor_center/monitor_center_section_models.dart`:

```dart
class MonitorCenterStatusViewData {
  const MonitorCenterStatusViewData({
    required this.shellState,
    required this.loginState,
    required this.captureState,
    this.summaryLines = const <String>[],
  });

  final String shellState;
  final String loginState;
  final String captureState;
  final List<String> summaryLines;
}

class MonitorCenterRoutesViewData {
  const MonitorCenterRoutesViewData({
    required this.emptyHint,
    this.routeLines = const <String>[],
  });

  final String emptyHint;
  final List<String> routeLines;
}

class MonitorCenterLogsViewData {
  const MonitorCenterLogsViewData({
    this.logLines = const <String>[],
  });

  final List<String> logLines;
}

class MonitorCenterControlsViewData {
  const MonitorCenterControlsViewData({
    required this.startLabel,
    required this.stopLabel,
    required this.reloadLabel,
    required this.loginHint,
  });

  final String startLabel;
  final String stopLabel;
  final String reloadLabel;
  final String loginHint;
}
```

Create `lib/modules/monitor_center/monitor_center_page_scaffold.dart`:

```dart
import 'package:flutter/material.dart';

import '../../widgets/wk_sub_page_scaffold.dart';
import 'monitor_center_controls_section.dart';
import 'monitor_center_logs_section.dart';
import 'monitor_center_routes_section.dart';
import 'monitor_center_section_models.dart';
import 'monitor_center_status_section.dart';

class MonitorCenterPageScaffold extends StatelessWidget {
  const MonitorCenterPageScaffold({
    super.key,
    required this.title,
    required this.status,
    required this.routesSection,
    required this.logsSection,
    required this.controlsSection,
  });

  final String title;
  final MonitorCenterStatusViewData status;
  final MonitorCenterRoutesViewData routesSection;
  final MonitorCenterLogsViewData logsSection;
  final MonitorCenterControlsViewData controlsSection;

  @override
  Widget build(BuildContext context) {
    return WKSubPageScaffold(
      title: title,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          MonitorCenterStatusSection(data: status),
          const SizedBox(height: 12),
          MonitorCenterControlsSection(data: controlsSection),
          const SizedBox(height: 12),
          MonitorCenterRoutesSection(data: routesSection),
          const SizedBox(height: 12),
          MonitorCenterLogsSection(data: logsSection),
        ],
      ),
    );
  }
}
```

Create the minimal section widgets:

```dart
import 'package:flutter/material.dart';
import 'monitor_center_section_models.dart';

class MonitorCenterStatusSection extends StatelessWidget {
  const MonitorCenterStatusSection({super.key, required this.data});
  final MonitorCenterStatusViewData data;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('shell: ${data.shellState}'),
            Text('login: ${data.loginState}'),
            Text('capture: ${data.captureState}'),
            for (final line in data.summaryLines) Text(line),
          ],
        ),
      ),
    );
  }
}
```

```dart
import 'package:flutter/material.dart';
import 'monitor_center_section_models.dart';

class MonitorCenterRoutesSection extends StatelessWidget {
  const MonitorCenterRoutesSection({super.key, required this.data});
  final MonitorCenterRoutesViewData data;

  @override
  Widget build(BuildContext context) {
    final routeLines = data.routeLines;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: routeLines.isEmpty
              ? [Text(data.emptyHint)]
              : routeLines.map(Text.new).toList(growable: false),
        ),
      ),
    );
  }
}
```

```dart
import 'package:flutter/material.dart';
import 'monitor_center_section_models.dart';

class MonitorCenterLogsSection extends StatelessWidget {
  const MonitorCenterLogsSection({super.key, required this.data});
  final MonitorCenterLogsViewData data;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: data.logLines.map(Text.new).toList(growable: false),
        ),
      ),
    );
  }
}
```

```dart
import 'package:flutter/material.dart';
import 'monitor_center_section_models.dart';

class MonitorCenterControlsSection extends StatelessWidget {
  const MonitorCenterControlsSection({super.key, required this.data});
  final MonitorCenterControlsViewData data;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(data.loginHint),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton(onPressed: null, child: Text(data.startLabel)),
                OutlinedButton(onPressed: null, child: Text(data.stopLabel)),
                OutlinedButton(onPressed: null, child: Text(data.reloadLabel)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run the test to verify GREEN**

Run:

```powershell
cd C:\Users\COLORFUL\Desktop\WuKong
flutter test test/modules/monitor_center/monitor_center_page_scaffold_test.dart -r compact
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/modules/monitor_center test/modules/monitor_center/monitor_center_page_scaffold_test.dart
git commit -m "feat: add shared monitor center scaffold"
```

### Task 3: Move Feishu Center Onto the Shared Scaffold Without Regressing Behavior

**Files:**
- Modify: `lib/modules/feishu_monitor/feishu_monitor_center_page.dart`
- Modify: `test/modules/feishu_monitor/feishu_monitor_center_page_test.dart`
- Modify: `test/modules/vip/vip_management_page_test.dart`

- [ ] **Step 1: Add a failing Feishu regression test around the shared-shell migration**

Append to `test/modules/feishu_monitor/feishu_monitor_center_page_test.dart`:

```dart
testWidgets('feishu center still renders title and key runtime actions after scaffold migration', (
  tester,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: FeishuMonitorCenterPage(
        client: FakeFeishuMonitorShellClient(),
        forwardingService: FakeFeishuMonitorForwardingService(),
        forwardingSettingsStore: FakeFeishuMonitorForwardingSettingsStore(),
        loadTargetGroups: () async => <GroupInfo>[],
      ),
    ),
  );

  await tester.pumpAndSettle();

  expect(find.text('飞书信息转发中心'), findsOneWidget);
  expect(find.byKey(const ValueKey('feishu-monitor-start-capture-button')), findsOneWidget);
  expect(find.byKey(const ValueKey('feishu-monitor-auto-forward-switch')), findsOneWidget);
});
```

- [ ] **Step 2: Run the test to verify RED**

Run:

```powershell
cd C:\Users\COLORFUL\Desktop\WuKong
flutter test test/modules/feishu_monitor/feishu_monitor_center_page_test.dart -r compact
```

Expected: FAIL once the page stops directly composing its old structure and before the shared-scaffold wiring is complete.

- [ ] **Step 3: Refactor Feishu page composition onto the shared scaffold**

In `lib/modules/feishu_monitor/feishu_monitor_center_page.dart`, keep Feishu-specific data loading and actions, but move the outer layout to `MonitorCenterPageScaffold`.

Add imports:

```dart
import '../monitor_center/monitor_center_page_scaffold.dart';
import '../monitor_center/monitor_center_section_models.dart';
```

Build shared view data near `build()`:

```dart
MonitorCenterStatusViewData _buildSharedStatusData() {
  final status = _status;
  return MonitorCenterStatusViewData(
    shellState: status?.shellState ?? 'offline',
    loginState: status?.loginState ?? 'unknown',
    captureState: status?.captureState ?? 'stopped',
    summaryLines: <String>[
      if ((status?.pageTitle ?? '').trim().isNotEmpty) status!.pageTitle.trim(),
      if (_forwardingResult.trim().isNotEmpty) _forwardingResult.trim(),
      if (_error.trim().isNotEmpty) _error.trim(),
    ],
  );
}
```

Then render:

```dart
return MonitorCenterPageScaffold(
  title: '飞书信息转发中心',
  status: _buildSharedStatusData(),
  controlsSection: MonitorCenterControlsViewData(
    startLabel: '启动',
    stopLabel: '停止',
    reloadLabel: '重载',
    loginHint: '飞书中心保持现有登录/运行提示，具体控件仍由 Feishu 页面扩展区承载。',
  ),
  routesSection: MonitorCenterRoutesViewData(
    emptyHint: '暂无飞书转发路由',
    routeLines: _forwardingSettings.routes
        .map((route) => '${route.sourceConversationName} -> ${route.targetGroupName}')
        .toList(growable: false),
  ),
  logsSection: MonitorCenterLogsViewData(
    logLines: <String>[
      ...?_status?.recentEvents.take(5).map((event) => event.text),
    ],
  ),
);
```

Keep provider-specific action areas below or inside the scaffold sections by embedding the existing Feishu action widgets into the shared section content rather than deleting them.

- [ ] **Step 4: Run the Feishu regression tests to verify GREEN**

Run:

```powershell
cd C:\Users\COLORFUL\Desktop\WuKong
flutter test test/modules/feishu_monitor/feishu_monitor_center_page_test.dart -r compact
```

Expected: PASS with the title and Feishu-specific runtime controls still visible.

- [ ] **Step 5: Commit**

```bash
git add lib/modules/feishu_monitor/feishu_monitor_center_page.dart test/modules/feishu_monitor/feishu_monitor_center_page_test.dart
git commit -m "refactor: move feishu center onto shared scaffold"
```

### Task 4: Add Mengxia App-Side Provider Models, Shell Client, and Forwarding Settings

**Files:**
- Create: `lib/modules/mengxia_monitor/mengxia_monitor_shell_models.dart`
- Create: `lib/modules/mengxia_monitor/mengxia_monitor_shell_client.dart`
- Create: `lib/modules/mengxia_monitor/mengxia_monitor_forwarding_service.dart`
- Create: `test/modules/mengxia_monitor/mengxia_monitor_shell_client_test.dart`
- Create: `test/modules/mengxia_monitor/mengxia_monitor_forwarding_service_test.dart`

- [ ] **Step 1: Write the failing shell-model and forwarding tests**

Create `test/modules/mengxia_monitor/mengxia_monitor_shell_client_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/modules/mengxia_monitor/mengxia_monitor_shell_models.dart';

void main() {
  test('mengxia shell status maps neutral local monitor fields', () {
    final status = MengxiaMonitorShellStatus.fromJson(<String, dynamic>{
      'shell_state': 'online',
      'login_state': 'login_required',
      'capture_state': 'stopped',
      'page_title': '萌侠',
      'recent_events': <Map<String, dynamic>>[],
      'observed_conversations': <Map<String, dynamic>>[],
      'observed_messages': <Map<String, dynamic>>[],
    });

    expect(status.shellState, 'online');
    expect(status.loginState, 'login_required');
    expect(status.pageTitle, '萌侠');
  });
}
```

Create `test/modules/mengxia_monitor/mengxia_monitor_forwarding_service_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/modules/mengxia_monitor/mengxia_monitor_forwarding_service.dart';

void main() {
  test('mengxia forwarding settings use provider-specific keys', () {
    expect(mengxiaMonitorForwardingSettingsStorageKey, isNotEmpty);
    expect(mengxiaMonitorForwardingSettingsStorageKey, isNot(contains('feishu')));
  });
}
```

- [ ] **Step 2: Run the tests to verify RED**

Run:

```powershell
cd C:\Users\COLORFUL\Desktop\WuKong
flutter test test/modules/mengxia_monitor/mengxia_monitor_shell_client_test.dart test/modules/mengxia_monitor/mengxia_monitor_forwarding_service_test.dart -r compact
```

Expected: FAIL because the Mengxia provider files do not exist yet.

- [ ] **Step 3: Implement the provider models and forwarding settings**

Create `lib/modules/mengxia_monitor/mengxia_monitor_shell_models.dart` mirroring the Feishu typed wrapper pattern:

```dart
import 'package:wukong_im_app/modules/local_monitor/local_monitor_shell_models.dart';

class MengxiaMonitorShellStatus {
  const MengxiaMonitorShellStatus({
    required this.shellState,
    required this.captureState,
    required this.loginState,
    required this.pageTitle,
    required this.recentEvents,
    required this.observedConversations,
  });

  final String shellState;
  final String captureState;
  final String loginState;
  final String pageTitle;
  final List<MengxiaMonitorMessageEvent> recentEvents;
  final List<MengxiaMonitorObservedConversation> observedConversations;

  factory MengxiaMonitorShellStatus.fromJson(Map<String, dynamic> json) {
    final local = LocalMonitorShellStatus.fromJson(json);
    return MengxiaMonitorShellStatus(
      shellState: local.shellState,
      captureState: local.captureState,
      loginState: local.loginState,
      pageTitle: local.pageTitle,
      recentEvents: local.recentEvents
          .map(MengxiaMonitorMessageEvent.fromLocal)
          .toList(growable: false),
      observedConversations: local.observedConversations
          .map(MengxiaMonitorObservedConversation.fromLocal)
          .toList(growable: false),
    );
  }
}

class MengxiaMonitorObservedConversation {
  const MengxiaMonitorObservedConversation({
    required this.id,
    required this.name,
  });

  final String id;
  final String name;

  factory MengxiaMonitorObservedConversation.fromLocal(
    LocalMonitorObservedConversation conversation,
  ) {
    return MengxiaMonitorObservedConversation(
      id: conversation.id,
      name: conversation.name,
    );
  }
}

class MengxiaMonitorMessageEvent {
  const MengxiaMonitorMessageEvent({
    required this.eventId,
    required this.conversationId,
    required this.conversationName,
    required this.text,
  });

  final String eventId;
  final String conversationId;
  final String conversationName;
  final String text;

  factory MengxiaMonitorMessageEvent.fromLocal(LocalMonitorMessageEvent event) {
    return MengxiaMonitorMessageEvent(
      eventId: event.eventId,
      conversationId: event.conversationId,
      conversationName: event.conversationName,
      text: event.text,
    );
  }
}
```

Create `lib/modules/mengxia_monitor/mengxia_monitor_shell_client.dart`:

```dart
import 'package:dio/dio.dart';
import 'package:wukong_im_app/modules/local_monitor/local_monitor_shell_client.dart';

import 'mengxia_monitor_shell_models.dart';

class MengxiaMonitorShellClient {
  MengxiaMonitorShellClient({
    Dio? dio,
    String baseUrl = 'http://127.0.0.1:18786',
    String token = 'wukong-mengxia-shell-dev',
  }) : _client = LocalMonitorShellClient(
         dio: dio,
         baseUrl: baseUrl,
         token: token,
       );

  final LocalMonitorShellClient _client;

  Future<MengxiaMonitorShellStatus> fetchStatus() async {
    return MengxiaMonitorShellStatus.fromLocal(await _client.fetchStatus());
  }

  Future<void> startCapture() => _client.startCapture();
  Future<void> stopCapture() => _client.stopCapture();
  Future<void> reloadRuntime() => _client.reloadRuntime();
  Stream<LocalMonitorShellEvent> watchEvents() => _client.watchEvents();
}

extension on MengxiaMonitorShellStatus {
  static MengxiaMonitorShellStatus fromLocal(LocalMonitorShellStatus status) {
    return MengxiaMonitorShellStatus(
      shellState: status.shellState,
      captureState: status.captureState,
      loginState: status.loginState,
      pageTitle: status.pageTitle,
      recentEvents: status.recentEvents
          .map(MengxiaMonitorMessageEvent.fromLocal)
          .toList(growable: false),
      observedConversations: status.observedConversations
          .map(MengxiaMonitorObservedConversation.fromLocal)
          .toList(growable: false),
    );
  }
}
```

Create `lib/modules/mengxia_monitor/mengxia_monitor_forwarding_service.dart`:

```dart
import 'package:shared_preferences/shared_preferences.dart';

const String mengxiaMonitorForwardingSettingsStorageKey =
    'mengxia_monitor_forwarding_settings_v1';
const String mengxiaMonitorForwardedDedupeStorageKey =
    'mengxia_monitor_forwarded_dedupe_keys_v1';

class MengxiaMonitorForwardingRoute {
  const MengxiaMonitorForwardingRoute({
    required this.id,
    required this.enabled,
    required this.sourceConversationId,
    required this.sourceConversationName,
    required this.targetGroupId,
    required this.targetGroupName,
  });

  final String id;
  final bool enabled;
  final String sourceConversationId;
  final String sourceConversationName;
  final String targetGroupId;
  final String targetGroupName;
}

class MengxiaMonitorForwardingSettings {
  const MengxiaMonitorForwardingSettings({
    required this.enabled,
    required this.routes,
  });

  final bool enabled;
  final List<MengxiaMonitorForwardingRoute> routes;
}

class SharedPreferencesMengxiaMonitorForwardingSettingsStore {
  const SharedPreferencesMengxiaMonitorForwardingSettingsStore();

  Future<void> saveRawJson(String json) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(mengxiaMonitorForwardingSettingsStorageKey, json);
  }

  Future<String> loadRawJson() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(mengxiaMonitorForwardingSettingsStorageKey) ?? '{}';
  }
}
```

- [ ] **Step 4: Run the tests to verify GREEN**

Run:

```powershell
cd C:\Users\COLORFUL\Desktop\WuKong
flutter test test/modules/mengxia_monitor/mengxia_monitor_shell_client_test.dart test/modules/mengxia_monitor/mengxia_monitor_forwarding_service_test.dart -r compact
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/modules/mengxia_monitor test/modules/mengxia_monitor
git commit -m "feat: add mengxia provider shell models and settings"
```

### Task 5: Add a Strict-Incognito Mengxia Shell Runtime Skeleton

**Files:**
- Create: `tools/mengxia_monitor_shell_app/pubspec.yaml`
- Create: `tools/mengxia_monitor_shell_app/lib/main.dart`
- Create: `tools/mengxia_monitor_shell_app/lib/src/mengxia_incognito_runtime.dart`
- Create: `tools/mengxia_monitor_shell_app/test/mengxia_incognito_runtime_test.dart`

- [ ] **Step 1: Write the failing incognito-runtime tests**

Create `tools/mengxia_monitor_shell_app/test/mengxia_incognito_runtime_test.dart`:

```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mengxia_monitor_shell_app/src/mengxia_incognito_runtime.dart';

void main() {
  test('fresh session directory path changes across launches', () async {
    final base = await Directory.systemTemp.createTemp('mengxia_incognito_test');
    final first = await createMengxiaFreshSessionDirectory(base);
    final second = await createMengxiaFreshSessionDirectory(base);

    expect(first.path, isNot(second.path));
  });

  test('cleanup removes reusable session directory', () async {
    final base = await Directory.systemTemp.createTemp('mengxia_incognito_test');
    final session = await createMengxiaFreshSessionDirectory(base);

    expect(await session.exists(), isTrue);
    await destroyMengxiaFreshSessionDirectory(session);
    expect(await session.exists(), isFalse);
  });
}
```

- [ ] **Step 2: Run the test to verify RED**

Run:

```powershell
cd C:\Users\COLORFUL\Desktop\WuKong\tools\mengxia_monitor_shell_app
flutter test test/mengxia_incognito_runtime_test.dart -r compact
```

Expected: FAIL because the shell app and runtime files do not exist yet.

- [ ] **Step 3: Implement the minimal incognito runtime**

Create `tools/mengxia_monitor_shell_app/lib/src/mengxia_incognito_runtime.dart`:

```dart
import 'dart:io';

Future<Directory> createMengxiaFreshSessionDirectory(Directory base) async {
  final session = Directory(
    '${base.path}${Platform.pathSeparator}session_${DateTime.now().microsecondsSinceEpoch}',
  );
  await session.create(recursive: true);
  return session;
}

Future<void> destroyMengxiaFreshSessionDirectory(Directory session) async {
  if (await session.exists()) {
    await session.delete(recursive: true);
  }
}
```

Create the minimal `tools/mengxia_monitor_shell_app/lib/main.dart`:

```dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import 'src/mengxia_incognito_runtime.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final supportDirectory = await getApplicationSupportDirectory();
  final sessionDirectory = await createMengxiaFreshSessionDirectory(
    Directory('${supportDirectory.path}${Platform.pathSeparator}mengxia_monitor_shell'),
  );
  runApp(MengxiaShellApp(sessionDirectory: sessionDirectory));
}

class MengxiaShellApp extends StatefulWidget {
  const MengxiaShellApp({super.key, required this.sessionDirectory});

  final Directory sessionDirectory;

  @override
  State<MengxiaShellApp> createState() => _MengxiaShellAppState();
}

class _MengxiaShellAppState extends State<MengxiaShellApp> {
  @override
  void dispose() {
    destroyMengxiaFreshSessionDirectory(widget.sessionDirectory);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: Scaffold(
        body: Center(
          child: Text('Mengxia monitor shell (manual login required)'),
        ),
      ),
    );
  }
}
```

Create `tools/mengxia_monitor_shell_app/pubspec.yaml`:

```yaml
name: mengxia_monitor_shell_app
publish_to: none
environment:
  sdk: ^3.11.1

dependencies:
  flutter:
    sdk: flutter
  path_provider: ^2.1.2

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^6.0.0

flutter:
  uses-material-design: true
```

- [ ] **Step 4: Run the test to verify GREEN**

Run:

```powershell
cd C:\Users\COLORFUL\Desktop\WuKong\tools\mengxia_monitor_shell_app
flutter test test/mengxia_incognito_runtime_test.dart -r compact
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add tools/mengxia_monitor_shell_app
git commit -m "feat: add mengxia strict incognito shell skeleton"
```

### Task 6: Add a Neutral-Shell Mengxia Runtime With Manual Login State

**Files:**
- Modify: `tools/mengxia_monitor_shell_app/lib/main.dart`
- Create: `tools/mengxia_monitor_shell_app/lib/src/mengxia_page_observer.dart`
- Create: `tools/mengxia_monitor_shell_app/lib/src/mengxia_page_probe.dart`
- Create: `tools/mengxia_monitor_shell_app/lib/src/mengxia_runtime_snapshot_mapper.dart`
- Create: `tools/mengxia_monitor_shell_app/test/mengxia_runtime_snapshot_mapper_test.dart`

- [ ] **Step 1: Write the failing snapshot-mapper test**

Create `tools/mengxia_monitor_shell_app/test/mengxia_runtime_snapshot_mapper_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mengxia_monitor_shell_app/src/mengxia_runtime_snapshot_mapper.dart';

void main() {
  test('maps login page probe to login required shell state', () {
    final snapshot = mapMengxiaProbeToShellSnapshot(
      pageTitle: 'MX技术小筑',
      pageKind: 'login',
      conversations: const <Map<String, String>>[],
      events: const <Map<String, String>>[],
    );

    expect(snapshot['login_state'], 'login_required');
    expect(snapshot['capture_state'], 'stopped');
  });
}
```

- [ ] **Step 2: Run the test to verify RED**

Run:

```powershell
cd C:\Users\COLORFUL\Desktop\WuKong\tools\mengxia_monitor_shell_app
flutter test test/mengxia_runtime_snapshot_mapper_test.dart -r compact
```

Expected: FAIL because the mapper file does not exist yet.

- [ ] **Step 3: Implement the minimal neutral-shell mapping**

Create `tools/mengxia_monitor_shell_app/lib/src/mengxia_runtime_snapshot_mapper.dart`:

```dart
Map<String, dynamic> mapMengxiaProbeToShellSnapshot({
  required String pageTitle,
  required String pageKind,
  required List<Map<String, String>> conversations,
  required List<Map<String, String>> events,
}) {
  final loginRequired = pageKind.trim() == 'login';
  return <String, dynamic>{
    'shell_state': 'online',
    'capture_state': loginRequired ? 'stopped' : 'running',
    'login_state': loginRequired ? 'login_required' : 'logged_in',
    'hook_state': 'healthy',
    'runtime_url': '',
    'page_title': pageTitle,
    'page_kind': pageKind,
    'webview_available': true,
    'shell_mode': 'service',
    'queue_depth': 0,
    'messages_today': 0,
    'deliveries_succeeded_today': 0,
    'deliveries_failed_today': 0,
    'observed_conversations': conversations,
    'observed_messages': const <Map<String, dynamic>>[],
    'recent_events': events,
    'worker_id': 'worker-1',
    'probe_diagnostics': <String, dynamic>{},
    'last_error': '',
  };
}
```

Create placeholder observer/probe files:

```dart
const String mengxiaPageObserverScript = r'''
(() => ({ installed: true, provider: 'mengxia' }))();
''';
```

```dart
Map<String, dynamic> classifyMengxiaPage({
  required String url,
  required String title,
}) {
  final normalizedUrl = url.toLowerCase();
  if (normalizedUrl.contains('/pages/login/login')) {
    return <String, dynamic>{'page_kind': 'login', 'page_title': title};
  }
  return <String, dynamic>{'page_kind': 'workspace', 'page_title': title};
}
```

Update `tools/mengxia_monitor_shell_app/lib/main.dart` to note manual-login state in the runtime UI:

```dart
const Text('Mengxia monitor shell (manual login required every launch)')
```

- [ ] **Step 4: Run the test to verify GREEN**

Run:

```powershell
cd C:\Users\COLORFUL\Desktop\WuKong\tools\mengxia_monitor_shell_app
flutter test test/mengxia_runtime_snapshot_mapper_test.dart -r compact
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add tools/mengxia_monitor_shell_app/lib tools/mengxia_monitor_shell_app/test/mengxia_runtime_snapshot_mapper_test.dart
git commit -m "feat: add mengxia neutral shell login-state mapping"
```

### Task 7: Add the Mengxia Center Page and Manual-Login Runtime Controls

**Files:**
- Create: `lib/modules/mengxia_monitor/mengxia_monitor_center_page.dart`
- Create: `lib/modules/mengxia_monitor/mengxia_monitor_auto_forward_runner.dart`
- Create: `lib/modules/mengxia_monitor/mengxia_monitor_launch_service.dart`
- Create: `test/modules/mengxia_monitor/mengxia_monitor_center_page_test.dart`
- Create: `test/modules/mengxia_monitor/mengxia_monitor_auto_forward_runner_test.dart`
- Modify: `lib/app/app.dart`

- [ ] **Step 1: Write the failing widget test**

Create `test/modules/mengxia_monitor/mengxia_monitor_center_page_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/modules/mengxia_monitor/mengxia_monitor_center_page.dart';

void main() {
  testWidgets('mengxia center shows manual login guidance', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MengxiaMonitorCenterPage(),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('萌侠信息转发中心'), findsOneWidget);
    expect(find.textContaining('人工登录'), findsWidgets);
  });
}
```

- [ ] **Step 2: Run the test to verify RED**

Run:

```powershell
cd C:\Users\COLORFUL\Desktop\WuKong
flutter test test/modules/mengxia_monitor/mengxia_monitor_center_page_test.dart -r compact
```

Expected: FAIL because the page does not exist yet.

- [ ] **Step 3: Implement the minimal page, runner, and app bootstrap**

Create `lib/modules/mengxia_monitor/mengxia_monitor_launch_service.dart`:

```dart
class MengxiaMonitorLaunchService {
  Future<void> startShell() async {}
  Future<void> stopShell() async {}
}
```

Create `lib/modules/mengxia_monitor/mengxia_monitor_auto_forward_runner.dart`:

```dart
class MengxiaMonitorAutoForwardRunner {
  void start() {}
  void stop() {}
  void dispose() => stop();
}
```

Create `lib/modules/mengxia_monitor/mengxia_monitor_center_page.dart`:

```dart
import 'package:flutter/material.dart';

import '../monitor_center/monitor_center_page_scaffold.dart';
import '../monitor_center/monitor_center_section_models.dart';

class MengxiaMonitorCenterPage extends StatelessWidget {
  const MengxiaMonitorCenterPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const MonitorCenterPageScaffold(
      title: '萌侠信息转发中心',
      status: MonitorCenterStatusViewData(
        shellState: 'offline',
        loginState: 'login_required',
        captureState: 'stopped',
        summaryLines: <String>['每次启动都需要人工登录，关闭后不保留会话痕迹。'],
      ),
      routesSection: MonitorCenterRoutesViewData(
        emptyHint: '暂无萌侠转发路由',
      ),
      logsSection: MonitorCenterLogsViewData(
        logLines: <String>['等待人工登录后开始观察源会话。'],
      ),
      controlsSection: MonitorCenterControlsViewData(
        startLabel: '启动',
        stopLabel: '停止',
        reloadLabel: '重载',
        loginHint: '萌侠必须人工登录，且每次启动都是全新无痕会话。',
      ),
    );
  }
}
```

Update `lib/app/app.dart` with a placeholder Mengxia runner lifecycle that matches the Feishu pattern without starting by default until the provider is complete:

```dart
import '../modules/mengxia_monitor/mengxia_monitor_auto_forward_runner.dart';
```

Add field:

```dart
late final MengxiaMonitorAutoForwardRunner _mengxiaAutoForwardRunner;
```

Initialize it:

```dart
_mengxiaAutoForwardRunner = MengxiaMonitorAutoForwardRunner();
```

Dispose it:

```dart
_mengxiaAutoForwardRunner.dispose();
```

- [ ] **Step 4: Run the page test to verify GREEN**

Run:

```powershell
cd C:\Users\COLORFUL\Desktop\WuKong
flutter test test/modules/mengxia_monitor/mengxia_monitor_center_page_test.dart -r compact
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/modules/mengxia_monitor lib/app/app.dart test/modules/mengxia_monitor/mengxia_monitor_center_page_test.dart
git commit -m "feat: add mengxia center page and runtime placeholders"
```

### Task 8: Add Focused Cross-Provider Verification

**Files:**
- Verify: `test/modules/vip/vip_management_page_test.dart`
- Verify: `test/modules/monitor_center/monitor_center_page_scaffold_test.dart`
- Verify: `test/modules/feishu_monitor/feishu_monitor_center_page_test.dart`
- Verify: `test/modules/mengxia_monitor/*.dart`
- Verify: `tools/mengxia_monitor_shell_app/test/*.dart`

- [ ] **Step 1: Run focused app-side tests**

Run:

```powershell
cd C:\Users\COLORFUL\Desktop\WuKong
flutter test test/modules/vip/vip_management_page_test.dart test/modules/monitor_center/monitor_center_page_scaffold_test.dart test/modules/feishu_monitor/feishu_monitor_center_page_test.dart test/modules/mengxia_monitor -r compact
```

Expected: PASS.

- [ ] **Step 2: Run focused app-side analyze**

Run:

```powershell
cd C:\Users\COLORFUL\Desktop\WuKong
flutter analyze lib/modules/vip lib/modules/monitor_center lib/modules/feishu_monitor lib/modules/mengxia_monitor lib/app/app.dart test/modules/vip test/modules/monitor_center test/modules/mengxia_monitor
```

Expected: PASS.

- [ ] **Step 3: Run Mengxia shell tests**

Run:

```powershell
cd C:\Users\COLORFUL\Desktop\WuKong\tools\mengxia_monitor_shell_app
flutter test test -r compact
flutter analyze lib test
```

Expected: PASS.

- [ ] **Step 4: Build the Mengxia shell release binary**

Run:

```powershell
cd C:\Users\COLORFUL\Desktop\WuKong\tools\mengxia_monitor_shell_app
flutter build windows --release
```

Expected: PASS and a Windows build artifact is produced.

- [ ] **Step 5: Manual verification**

Perform and record:

```text
1. Open 系统管理 and confirm Feishu + Mengxia cards both show.
2. Open 萌侠信息转发中心 and confirm manual-login guidance is visible.
3. Start the Mengxia shell and manually log in.
4. Observe at least one source conversation.
5. Configure one route from a Mengxia source conversation to a WuKong target group.
6. Send a message in Mengxia and confirm it reaches the target WuKong group.
7. Stop the Mengxia shell completely.
8. Relaunch and confirm manual login is required again.
```

- [ ] **Step 6: Commit**

```bash
git add docs/superpowers/plans/2026-05-15-mengxia-monitor-center-parallel-entry.md
git commit -m "docs: add mengxia monitor center implementation plan"
```

# Feishu Monitor Center MVP Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the first product-facing slice for “飞书信息监控中心” inside the management system, with a platform-specific Feishu entry, reusable Monitor models/API surface, and a Feishu Web group → Wukong IM group rule management UI.

**Architecture:** The user-facing management system shows separate platform centers, starting with Feishu. Under the UI, all data uses reusable Monitor abstractions: agents, routes, groups, logs, and pairing codes. This plan creates the control-plane UI/API contracts; the Windows Playwright Agent runtime is a later plan.

**Tech Stack:** Flutter/Dart, Riverpod-compatible callback injection, Dio, existing `WKSubPageScaffold`, existing `ApiClient`, existing `GroupApi`, `flutter_test`, and fake `HttpClientAdapter` API tests.

---

## Scope

This plan implements the management/control-plane MVP:

- 管理系统 shows platform-specific cards:
  - 飞书信息监控中心
  - 钉钉信息监控中心
  - 小鹅通信息监控中心
- 飞书信息监控中心 supports:
  - Stats cards
  - Agent onboarding and pairing-code display
  - Rule list
  - Agent card
  - Recent logs
  - New rule dialog for 飞书 Web 群 → 悟空 IM 群
- Shared monitor API/model layer uses generic naming for future DingTalk/Xiaoetong reuse.

This plan does **not** build the Windows Agent, Playwright browser watcher, local SQLite queue, or real IM forwarding worker.

## File structure

- Create: `lib/modules/monitor/monitor_models.dart`
  - Reusable monitor enums and immutable models.
  - Parse API payloads for agents, routes, logs, stats, pairing codes, and selectable IM groups.
  - Serialize Feishu route creation requests.

- Create: `lib/service/api/monitor_api.dart`
  - `/v1/monitor/*` HTTP client.
  - Response normalization matching existing API client style.

- Create: `lib/modules/monitor/monitor_repository.dart`
  - UI-facing repository over `MonitorApi` and `GroupApi`.

- Create: `lib/modules/monitor/feishu_monitor_center_page.dart`
  - Feishu information monitor center UI.

- Modify: `lib/modules/vip/vip_management_page.dart`
  - Replace placeholder with management-system platform cards.

- Create: `test/modules/monitor/monitor_models_test.dart`
- Create: `test/service/api/monitor_api_test.dart`
- Create: `test/modules/monitor/feishu_monitor_center_page_test.dart`
- Create or modify: `test/modules/vip/vip_management_page_test.dart`
- Modify if needed: `test/modules/user/user_page_parity_test.dart`

---

### Task 1: Add reusable Monitor domain models

**Files:**
- Create: `lib/modules/monitor/monitor_models.dart`
- Create: `test/modules/monitor/monitor_models_test.dart`

- [ ] **Step 1: Write failing model tests**

Create `test/modules/monitor/monitor_models_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/modules/monitor/monitor_models.dart';

void main() {
  group('monitor models', () {
    test('MonitorRoute parses Feishu Web group route and exposes labels', () {
      final route = MonitorRoute.fromJson(const <String, dynamic>{
        'id': 'route_1',
        'platform': 'feishu',
        'connector_type': 'feishu_web_group',
        'route_type': 'feishu_web_group_to_wukong_im_group',
        'source_name': '飞书新闻群',
        'destination_name': '悟空 IM 新闻群',
        'status': 'running',
        'today_forwarded_count': 28,
        'last_forwarded_at': '2026-05-06 16:32',
        'agent_id': 'agent_1',
        'include_text': true,
        'include_links': true,
        'include_images': false,
        'include_files': false,
      });

      expect(route.id, 'route_1');
      expect(route.platform, MonitorPlatform.feishu);
      expect(route.connectorType, MonitorConnectorType.feishuWebGroup);
      expect(route.status, MonitorRouteStatus.running);
      expect(route.statusLabel, '运行中');
      expect(route.title, '飞书新闻群 → 悟空 IM 新闻群');
      expect(route.sourceTypeLabel, '飞书 Web 群');
      expect(route.todayForwardedCount, 28);
      expect(route.lastForwardedAt, '2026-05-06 16:32');
      expect(route.includeText, isTrue);
      expect(route.includeLinks, isTrue);
      expect(route.includeImages, isFalse);
      expect(route.includeFiles, isFalse);
    });

    test('MonitorAgent parses status and exposes display labels', () {
      final agent = MonitorAgent.fromJson(const <String, dynamic>{
        'id': 'agent_1',
        'device_name': 'COLORFUL-PC',
        'platform': 'windows',
        'version': '0.1.0',
        'status': 'online',
        'last_heartbeat_at': '刚刚',
      });

      expect(agent.id, 'agent_1');
      expect(agent.deviceName, 'COLORFUL-PC');
      expect(agent.platformLabel, 'Windows');
      expect(agent.status, MonitorAgentStatus.online);
      expect(agent.statusLabel, '在线');
      expect(agent.lastHeartbeatAt, '刚刚');
    });

    test('MonitorStats tolerates missing payload values', () {
      final stats = MonitorStats.fromJson(const <String, dynamic>{});

      expect(stats.runningRoutes, 0);
      expect(stats.todayForwarded, 0);
      expect(stats.alerts, 0);
    });

    test('CreateFeishuMonitorRouteRequest serializes backend contract', () {
      const request = CreateFeishuMonitorRouteRequest(
        sourceChatName: '飞书新闻群',
        destinationGroupNo: 'group_1',
        destinationGroupName: '悟空 IM 新闻群',
        includeText: true,
        includeLinks: true,
        includeImages: false,
        includeFiles: false,
      );

      expect(request.toJson(), <String, dynamic>{
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
    });

    test('MonitorLogEntry uses readable fallback text', () {
      final log = MonitorLogEntry.fromJson(const <String, dynamic>{
        'id': 'log_1',
        'type': 'forwarded',
        'occurred_at': '16:32',
        'message': '已转发 飞书新闻群 → 悟空 IM 新闻群',
      });

      expect(log.id, 'log_1');
      expect(log.occurredAt, '16:32');
      expect(log.message, '已转发 飞书新闻群 → 悟空 IM 新闻群');
    });
  });
}
```

- [ ] **Step 2: Run tests and confirm red**

Run:

```powershell
flutter test test/modules/monitor/monitor_models_test.dart
```

Expected: FAIL because `monitor_models.dart` does not exist.

- [ ] **Step 3: Implement monitor models**

Create `lib/modules/monitor/monitor_models.dart`:

```dart
enum MonitorPlatform {
  feishu,
  dingtalk,
  xiaoe,
  unknown;

  String get apiValue {
    switch (this) {
      case MonitorPlatform.feishu:
        return 'feishu';
      case MonitorPlatform.dingtalk:
        return 'dingtalk';
      case MonitorPlatform.xiaoe:
        return 'xiaoe';
      case MonitorPlatform.unknown:
        return 'unknown';
    }
  }

  String get label {
    switch (this) {
      case MonitorPlatform.feishu:
        return '飞书';
      case MonitorPlatform.dingtalk:
        return '钉钉';
      case MonitorPlatform.xiaoe:
        return '小鹅通';
      case MonitorPlatform.unknown:
        return '未知平台';
    }
  }

  static MonitorPlatform parse(dynamic value) {
    switch (_toString(value)) {
      case 'feishu':
        return MonitorPlatform.feishu;
      case 'dingtalk':
        return MonitorPlatform.dingtalk;
      case 'xiaoe':
      case 'xiaoetong':
        return MonitorPlatform.xiaoe;
      default:
        return MonitorPlatform.unknown;
    }
  }
}

enum MonitorConnectorType {
  feishuWebGroup,
  dingtalkWebGroup,
  xiaoeWeb,
  unknown;

  String get apiValue {
    switch (this) {
      case MonitorConnectorType.feishuWebGroup:
        return 'feishu_web_group';
      case MonitorConnectorType.dingtalkWebGroup:
        return 'dingtalk_web_group';
      case MonitorConnectorType.xiaoeWeb:
        return 'xiaoe_web';
      case MonitorConnectorType.unknown:
        return 'unknown';
    }
  }

  String get label {
    switch (this) {
      case MonitorConnectorType.feishuWebGroup:
        return '飞书 Web 群';
      case MonitorConnectorType.dingtalkWebGroup:
        return '钉钉 Web 群';
      case MonitorConnectorType.xiaoeWeb:
        return '小鹅通 Web';
      case MonitorConnectorType.unknown:
        return '未知来源';
    }
  }

  static MonitorConnectorType parse(dynamic value) {
    switch (_toString(value)) {
      case 'feishu_web_group':
        return MonitorConnectorType.feishuWebGroup;
      case 'dingtalk_web_group':
        return MonitorConnectorType.dingtalkWebGroup;
      case 'xiaoe_web':
      case 'xiaoetong_web':
        return MonitorConnectorType.xiaoeWeb;
      default:
        return MonitorConnectorType.unknown;
    }
  }
}

enum MonitorRouteStatus {
  running,
  paused,
  loginRequired,
  agentOffline,
  destinationError,
  selectorError,
  unknown;

  String get apiValue {
    switch (this) {
      case MonitorRouteStatus.running:
        return 'running';
      case MonitorRouteStatus.paused:
        return 'paused';
      case MonitorRouteStatus.loginRequired:
        return 'login_required';
      case MonitorRouteStatus.agentOffline:
        return 'agent_offline';
      case MonitorRouteStatus.destinationError:
        return 'destination_error';
      case MonitorRouteStatus.selectorError:
        return 'selector_error';
      case MonitorRouteStatus.unknown:
        return 'unknown';
    }
  }

  String get label {
    switch (this) {
      case MonitorRouteStatus.running:
        return '运行中';
      case MonitorRouteStatus.paused:
        return '已暂停';
      case MonitorRouteStatus.loginRequired:
        return '需要登录';
      case MonitorRouteStatus.agentOffline:
        return 'Agent 离线';
      case MonitorRouteStatus.destinationError:
        return '目标 IM 异常';
      case MonitorRouteStatus.selectorError:
        return '页面结构异常';
      case MonitorRouteStatus.unknown:
        return '未知状态';
    }
  }

  static MonitorRouteStatus parse(dynamic value) {
    switch (_toString(value)) {
      case 'running':
        return MonitorRouteStatus.running;
      case 'paused':
        return MonitorRouteStatus.paused;
      case 'login_required':
        return MonitorRouteStatus.loginRequired;
      case 'agent_offline':
        return MonitorRouteStatus.agentOffline;
      case 'destination_error':
        return MonitorRouteStatus.destinationError;
      case 'selector_error':
        return MonitorRouteStatus.selectorError;
      default:
        return MonitorRouteStatus.unknown;
    }
  }
}

enum MonitorAgentStatus {
  online,
  offline,
  loginRequired,
  unknown;

  String get label {
    switch (this) {
      case MonitorAgentStatus.online:
        return '在线';
      case MonitorAgentStatus.offline:
        return '离线';
      case MonitorAgentStatus.loginRequired:
        return '需要登录';
      case MonitorAgentStatus.unknown:
        return '未知状态';
    }
  }

  static MonitorAgentStatus parse(dynamic value) {
    switch (_toString(value)) {
      case 'online':
        return MonitorAgentStatus.online;
      case 'offline':
        return MonitorAgentStatus.offline;
      case 'login_required':
        return MonitorAgentStatus.loginRequired;
      default:
        return MonitorAgentStatus.unknown;
    }
  }
}

class MonitorStats {
  const MonitorStats({
    required this.runningRoutes,
    required this.todayForwarded,
    required this.alerts,
  });

  final int runningRoutes;
  final int todayForwarded;
  final int alerts;

  factory MonitorStats.fromJson(Map<String, dynamic> json) {
    return MonitorStats(
      runningRoutes: _toInt(json['running_routes']),
      todayForwarded: _toInt(json['today_forwarded']),
      alerts: _toInt(json['alerts']),
    );
  }

  static const empty = MonitorStats(
    runningRoutes: 0,
    todayForwarded: 0,
    alerts: 0,
  );
}

class MonitorAgent {
  const MonitorAgent({
    required this.id,
    required this.deviceName,
    required this.platform,
    required this.version,
    required this.status,
    required this.lastHeartbeatAt,
  });

  final String id;
  final String deviceName;
  final String platform;
  final String version;
  final MonitorAgentStatus status;
  final String lastHeartbeatAt;

  String get statusLabel => status.label;

  String get platformLabel {
    switch (platform.toLowerCase()) {
      case 'windows':
        return 'Windows';
      case 'macos':
        return 'macOS';
      case 'linux':
        return 'Linux';
      default:
        return platform.isEmpty ? '未知平台' : platform;
    }
  }

  factory MonitorAgent.fromJson(Map<String, dynamic> json) {
    return MonitorAgent(
      id: _toString(json['id'] ?? json['agent_id']),
      deviceName: _toString(json['device_name'], fallback: '未命名设备'),
      platform: _toString(json['platform'], fallback: 'unknown'),
      version: _toString(json['version'] ?? json['agent_version']),
      status: MonitorAgentStatus.parse(json['status']),
      lastHeartbeatAt: _toString(json['last_heartbeat_at']),
    );
  }
}

class MonitorRoute {
  const MonitorRoute({
    required this.id,
    required this.platform,
    required this.connectorType,
    required this.routeType,
    required this.sourceName,
    required this.destinationName,
    required this.status,
    required this.todayForwardedCount,
    required this.lastForwardedAt,
    required this.agentId,
    required this.includeText,
    required this.includeLinks,
    required this.includeImages,
    required this.includeFiles,
  });

  final String id;
  final MonitorPlatform platform;
  final MonitorConnectorType connectorType;
  final String routeType;
  final String sourceName;
  final String destinationName;
  final MonitorRouteStatus status;
  final int todayForwardedCount;
  final String lastForwardedAt;
  final String agentId;
  final bool includeText;
  final bool includeLinks;
  final bool includeImages;
  final bool includeFiles;

  String get title => '$sourceName → $destinationName';
  String get statusLabel => status.label;
  String get sourceTypeLabel => connectorType.label;

  factory MonitorRoute.fromJson(Map<String, dynamic> json) {
    return MonitorRoute(
      id: _toString(json['id'] ?? json['route_id']),
      platform: MonitorPlatform.parse(json['platform']),
      connectorType: MonitorConnectorType.parse(json['connector_type']),
      routeType: _toString(json['route_type']),
      sourceName: _toString(json['source_name'], fallback: '未命名来源'),
      destinationName: _toString(
        json['destination_name'],
        fallback: '未命名目标',
      ),
      status: MonitorRouteStatus.parse(json['status']),
      todayForwardedCount: _toInt(json['today_forwarded_count']),
      lastForwardedAt: _toString(json['last_forwarded_at']),
      agentId: _toString(json['agent_id']),
      includeText: _toBool(json['include_text'], fallback: true),
      includeLinks: _toBool(json['include_links'], fallback: true),
      includeImages: _toBool(json['include_images']),
      includeFiles: _toBool(json['include_files']),
    );
  }
}

class MonitorLogEntry {
  const MonitorLogEntry({
    required this.id,
    required this.type,
    required this.occurredAt,
    required this.message,
    this.routeId = '',
  });

  final String id;
  final String type;
  final String occurredAt;
  final String message;
  final String routeId;

  factory MonitorLogEntry.fromJson(Map<String, dynamic> json) {
    return MonitorLogEntry(
      id: _toString(json['id'] ?? json['event_id']),
      type: _toString(json['type']),
      occurredAt: _toString(json['occurred_at'] ?? json['created_at']),
      message: _toString(json['message'], fallback: '暂无详情'),
      routeId: _toString(json['route_id']),
    );
  }
}

class MonitorPairingCode {
  const MonitorPairingCode({required this.code, required this.expiresAt});

  final String code;
  final String expiresAt;

  factory MonitorPairingCode.fromJson(Map<String, dynamic> json) {
    return MonitorPairingCode(
      code: _toString(json['pairing_code'] ?? json['pairingCode']),
      expiresAt: _toString(json['expires_at'] ?? json['expiresAt']),
    );
  }
}

class MonitorSelectableGroup {
  const MonitorSelectableGroup({required this.groupNo, required this.name});

  final String groupNo;
  final String name;

  String get label => name.isEmpty ? groupNo : name;
}

class FeishuMonitorSnapshot {
  const FeishuMonitorSnapshot({
    required this.stats,
    required this.agents,
    required this.routes,
    required this.logs,
  });

  final MonitorStats stats;
  final List<MonitorAgent> agents;
  final List<MonitorRoute> routes;
  final List<MonitorLogEntry> logs;

  bool get hasAgent => agents.isNotEmpty;

  static const empty = FeishuMonitorSnapshot(
    stats: MonitorStats.empty,
    agents: <MonitorAgent>[],
    routes: <MonitorRoute>[],
    logs: <MonitorLogEntry>[],
  );
}

class CreateFeishuMonitorRouteRequest {
  const CreateFeishuMonitorRouteRequest({
    required this.sourceChatName,
    required this.destinationGroupNo,
    required this.destinationGroupName,
    this.includeText = true,
    this.includeLinks = true,
    this.includeImages = false,
    this.includeFiles = false,
  });

  final String sourceChatName;
  final String destinationGroupNo;
  final String destinationGroupName;
  final bool includeText;
  final bool includeLinks;
  final bool includeImages;
  final bool includeFiles;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'platform': MonitorPlatform.feishu.apiValue,
      'connector_type': MonitorConnectorType.feishuWebGroup.apiValue,
      'route_type': 'feishu_web_group_to_wukong_im_group',
      'source': <String, dynamic>{'chat_name': sourceChatName.trim()},
      'destination': <String, dynamic>{
        'type': 'wukong_im_group',
        'group_no': destinationGroupNo.trim(),
        'group_name': destinationGroupName.trim(),
      },
      'message_policy': <String, dynamic>{
        'include_text': includeText,
        'include_links': includeLinks,
        'include_images': includeImages,
        'include_files': includeFiles,
      },
    };
  }
}

int _toInt(dynamic value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

bool _toBool(dynamic value, {bool fallback = false}) {
  if (value is bool) {
    return value;
  }
  if (value is num) {
    return value != 0;
  }
  final normalized = value?.toString().trim().toLowerCase() ?? '';
  if (normalized == 'true' || normalized == '1') {
    return true;
  }
  if (normalized == 'false' || normalized == '0') {
    return false;
  }
  return fallback;
}

String _toString(dynamic value, {String fallback = ''}) {
  final normalized = value?.toString().trim() ?? '';
  return normalized.isEmpty ? fallback : normalized;
}
```

- [ ] **Step 4: Run model tests and confirm green**

Run:

```powershell
flutter test test/modules/monitor/monitor_models_test.dart
```

Expected: PASS.

- [ ] **Step 5: Commit**

```powershell
git add lib/modules/monitor/monitor_models.dart test/modules/monitor/monitor_models_test.dart
git commit -m "feat: add monitor domain models"
```

---

### Task 2: Add Monitor API client

**Files:**
- Create: `lib/service/api/monitor_api.dart`
- Create: `test/service/api/monitor_api_test.dart`

- [ ] **Step 1: Write failing API tests**

Create `test/service/api/monitor_api_test.dart`:

```dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/modules/monitor/monitor_models.dart';
import 'package:wukong_im_app/service/api/api_client.dart';
import 'package:wukong_im_app/service/api/monitor_api.dart';

void main() {
  late HttpClientAdapter originalAdapter;
  late _MonitorApiAdapter adapter;

  setUp(() {
    originalAdapter = ApiClient.instance.dio.httpClientAdapter;
    adapter = _MonitorApiAdapter();
    ApiClient.instance.dio.httpClientAdapter = adapter;
  });

  tearDown(() {
    ApiClient.instance.dio.httpClientAdapter = originalAdapter;
  });

  test('fetchStats calls Feishu stats endpoint', () async {
    adapter.payload = const <String, dynamic>{
      'code': 0,
      'data': <String, dynamic>{
        'running_routes': 1,
        'today_forwarded': 28,
        'alerts': 0,
      },
    };

    final stats = await MonitorApi.instance.fetchStats(
      platform: MonitorPlatform.feishu,
    );

    expect(adapter.lastMethod, 'GET');
    expect(adapter.lastPath, '/v1/monitor/platforms/feishu/stats');
    expect(stats.runningRoutes, 1);
    expect(stats.todayForwarded, 28);
    expect(stats.alerts, 0);
  });

  test('fetchRoutes maps route list payload', () async {
    adapter.payload = const <String, dynamic>{
      'code': 0,
      'data': <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'route_1',
          'platform': 'feishu',
          'connector_type': 'feishu_web_group',
          'route_type': 'feishu_web_group_to_wukong_im_group',
          'source_name': '飞书新闻群',
          'destination_name': '悟空 IM 新闻群',
          'status': 'running',
        },
      ],
    };

    final routes = await MonitorApi.instance.fetchRoutes(
      platform: MonitorPlatform.feishu,
    );

    expect(adapter.lastPath, '/v1/monitor/routes');
    expect(adapter.lastQueryParameters, <String, dynamic>{'platform': 'feishu'});
    expect(routes.single.id, 'route_1');
    expect(routes.single.sourceName, '飞书新闻群');
  });

  test('createFeishuRoute posts serialized route request', () async {
    adapter.payload = const <String, dynamic>{
      'code': 0,
      'data': <String, dynamic>{
        'id': 'route_1',
        'platform': 'feishu',
        'connector_type': 'feishu_web_group',
        'route_type': 'feishu_web_group_to_wukong_im_group',
        'source_name': '飞书新闻群',
        'destination_name': '悟空 IM 新闻群',
        'status': 'paused',
      },
    };

    final route = await MonitorApi.instance.createFeishuRoute(
      const CreateFeishuMonitorRouteRequest(
        sourceChatName: '飞书新闻群',
        destinationGroupNo: 'group_1',
        destinationGroupName: '悟空 IM 新闻群',
      ),
    );

    expect(adapter.lastMethod, 'POST');
    expect(adapter.lastPath, '/v1/monitor/routes');
    expect(adapter.lastBody, containsPair('platform', 'feishu'));
    expect(route.id, 'route_1');
    expect(route.status, MonitorRouteStatus.paused);
  });

  test('createPairingCode posts device name and parses code', () async {
    adapter.payload = const <String, dynamic>{
      'code': 0,
      'data': <String, dynamic>{
        'pairing_code': 'ABCD-1234',
        'expires_at': '2026-05-06 18:00',
      },
    };

    final code = await MonitorApi.instance.createPairingCode('COLORFUL-PC');

    expect(adapter.lastMethod, 'POST');
    expect(adapter.lastPath, '/v1/monitor/agent-pairing-codes');
    expect(adapter.lastBody, <String, dynamic>{'device_name': 'COLORFUL-PC'});
    expect(code.code, 'ABCD-1234');
    expect(code.expiresAt, '2026-05-06 18:00');
  });
}

class _MonitorApiAdapter implements HttpClientAdapter {
  Object payload = const <String, dynamic>{'code': 0, 'data': null};
  String? lastMethod;
  String? lastPath;
  Map<String, dynamic>? lastQueryParameters;
  dynamic lastBody;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastMethod = options.method;
    lastPath = options.path;
    lastQueryParameters = Map<String, dynamic>.from(options.queryParameters);
    lastBody = options.data;
    return ResponseBody.fromString(
      jsonEncode(payload),
      200,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>[Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
```

- [ ] **Step 2: Run tests and confirm red**

```powershell
flutter test test/service/api/monitor_api_test.dart
```

Expected: FAIL because `monitor_api.dart` does not exist.

- [ ] **Step 3: Implement MonitorApi**

Create `lib/service/api/monitor_api.dart`:

```dart
import 'dart:convert';

import 'package:dio/dio.dart';

import '../../modules/monitor/monitor_models.dart';
import 'api_client.dart';

class MonitorApi {
  MonitorApi._();

  static final MonitorApi _instance = MonitorApi._();
  static MonitorApi get instance => _instance;

  final ApiClient _client = ApiClient.instance;
  final Options _plainTextOptions = Options(responseType: ResponseType.plain);

  Future<MonitorStats> fetchStats({required MonitorPlatform platform}) async {
    final response = await _client.get(
      '/v1/monitor/platforms/${platform.apiValue}/stats',
      options: _plainTextOptions,
    );
    return MonitorStats.fromJson(_resolveObjectPayload(response.data));
  }

  Future<List<MonitorAgent>> fetchAgents({MonitorPlatform? platform}) async {
    final response = await _client.get(
      '/v1/monitor/agents',
      queryParameters: platform == null
          ? null
          : <String, dynamic>{'platform': platform.apiValue},
      options: _plainTextOptions,
    );
    return _resolveListPayload(response.data)
        .map(_normalizeMap)
        .map(MonitorAgent.fromJson)
        .toList(growable: false);
  }

  Future<List<MonitorRoute>> fetchRoutes({MonitorPlatform? platform}) async {
    final response = await _client.get(
      '/v1/monitor/routes',
      queryParameters: platform == null
          ? null
          : <String, dynamic>{'platform': platform.apiValue},
      options: _plainTextOptions,
    );
    return _resolveListPayload(response.data)
        .map(_normalizeMap)
        .map(MonitorRoute.fromJson)
        .toList(growable: false);
  }

  Future<List<MonitorLogEntry>> fetchLogs({
    MonitorPlatform? platform,
    int limit = 20,
  }) async {
    final response = await _client.get(
      '/v1/monitor/events',
      queryParameters: <String, dynamic>{
        if (platform != null) 'platform': platform.apiValue,
        'limit': limit,
      },
      options: _plainTextOptions,
    );
    return _resolveListPayload(response.data)
        .map(_normalizeMap)
        .map(MonitorLogEntry.fromJson)
        .toList(growable: false);
  }

  Future<MonitorRoute> createFeishuRoute(
    CreateFeishuMonitorRouteRequest request,
  ) async {
    final response = await _client.post(
      '/v1/monitor/routes',
      data: request.toJson(),
      options: _plainTextOptions,
    );
    return MonitorRoute.fromJson(_resolveObjectPayload(response.data));
  }

  Future<void> updateRouteStatus({
    required String routeId,
    required MonitorRouteStatus status,
  }) async {
    final response = await _client.put(
      '/v1/monitor/routes/${routeId.trim()}/status',
      data: <String, dynamic>{'status': status.apiValue},
      options: _plainTextOptions,
    );
    _ensureSuccess(response, fallback: 'update monitor route status failed');
  }

  Future<MonitorPairingCode> createPairingCode(String deviceName) async {
    final response = await _client.post(
      '/v1/monitor/agent-pairing-codes',
      data: <String, dynamic>{'device_name': deviceName.trim()},
      options: _plainTextOptions,
    );
    return MonitorPairingCode.fromJson(_resolveObjectPayload(response.data));
  }

  Map<String, dynamic> _resolveObjectPayload(dynamic rawData) {
    final body = _normalizeBody(rawData);
    final data = body['data'];
    if (data == null) {
      return body;
    }
    if (data is Map<String, dynamic>) {
      return data;
    }
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }
    throw const FormatException('Response data payload must be a JSON object.');
  }

  List<dynamic> _resolveListPayload(dynamic rawData) {
    final body = _normalizeBody(rawData);
    final data = body['data'];
    if (data == null) {
      return body is List ? body as List<dynamic> : const <dynamic>[];
    }
    if (data is List) {
      return data;
    }
    throw const FormatException('Response data payload must be a JSON array.');
  }

  Map<String, dynamic> _normalizeBody(dynamic rawData) {
    if (rawData == null) {
      throw const FormatException('Response payload is empty.');
    }
    if (rawData is String) {
      final body = rawData.trim();
      if (body.isEmpty) {
        throw const FormatException('Response payload is empty.');
      }
      final decoded = jsonDecode(body);
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
      if (decoded is List) {
        return <String, dynamic>{'data': decoded};
      }
      throw const FormatException('Response payload must be valid JSON.');
    }
    if (rawData is Map<String, dynamic>) {
      return rawData;
    }
    if (rawData is Map) {
      return Map<String, dynamic>.from(rawData);
    }
    if (rawData is List) {
      return <String, dynamic>{'data': rawData};
    }
    throw FormatException(
      'Unsupported response payload type: ${rawData.runtimeType}.',
    );
  }

  Map<String, dynamic> _normalizeMap(dynamic rawData) {
    if (rawData is Map<String, dynamic>) {
      return rawData;
    }
    if (rawData is Map) {
      return Map<String, dynamic>.from(rawData);
    }
    throw const FormatException('Response item must be a JSON object.');
  }

  void _ensureSuccess(Response<dynamic> response, {required String fallback}) {
    final body = _normalizeBody(response.data);
    final statusCode = response.statusCode ?? 200;
    final code = body['code'];
    final status = body['status'];
    final message = (body['msg'] ?? body['message'] ?? fallback).toString();
    final hasErrorCode =
        (code is num && code.toInt() != 0) ||
        (status is num && status.toInt() >= 400);
    if (statusCode >= 400 || hasErrorCode) {
      throw Exception(message);
    }
  }
}
```

- [ ] **Step 4: Run API tests and confirm green**

```powershell
flutter test test/service/api/monitor_api_test.dart
```

Expected: PASS.

- [ ] **Step 5: Commit**

```powershell
git add lib/service/api/monitor_api.dart test/service/api/monitor_api_test.dart
git commit -m "feat: add monitor api client"
```

---

### Task 3: Add Monitor repository abstraction

**Files:**
- Create: `lib/modules/monitor/monitor_repository.dart`

- [ ] **Step 1: Create repository**

Create `lib/modules/monitor/monitor_repository.dart`:

```dart
import '../../data/models/group.dart';
import '../../service/api/group_api.dart';
import '../../service/api/monitor_api.dart';
import 'monitor_models.dart';

class MonitorRepository {
  MonitorRepository({MonitorApi? api, GroupApi? groupApi})
    : _api = api ?? MonitorApi.instance,
      _groupApi = groupApi ?? GroupApi.instance;

  final MonitorApi _api;
  final GroupApi _groupApi;

  Future<FeishuMonitorSnapshot> loadFeishuSnapshot() async {
    final results = await Future.wait<dynamic>(<Future<dynamic>>[
      _api.fetchStats(platform: MonitorPlatform.feishu),
      _api.fetchAgents(platform: MonitorPlatform.feishu),
      _api.fetchRoutes(platform: MonitorPlatform.feishu),
      _api.fetchLogs(platform: MonitorPlatform.feishu, limit: 20),
    ]);

    return FeishuMonitorSnapshot(
      stats: results[0] as MonitorStats,
      agents: List<MonitorAgent>.unmodifiable(results[1] as List<MonitorAgent>),
      routes: List<MonitorRoute>.unmodifiable(results[2] as List<MonitorRoute>),
      logs: List<MonitorLogEntry>.unmodifiable(
        results[3] as List<MonitorLogEntry>,
      ),
    );
  }

  Future<List<MonitorSelectableGroup>> loadDestinationGroups() async {
    final groups = await _groupApi.getMyGroups();
    return groups.map(_mapGroup).toList(growable: false);
  }

  Future<MonitorPairingCode> createPairingCode(String deviceName) {
    return _api.createPairingCode(deviceName);
  }

  Future<MonitorRoute> createFeishuRoute(
    CreateFeishuMonitorRouteRequest request,
  ) {
    return _api.createFeishuRoute(request);
  }

  Future<void> pauseRoute(String routeId) {
    return _api.updateRouteStatus(
      routeId: routeId,
      status: MonitorRouteStatus.paused,
    );
  }

  Future<void> resumeRoute(String routeId) {
    return _api.updateRouteStatus(
      routeId: routeId,
      status: MonitorRouteStatus.running,
    );
  }

  MonitorSelectableGroup _mapGroup(GroupInfo group) {
    return MonitorSelectableGroup(
      groupNo: group.groupNo,
      name: (group.name ?? '').trim(),
    );
  }
}
```

- [ ] **Step 2: Analyze repository**

```powershell
flutter analyze lib/modules/monitor/monitor_repository.dart
```

Expected: no issues.

- [ ] **Step 3: Commit**

```powershell
git add lib/modules/monitor/monitor_repository.dart
git commit -m "feat: add monitor repository"
```

---

### Task 4: Build Feishu monitor center page UI

**Files:**
- Create: `lib/modules/monitor/feishu_monitor_center_page.dart`
- Create: `test/modules/monitor/feishu_monitor_center_page_test.dart`

- [ ] **Step 1: Write failing widget tests**

Create `test/modules/monitor/feishu_monitor_center_page_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/modules/monitor/feishu_monitor_center_page.dart';
import 'package:wukong_im_app/modules/monitor/monitor_models.dart';

void main() {
  testWidgets('Feishu center renders stats, route, agent, and logs', (
    tester,
  ) async {
    var downloadTapCount = 0;
    var pauseTapCount = 0;
    var logTapCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: FeishuMonitorCenterPage(
          loadSnapshot: () async => _snapshotWithData,
          loadDestinationGroups: () async => const <MonitorSelectableGroup>[],
          onDownloadAgent: () => downloadTapCount++,
          onPauseRoute: (_) async => pauseTapCount++,
          onResumeRoute: (_) async {},
          onViewRouteLogs: (_) => logTapCount++,
          onCreatePairingCode: (_) async => const MonitorPairingCode(
            code: 'ABCD-1234',
            expiresAt: '2026-05-06 18:00',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('飞书信息监控中心'), findsWidgets);
    expect(find.text('运行中规则'), findsOneWidget);
    expect(find.text('今日转发'), findsOneWidget);
    expect(find.text('28'), findsOneWidget);
    expect(find.text('异常提醒'), findsOneWidget);
    expect(find.text('飞书新闻群 → 悟空 IM 新闻群'), findsOneWidget);
    expect(find.text('来源：飞书 Web 群'), findsOneWidget);
    expect(find.text('状态：运行中'), findsOneWidget);
    expect(find.text('COLORFUL-PC'), findsOneWidget);
    expect(find.text('16:32 已转发 飞书新闻群 → 悟空 IM 新闻群'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('feishu-monitor-download-agent')));
    await tester.pump();
    expect(downloadTapCount, 1);

    await tester.tap(find.byKey(const ValueKey('monitor-route-pause-route_1')));
    await tester.pump();
    expect(pauseTapCount, 1);

    await tester.tap(find.byKey(const ValueKey('monitor-route-logs-route_1')));
    await tester.pump();
    expect(logTapCount, 1);
  });

  testWidgets('Feishu center shows agent onboarding and pairing code', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: FeishuMonitorCenterPage(
          loadSnapshot: () async => FeishuMonitorSnapshot.empty,
          loadDestinationGroups: () async => const <MonitorSelectableGroup>[],
          onDownloadAgent: () {},
          onPauseRoute: (_) async {},
          onResumeRoute: (_) async {},
          onViewRouteLogs: (_) {},
          onCreatePairingCode: (_) async => const MonitorPairingCode(
            code: 'ABCD-1234',
            expiresAt: '2026-05-06 18:00',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('还没有绑定 Windows Agent'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('feishu-monitor-create-pairing')));
    await tester.pumpAndSettle();

    expect(find.text('配对码：ABCD-1234'), findsOneWidget);
    expect(find.text('有效期至：2026-05-06 18:00'), findsOneWidget);
  });

  testWidgets('Feishu center creates route from dialog input', (tester) async {
    CreateFeishuMonitorRouteRequest? created;

    await tester.pumpWidget(
      MaterialApp(
        home: FeishuMonitorCenterPage(
          loadSnapshot: () async => const FeishuMonitorSnapshot(
            stats: MonitorStats.empty,
            agents: <MonitorAgent>[
              MonitorAgent(
                id: 'agent_1',
                deviceName: 'COLORFUL-PC',
                platform: 'windows',
                version: '0.1.0',
                status: MonitorAgentStatus.online,
                lastHeartbeatAt: '刚刚',
              ),
            ],
            routes: <MonitorRoute>[],
            logs: <MonitorLogEntry>[],
          ),
          loadDestinationGroups: () async => const <MonitorSelectableGroup>[
            MonitorSelectableGroup(groupNo: 'group_1', name: '悟空 IM 新闻群'),
          ],
          onDownloadAgent: () {},
          onPauseRoute: (_) async {},
          onResumeRoute: (_) async {},
          onViewRouteLogs: (_) {},
          onCreatePairingCode: (_) async => const MonitorPairingCode(
            code: 'ABCD-1234',
            expiresAt: '2026-05-06 18:00',
          ),
          onCreateRoute: (request) async {
            created = request;
            return MonitorRoute.fromJson(const <String, dynamic>{
              'id': 'route_created',
              'platform': 'feishu',
              'connector_type': 'feishu_web_group',
              'route_type': 'feishu_web_group_to_wukong_im_group',
              'source_name': '飞书新闻群',
              'destination_name': '悟空 IM 新闻群',
              'status': 'paused',
            });
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('feishu-monitor-new-route')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('feishu-route-source-chat-input')),
      '飞书新闻群',
    );
    await tester.tap(find.text('悟空 IM 新闻群'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('feishu-route-submit')));
    await tester.pumpAndSettle();

    expect(created, isNotNull);
    expect(created!.sourceChatName, '飞书新闻群');
    expect(created!.destinationGroupNo, 'group_1');
    expect(created!.destinationGroupName, '悟空 IM 新闻群');
    expect(created!.includeText, isTrue);
    expect(created!.includeLinks, isTrue);
    expect(created!.includeImages, isFalse);
    expect(created!.includeFiles, isFalse);
  });
}

const _snapshotWithData = FeishuMonitorSnapshot(
  stats: MonitorStats(runningRoutes: 1, todayForwarded: 28, alerts: 0),
  agents: <MonitorAgent>[
    MonitorAgent(
      id: 'agent_1',
      deviceName: 'COLORFUL-PC',
      platform: 'windows',
      version: '0.1.0',
      status: MonitorAgentStatus.online,
      lastHeartbeatAt: '刚刚',
    ),
  ],
  routes: <MonitorRoute>[
    MonitorRoute(
      id: 'route_1',
      platform: MonitorPlatform.feishu,
      connectorType: MonitorConnectorType.feishuWebGroup,
      routeType: 'feishu_web_group_to_wukong_im_group',
      sourceName: '飞书新闻群',
      destinationName: '悟空 IM 新闻群',
      status: MonitorRouteStatus.running,
      todayForwardedCount: 28,
      lastForwardedAt: '2026-05-06 16:32',
      agentId: 'agent_1',
      includeText: true,
      includeLinks: true,
      includeImages: false,
      includeFiles: false,
    ),
  ],
  logs: <MonitorLogEntry>[
    MonitorLogEntry(
      id: 'log_1',
      type: 'forwarded',
      occurredAt: '16:32',
      message: '已转发 飞书新闻群 → 悟空 IM 新闻群',
    ),
  ],
);
```

- [ ] **Step 2: Run tests and confirm red**

```powershell
flutter test test/modules/monitor/feishu_monitor_center_page_test.dart
```

Expected: FAIL because the page does not exist.

- [ ] **Step 3: Implement the page**

Create `lib/modules/monitor/feishu_monitor_center_page.dart`. Keep the file focused:

```dart
import 'package:flutter/material.dart';

import '../../widgets/wk_colors.dart';
import '../../widgets/wk_design_tokens.dart';
import '../../widgets/wk_sub_page_scaffold.dart';
import 'monitor_models.dart';
import 'monitor_repository.dart';

typedef FeishuSnapshotLoader = Future<FeishuMonitorSnapshot> Function();
typedef MonitorGroupsLoader = Future<List<MonitorSelectableGroup>> Function();
typedef PairingCodeCreator = Future<MonitorPairingCode> Function(
  String deviceName,
);
typedef FeishuRouteCreator = Future<MonitorRoute> Function(
  CreateFeishuMonitorRouteRequest request,
);
typedef MonitorRouteAction = Future<void> Function(String routeId);
typedef MonitorRouteCallback = void Function(String routeId);

class FeishuMonitorCenterPage extends StatefulWidget {
  FeishuMonitorCenterPage({
    super.key,
    MonitorRepository? repository,
    this.loadSnapshot,
    this.loadDestinationGroups,
    this.onCreatePairingCode,
    this.onCreateRoute,
    this.onPauseRoute,
    this.onResumeRoute,
    this.onViewRouteLogs,
    this.onDownloadAgent,
  }) : _repository = repository ?? MonitorRepository();

  final MonitorRepository _repository;
  final FeishuSnapshotLoader? loadSnapshot;
  final MonitorGroupsLoader? loadDestinationGroups;
  final PairingCodeCreator? onCreatePairingCode;
  final FeishuRouteCreator? onCreateRoute;
  final MonitorRouteAction? onPauseRoute;
  final MonitorRouteAction? onResumeRoute;
  final MonitorRouteCallback? onViewRouteLogs;
  final VoidCallback? onDownloadAgent;

  @override
  State<FeishuMonitorCenterPage> createState() =>
      _FeishuMonitorCenterPageState();
}

class _FeishuMonitorCenterPageState extends State<FeishuMonitorCenterPage> {
  late Future<FeishuMonitorSnapshot> _snapshotFuture;
  MonitorPairingCode? _pairingCode;
  bool _isCreatingPairingCode = false;

  @override
  void initState() {
    super.initState();
    _snapshotFuture = _loadSnapshot();
  }

  Future<FeishuMonitorSnapshot> _loadSnapshot() {
    return widget.loadSnapshot?.call() ?? widget._repository.loadFeishuSnapshot();
  }

  Future<List<MonitorSelectableGroup>> _loadDestinationGroups() {
    return widget.loadDestinationGroups?.call() ??
        widget._repository.loadDestinationGroups();
  }

  Future<void> _refresh() async {
    setState(() => _snapshotFuture = _loadSnapshot());
    await _snapshotFuture;
  }

  Future<void> _createPairingCode() async {
    if (_isCreatingPairingCode) {
      return;
    }
    setState(() => _isCreatingPairingCode = true);
    try {
      final creator =
          widget.onCreatePairingCode ?? widget._repository.createPairingCode;
      final code = await creator('Windows Agent');
      if (mounted) {
        setState(() => _pairingCode = code);
      }
    } catch (error) {
      if (mounted) {
        _showSnackBar('生成配对码失败：$error');
      }
    } finally {
      if (mounted) {
        setState(() => _isCreatingPairingCode = false);
      }
    }
  }

  Future<void> _openCreateRouteDialog() async {
    final groups = await _loadDestinationGroups();
    if (!mounted) {
      return;
    }
    final created = await showDialog<bool>(
      context: context,
      builder: (context) => _CreateFeishuRouteDialog(
        groups: groups,
        onSubmit: (request) async {
          final creator =
              widget.onCreateRoute ?? widget._repository.createFeishuRoute;
          await creator(request);
          if (mounted) {
            setState(() => _snapshotFuture = _loadSnapshot());
          }
        },
      ),
    );
    if (created == true && mounted) {
      _showSnackBar('飞书监控规则已创建');
    }
  }

  Future<void> _pauseRoute(String routeId) async {
    final action = widget.onPauseRoute ?? widget._repository.pauseRoute;
    await action(routeId);
    if (mounted) {
      setState(() => _snapshotFuture = _loadSnapshot());
    }
  }

  Future<void> _resumeRoute(String routeId) async {
    final action = widget.onResumeRoute ?? widget._repository.resumeRoute;
    await action(routeId);
    if (mounted) {
      setState(() => _snapshotFuture = _loadSnapshot());
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WKSubPageScaffold(
      title: '飞书信息监控中心',
      trailingWidth: 64,
      trailing: WKSubPageAction(text: '刷新', onTap: _refresh),
      body: FutureBuilder<FeishuMonitorSnapshot>(
        future: _snapshotFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _ErrorState(
              message: '加载失败：${snapshot.error}',
              onRetry: _refresh,
            );
          }
          final data = snapshot.data ?? FeishuMonitorSnapshot.empty;
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
              children: [
                const _HeroCard(),
                const SizedBox(height: WKSpace.md),
                _StatsRow(stats: data.stats),
                const SizedBox(height: WKSpace.md),
                _ActionRow(
                  onNewRoute: data.hasAgent ? _openCreateRouteDialog : null,
                  onDownloadAgent: widget.onDownloadAgent,
                ),
                const SizedBox(height: WKSpace.md),
                if (!data.hasAgent)
                  _AgentOnboardingCard(
                    pairingCode: _pairingCode,
                    isCreating: _isCreatingPairingCode,
                    onCreatePairingCode: _createPairingCode,
                    onDownloadAgent: widget.onDownloadAgent,
                  )
                else ...[
                  const _SectionTitle(title: '监控规则'),
                  if (data.routes.isEmpty)
                    _EmptyCard(
                      title: '还没有飞书监控规则',
                      description: '创建一条飞书 Web 群 → 悟空 IM 群规则后，Agent 会开始监听。',
                      actionText: '新建飞书监控规则',
                      onAction: _openCreateRouteDialog,
                    )
                  else
                    for (final route in data.routes)
                      _RouteCard(
                        route: route,
                        onPause: () => _pauseRoute(route.id),
                        onResume: () => _resumeRoute(route.id),
                        onLogs: () => widget.onViewRouteLogs?.call(route.id),
                      ),
                  const SizedBox(height: WKSpace.md),
                  const _SectionTitle(title: 'Windows Agent'),
                  for (final agent in data.agents) _AgentCard(agent: agent),
                ],
                const SizedBox(height: WKSpace.md),
                const _SectionTitle(title: '最近日志'),
                if (data.logs.isEmpty)
                  const _MutedCard(text: '暂无运行日志')
                else
                  _LogsCard(logs: data.logs),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard();

  @override
  Widget build(BuildContext context) {
    return const _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '飞书信息监控中心',
            style: TextStyle(
              fontFamily: WKFontFamily.primary,
              fontFamilyFallback: WKTypography.fontFamilyFallback,
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: WKColors.colorDark,
            ),
          ),
          SizedBox(height: WKSpace.xs),
          Text(
            '实时监听你已登录飞书账号可见的群消息，并自动转发到悟空 IM 群。',
            style: TextStyle(
              fontFamily: WKFontFamily.primary,
              fontFamilyFallback: WKTypography.fontFamilyFallback,
              fontSize: 14,
              height: 1.45,
              color: WKColors.color999,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.stats});

  final MonitorStats stats;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(label: '运行中规则', value: '${stats.runningRoutes}'),
        ),
        const SizedBox(width: WKSpace.sm),
        Expanded(
          child: _StatCard(label: '今日转发', value: '${stats.todayForwarded}'),
        ),
        const SizedBox(width: WKSpace.sm),
        Expanded(child: _StatCard(label: '异常提醒', value: '${stats.alerts}')),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      padding: const EdgeInsets.all(WKSpace.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: WKColors.color999, fontSize: 12)),
          const SizedBox(height: WKSpace.xs),
          Text(
            value,
            style: const TextStyle(
              fontFamily: WKFontFamily.primary,
              fontFamilyFallback: WKTypography.fontFamilyFallback,
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: WKColors.colorDark,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({required this.onNewRoute, required this.onDownloadAgent});

  final VoidCallback? onNewRoute;
  final VoidCallback? onDownloadAgent;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: WKSpace.sm,
      runSpacing: WKSpace.sm,
      children: [
        FilledButton.icon(
          key: const ValueKey('feishu-monitor-new-route'),
          onPressed: onNewRoute,
          icon: const Icon(Icons.add_rounded),
          label: const Text('新建飞书监控规则'),
        ),
        OutlinedButton.icon(
          key: const ValueKey('feishu-monitor-download-agent'),
          onPressed: onDownloadAgent,
          icon: const Icon(Icons.download_rounded),
          label: const Text('下载 Windows Agent'),
        ),
      ],
    );
  }
}

class _AgentOnboardingCard extends StatelessWidget {
  const _AgentOnboardingCard({
    required this.pairingCode,
    required this.isCreating,
    required this.onCreatePairingCode,
    required this.onDownloadAgent,
  });

  final MonitorPairingCode? pairingCode;
  final bool isCreating;
  final VoidCallback onCreatePairingCode;
  final VoidCallback? onDownloadAgent;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '还没有绑定 Windows Agent',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: WKSpace.sm),
          const Text('1. 下载 Windows Agent'),
          const Text('2. 使用配对码绑定设备'),
          const Text('3. 扫码登录飞书 Web'),
          const Text('4. 创建飞书群转发规则'),
          const SizedBox(height: WKSpace.md),
          Wrap(
            spacing: WKSpace.sm,
            runSpacing: WKSpace.sm,
            children: [
              FilledButton(
                key: const ValueKey('feishu-monitor-create-pairing'),
                onPressed: isCreating ? null : onCreatePairingCode,
                child: Text(isCreating ? '生成中...' : '生成配对码'),
              ),
              OutlinedButton(
                onPressed: onDownloadAgent,
                child: const Text('下载 Windows Agent'),
              ),
            ],
          ),
          if (pairingCode != null) ...[
            const SizedBox(height: WKSpace.md),
            Text(
              '配对码：${pairingCode!.code}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            Text('有效期至：${pairingCode!.expiresAt}'),
          ],
        ],
      ),
    );
  }
}

class _RouteCard extends StatelessWidget {
  const _RouteCard({
    required this.route,
    required this.onPause,
    required this.onResume,
    required this.onLogs,
  });

  final MonitorRoute route;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onLogs;

  @override
  Widget build(BuildContext context) {
    final isRunning = route.status == MonitorRouteStatus.running;
    return _Panel(
      margin: const EdgeInsets.only(bottom: WKSpace.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            route.title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: WKSpace.xs),
          Text('来源：${route.sourceTypeLabel}'),
          Text('状态：${route.statusLabel}'),
          Text('最近转发：${route.lastForwardedAt.isEmpty ? '暂无' : route.lastForwardedAt}'),
          Text('今日转发：${route.todayForwardedCount} 条'),
          const SizedBox(height: WKSpace.sm),
          Wrap(
            spacing: WKSpace.xs,
            children: [
              TextButton(
                key: ValueKey(
                  'monitor-route-${isRunning ? 'pause' : 'resume'}-${route.id}',
                ),
                onPressed: isRunning ? onPause : onResume,
                child: Text(isRunning ? '暂停' : '恢复'),
              ),
              TextButton(
                key: ValueKey('monitor-route-logs-${route.id}'),
                onPressed: onLogs,
                child: const Text('查看日志'),
              ),
              TextButton(onPressed: () {}, child: const Text('编辑')),
            ],
          ),
        ],
      ),
    );
  }
}

class _AgentCard extends StatelessWidget {
  const _AgentCard({required this.agent});

  final MonitorAgent agent;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      margin: const EdgeInsets.only(bottom: WKSpace.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            agent.deviceName,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: WKSpace.xs),
          Text('平台：${agent.platformLabel}'),
          Text('版本：${agent.version.isEmpty ? '未知' : agent.version}'),
          Text('状态：${agent.statusLabel}'),
          Text('最近心跳：${agent.lastHeartbeatAt.isEmpty ? '暂无' : agent.lastHeartbeatAt}'),
          const SizedBox(height: WKSpace.sm),
          Wrap(
            spacing: WKSpace.xs,
            children: [
              TextButton(onPressed: () {}, child: const Text('重新配对')),
              TextButton(onPressed: () {}, child: const Text('查看日志')),
              TextButton(onPressed: () {}, child: const Text('更新 Agent')),
            ],
          ),
        ],
      ),
    );
  }
}

class _LogsCard extends StatelessWidget {
  const _LogsCard({required this.logs});

  final List<MonitorLogEntry> logs;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final log in logs)
            Padding(
              padding: const EdgeInsets.only(bottom: WKSpace.xs),
              child: Text('${log.occurredAt} ${log.message}'),
            ),
        ],
      ),
    );
  }
}

class _CreateFeishuRouteDialog extends StatefulWidget {
  const _CreateFeishuRouteDialog({
    required this.groups,
    required this.onSubmit,
  });

  final List<MonitorSelectableGroup> groups;
  final FeishuRouteCreator onSubmit;

  @override
  State<_CreateFeishuRouteDialog> createState() =>
      _CreateFeishuRouteDialogState();
}

class _CreateFeishuRouteDialogState extends State<_CreateFeishuRouteDialog> {
  final _chatController = TextEditingController();
  MonitorSelectableGroup? _selectedGroup;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _selectedGroup = widget.groups.isEmpty ? null : widget.groups.first;
  }

  @override
  void dispose() {
    _chatController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final chatName = _chatController.text.trim();
    final group = _selectedGroup;
    if (chatName.isEmpty || group == null || _submitting) {
      return;
    }
    setState(() => _submitting = true);
    try {
      await widget.onSubmit(
        CreateFeishuMonitorRouteRequest(
          sourceChatName: chatName,
          destinationGroupNo: group.groupNo,
          destinationGroupName: group.label,
        ),
      );
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('新建飞书监控规则'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              key: const ValueKey('feishu-route-source-chat-input'),
              controller: _chatController,
              decoration: const InputDecoration(
                labelText: '飞书群名称',
                hintText: '例如：新闻群',
              ),
            ),
            const SizedBox(height: WKSpace.md),
            DropdownButtonFormField<MonitorSelectableGroup>(
              value: _selectedGroup,
              decoration: const InputDecoration(labelText: '悟空 IM 群'),
              items: [
                for (final group in widget.groups)
                  DropdownMenuItem(value: group, child: Text(group.label)),
              ],
              onChanged: (value) => setState(() => _selectedGroup = value),
            ),
            const SizedBox(height: WKSpace.md),
            const Text('转发内容：文本、链接'),
            const Text('图片、文件：暂不支持，后续支持'),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('取消'),
        ),
        FilledButton(
          key: const ValueKey('feishu-route-submit'),
          onPressed: _submitting ? null : _submit,
          child: Text(_submitting ? '创建中...' : '确认并启动'),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: WKSpace.sm),
      child: Text(
        title,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({
    required this.title,
    required this.description,
    required this.actionText,
    required this.onAction,
  });

  final String title;
  final String description;
  final String actionText;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: WKSpace.xs),
          Text(description, style: const TextStyle(color: WKColors.color999)),
          const SizedBox(height: WKSpace.sm),
          FilledButton(onPressed: onAction, child: Text(actionText)),
        ],
      ),
    );
  }
}

class _MutedCard extends StatelessWidget {
  const _MutedCard({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Text(text, style: const TextStyle(color: WKColors.color999)),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: WKSpace.md),
          FilledButton(onPressed: onRetry, child: const Text('重试')),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({
    required this.child,
    this.padding = const EdgeInsets.all(WKSpace.lg),
    this.margin = EdgeInsets.zero,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: WKColors.surface,
        borderRadius: BorderRadius.circular(WKRadius.lg),
        boxShadow: WKShadows.soft,
      ),
      child: child,
    );
  }
}
```

- [ ] **Step 4: Run tests and confirm green**

```powershell
flutter test test/modules/monitor/feishu_monitor_center_page_test.dart
```

Expected: PASS.

- [ ] **Step 5: Commit**

```powershell
git add lib/modules/monitor/feishu_monitor_center_page.dart test/modules/monitor/feishu_monitor_center_page_test.dart
git commit -m "feat: add feishu monitor center page"
```

---

### Task 5: Replace management-system placeholder with platform center cards

**Files:**
- Modify: `lib/modules/vip/vip_management_page.dart`
- Create or modify: `test/modules/vip/vip_management_page_test.dart`

- [ ] **Step 1: Write failing management page tests**

Create or replace `test/modules/vip/vip_management_page_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/modules/monitor/feishu_monitor_center_page.dart';
import 'package:wukong_im_app/modules/vip/vip_management_page.dart';

void main() {
  testWidgets('management page renders platform-specific monitor centers', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: VipManagementPage()));
    await tester.pumpAndSettle();

    expect(find.text('管理系统'), findsWidgets);
    expect(find.text('飞书信息监控中心'), findsOneWidget);
    expect(find.text('同步飞书 Web 群消息到悟空 IM 群'), findsOneWidget);
    expect(find.text('钉钉信息监控中心'), findsOneWidget);
    expect(find.text('即将上线'), findsNWidgets(2));
    expect(find.text('小鹅通信息监控中心'), findsOneWidget);
  });

  testWidgets('management page opens Feishu monitor center', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: VipManagementPage()));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('management-center-feishu')));
    await tester.pumpAndSettle();

    expect(find.byType(FeishuMonitorCenterPage), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run tests and confirm red**

```powershell
flutter test test/modules/vip/vip_management_page_test.dart
```

Expected: FAIL because the page still shows placeholder content.

- [ ] **Step 3: Implement management page**

Replace `lib/modules/vip/vip_management_page.dart`:

```dart
import 'package:flutter/material.dart';

import '../../widgets/wk_colors.dart';
import '../../widgets/wk_design_tokens.dart';
import '../../widgets/wk_sub_page_scaffold.dart';
import '../monitor/feishu_monitor_center_page.dart';

class VipManagementPage extends StatelessWidget {
  const VipManagementPage({super.key});

  void _openFeishuCenter(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => FeishuMonitorCenterPage()),
    );
  }

  void _showComingSoon(BuildContext context, String title) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$title 即将上线')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WKSubPageScaffold(
      title: '管理系统',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          const _ManagementHeader(),
          const SizedBox(height: WKSpace.md),
          _ManagementCenterCard(
            key: const ValueKey('management-center-feishu'),
            title: '飞书信息监控中心',
            description: '同步飞书 Web 群消息到悟空 IM 群',
            status: '可用',
            icon: Icons.forum_rounded,
            enabled: true,
            onTap: () => _openFeishuCenter(context),
          ),
          const SizedBox(height: WKSpace.sm),
          _ManagementCenterCard(
            key: const ValueKey('management-center-dingtalk'),
            title: '钉钉信息监控中心',
            description: '同步钉钉群、机器人消息到悟空 IM 群',
            status: '即将上线',
            icon: Icons.notifications_active_rounded,
            enabled: false,
            onTap: () => _showComingSoon(context, '钉钉信息监控中心'),
          ),
          const SizedBox(height: WKSpace.sm),
          _ManagementCenterCard(
            key: const ValueKey('management-center-xiaoe'),
            title: '小鹅通信息监控中心',
            description: '监控课程、订单、通知并转发到悟空 IM 群',
            status: '即将上线',
            icon: Icons.school_rounded,
            enabled: false,
            onTap: () => _showComingSoon(context, '小鹅通信息监控中心'),
          ),
        ],
      ),
    );
  }
}

class _ManagementHeader extends StatelessWidget {
  const _ManagementHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(WKSpace.lg),
      decoration: BoxDecoration(
        color: WKColors.surface,
        borderRadius: BorderRadius.circular(WKRadius.lg),
        boxShadow: WKShadows.soft,
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '信息监控服务',
            style: TextStyle(
              fontFamily: WKFontFamily.primary,
              fontFamilyFallback: WKTypography.fontFamilyFallback,
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: WKColors.colorDark,
            ),
          ),
          SizedBox(height: WKSpace.xs),
          Text(
            '按平台管理消息监控与自动转发，当前优先支持飞书 Web 群转发到悟空 IM 群。',
            style: TextStyle(
              fontFamily: WKFontFamily.primary,
              fontFamilyFallback: WKTypography.fontFamilyFallback,
              fontSize: 14,
              height: 1.45,
              color: WKColors.color999,
            ),
          ),
        ],
      ),
    );
  }
}

class _ManagementCenterCard extends StatelessWidget {
  const _ManagementCenterCard({
    super.key,
    required this.title,
    required this.description,
    required this.status,
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  final String title;
  final String description;
  final String status;
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final statusColor = enabled ? WKColors.success : WKColors.color999;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(WKRadius.lg),
        child: Ink(
          padding: const EdgeInsets.all(WKSpace.lg),
          decoration: BoxDecoration(
            color: WKColors.surface,
            borderRadius: BorderRadius.circular(WKRadius.lg),
            boxShadow: WKShadows.soft,
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: enabled ? WKColors.brand50 : WKColors.surfaceSoft,
                  borderRadius: BorderRadius.circular(WKRadius.lg),
                ),
                child: Icon(
                  icon,
                  color: enabled ? WKColors.brand500 : WKColors.color999,
                ),
              ),
              const SizedBox(width: WKSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: WKColors.colorDark,
                      ),
                    ),
                    const SizedBox(height: WKSpace.xxs),
                    Text(
                      description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.35,
                        color: WKColors.color999,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: WKSpace.sm),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: WKSpace.sm,
                      vertical: WKSpace.xxs,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(WKRadius.pill),
                    ),
                    child: Text(
                      status,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: statusColor,
                      ),
                    ),
                  ),
                  const SizedBox(height: WKSpace.xs),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: WKColors.color999,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run tests and confirm green**

```powershell
flutter test test/modules/vip/vip_management_page_test.dart
```

Expected: PASS.

- [ ] **Step 5: Commit**

```powershell
git add lib/modules/vip/vip_management_page.dart test/modules/vip/vip_management_page_test.dart
git commit -m "feat: add management monitor center entries"
```

---

### Task 6: Add integration coverage from UserPage

**Files:**
- Modify: `test/modules/user/user_page_parity_test.dart`

- [ ] **Step 1: Add VIP management navigation assertion**

If the file already has a VIP management navigation test, add these assertions after opening `VipManagementPage`:

```dart
expect(find.byType(VipManagementPage), findsOneWidget);
expect(find.text('飞书信息监控中心'), findsOneWidget);
expect(find.text('钉钉信息监控中心'), findsOneWidget);
expect(find.text('小鹅通信息监控中心'), findsOneWidget);
```

If there is no such test, add this test inside `main()`:

```dart
testWidgets('VIP user opens management system with monitor center entries', (
  tester,
) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(1080, 3000);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authProvider.overrideWith((ref) {
          return _TestAuthNotifier(
            ref,
            initialState: AuthState(
              isLoggedIn: true,
              isRestoringSession: false,
              userInfo: UserInfo(uid: 'vip_user', vipLevel: 1),
            ),
          );
        }),
        authCurrentUserLoaderProvider.overrideWithValue(() async => null),
        authDraftSyncProvider.overrideWithValue(() async {}),
        userPageVersionLoaderProvider.overrideWithValue(() async => null),
        slotRegistryProvider.overrideWithValue(SlotRegistry()),
      ],
      child: const MaterialApp(home: UserPage()),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));

  final managementRow =
      find.byKey(const ValueKey<String>('user_menu_vip_management'));
  await tester.ensureVisible(managementRow);
  final tapTarget = tester.widget<InkWell>(
    find.descendant(of: managementRow, matching: find.byType(InkWell)),
  );
  tapTarget.onTap!.call();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));

  expect(find.byType(VipManagementPage), findsOneWidget);
  expect(find.text('飞书信息监控中心'), findsOneWidget);
  expect(find.text('钉钉信息监控中心'), findsOneWidget);
  expect(find.text('小鹅通信息监控中心'), findsOneWidget);
});
```

- [ ] **Step 2: Run integration test**

```powershell
flutter test test/modules/user/user_page_parity_test.dart
```

Expected: PASS.

- [ ] **Step 3: Commit**

```powershell
git add test/modules/user/user_page_parity_test.dart
git commit -m "test: cover monitor entries in management navigation"
```

---

### Task 7: Targeted verification

**Files:**
- Modify only files touched above if verification fails.

- [ ] **Step 1: Run monitor/model/API/page tests**

```powershell
flutter test test/modules/monitor test/service/api/monitor_api_test.dart test/modules/vip/vip_management_page_test.dart
```

Expected: PASS.

- [ ] **Step 2: Run user navigation tests**

```powershell
flutter test test/modules/user/user_page_parity_test.dart test/modules/user/user_page_slot_assembly_test.dart
```

Expected: PASS.

- [ ] **Step 3: Run analyzer on touched production files**

```powershell
flutter analyze lib/modules/monitor lib/service/api/monitor_api.dart lib/modules/vip/vip_management_page.dart
```

Expected: no issues.

- [ ] **Step 4: Fix verification failures with focused patches**

Use these exact fixes for likely failures:

- If a widget is offscreen in a test, add `await tester.ensureVisible(finder);` before tapping.
- If a widget overflows, replace the row of action buttons with `Wrap(spacing: WKSpace.xs, runSpacing: WKSpace.xs, children: [...])`.
- If analyzer reports an unused import, remove the import.
- If `withValues` is unavailable in the local Flutter SDK, replace `statusColor.withValues(alpha: 0.12)` with `statusColor.withOpacity(0.12)`.
- If a dropdown test cannot tap the selected value, replace `await tester.tap(find.text('悟空 IM 新闻群'));` with:

```dart
await tester.tap(find.byType(DropdownButtonFormField<MonitorSelectableGroup>));
await tester.pumpAndSettle();
await tester.tap(find.text('悟空 IM 新闻群').last);
await tester.pumpAndSettle();
```

After each patch, rerun the failing command until it passes.

- [ ] **Step 5: Commit fixes if any**

```powershell
git add lib/modules/monitor lib/service/api/monitor_api.dart lib/modules/vip/vip_management_page.dart test/modules/monitor test/service/api/monitor_api_test.dart test/modules/vip/vip_management_page_test.dart test/modules/user/user_page_parity_test.dart
git commit -m "fix: stabilize monitor center integration"
```

If no files changed, do not create an empty commit.

---

### Task 8: Final design alignment and verification

**Files:**
- Modify: `docs/superpowers/specs/2026-05-06-feishu-im-local-agent-bridge-design.md` only if implementation names diverge from the spec.

- [ ] **Step 1: Compare names with spec**

Confirm implementation uses these names exactly:

```text
飞书信息监控中心
钉钉信息监控中心
小鹅通信息监控中心
platform: feishu
connector_type: feishu_web_group
route_type: feishu_web_group_to_wukong_im_group
```

Expected: names match. If names do not match, update the implementation or spec so they match.

- [ ] **Step 2: Run final targeted tests**

```powershell
flutter test test/modules/monitor test/service/api/monitor_api_test.dart test/modules/vip/vip_management_page_test.dart test/modules/user/user_page_parity_test.dart
```

Expected: PASS.

- [ ] **Step 3: Run final analyzer**

```powershell
flutter analyze lib/modules/monitor lib/service/api/monitor_api.dart lib/modules/vip/vip_management_page.dart
```

Expected: no issues.

- [ ] **Step 4: Commit documentation alignment if any**

```powershell
git add docs/superpowers/specs/2026-05-06-feishu-im-local-agent-bridge-design.md
git commit -m "docs: align feishu monitor center design"
```

Only run this commit if the spec changed.

## Self-review checklist

- Spec coverage:
  - Management system platform-specific entries: Task 5.
  - Feishu information monitor center layout: Task 4.
  - Reusable Monitor model/API layer: Tasks 1–3.
  - Feishu Web group → Wukong IM group route creation: Tasks 2 and 4.
  - Agent onboarding and pairing code: Task 4.
  - DingTalk and Xiaoetong coming-soon entries: Task 5.
  - Windows Agent runtime: intentionally deferred.
- Placeholder scan:
  - No TBD/TODO/fill-in-later placeholders.
  - Code-writing steps include concrete code.
  - Verification steps include exact commands and expected results.
- Type consistency:
  - `MonitorPlatform.feishu.apiValue` → `feishu`.
  - `MonitorConnectorType.feishuWebGroup.apiValue` → `feishu_web_group`.
  - `CreateFeishuMonitorRouteRequest.route_type` → `feishu_web_group_to_wukong_im_group`.
  - `FeishuMonitorCenterPage` can use `MonitorRepository` in production and callbacks in tests.

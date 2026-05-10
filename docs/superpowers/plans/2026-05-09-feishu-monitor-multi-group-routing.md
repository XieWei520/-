# Feishu Monitor Multi Group Routing Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add multi-rule routing so different Feishu source conversations can forward to different WuKongIM target groups.

**Architecture:** Keep Feishu Monitor Shell as the capture source and keep WuKongIM desktop as the routing/control plane. Upgrade the local forwarding settings from one target group to a list of enabled routes, then make manual and auto forwarding use the same route matcher. Preserve the already-working local SDK send path and only change how events choose their target.

**Tech Stack:** Flutter desktop, Dart unit/widget tests, `shared_preferences`, JSON settings persistence, existing WuKongIM SDK send path.

---

## File Structure

- Modify `lib/modules/feishu_monitor/feishu_monitor_forwarding_service.dart`
  - Owns forwarding route models, settings JSON, route matching, dedupe, and text sending.
- Modify `lib/modules/feishu_monitor/feishu_monitor_center_page.dart`
  - Owns monitor center state, route creation/edit/delete interactions, manual forwarding trigger, and tab display.
- Modify `test/modules/feishu_monitor/feishu_monitor_forwarding_service_test.dart`
  - Covers route serialization, settings migration, route matching, forwarding counts, dedupe, and unmatched behavior.
- Modify `test/modules/feishu_monitor/feishu_monitor_center_page_test.dart`
  - Covers UI route creation from Feishu groups, target group picker display, rule table rendering, and manual forwarding through routes.

Do not create a new persistence backend in this slice. Keep settings local to the desktop client.

---

### Task 1: Route Model And Matching

**Files:**
- Modify: `lib/modules/feishu_monitor/feishu_monitor_forwarding_service.dart`
- Modify: `test/modules/feishu_monitor/feishu_monitor_forwarding_service_test.dart`

- [ ] **Step 1: Add failing route model tests**

Append these tests near the top of `test/modules/feishu_monitor/feishu_monitor_forwarding_service_test.dart`:

```dart
test('forwarding route round-trips through json', () {
  final route = FeishuMonitorForwardingRoute(
    id: 'route_1',
    enabled: true,
    sourceConversationId: 'feed:alpha',
    sourceConversationName: 'Alpha Group',
    sourceConversationType: 'group',
    targetGroupId: 'wk_group_1',
    targetGroupName: '悟空 Alpha 群',
    createdAt: DateTime.parse('2026-05-09T01:02:03Z'),
    updatedAt: DateTime.parse('2026-05-09T04:05:06Z'),
  );

  final decoded = FeishuMonitorForwardingRoute.fromJson(route.toJson());

  expect(decoded.id, 'route_1');
  expect(decoded.enabled, isTrue);
  expect(decoded.sourceConversationId, 'feed:alpha');
  expect(decoded.sourceConversationName, 'Alpha Group');
  expect(decoded.sourceConversationType, 'group');
  expect(decoded.targetGroupId, 'wk_group_1');
  expect(decoded.targetGroupName, '悟空 Alpha 群');
  expect(decoded.createdAt, DateTime.parse('2026-05-09T01:02:03Z'));
  expect(decoded.updatedAt, DateTime.parse('2026-05-09T04:05:06Z'));
});

test('findRouteForEvent prefers conversation id and falls back to normalized name', () {
  final routes = <FeishuMonitorForwardingRoute>[
    _route(
      id: 'route_alpha',
      sourceConversationId: 'feed:alpha',
      sourceConversationName: 'Alpha Group',
      targetGroupId: 'wk_alpha',
    ),
    _route(
      id: 'route_beta',
      sourceConversationId: '',
      sourceConversationName: 'Beta   Group',
      targetGroupId: 'wk_beta',
    ),
  ];

  final byId = findFeishuMonitorRouteForEvent(
    routes: routes,
    event: _event(conversationId: 'feed:alpha', conversationName: 'Wrong Name'),
  );
  final byName = findFeishuMonitorRouteForEvent(
    routes: routes,
    event: _event(conversationId: '', conversationName: ' beta group '),
  );
  final unmatched = findFeishuMonitorRouteForEvent(
    routes: routes,
    event: _event(conversationId: 'feed:missing', conversationName: 'Missing'),
  );

  expect(byId?.targetGroupId, 'wk_alpha');
  expect(byName?.targetGroupId, 'wk_beta');
  expect(unmatched, isNull);
});

test('disabled routes are ignored by matcher', () {
  final route = _route(
    enabled: false,
    sourceConversationId: 'feed:alpha',
    sourceConversationName: 'Alpha Group',
    targetGroupId: 'wk_alpha',
  );

  final matched = findFeishuMonitorRouteForEvent(
    routes: <FeishuMonitorForwardingRoute>[route],
    event: _event(conversationId: 'feed:alpha'),
  );

  expect(matched, isNull);
});
```

Add this helper below the existing `_event` helper:

```dart
FeishuMonitorForwardingRoute _route({
  String id = 'route_1',
  bool enabled = true,
  String sourceConversationId = 'chat_1',
  String sourceConversationName = 'Alpha Group',
  String sourceConversationType = 'group',
  String targetGroupId = 'group_1',
  String targetGroupName = 'Target Group',
}) {
  return FeishuMonitorForwardingRoute(
    id: id,
    enabled: enabled,
    sourceConversationId: sourceConversationId,
    sourceConversationName: sourceConversationName,
    sourceConversationType: sourceConversationType,
    targetGroupId: targetGroupId,
    targetGroupName: targetGroupName,
    createdAt: DateTime.parse('2026-05-09T01:00:00Z'),
    updatedAt: DateTime.parse('2026-05-09T01:00:00Z'),
  );
}
```

- [ ] **Step 2: Run the focused test and confirm it fails**

Run:

```powershell
D:\Apps\flutter\bin\flutter.bat test test/modules/feishu_monitor/feishu_monitor_forwarding_service_test.dart
```

Expected: FAIL because `FeishuMonitorForwardingRoute` and `findFeishuMonitorRouteForEvent` do not exist.

- [ ] **Step 3: Implement route model and matcher**

In `lib/modules/feishu_monitor/feishu_monitor_forwarding_service.dart`, add `dart:convert` only if this file does not already import it:

```dart
import 'dart:convert';
```

Add this model above the existing `FeishuMonitorForwardingRule`:

```dart
class FeishuMonitorForwardingRoute {
  const FeishuMonitorForwardingRoute({
    required this.id,
    required this.enabled,
    required this.sourceConversationId,
    required this.sourceConversationName,
    required this.sourceConversationType,
    required this.targetGroupId,
    required this.targetGroupName,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final bool enabled;
  final String sourceConversationId;
  final String sourceConversationName;
  final String sourceConversationType;
  final String targetGroupId;
  final String targetGroupName;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory FeishuMonitorForwardingRoute.fromJson(Map<String, dynamic> json) {
    return FeishuMonitorForwardingRoute(
      id: (json['id'] ?? '').toString(),
      enabled: json['enabled'] != false,
      sourceConversationId: (json['source_conversation_id'] ?? '').toString(),
      sourceConversationName:
          (json['source_conversation_name'] ?? '').toString(),
      sourceConversationType:
          (json['source_conversation_type'] ?? 'group').toString(),
      targetGroupId: (json['target_group_id'] ?? '').toString(),
      targetGroupName: (json['target_group_name'] ?? '').toString(),
      createdAt:
          DateTime.tryParse((json['created_at'] ?? '').toString()) ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      updatedAt:
          DateTime.tryParse((json['updated_at'] ?? '').toString()) ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'enabled': enabled,
      'source_conversation_id': sourceConversationId,
      'source_conversation_name': sourceConversationName,
      'source_conversation_type': sourceConversationType,
      'target_group_id': targetGroupId,
      'target_group_name': targetGroupName,
      'created_at': createdAt.toUtc().toIso8601String(),
      'updated_at': updatedAt.toUtc().toIso8601String(),
    };
  }

  FeishuMonitorForwardingRoute copyWith({
    bool? enabled,
    String? targetGroupId,
    String? targetGroupName,
    DateTime? updatedAt,
  }) {
    return FeishuMonitorForwardingRoute(
      id: id,
      enabled: enabled ?? this.enabled,
      sourceConversationId: sourceConversationId,
      sourceConversationName: sourceConversationName,
      sourceConversationType: sourceConversationType,
      targetGroupId: targetGroupId ?? this.targetGroupId,
      targetGroupName: targetGroupName ?? this.targetGroupName,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  FeishuMonitorForwardingRule toSingleTargetRule() {
    return FeishuMonitorForwardingRule(
      enabled: enabled,
      targetGroupId: targetGroupId,
      targetGroupName: targetGroupName,
    );
  }
}
```

Add these helpers below `_eventDedupeKey`:

```dart
FeishuMonitorForwardingRoute? findFeishuMonitorRouteForEvent({
  required List<FeishuMonitorForwardingRoute> routes,
  required FeishuMonitorMessageEvent event,
}) {
  final eventConversationId = event.conversationId.trim();
  if (eventConversationId.isNotEmpty) {
    for (final route in routes) {
      if (!route.enabled || route.targetGroupId.trim().isEmpty) {
        continue;
      }
      if (route.sourceConversationId.trim() == eventConversationId) {
        return route;
      }
    }
  }

  final eventName = normalizeFeishuMonitorRouteName(event.conversationName);
  if (eventName.isEmpty) {
    return null;
  }
  for (final route in routes) {
    if (!route.enabled || route.targetGroupId.trim().isEmpty) {
      continue;
    }
    if (route.sourceConversationId.trim().isNotEmpty) {
      continue;
    }
    if (normalizeFeishuMonitorRouteName(route.sourceConversationName) ==
        eventName) {
      return route;
    }
  }
  return null;
}

String normalizeFeishuMonitorRouteName(String value) {
  return value.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
}
```

- [ ] **Step 4: Verify route tests pass**

Run:

```powershell
D:\Apps\flutter\bin\flutter.bat test test/modules/feishu_monitor/feishu_monitor_forwarding_service_test.dart
```

Expected: PASS for existing tests and new route model tests.

---

### Task 2: Settings V2 Persistence And Legacy Migration

**Files:**
- Modify: `lib/modules/feishu_monitor/feishu_monitor_forwarding_service.dart`
- Modify: `test/modules/feishu_monitor/feishu_monitor_forwarding_service_test.dart`

- [ ] **Step 1: Add failing settings tests**

Add this import to the test file:

```dart
import 'package:shared_preferences/shared_preferences.dart';
```

Add these tests:

```dart
test('settings store saves and loads v2 route list', () async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  const store = SharedPreferencesFeishuMonitorForwardingSettingsStore();
  final settings = FeishuMonitorForwardingSettings(
    enabled: true,
    routes: <FeishuMonitorForwardingRoute>[
      _route(
        id: 'route_alpha',
        sourceConversationId: 'feed:alpha',
        targetGroupId: 'wk_alpha',
        targetGroupName: '悟空 Alpha 群',
      ),
      _route(
        id: 'route_beta',
        sourceConversationId: 'feed:beta',
        sourceConversationName: 'Beta Group',
        targetGroupId: 'wk_beta',
        targetGroupName: '悟空 Beta 群',
      ),
    ],
    legacyTargetGroupId: '',
  );

  await store.save(settings);
  final loaded = await store.load();

  expect(loaded.enabled, isTrue);
  expect(loaded.routes, hasLength(2));
  expect(loaded.routes.first.sourceConversationId, 'feed:alpha');
  expect(loaded.routes.first.targetGroupId, 'wk_alpha');
  expect(loaded.routes.last.sourceConversationName, 'Beta Group');
  expect(loaded.routes.last.targetGroupName, '悟空 Beta 群');
});

test('settings store migrates old single target as legacy hint only', () async {
  SharedPreferences.setMockInitialValues(<String, Object>{
    'feishu_monitor_forwarding_enabled': true,
    'feishu_monitor_target_group_id': 'old_group',
  });
  const store = SharedPreferencesFeishuMonitorForwardingSettingsStore();

  final loaded = await store.load();

  expect(loaded.enabled, isTrue);
  expect(loaded.routes, isEmpty);
  expect(loaded.legacyTargetGroupId, 'old_group');
});
```

- [ ] **Step 2: Run the settings tests and confirm they fail**

Run:

```powershell
D:\Apps\flutter\bin\flutter.bat test test/modules/feishu_monitor/feishu_monitor_forwarding_service_test.dart
```

Expected: FAIL because `FeishuMonitorForwardingSettings` does not yet expose `routes` or `legacyTargetGroupId`.

- [ ] **Step 3: Upgrade settings model**

Replace the current `FeishuMonitorForwardingSettings` class with:

```dart
class FeishuMonitorForwardingSettings {
  const FeishuMonitorForwardingSettings({
    required this.enabled,
    this.routes = const <FeishuMonitorForwardingRoute>[],
    this.legacyTargetGroupId = '',
  });

  final bool enabled;
  final List<FeishuMonitorForwardingRoute> routes;
  final String legacyTargetGroupId;

  String get targetGroupId {
    if (routes.length == 1) {
      return routes.single.targetGroupId;
    }
    return legacyTargetGroupId;
  }

  FeishuMonitorForwardingSettings copyWith({
    bool? enabled,
    List<FeishuMonitorForwardingRoute>? routes,
    String? legacyTargetGroupId,
  }) {
    return FeishuMonitorForwardingSettings(
      enabled: enabled ?? this.enabled,
      routes: routes ?? this.routes,
      legacyTargetGroupId: legacyTargetGroupId ?? this.legacyTargetGroupId,
    );
  }

  FeishuMonitorForwardingRule toRule() {
    return FeishuMonitorForwardingRule(
      enabled: enabled,
      targetGroupId: targetGroupId,
    );
  }

  factory FeishuMonitorForwardingSettings.fromJson(Map<String, dynamic> json) {
    final rawRoutes = json['routes'];
    return FeishuMonitorForwardingSettings(
      enabled: json['enabled'] == true,
      routes: rawRoutes is List
          ? rawRoutes
                .whereType<Object?>()
                .map((item) {
                  if (item is Map<String, dynamic>) {
                    return FeishuMonitorForwardingRoute.fromJson(item);
                  }
                  if (item is Map) {
                    return FeishuMonitorForwardingRoute.fromJson(
                      Map<String, dynamic>.from(item),
                    );
                  }
                  return null;
                })
                .whereType<FeishuMonitorForwardingRoute>()
                .toList(growable: false)
          : const <FeishuMonitorForwardingRoute>[],
      legacyTargetGroupId: (json['legacy_target_group_id'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'enabled': enabled,
      'routes': routes.map((route) => route.toJson()).toList(growable: false),
      'legacy_target_group_id': legacyTargetGroupId,
    };
  }
}
```

- [ ] **Step 4: Upgrade shared preferences store**

Replace the internals of `SharedPreferencesFeishuMonitorForwardingSettingsStore` with:

```dart
class SharedPreferencesFeishuMonitorForwardingSettingsStore
    implements FeishuMonitorForwardingSettingsStore {
  const SharedPreferencesFeishuMonitorForwardingSettingsStore();

  static const String _settingsV2Key =
      'feishu_monitor_forwarding_settings_v2';
  static const String _enabledKey = 'feishu_monitor_forwarding_enabled';
  static const String _targetGroupIdKey = 'feishu_monitor_target_group_id';

  @override
  Future<FeishuMonitorForwardingSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    final rawV2 = prefs.getString(_settingsV2Key);
    if (rawV2 != null && rawV2.trim().isNotEmpty) {
      final decoded = jsonDecode(rawV2);
      if (decoded is Map<String, dynamic>) {
        return FeishuMonitorForwardingSettings.fromJson(decoded);
      }
      if (decoded is Map) {
        return FeishuMonitorForwardingSettings.fromJson(
          Map<String, dynamic>.from(decoded),
        );
      }
    }

    return FeishuMonitorForwardingSettings(
      enabled: prefs.getBool(_enabledKey) ?? false,
      routes: const <FeishuMonitorForwardingRoute>[],
      legacyTargetGroupId: prefs.getString(_targetGroupIdKey) ?? '',
    );
  }

  @override
  Future<void> save(FeishuMonitorForwardingSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_settingsV2Key, jsonEncode(settings.toJson()));
  }
}
```

- [ ] **Step 5: Verify settings tests pass**

Run:

```powershell
D:\Apps\flutter\bin\flutter.bat test test/modules/feishu_monitor/feishu_monitor_forwarding_service_test.dart
```

Expected: PASS.

---

### Task 3: Routed Forwarding Service

**Files:**
- Modify: `lib/modules/feishu_monitor/feishu_monitor_forwarding_service.dart`
- Modify: `test/modules/feishu_monitor/feishu_monitor_forwarding_service_test.dart`

- [ ] **Step 1: Add failing routed forwarding tests**

Add these tests:

```dart
test('forwardRoutedRecentEvents sends each source to its configured target', () async {
  final sender = _RecordingSender();
  final service = FeishuMonitorForwardingService(sender: sender);
  final settings = FeishuMonitorForwardingSettings(
    enabled: true,
    routes: <FeishuMonitorForwardingRoute>[
      _route(
        id: 'route_alpha',
        sourceConversationId: 'feed:alpha',
        sourceConversationName: 'Alpha Group',
        targetGroupId: 'wk_alpha',
        targetGroupName: '悟空 Alpha 群',
      ),
      _route(
        id: 'route_beta',
        sourceConversationId: 'feed:beta',
        sourceConversationName: 'Beta Group',
        targetGroupId: 'wk_beta',
        targetGroupName: '悟空 Beta 群',
      ),
    ],
  );

  final result = await service.forwardRoutedRecentEvents(
    settings: settings,
    events: <FeishuMonitorMessageEvent>[
      _event(
        messageId: 'msg_a',
        dedupeKey: 'dedupe_a',
        conversationId: 'feed:alpha',
        conversationName: 'Alpha Group',
      ),
      _event(
        messageId: 'msg_b',
        dedupeKey: 'dedupe_b',
        conversationId: 'feed:beta',
        conversationName: 'Beta Group',
      ),
      _event(
        messageId: 'msg_c',
        dedupeKey: 'dedupe_c',
        conversationId: 'feed:missing',
        conversationName: 'Missing Group',
      ),
    ],
  );

  expect(result.sent, 2);
  expect(result.skippedUnmatched, 1);
  expect(result.skippedDuplicate, 0);
  expect(result.failed, 0);
  expect(sender.targetGroupIds, <String>['wk_alpha', 'wk_beta']);
});

test('forwardRoutedRecentEvents uses dedupe across routed sends', () async {
  final sender = _RecordingSender();
  final service = FeishuMonitorForwardingService(sender: sender);
  final settings = FeishuMonitorForwardingSettings(
    enabled: true,
    routes: <FeishuMonitorForwardingRoute>[
      _route(sourceConversationId: 'feed:alpha', targetGroupId: 'wk_alpha'),
    ],
  );
  final event = _event(
    messageId: 'msg_a',
    dedupeKey: 'dedupe_a',
    conversationId: 'feed:alpha',
  );

  final first = await service.forwardRoutedRecentEvents(
    settings: settings,
    events: <FeishuMonitorMessageEvent>[event],
  );
  final second = await service.forwardRoutedRecentEvents(
    settings: settings,
    events: <FeishuMonitorMessageEvent>[event],
  );

  expect(first.sent, 1);
  expect(second.sent, 0);
  expect(second.skippedDuplicate, 1);
  expect(sender.targetGroupIds, <String>['wk_alpha']);
});

test('forwardRoutedRecentEvents skips all events when global forwarding is disabled', () async {
  final sender = _RecordingSender();
  final service = FeishuMonitorForwardingService(sender: sender);

  final result = await service.forwardRoutedRecentEvents(
    settings: FeishuMonitorForwardingSettings(
      enabled: false,
      routes: <FeishuMonitorForwardingRoute>[
        _route(sourceConversationId: 'feed:alpha', targetGroupId: 'wk_alpha'),
      ],
    ),
    events: <FeishuMonitorMessageEvent>[
      _event(conversationId: 'feed:alpha'),
    ],
  );

  expect(result.sent, 0);
  expect(result.skippedDisabled, 1);
  expect(sender.targetGroupIds, isEmpty);
});
```

- [ ] **Step 2: Run the routed forwarding tests and confirm they fail**

Run:

```powershell
D:\Apps\flutter\bin\flutter.bat test test/modules/feishu_monitor/feishu_monitor_forwarding_service_test.dart
```

Expected: FAIL because `forwardRoutedRecentEvents` and detailed skip counters do not exist.

- [ ] **Step 3: Extend forwarding result**

Replace `FeishuMonitorForwardingResult` with:

```dart
class FeishuMonitorForwardingResult {
  const FeishuMonitorForwardingResult({
    required this.sent,
    this.skippedDuplicate = 0,
    this.skippedUnmatched = 0,
    this.skippedDisabled = 0,
    required this.failed,
  });

  final int sent;
  final int skippedDuplicate;
  final int skippedUnmatched;
  final int skippedDisabled;
  final int failed;

  int get skipped => skippedDuplicate + skippedUnmatched + skippedDisabled;
}
```

Update the old single-rule call sites inside the service so they construct the new result shape:

```dart
return FeishuMonitorForwardingResult(
  sent: 0,
  skippedDisabled: events.length,
  failed: 0,
);
```

and:

```dart
return FeishuMonitorForwardingResult(
  sent: sent,
  skippedDuplicate: skipped,
  failed: failed,
);
```

- [ ] **Step 4: Implement routed forwarding**

Add this method inside `FeishuMonitorForwardingService`:

```dart
Future<FeishuMonitorForwardingResult> forwardRoutedRecentEvents({
  required FeishuMonitorForwardingSettings settings,
  required List<FeishuMonitorMessageEvent> events,
}) async {
  if (!settings.enabled) {
    return FeishuMonitorForwardingResult(
      sent: 0,
      skippedDisabled: events.length,
      failed: 0,
    );
  }

  var sent = 0;
  var skippedDuplicate = 0;
  var skippedUnmatched = 0;
  var skippedDisabled = 0;
  var failed = 0;

  for (final event in events) {
    final route = findFeishuMonitorRouteForEvent(
      routes: settings.routes,
      event: event,
    );
    if (route == null) {
      skippedUnmatched += 1;
      continue;
    }
    if (!route.enabled || route.targetGroupId.trim().isEmpty) {
      skippedDisabled += 1;
      continue;
    }

    final key = _eventDedupeKey(event);
    if (key.isEmpty || _sentKeys.contains(key)) {
      skippedDuplicate += 1;
      continue;
    }

    try {
      await _sender.sendText(
        channelId: route.targetGroupId.trim(),
        channelType: WKChannelType.group,
        channelName: route.targetGroupName,
        text: formatFeishuMonitorEventForForward(event),
      );
      _sentKeys.add(key);
      sent += 1;
    } catch (_) {
      failed += 1;
    }
  }

  return FeishuMonitorForwardingResult(
    sent: sent,
    skippedDuplicate: skippedDuplicate,
    skippedUnmatched: skippedUnmatched,
    skippedDisabled: skippedDisabled,
    failed: failed,
  );
}
```

- [ ] **Step 5: Verify routed forwarding tests pass**

Run:

```powershell
D:\Apps\flutter\bin\flutter.bat test test/modules/feishu_monitor/feishu_monitor_forwarding_service_test.dart
```

Expected: PASS.

---

### Task 4: UI Route Creation From Feishu Groups

**Files:**
- Modify: `lib/modules/feishu_monitor/feishu_monitor_center_page.dart`
- Modify: `test/modules/feishu_monitor/feishu_monitor_center_page_test.dart`

- [ ] **Step 1: Update fake settings store for route settings**

In `test/modules/feishu_monitor/feishu_monitor_center_page_test.dart`, update `_MemoryForwardingSettingsStore` default:

```dart
class _MemoryForwardingSettingsStore
    implements FeishuMonitorForwardingSettingsStore {
  _MemoryForwardingSettingsStore({
    this.initial = const FeishuMonitorForwardingSettings(
      enabled: false,
      routes: <FeishuMonitorForwardingRoute>[],
      legacyTargetGroupId: '',
    ),
  });

  final FeishuMonitorForwardingSettings initial;
  FeishuMonitorForwardingSettings? saved;

  @override
  Future<FeishuMonitorForwardingSettings> load() async {
    return saved ?? initial;
  }

  @override
  Future<void> save(FeishuMonitorForwardingSettings settings) async {
    saved = settings;
  }
}
```

- [ ] **Step 2: Add failing widget test for creating a route from a Feishu group**

Add this widget test:

```dart
testWidgets('creates forwarding route from Feishu group row', (tester) async {
  final settingsStore = _MemoryForwardingSettingsStore();

  await _pumpCenter(
    tester,
    status: _onlineStatus(
      probeObservedAt: probeObservedAt,
      observedConversations: observedConversations,
      observedMessages: observedMessages.take(1).toList(),
      recentEvents: recentEvents.take(2).toList(),
    ),
    settingsStore: settingsStore,
    loadTargetGroups: () async => <GroupInfo>[
      GroupInfo(groupNo: 'wk_alpha', name: '悟空 Alpha 群', save: 1, status: 1),
      GroupInfo(groupNo: 'wk_beta', name: '悟空 Beta 群', save: 1, status: 1),
    ],
  );

  await _tapVisible(tester, find.text('飞书群组'));
  await _tapVisible(
    tester,
    find.byKey(const ValueKey('feishu-route-configure-feed:alpha')),
  );
  await _tapVisible(tester, find.text('悟空 Alpha 群'));

  final saved = settingsStore.saved;
  expect(saved, isNotNull);
  expect(saved!.routes, hasLength(1));
  expect(saved.routes.single.sourceConversationId, 'feed:alpha');
  expect(saved.routes.single.sourceConversationName, 'Project Phoenix');
  expect(saved.routes.single.targetGroupId, 'wk_alpha');
  expect(saved.routes.single.targetGroupName, '悟空 Alpha 群');
});
```

- [ ] **Step 3: Run widget test and confirm it fails**

Run:

```powershell
D:\Apps\flutter\bin\flutter.bat test test/modules/feishu_monitor/feishu_monitor_center_page_test.dart
```

Expected: FAIL because the group row has no per-conversation route configuration action yet.

- [ ] **Step 4: Replace page state fields with settings object**

In `_FeishuMonitorCenterPageState`, replace:

```dart
bool _autoForwarding = false;
late final TextEditingController _targetGroupController;
```

with:

```dart
FeishuMonitorForwardingSettings _forwardingSettings =
    const FeishuMonitorForwardingSettings(
  enabled: false,
  routes: <FeishuMonitorForwardingRoute>[],
  legacyTargetGroupId: '',
);
```

Remove `_targetGroupController` initialization and disposal.

Update `_loadForwardingSettings`:

```dart
Future<void> _loadForwardingSettings() async {
  final settings = await widget.forwardingSettingsStore.load();
  if (!mounted) {
    return;
  }
  setState(() {
    _forwardingSettings = settings;
  });
  _syncAutoForwardTimer();
}
```

Update `_saveForwardingSettings`:

```dart
Future<void> _saveForwardingSettings(FeishuMonitorForwardingSettings settings) {
  _forwardingSettings = settings;
  return widget.forwardingSettingsStore.save(settings);
}
```

- [ ] **Step 5: Add route upsert interaction**

Add this method to `_FeishuMonitorCenterPageState`:

```dart
Future<void> _configureRouteForConversation(
  FeishuMonitorObservedConversation conversation,
) async {
  final selected = await showModalBottomSheet<GroupInfo>(
    context: context,
    backgroundColor: WKColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(WKRadius.lg)),
    ),
    builder: (context) {
      return _TargetGroupPicker(loadGroups: widget.loadTargetGroups);
    },
  );
  if (selected == null || !mounted) {
    return;
  }

  final now = DateTime.now().toUtc();
  final targetName = await _resolveTargetGroupTitle(selected);
  final route = FeishuMonitorForwardingRoute(
    id: _routeIdForConversation(conversation),
    enabled: true,
    sourceConversationId: conversation.id,
    sourceConversationName: conversation.name,
    sourceConversationType: conversation.type,
    targetGroupId: selected.groupNo,
    targetGroupName: targetName,
    createdAt: now,
    updatedAt: now,
  );
  final routes = <FeishuMonitorForwardingRoute>[
    for (final existing in _forwardingSettings.routes)
      if (existing.sourceConversationId.trim() != conversation.id.trim())
        existing,
    route,
  ];
  final nextSettings = _forwardingSettings.copyWith(routes: routes);
  setState(() {
    _forwardingSettings = nextSettings;
  });
  await widget.forwardingSettingsStore.save(nextSettings);
}
```

Add these helpers near target group helpers:

```dart
String _routeIdForConversation(FeishuMonitorObservedConversation conversation) {
  final id = conversation.id.trim();
  if (id.isNotEmpty) {
    return 'route_${id.replaceAll(RegExp(r'[^a-zA-Z0-9_-]+'), '_')}';
  }
  return 'route_${normalizeFeishuMonitorRouteName(conversation.name).replaceAll(' ', '_')}';
}

Future<String> _resolveTargetGroupTitle(GroupInfo group) async {
  final explicitName = _targetGroupDisplayName(group);
  if (explicitName.isNotEmpty) {
    return explicitName;
  }
  final cachedName = await _cachedTargetGroupDisplayName(group.groupNo);
  return cachedName.isEmpty ? group.groupNo : cachedName;
}
```

- [ ] **Step 6: Pass routes into tab body**

Update `_ConsoleTabBody` constructor and fields:

```dart
const _ConsoleTabBody({
  required this.selected,
  required this.status,
  required this.forwardingSettings,
  required this.onConfigureRoute,
});

final FeishuMonitorForwardingSettings forwardingSettings;
final ValueChanged<FeishuMonitorObservedConversation> onConfigureRoute;
```

Update page build call:

```dart
_ConsoleTabBody(
  selected: _selectedTab,
  status: status,
  forwardingSettings: _forwardingSettings,
  onConfigureRoute: _configureRouteForConversation,
)
```

In `_ConsoleTabBody.build`, pass `forwardingSettings.routes` to rules and groups tabs and pass `onConfigureRoute` to groups.

- [ ] **Step 7: Add group-row configure button**

Update `_FeishuGroupsTab` to accept:

```dart
final List<FeishuMonitorForwardingRoute> routes;
final ValueChanged<FeishuMonitorObservedConversation> onConfigureRoute;
```

For each conversation row, compute the route with this local helper:

```dart
FeishuMonitorForwardingRoute? _routeForConversation(
  List<FeishuMonitorForwardingRoute> routes,
  FeishuMonitorObservedConversation conversation,
) {
  for (final route in routes) {
    if (route.sourceConversationId.trim() == conversation.id.trim()) {
      return route;
    }
  }
  return null;
}
```

Add an action button in the row:

```dart
TextButton(
  key: ValueKey('feishu-route-configure-${item.id}'),
  onPressed: () => onConfigureRoute(item),
  child: Text(route == null ? '设置转发' : '修改目标'),
)
```

Display route status as:

```dart
route == null
    ? '未配置'
    : route.enabled
        ? '已转发到 ${route.targetGroupName.isEmpty ? route.targetGroupId : route.targetGroupName}'
        : '已停用'
```

- [ ] **Step 8: Verify route creation widget test passes**

Run:

```powershell
D:\Apps\flutter\bin\flutter.bat test test/modules/feishu_monitor/feishu_monitor_center_page_test.dart
```

Expected: PASS after updating old single-target assertions to route-based assertions.

---

### Task 5: Rules Tab, Manual Forwarding, And Auto Forwarding

**Files:**
- Modify: `lib/modules/feishu_monitor/feishu_monitor_center_page.dart`
- Modify: `test/modules/feishu_monitor/feishu_monitor_center_page_test.dart`

- [ ] **Step 1: Update fake forwarding service**

If `test/modules/feishu_monitor/feishu_monitor_center_page_test.dart` does not already have a `_route` helper, add this near the other test helpers:

```dart
FeishuMonitorForwardingRoute _route({
  String id = 'route_1',
  bool enabled = true,
  String sourceConversationId = 'feed:alpha',
  String sourceConversationName = 'Project Phoenix',
  String sourceConversationType = 'group',
  String targetGroupId = 'wk_alpha',
  String targetGroupName = '悟空 Alpha 群',
}) {
  return FeishuMonitorForwardingRoute(
    id: id,
    enabled: enabled,
    sourceConversationId: sourceConversationId,
    sourceConversationName: sourceConversationName,
    sourceConversationType: sourceConversationType,
    targetGroupId: targetGroupId,
    targetGroupName: targetGroupName,
    createdAt: DateTime.parse('2026-05-09T01:00:00Z'),
    updatedAt: DateTime.parse('2026-05-09T01:00:00Z'),
  );
}
```

Replace `_FakeForwardingService` override with:

```dart
class _FakeForwardingService extends FeishuMonitorForwardingService {
  _FakeForwardingService() : super(sender: _NoopTextSender());

  FeishuMonitorForwardingSettings? lastSettings;
  List<FeishuMonitorMessageEvent> lastEvents =
      const <FeishuMonitorMessageEvent>[];

  @override
  Future<FeishuMonitorForwardingResult> forwardRoutedRecentEvents({
    required FeishuMonitorForwardingSettings settings,
    required List<FeishuMonitorMessageEvent> events,
  }) async {
    lastSettings = settings;
    lastEvents = List<FeishuMonitorMessageEvent>.from(events);
    return FeishuMonitorForwardingResult(
      sent: events.length,
      skippedUnmatched: 0,
      failed: 0,
    );
  }
}
```

Update `_FailingForwardingService` to override `forwardRoutedRecentEvents` and throw the configured error.

- [ ] **Step 2: Add failing manual forwarding test for routes**

Replace the old manual forwarding test with:

```dart
testWidgets('manual forwarding sends recent events through configured routes', (
  tester,
) async {
  final forwardingService = _FakeForwardingService();
  final settingsStore = _MemoryForwardingSettingsStore(
    initial: FeishuMonitorForwardingSettings(
      enabled: true,
      routes: <FeishuMonitorForwardingRoute>[
        _route(
          id: 'route_alpha',
          sourceConversationId: 'feed:alpha',
          sourceConversationName: 'Project Phoenix',
          targetGroupId: 'wk_alpha',
          targetGroupName: '悟空 Alpha 群',
        ),
      ],
      legacyTargetGroupId: '',
    ),
  );

  await _pumpCenter(
    tester,
    status: _onlineStatus(
      probeObservedAt: probeObservedAt,
      observedConversations: observedConversations,
      observedMessages: observedMessages.take(1).toList(),
      recentEvents: recentEvents.take(2).toList(),
    ),
    forwardingService: forwardingService,
    settingsStore: settingsStore,
  );

  await _tapVisible(
    tester,
    find.byKey(const ValueKey('feishu-monitor-forward-recent-button')),
  );

  expect(forwardingService.lastSettings?.routes, hasLength(1));
  expect(forwardingService.lastSettings?.routes.single.targetGroupId, 'wk_alpha');
  expect(forwardingService.lastEvents, hasLength(2));
  expect(find.textContaining('已转发 2 条'), findsOneWidget);
});
```

- [ ] **Step 3: Add failing rules tab test**

Add:

```dart
testWidgets('rules tab renders multiple forwarding routes', (tester) async {
  await _pumpCenter(
    tester,
    status: _onlineStatus(
      probeObservedAt: probeObservedAt,
      observedConversations: observedConversations,
      observedMessages: observedMessages.take(1).toList(),
      recentEvents: recentEvents.take(2).toList(),
    ),
    settingsStore: _MemoryForwardingSettingsStore(
      initial: FeishuMonitorForwardingSettings(
        enabled: true,
        routes: <FeishuMonitorForwardingRoute>[
          _route(
            id: 'route_alpha',
            sourceConversationId: 'feed:alpha',
            sourceConversationName: 'Project Phoenix',
            targetGroupId: 'wk_alpha',
            targetGroupName: '悟空 Alpha 群',
          ),
          _route(
            id: 'route_mm12',
            sourceConversationId: 'feed:mm12',
            sourceConversationName: 'MM12 交流群',
            targetGroupId: 'wk_mm12',
            targetGroupName: '悟空 MM12 群',
          ),
        ],
        legacyTargetGroupId: '',
      ),
    ),
  );

  await _tapVisible(tester, find.text('转发规则'));

  expect(find.text('Project Phoenix'), findsWidgets);
  expect(find.text('悟空 Alpha 群'), findsOneWidget);
  expect(find.text('MM12 交流群'), findsOneWidget);
  expect(find.text('悟空 MM12 群'), findsOneWidget);
});
```

- [ ] **Step 4: Run widget tests and confirm failures**

Run:

```powershell
D:\Apps\flutter\bin\flutter.bat test test/modules/feishu_monitor/feishu_monitor_center_page_test.dart
```

Expected: FAIL because page still calls the single-rule forwarding method and rules tab still renders one default row.

- [ ] **Step 5: Update manual and auto forwarding to use routes**

Update `_refresh` forwarding gate:

```dart
if (_forwardingSettings.enabled &&
    _forwardingSettings.routes.any((route) => route.enabled)) {
  await _forwardRecentEvents();
}
```

Update `_forwardRecentEvents`:

```dart
final result = await widget.forwardingService.forwardRoutedRecentEvents(
  settings: _forwardingSettings,
  events: status.recentEvents,
);
```

Update result text:

```dart
_forwardingResult =
    '已转发 ${result.sent} 条，重复跳过 ${result.skippedDuplicate} 条，未匹配 ${result.skippedUnmatched} 条，失败 ${result.failed} 条';
```

Update auto switch handling:

```dart
onAutoForwardingChanged: (value) async {
  final nextSettings = _forwardingSettings.copyWith(enabled: value);
  setState(() {
    _forwardingSettings = nextSettings;
  });
  _syncAutoForwardTimer();
  await widget.forwardingSettingsStore.save(nextSettings);
  if (value) {
    await _forwardRecentEvents();
  }
},
```

- [ ] **Step 6: Replace quick action target field with route summary**

In `_QuickActions`, remove the target group text field and `onTargetChanged` callback. Keep:

- start capture
- stop capture
- reload Feishu
- forward recent events
- auto forwarding switch
- select target action removed from quick actions because target selection is now per Feishu group row

Add a compact summary line:

```dart
Text(
  '已配置 ${routeCount} 条转发规则，未配置来源默认跳过',
  style: const TextStyle(fontSize: 12, color: WKColors.colorGray),
)
```

Pass `routeCount: _forwardingSettings.routes.length`.

- [ ] **Step 7: Render multi-route rules table**

Update `_ForwardingRulesTab` to accept `List<FeishuMonitorForwardingRoute> routes`.

If `routes.isEmpty`, show:

```dart
const Text('还没有转发规则，请先到飞书群组页为来源群设置目标群。')
```

If routes exist, render rows:

```dart
for (final route in routes)
  [
    route.enabled ? '启用' : '停用',
    route.sourceConversationName.isEmpty
        ? route.sourceConversationId
        : route.sourceConversationName,
    route.targetGroupName.isEmpty ? route.targetGroupId : route.targetGroupName,
    '本地 SDK',
    '0',
    '0',
    '编辑  测试  删除',
  ]
```

Keep action labels static in this slice unless the widget tests require interaction. Interactive edit/delete can be added after the route creation and forwarding path is stable.

- [ ] **Step 8: Update system settings display**

In `_SystemSettingsTab`, replace the old target group row with:

```dart
_FormLine('自动转发', autoForwarding ? '开启' : '关闭'),
_FormLine('转发规则数', '$routeCount'),
const _FormLine('未匹配来源', '默认跳过'),
const _FormLine('去重窗口', '当前运行期'),
const _FormLine('失败重试', '下一阶段接入'),
const _FormLine('投递通道', '本地 SDK'),
```

- [ ] **Step 9: Verify widget tests pass**

Run:

```powershell
D:\Apps\flutter\bin\flutter.bat test test/modules/feishu_monitor/feishu_monitor_center_page_test.dart
```

Expected: PASS.

---

### Task 6: Focused Verification And Manual Test Prep

**Files:**
- Verify: `lib/modules/feishu_monitor/feishu_monitor_forwarding_service.dart`
- Verify: `lib/modules/feishu_monitor/feishu_monitor_center_page.dart`
- Verify: `test/modules/feishu_monitor/feishu_monitor_forwarding_service_test.dart`
- Verify: `test/modules/feishu_monitor/feishu_monitor_center_page_test.dart`

- [ ] **Step 1: Run all Feishu monitor tests**

Run:

```powershell
D:\Apps\flutter\bin\flutter.bat test test/modules/feishu_monitor/feishu_monitor_forwarding_service_test.dart test/modules/feishu_monitor/feishu_monitor_shell_client_test.dart test/modules/feishu_monitor/feishu_monitor_center_page_test.dart
```

Expected: PASS.

- [ ] **Step 2: Run analyzer on changed Feishu monitor files**

Run:

```powershell
D:\Apps\flutter\bin\flutter.bat analyze lib/modules/feishu_monitor test/modules/feishu_monitor
```

Expected: `No issues found!`

- [ ] **Step 3: Build Windows debug app**

If `InfoEquity.exe` is running, close it first from Task Manager or stop the process. Then run:

```powershell
D:\Apps\flutter\bin\flutter.bat build windows --debug
```

Expected: build succeeds.

- [ ] **Step 4: Manual joint test with two Feishu groups**

Use the already running Feishu shell and WuKongIM desktop.

1. Open `系统管理 -> 飞书信息监控中心`.
2. Confirm Shell online, Feishu logged in, and capture running.
3. Open `飞书群组`.
4. Choose Feishu group A, click `设置转发`, select WuKongIM group 1 by nickname.
5. Choose Feishu group B, click `设置转发`, select WuKongIM group 2 by nickname.
6. Open `转发规则` and confirm two routes are visible.
7. Send one new Feishu message in group A and one in group B.
8. Click `转发最近事件`.
9. Confirm group A message appears in WuKongIM group 1.
10. Confirm group B message appears in WuKongIM group 2.
11. Send a message in an unconfigured Feishu group C.
12. Click `转发最近事件` again and confirm the result text includes an unmatched count.

Expected: configured groups forward to their own targets, unconfigured groups are skipped.

---

## Self-Review

- Spec coverage: model, local persistence, id/name matching, unmatched skip, manual forwarding, auto forwarding, target group nickname selection, and focused manual test are covered.
- Scope control: one source maps to one active target in this slice. Multi-destination, cloud sync, media forwarding, and batch import remain outside this plan.
- Compatibility: the existing single-target send path remains available for older unit tests and local fallback, but the monitor center switches to routed forwarding for multi-group behavior.
- Ambiguity removed: unmatched Feishu events are skipped and counted; legacy single-target settings are a hint only and do not become a global catch-all route.

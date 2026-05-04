# Endpoint And UIKit Rebuild Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rebuild the Flutter client's main UI composition around typed slot registries so that the Android reference extension points for home actions, contacts header, personal center, settings, chat toolbar, and group detail are live on the new Flutter mainline.

**Architecture:** This plan adds a new `lib/wk_endpoint` typed slot kernel, keeps the current routed app shell intact, and ports the highest-value Android endpoint surfaces away from hardcoded widget composition. Existing Flutter pages remain the production entry points, but their menus and injected sections are moved behind idempotent slot installers so dormant or future modules can register behavior the same way the Android reference uses `EndpointManager`.

**Tech Stack:** Flutter, flutter_riverpod, existing WKIM SDK, widget tests, flutter_test, PowerShell

---

**Workspace Note:** This working copy does not currently contain `.git` metadata. The `git add` and `git commit` commands below are the correct checkpoints for the canonical repository checkout. In this local copy, record the same checkpoints together with verification output until the repository is initialized.

## Scope Boundary

This plan only implements `Phase 2: Endpoint and UIKit Rebuild` from `docs/superpowers/specs/2026-04-03-complete-feature-alignment-design.md`.

In scope:

- typed slot kernel under `lib/wk_endpoint`
- legacy endpoint import strategy for the currently dormant Flutter `EndpointManager`
- Android-style top-right home popup menu assembly for conversation and contacts
- Android-style contacts header assembly
- Android-style personal center assembly
- settings section assembly
- chat toolbar and function panel assembly
- group detail extension point assembly
- widget, compile, and registry tests proving the extension points are live

Out of scope for this plan:

- login and device-login completeness
- chat long-press parity and message action completeness
- scoped search parity
- push vendor parity
- call parity
- large-scale retirement of old `wukong_base/endpoint/**` files

## Android Reference Anchors

The implementation in this plan is intentionally pinned to the Android reference surfaces below.

- `wkbase/src/main/java/com/chat/base/endpoint/EndpointCategory.java`
  - `personalCenter`
  - `mailList`
  - `tabMenus`
  - `wkChatToolBar`
  - `chatFunction`
  - `chatSettingCell`
  - `wkExitChat`
- `wkuikit/src/main/java/com/chat/uikit/fragment/ContactsFragment.java`
  - contacts header is assembled from `EndpointCategory.mailList`
  - top-right popup uses `EndpointCategory.tabMenus`
- `wkuikit/src/main/java/com/chat/uikit/fragment/MyFragment.java`
  - personal center rows are assembled from `EndpointCategory.personalCenter`
- `wkuikit/src/main/java/com/chat/uikit/chat/ChatPanelManager.kt`
  - toolbar items come from `EndpointCategory.wkChatToolBar`
  - function panel items come from `EndpointCategory.chatFunction`
- `wkuikit/src/main/java/com/chat/uikit/group/GroupDetailActivity.java`
  - optional sections are injected through `msg_remind_view`, `msg_receipt_view`, `chat_setting_msg_privacy`, `group_avatar_view`, `group_manager_view`, and `chat_pwd_view`

## File Structure

### New Files

- `lib/wk_endpoint/core/slot_descriptor.dart`
  - Typed slot identifiers.
- `lib/wk_endpoint/core/slot_entry.dart`
  - Slot payload builder and visibility predicate definition.
- `lib/wk_endpoint/core/slot_registry.dart`
  - Shared registry, owner scopes, idempotency helpers, and resolution logic.
- `lib/wk_endpoint/providers/slot_registry_provider.dart`
  - Riverpod provider for the shared slot registry.
- `lib/wk_endpoint/legacy/legacy_endpoint_importer.dart`
  - Imports dormant string-based endpoint registrations into typed slots.
- `lib/wk_endpoint/slots/home_slots.dart`
  - Contracts for Android-style top-right home popup actions.
- `lib/wk_endpoint/slots/contacts_slots.dart`
  - Contracts for contacts header menu slots.
- `lib/wk_endpoint/slots/personal_center_slots.dart`
  - Contracts for personal center rows.
- `lib/wk_endpoint/slots/settings_slots.dart`
  - Contracts for settings sections and cells.
- `lib/wk_endpoint/slots/chat_slots.dart`
  - Contracts for chat toolbar items and chat function panel items.
- `lib/wk_endpoint/slots/group_detail_slots.dart`
  - Contracts for group detail extension points.
- `lib/modules/home/home_top_menu_slot_assembly.dart`
  - Default Android-aligned top-right popup menu installers and resolvers.
- `lib/modules/contacts/contacts_slot_assembly.dart`
  - Default Android-aligned contacts header installers and resolvers.
- `lib/modules/user/user_slot_assembly.dart`
  - Default Android-aligned personal center installers and resolvers.
- `lib/wukong_uikit/setting/setting_slot_assembly.dart`
  - Default settings section installers and resolvers.
- `lib/modules/chat/chat_toolbar_slot_assembly.dart`
  - Default chat toolbar and function panel installers and render helpers.
- `lib/wukong_uikit/group/group_detail_slot_assembly.dart`
  - Group detail extension-point resolver for injected optional sections.
- `test/wk_endpoint/slot_registry_test.dart`
  - Covers registry sorting, filtering, scope disposal, and idempotency.
- `test/wk_endpoint/legacy_endpoint_importer_test.dart`
  - Covers migration from dormant legacy endpoint categories into typed slots.
- `test/modules/home/home_top_menu_slot_assembly_test.dart`
  - Covers Android ordering and enablement for home popup actions.
- `test/modules/contacts/contacts_slot_assembly_test.dart`
  - Covers default contacts header resolution and request badge wiring.
- `test/modules/user/user_page_slot_assembly_test.dart`
  - Covers default personal center menu resolution.
- `test/wukong_uikit/setting/setting_page_slot_assembly_test.dart`
  - Covers settings section ordering and destructive row rendering metadata.
- `test/modules/chat/chat_toolbar_slot_assembly_test.dart`
  - Covers toolbar ordering and function panel defaults.
- `test/wukong_uikit/group/group_detail_slot_assembly_test.dart`
  - Covers group detail extension-point routing.
- `test/modules/shell/phase2_endpoint_surface_compile_test.dart`
  - Covers installer idempotency from a shared registry.

### Existing Files To Modify

- `lib/modules/conversation/conversation_list_page.dart`
  - Replace hardcoded top-right popup menu assembly with typed slot resolution.
- `lib/modules/contacts/contacts_page.dart`
  - Replace hardcoded header rows and top-right popup menu assembly with typed slot resolution.
- `lib/modules/user/user_page.dart`
  - Replace local `UserPageMenuEntry` assembly with typed personal center resolution.
- `lib/wukong_uikit/setting/setting_page.dart`
  - Replace static settings list composition with typed section resolution.
- `lib/modules/chat/chat_page_shell.dart`
  - Replace hardcoded toolbar and function panel item assembly with typed slot resolution.
- `lib/wukong_uikit/group/group_detail_page.dart`
  - Resolve group detail extension widgets through typed insertion points.

## Verification Commands Used Throughout

- `dart analyze lib/wk_endpoint lib/modules/home lib/modules/contacts lib/modules/user lib/modules/chat lib/wukong_uikit/group lib/wukong_uikit/setting`
- `flutter test test/wk_endpoint/slot_registry_test.dart test/wk_endpoint/legacy_endpoint_importer_test.dart`
- `flutter test test/modules/home/home_top_menu_slot_assembly_test.dart test/modules/contacts/contacts_slot_assembly_test.dart`
- `flutter test test/modules/user/user_page_slot_assembly_test.dart test/wukong_uikit/setting/setting_page_slot_assembly_test.dart`
- `flutter test test/modules/chat/chat_toolbar_slot_assembly_test.dart test/wukong_uikit/group/group_detail_slot_assembly_test.dart`
- `flutter test test/modules/shell/phase2_endpoint_surface_compile_test.dart test/modules/profile/profile_pages_compile_test.dart test/modules/shell/android_ui_parity_shell_test.dart`

### Task 1: Create The Typed Slot Kernel

**Files:**
- Create: `lib/wk_endpoint/core/slot_descriptor.dart`
- Create: `lib/wk_endpoint/core/slot_entry.dart`
- Create: `lib/wk_endpoint/core/slot_registry.dart`
- Create: `lib/wk_endpoint/providers/slot_registry_provider.dart`
- Test: `test/wk_endpoint/slot_registry_test.dart`

- [ ] **Step 1: Write the failing slot-registry tests**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/wk_endpoint/core/slot_descriptor.dart';
import 'package:wukong_im_app/wk_endpoint/core/slot_entry.dart';
import 'package:wukong_im_app/wk_endpoint/core/slot_registry.dart';

void main() {
  const demoSlot = SlotDescriptor<int, String>('demo.slot');

  test('registry resolves matching entries by priority descending', () {
    final registry = SlotRegistry();

    registry.register(
      demoSlot,
      const SlotEntry<int, String>(
        id: 'late',
        priority: 10,
        build: _lateBuilder,
      ),
    );
    registry.register(
      demoSlot,
      const SlotEntry<int, String>(
        id: 'even-only',
        priority: 50,
        predicate: _evenOnly,
        build: _evenBuilder,
      ),
    );
    registry.register(
      demoSlot,
      const SlotEntry<int, String>(
        id: 'first',
        priority: 100,
        build: _firstBuilder,
      ),
    );

    expect(registry.resolve(demoSlot, 1), <String>['first:1', 'late:1']);
    expect(
      registry.resolve(demoSlot, 2),
      <String>['first:2', 'even:2', 'late:2'],
    );
  });

  test('scope disposal only removes entries owned by that scope', () {
    final registry = SlotRegistry();
    final firstScope = registry.scope('scope:first');
    final secondScope = registry.scope('scope:second');

    firstScope.register(
      demoSlot,
      const SlotEntry<int, String>(id: 'first', build: _constantA),
    );
    secondScope.register(
      demoSlot,
      const SlotEntry<int, String>(id: 'second', build: _constantB),
    );

    expect(registry.resolve(demoSlot, 0), <String>['a', 'b']);

    firstScope.dispose();

    expect(registry.resolve(demoSlot, 0), <String>['b']);
  });

  test('containsId supports idempotent installers', () {
    final registry = SlotRegistry();
    registry.register(
      demoSlot,
      const SlotEntry<int, String>(id: 'one', build: _constantA),
    );

    expect(registry.containsId(demoSlot, 'one'), isTrue);
    expect(registry.containsId(demoSlot, 'two'), isFalse);
  });
}

String _lateBuilder(int value) => 'late:$value';
String _evenBuilder(int value) => 'even:$value';
String _firstBuilder(int value) => 'first:$value';
bool _evenOnly(int value) => value.isEven;
String _constantA(int _) => 'a';
String _constantB(int _) => 'b';
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/wk_endpoint/slot_registry_test.dart`
Expected: FAIL with missing `SlotDescriptor`, `SlotEntry`, or `SlotRegistry`

- [ ] **Step 3: Implement the typed slot identifier and entry definitions**

```dart
// lib/wk_endpoint/core/slot_descriptor.dart
import 'package:flutter/foundation.dart';

@immutable
class SlotDescriptor<TContext, TPayload> {
  const SlotDescriptor(this.name);

  final String name;

  @override
  bool operator ==(Object other) {
    return other is SlotDescriptor && other.name == name;
  }

  @override
  int get hashCode => name.hashCode;

  @override
  String toString() => 'SlotDescriptor($name)';
}
```

```dart
// lib/wk_endpoint/core/slot_entry.dart
import 'package:flutter/foundation.dart';

typedef SlotPredicate<TContext> = bool Function(TContext context);
typedef SlotBuilder<TContext, TPayload> = TPayload Function(TContext context);

@immutable
class SlotEntry<TContext, TPayload> {
  const SlotEntry({
    required this.id,
    required this.build,
    this.priority = 0,
    this.predicate,
  });

  final String id;
  final int priority;
  final SlotPredicate<TContext>? predicate;
  final SlotBuilder<TContext, TPayload> build;

  bool matches(TContext context) => predicate?.call(context) ?? true;
}
```

- [ ] **Step 4: Implement the shared registry, owner scopes, and provider**

```dart
// lib/wk_endpoint/core/slot_registry.dart
import 'package:flutter/foundation.dart';

import 'slot_descriptor.dart';
import 'slot_entry.dart';

class SlotRegistry {
  final Map<String, List<_SlotRecord<Object?, Object?>>> _records =
      <String, List<_SlotRecord<Object?, Object?>>>{};

  SlotRegistration register<TContext, TPayload>(
    SlotDescriptor<TContext, TPayload> descriptor,
    SlotEntry<TContext, TPayload> entry, {
    String owner = 'global',
  }) {
    final list =
        _records.putIfAbsent(
          descriptor.name,
          () => <_SlotRecord<Object?, Object?>>[],
        );
    final record = _SlotRecord<TContext, TPayload>(
      owner: owner,
      descriptor: descriptor,
      entry: entry,
    );
    list.add(record);
    return SlotRegistration._(() {
      list.remove(record);
      if (list.isEmpty) {
        _records.remove(descriptor.name);
      }
    });
  }

  List<TPayload> resolve<TContext, TPayload>(
    SlotDescriptor<TContext, TPayload> descriptor,
    TContext context,
  ) {
    final list = _records[descriptor.name];
    if (list == null || list.isEmpty) {
      return const <TPayload>[];
    }

    final typed = list.cast<_SlotRecord<TContext, TPayload>>().toList()
      ..sort((left, right) => right.entry.priority.compareTo(left.entry.priority));

    return typed
        .where((record) => record.entry.matches(context))
        .map((record) => record.entry.build(context))
        .toList(growable: false);
  }

  bool containsId<TContext, TPayload>(
    SlotDescriptor<TContext, TPayload> descriptor,
    String id,
  ) {
    final list = _records[descriptor.name];
    if (list == null) {
      return false;
    }
    return list.any((record) => record.entry.id == id);
  }

  SlotScope scope(String owner) => SlotScope._(this, owner);

  void unregisterOwner(String owner) {
    final names = _records.keys.toList(growable: false);
    for (final name in names) {
      final list = _records[name];
      if (list == null) {
        continue;
      }
      list.removeWhere((record) => record.owner == owner);
      if (list.isEmpty) {
        _records.remove(name);
      }
    }
  }
}

class SlotScope {
  SlotScope._(this._registry, this._owner);

  final SlotRegistry _registry;
  final String _owner;

  SlotRegistration register<TContext, TPayload>(
    SlotDescriptor<TContext, TPayload> descriptor,
    SlotEntry<TContext, TPayload> entry,
  ) {
    return _registry.register(descriptor, entry, owner: _owner);
  }

  void dispose() {
    _registry.unregisterOwner(_owner);
  }
}

class SlotRegistration {
  SlotRegistration._(this._dispose);

  final VoidCallback _dispose;
  bool _disposed = false;

  void dispose() {
    if (_disposed) {
      return;
    }
    _disposed = true;
    _dispose();
  }
}

class _SlotRecord<TContext, TPayload> {
  const _SlotRecord({
    required this.owner,
    required this.descriptor,
    required this.entry,
  });

  final String owner;
  final SlotDescriptor<TContext, TPayload> descriptor;
  final SlotEntry<TContext, TPayload> entry;
}
```

```dart
// lib/wk_endpoint/providers/slot_registry_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/slot_registry.dart';

final slotRegistryProvider = Provider<SlotRegistry>((ref) {
  return SlotRegistry();
});
```

- [ ] **Step 5: Run analysis and the registry tests**

Run: `dart analyze lib/wk_endpoint/core lib/wk_endpoint/providers`
Expected: PASS with no analyzer errors

Run: `flutter test test/wk_endpoint/slot_registry_test.dart`
Expected: PASS with 3 tests green

- [ ] **Step 6: Checkpoint**

```bash
git add lib/wk_endpoint/core/slot_descriptor.dart lib/wk_endpoint/core/slot_entry.dart lib/wk_endpoint/core/slot_registry.dart lib/wk_endpoint/providers/slot_registry_provider.dart test/wk_endpoint/slot_registry_test.dart
git commit -m "refactor: add typed endpoint slot registry"
```

### Task 2: Define Surface Slot Contracts And The Legacy Importer

**Files:**
- Create: `lib/wk_endpoint/legacy/legacy_endpoint_importer.dart`
- Create: `lib/wk_endpoint/slots/home_slots.dart`
- Create: `lib/wk_endpoint/slots/contacts_slots.dart`
- Create: `lib/wk_endpoint/slots/personal_center_slots.dart`
- Create: `lib/wk_endpoint/slots/settings_slots.dart`
- Create: `lib/wk_endpoint/slots/chat_slots.dart`
- Create: `lib/wk_endpoint/slots/group_detail_slots.dart`
- Test: `test/wk_endpoint/legacy_endpoint_importer_test.dart`

- [ ] **Step 1: Write the failing legacy-import tests**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/wk_endpoint/core/slot_registry.dart';
import 'package:wukong_im_app/wk_endpoint/legacy/legacy_endpoint_importer.dart';
import 'package:wukong_im_app/wk_endpoint/slots/contacts_slots.dart';
import 'package:wukong_im_app/wk_endpoint/slots/personal_center_slots.dart';
import 'package:wukong_im_app/wukong_base/endpoint/endpoint_handler.dart';
import 'package:wukong_im_app/wukong_base/endpoint/endpoint_manager.dart';
import 'package:wukong_im_app/wukong_base/endpoint/entity/contacts_menu.dart';
import 'package:wukong_im_app/wukong_base/endpoint/entity/personal_info_menu.dart';

void main() {
  final manager = EndpointManager.getInstance();

  setUp(() {
    manager.clear();
  });

  test('legacy importer moves contacts mail_list entries into typed slots', () {
    manager.register(
      'mail_list_groups',
      'mail_list',
      90,
      SimpleFunctionHandler(([dynamic _]) {
        return ContactsMenu(sid: 'group', text: 'Saved groups');
      }),
    );
    manager.register(
      'mail_list_friend',
      'mail_list',
      100,
      SimpleFunctionHandler(([dynamic param]) {
        final context = param as ContactsHeaderSlotContext;
        return ContactsMenu(
          sid: 'friend',
          text: 'New friends',
          badgeNum: context.pendingRequestCount,
        );
      }),
    );

    final registry = SlotRegistry();
    LegacyEndpointImporter(manager: manager, registry: registry)
        .importContactsHeader();

    final items = registry.resolve(
      contactsHeaderSlot,
      const ContactsHeaderSlotContext(pendingRequestCount: 5),
    );

    expect(items.map((item) => item.sid), <String>['friend', 'group']);
    expect(items.first.badgeNum, 5);
  });

  test('legacy importer moves personal_center entries into typed slots', () {
    manager.register(
      'personal_center_currency',
      'personal_center',
      2,
      SimpleFunctionHandler(([dynamic param]) {
        final context = param as PersonalCenterSlotContext;
        return PersonalInfoMenu(
          sid: 'personal_center_currency',
          text: 'General',
          isNewVersion: context.hasNewVersion,
        );
      }),
    );

    final registry = SlotRegistry();
    LegacyEndpointImporter(manager: manager, registry: registry)
        .importPersonalCenter();

    final items = registry.resolve(
      personalCenterSlot,
      const PersonalCenterSlotContext(hasNewVersion: true),
    );

    expect(items.single.sid, 'personal_center_currency');
    expect(items.single.isNewVersion, isTrue);
  });
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/wk_endpoint/legacy_endpoint_importer_test.dart`
Expected: FAIL with missing slot contracts or missing `LegacyEndpointImporter`

- [ ] **Step 3: Create the typed slot contracts for all Phase 2 surfaces**

```dart
// lib/wk_endpoint/slots/home_slots.dart
import 'package:flutter/material.dart';

import '../../widgets/wk_screen_popup_menu.dart';
import '../core/slot_descriptor.dart';

@immutable
class HomeTopMenuContext {
  const HomeTopMenuContext({
    required this.hasConversations,
    required this.openCreateGroup,
    required this.openAddFriend,
    required this.openScan,
    required this.enterMultiSelect,
    required this.clearAllConversations,
  });

  final bool hasConversations;
  final VoidCallback openCreateGroup;
  final VoidCallback openAddFriend;
  final VoidCallback openScan;
  final VoidCallback enterMultiSelect;
  final VoidCallback clearAllConversations;
}

@immutable
class HomeTopMenuItem {
  const HomeTopMenuItem({
    required this.id,
    required this.title,
    this.assetIcon,
    this.icon,
    this.enabled = true,
    required this.onSelected,
  }) : assert(assetIcon != null || icon != null);

  final String id;
  final String title;
  final String? assetIcon;
  final IconData? icon;
  final bool enabled;
  final VoidCallback onSelected;

  WKScreenPopupMenuItem<HomeTopMenuItem> toPopupMenuItem() {
    return WKScreenPopupMenuItem<HomeTopMenuItem>(
      value: this,
      title: title,
      assetIcon: assetIcon,
      icon: icon,
      enabled: enabled,
    );
  }
}

const homeTopMenuSlot =
    SlotDescriptor<HomeTopMenuContext, HomeTopMenuItem>('home.top_menu');
```

```dart
// lib/wk_endpoint/slots/contacts_slots.dart
import '../../wukong_base/endpoint/entity/contacts_menu.dart';
import '../core/slot_descriptor.dart';

class ContactsHeaderSlotContext {
  const ContactsHeaderSlotContext({required this.pendingRequestCount});

  final int pendingRequestCount;
}

const contactsHeaderSlot = SlotDescriptor<
    ContactsHeaderSlotContext,
    ContactsMenu>('contacts.header');
```

```dart
// lib/wk_endpoint/slots/personal_center_slots.dart
import '../../wukong_base/endpoint/entity/personal_info_menu.dart';
import '../core/slot_descriptor.dart';

class PersonalCenterSlotContext {
  const PersonalCenterSlotContext({required this.hasNewVersion});

  final bool hasNewVersion;
}

const personalCenterSlot = SlotDescriptor<
    PersonalCenterSlotContext,
    PersonalInfoMenu>('personal.center');
```

```dart
// lib/wk_endpoint/slots/settings_slots.dart
import 'package:flutter/foundation.dart';

import '../core/slot_descriptor.dart';

enum SettingsCellStyle { normal, dangerCentered }

enum SettingsCellAccessory { arrow, none, about }

@immutable
class SettingsCellItem {
  const SettingsCellItem({
    required this.id,
    required this.title,
    required this.onTap,
    this.value,
    this.style = SettingsCellStyle.normal,
    this.accessory = SettingsCellAccessory.arrow,
    this.showNewVersionBadge = false,
  });

  final String id;
  final String title;
  final String? value;
  final SettingsCellStyle style;
  final SettingsCellAccessory accessory;
  final bool showNewVersionBadge;
  final VoidCallback onTap;
}

@immutable
class SettingsSectionItem {
  const SettingsSectionItem({
    required this.id,
    required this.cells,
  });

  final String id;
  final List<SettingsCellItem> cells;
}

@immutable
class SettingsSlotContext {
  const SettingsSlotContext({
    required this.darkModeStatus,
    required this.imageCacheSize,
    required this.hasNewVersion,
    required this.openThemeSettings,
    required this.openLanguageSettings,
    required this.openFontSizeSettings,
    required this.openChatBackgroundSettings,
    required this.clearImageCache,
    required this.openAppModules,
    required this.openThirdPartySharing,
    required this.openErrorLogs,
    required this.openAbout,
    required this.logout,
  });

  final String darkModeStatus;
  final String imageCacheSize;
  final bool hasNewVersion;
  final VoidCallback openThemeSettings;
  final VoidCallback openLanguageSettings;
  final VoidCallback openFontSizeSettings;
  final VoidCallback openChatBackgroundSettings;
  final VoidCallback clearImageCache;
  final VoidCallback openAppModules;
  final VoidCallback openThirdPartySharing;
  final VoidCallback openErrorLogs;
  final VoidCallback openAbout;
  final VoidCallback logout;
}

const settingsSectionSlot =
    SlotDescriptor<SettingsSlotContext, SettingsSectionItem>('settings.section');
```

```dart
// lib/wk_endpoint/slots/chat_slots.dart
import 'package:flutter/widgets.dart';

import '../../wukong_base/endpoint/entity/chat_toolbar_menu.dart';
import '../core/slot_descriptor.dart';

@immutable
class ChatToolbarSlotContext {
  const ChatToolbarSlotContext({
    required this.isGroup,
    required this.showEmojiPanel,
    required this.showFunctionPanel,
  });

  final bool isGroup;
  final bool showEmojiPanel;
  final bool showFunctionPanel;
}

const chatToolbarSlot = SlotDescriptor<
    ChatToolbarSlotContext,
    ChatToolBarMenu>('chat.toolbar');

const chatFunctionSlot = SlotDescriptor<
    ChatToolbarSlotContext,
    ChatFunctionMenu>('chat.function');
```

```dart
// lib/wk_endpoint/slots/group_detail_slots.dart
import 'package:flutter/material.dart';

import '../core/slot_descriptor.dart';

enum GroupDetailExtensionPoint {
  msgRemind,
  msgSettings,
  groupAvatar,
  groupManage,
  chatPassword,
}

@immutable
class GroupDetailExtensionContext {
  const GroupDetailExtensionContext({
    required this.point,
    required this.groupId,
    required this.channelType,
  });

  final GroupDetailExtensionPoint point;
  final String groupId;
  final int channelType;
}

@immutable
class GroupDetailExtensionItem {
  const GroupDetailExtensionItem({
    required this.id,
    required this.builder,
  });

  final String id;
  final WidgetBuilder builder;
}

const groupDetailExtensionSlot = SlotDescriptor<
    GroupDetailExtensionContext,
    GroupDetailExtensionItem>('group.detail.extension');
```

- [ ] **Step 4: Implement the legacy importer**

```dart
// lib/wk_endpoint/legacy/legacy_endpoint_importer.dart
import '../../wukong_base/endpoint/endpoint_manager.dart';
import '../../wukong_base/endpoint/entity/contacts_menu.dart';
import '../../wukong_base/endpoint/entity/personal_info_menu.dart';
import '../core/slot_entry.dart';
import '../core/slot_registry.dart';
import '../slots/contacts_slots.dart';
import '../slots/personal_center_slots.dart';

class LegacyEndpointImporter {
  LegacyEndpointImporter({
    required EndpointManager manager,
    required SlotRegistry registry,
  }) : _manager = manager,
       _registry = registry;

  final EndpointManager _manager;
  final SlotRegistry _registry;

  void importContactsHeader() {
    if (_registry.containsId(contactsHeaderSlot, 'legacy/mail_list')) {
      return;
    }

    for (final endpoint in _manager.getEndpoints('mail_list')) {
      _registry.register(
        contactsHeaderSlot,
        SlotEntry<ContactsHeaderSlotContext, ContactsMenu>(
          id: 'legacy/${endpoint.sid}',
          priority: endpoint.sort,
          build: (context) {
            final value = endpoint.handler.invoke(context);
            return value as ContactsMenu;
          },
        ),
      );
    }
  }

  void importPersonalCenter() {
    if (_registry.containsId(personalCenterSlot, 'legacy/personal_center')) {
      return;
    }

    for (final endpoint in _manager.getEndpoints('personal_center')) {
      _registry.register(
        personalCenterSlot,
        SlotEntry<PersonalCenterSlotContext, PersonalInfoMenu>(
          id: 'legacy/${endpoint.sid}',
          priority: endpoint.sort,
          build: (context) {
            final value = endpoint.handler.invoke(context);
            return value as PersonalInfoMenu;
          },
        ),
      );
    }
  }
}
```

- [ ] **Step 5: Run analysis and the legacy-import tests**

Run: `dart analyze lib/wk_endpoint/legacy lib/wk_endpoint/slots`
Expected: PASS with no analyzer errors

Run: `flutter test test/wk_endpoint/legacy_endpoint_importer_test.dart`
Expected: PASS with 2 tests green

- [ ] **Step 6: Checkpoint**

```bash
git add lib/wk_endpoint/legacy/legacy_endpoint_importer.dart lib/wk_endpoint/slots/home_slots.dart lib/wk_endpoint/slots/contacts_slots.dart lib/wk_endpoint/slots/personal_center_slots.dart lib/wk_endpoint/slots/settings_slots.dart lib/wk_endpoint/slots/chat_slots.dart lib/wk_endpoint/slots/group_detail_slots.dart test/wk_endpoint/legacy_endpoint_importer_test.dart
git commit -m "refactor: define typed phase2 endpoint contracts"
```

### Task 3: Rebuild Home Popup And Contacts Header Assembly

**Files:**
- Create: `lib/modules/home/home_top_menu_slot_assembly.dart`
- Create: `lib/modules/contacts/contacts_slot_assembly.dart`
- Modify: `lib/modules/conversation/conversation_list_page.dart`
- Modify: `lib/modules/contacts/contacts_page.dart`
- Test: `test/modules/home/home_top_menu_slot_assembly_test.dart`
- Test: `test/modules/contacts/contacts_slot_assembly_test.dart`

- [ ] **Step 1: Write the failing home-menu and contacts-header tests**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/modules/contacts/contacts_slot_assembly.dart';
import 'package:wukong_im_app/modules/home/home_top_menu_slot_assembly.dart';
import 'package:wukong_im_app/wk_endpoint/core/slot_registry.dart';
import 'package:wukong_im_app/wk_endpoint/slots/contacts_slots.dart';
import 'package:wukong_im_app/wk_endpoint/slots/home_slots.dart';

void main() {
  test('home popup installer exposes Android ordered actions', () {
    final registry = SlotRegistry();

    final items = resolveHomeTopMenuItems(
      registry,
      HomeTopMenuContext(
        hasConversations: false,
        openCreateGroup: () {},
        openAddFriend: () {},
        openScan: () {},
        enterMultiSelect: () {},
        clearAllConversations: () {},
      ),
    );

    expect(
      items.map((item) => item.id),
      <String>[
        'home.create_group',
        'home.add_friend',
        'home.scan',
        'home.multi_select',
        'home.clear_all',
      ],
    );
    expect(
      items.where((item) => !item.enabled).map((item) => item.id),
      <String>['home.multi_select', 'home.clear_all'],
    );
  });

  test('contacts installer exposes Android header rows with request count', () {
    final registry = SlotRegistry();

    final items = resolveContactsHeaderMenus(
      registry,
      const ContactsHeaderSlotContext(pendingRequestCount: 9),
      openNewFriendsPage: () {},
      openSavedGroupsPage: () {},
    );

    expect(items.map((item) => item.sid), <String>['friend', 'group']);
    expect(items.first.badgeNum, 9);
  });
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/modules/home/home_top_menu_slot_assembly_test.dart test/modules/contacts/contacts_slot_assembly_test.dart`
Expected: FAIL with missing assembly helpers

- [ ] **Step 3: Implement the default home-popup and contacts-header installers**

```dart
// lib/modules/home/home_top_menu_slot_assembly.dart
import 'package:flutter/material.dart';

import '../../widgets/wk_reference_assets.dart';
import '../../wk_endpoint/core/slot_entry.dart';
import '../../wk_endpoint/core/slot_registry.dart';
import '../../wk_endpoint/slots/home_slots.dart';

void ensureHomeTopMenuSlots(SlotRegistry registry) {
  if (registry.containsId(homeTopMenuSlot, 'home.create_group')) {
    return;
  }

  registry.register(
    homeTopMenuSlot,
    SlotEntry<HomeTopMenuContext, HomeTopMenuItem>(
      id: 'home.create_group',
      priority: 200,
      build: (context) => HomeTopMenuItem(
        id: 'home.create_group',
        title: 'Create group',
        assetIcon: WKReferenceAssets.menuChats,
        onSelected: context.openCreateGroup,
      ),
    ),
  );
  registry.register(
    homeTopMenuSlot,
    SlotEntry<HomeTopMenuContext, HomeTopMenuItem>(
      id: 'home.add_friend',
      priority: 99,
      build: (context) => HomeTopMenuItem(
        id: 'home.add_friend',
        title: 'Add friend',
        assetIcon: WKReferenceAssets.menuInvite,
        onSelected: context.openAddFriend,
      ),
    ),
  );
  registry.register(
    homeTopMenuSlot,
    SlotEntry<HomeTopMenuContext, HomeTopMenuItem>(
      id: 'home.scan',
      priority: 98,
      build: (context) => HomeTopMenuItem(
        id: 'home.scan',
        title: 'Scan',
        assetIcon: WKReferenceAssets.menuScan,
        onSelected: context.openScan,
      ),
    ),
  );
  registry.register(
    homeTopMenuSlot,
    SlotEntry<HomeTopMenuContext, HomeTopMenuItem>(
      id: 'home.multi_select',
      priority: 70,
      build: (context) => HomeTopMenuItem(
        id: 'home.multi_select',
        title: 'Multi-select',
        icon: Icons.playlist_add_check_circle_outlined,
        enabled: context.hasConversations,
        onSelected: context.enterMultiSelect,
      ),
    ),
  );
  registry.register(
    homeTopMenuSlot,
    SlotEntry<HomeTopMenuContext, HomeTopMenuItem>(
      id: 'home.clear_all',
      priority: 60,
      build: (context) => HomeTopMenuItem(
        id: 'home.clear_all',
        title: 'Clear all conversations',
        icon: Icons.delete_sweep_outlined,
        enabled: context.hasConversations,
        onSelected: context.clearAllConversations,
      ),
    ),
  );
}

List<HomeTopMenuItem> resolveHomeTopMenuItems(
  SlotRegistry registry,
  HomeTopMenuContext context,
) {
  ensureHomeTopMenuSlots(registry);
  return registry.resolve(homeTopMenuSlot, context);
}
```

```dart
// lib/modules/contacts/contacts_slot_assembly.dart
import '../../widgets/wk_reference_assets.dart';
import '../../wk_endpoint/core/slot_entry.dart';
import '../../wk_endpoint/core/slot_registry.dart';
import '../../wk_endpoint/slots/contacts_slots.dart';
import '../../wukong_base/endpoint/entity/contacts_menu.dart';

void ensureContactsHeaderSlots(SlotRegistry registry) {
  if (registry.containsId(contactsHeaderSlot, 'contacts.friend')) {
    return;
  }

  registry.register(
    contactsHeaderSlot,
    SlotEntry<ContactsHeaderSlotContext, ContactsMenu>(
      id: 'contacts.friend',
      priority: 100,
      build: (context) => ContactsMenu(
        sid: 'friend',
        imgResource: WKReferenceAssets.newFriend,
        text: 'New friends',
        badgeNum: context.pendingRequestCount,
      ),
    ),
  );
  registry.register(
    contactsHeaderSlot,
    SlotEntry<ContactsHeaderSlotContext, ContactsMenu>(
      id: 'contacts.group',
      priority: 90,
      build: (context) => ContactsMenu(
        sid: 'group',
        imgResource: WKReferenceAssets.savedGroups,
        text: 'Saved groups',
      ),
    ),
  );
}

List<ContactsMenu> resolveContactsHeaderMenus(
  SlotRegistry registry,
  ContactsHeaderSlotContext context, {
  required void Function() openNewFriendsPage,
  required void Function() openSavedGroupsPage,
}) {
  ensureContactsHeaderSlots(registry);
  final items = registry.resolve(contactsHeaderSlot, context);
  return items
      .map((item) {
        if (item.sid == 'friend') {
          return ContactsMenu(
            sid: item.sid,
            imgResource: item.imgResource,
            text: item.text,
            badgeNum: item.badgeNum,
            onClick: (_) => openNewFriendsPage(),
          );
        }
        if (item.sid == 'group') {
          return ContactsMenu(
            sid: item.sid,
            imgResource: item.imgResource,
            text: item.text,
            badgeNum: item.badgeNum,
            onClick: (_) => openSavedGroupsPage(),
          );
        }
        return item;
      })
      .toList(growable: false);
}
```

- [ ] **Step 4: Wire the new installers into conversation and contacts pages**

```dart
// lib/modules/conversation/conversation_list_page.dart
import '../home/home_top_menu_slot_assembly.dart';
import '../../wk_endpoint/providers/slot_registry_provider.dart';

Future<void> _showTopMenu(
  BuildContext context,
  BuildContext anchorContext,
  List<Conversation> conversations,
) async {
  final registry = ref.read(slotRegistryProvider);
  final items = resolveHomeTopMenuItems(
    registry,
    HomeTopMenuContext(
      hasConversations: conversations.isNotEmpty,
      openCreateGroup: () => _openCreateGroupPage(context),
      openAddFriend: () => _openAddFriendPage(context),
      openScan: () => _openScanPage(context),
      enterMultiSelect: _enterSelectionMode,
      clearAllConversations: () => _confirmClearAll(context),
    ),
  );

  final selected = await showWKScreenPopupMenu<HomeTopMenuItem>(
    context: context,
    anchorContext: anchorContext,
    items: items.map((item) => item.toPopupMenuItem()).toList(),
  );
  if (!mounted || selected == null || !selected.enabled) {
    return;
  }
  selected.onSelected();
}
```

```dart
// lib/modules/contacts/contacts_page.dart
import '../home/home_top_menu_slot_assembly.dart';
import '../../wk_endpoint/providers/slot_registry_provider.dart';
import 'contacts_slot_assembly.dart';

@override
Widget build(BuildContext context) {
  final registry = ref.read(slotRegistryProvider);
  final AsyncValue<List<Friend>> friendsState =
      widget.friendsStateOverride ?? ref.watch(friendListProvider);
  final requestCount = (widget.requestsStateOverride ?? ref.watch(friendRequestListProvider))
      .maybeWhen(data: countPendingFriendRequests, orElse: () => 0);
  final resolvedHeaderMenus = widget.headerMenus ??
      resolveContactsHeaderMenus(
        registry,
        ContactsHeaderSlotContext(pendingRequestCount: requestCount),
        openNewFriendsPage: _openNewFriendsPage,
        openSavedGroupsPage: _openSavedGroupsPage,
      );

  // existing body remains unchanged except that the header section now
  // receives resolvedHeaderMenus instead of building menus internally.
}

Future<void> _showTopMenu(BuildContext anchorContext) async {
  final registry = ref.read(slotRegistryProvider);
  final items = resolveHomeTopMenuItems(
    registry,
    HomeTopMenuContext(
      hasConversations: true,
      openCreateGroup: _openCreateGroupPage,
      openAddFriend: _openAddFriendPage,
      openScan: () async {
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const ScanPage()),
        );
      },
      enterMultiSelect: () {},
      clearAllConversations: () {},
    ),
  );

  final selected = await showWKScreenPopupMenu<HomeTopMenuItem>(
    context: context,
    anchorContext: anchorContext,
    items: items
        .where((item) => item.id == 'home.create_group' || item.id == 'home.add_friend' || item.id == 'home.scan')
        .map((item) => item.toPopupMenuItem())
        .toList(),
  );
  if (!mounted || selected == null || !selected.enabled) {
    return;
  }
  selected.onSelected();
}
```

- [ ] **Step 5: Run analysis and the new surface tests**

Run: `dart analyze lib/modules/home/home_top_menu_slot_assembly.dart lib/modules/contacts/contacts_slot_assembly.dart lib/modules/conversation/conversation_list_page.dart lib/modules/contacts/contacts_page.dart`
Expected: PASS with no analyzer errors

Run: `flutter test test/modules/home/home_top_menu_slot_assembly_test.dart test/modules/contacts/contacts_slot_assembly_test.dart`
Expected: PASS with 2 tests green

- [ ] **Step 6: Checkpoint**

```bash
git add lib/modules/home/home_top_menu_slot_assembly.dart lib/modules/contacts/contacts_slot_assembly.dart lib/modules/conversation/conversation_list_page.dart lib/modules/contacts/contacts_page.dart test/modules/home/home_top_menu_slot_assembly_test.dart test/modules/contacts/contacts_slot_assembly_test.dart
git commit -m "refactor: move home and contacts menus onto typed slots"
```

### Task 4: Rebuild Personal Center And Settings Assembly

**Files:**
- Create: `lib/modules/user/user_slot_assembly.dart`
- Create: `lib/wukong_uikit/setting/setting_slot_assembly.dart`
- Modify: `lib/modules/user/user_page.dart`
- Modify: `lib/wukong_uikit/setting/setting_page.dart`
- Test: `test/modules/user/user_page_slot_assembly_test.dart`
- Test: `test/wukong_uikit/setting/setting_page_slot_assembly_test.dart`

- [ ] **Step 1: Write the failing personal-center and settings tests**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/modules/user/user_slot_assembly.dart';
import 'package:wukong_im_app/wk_endpoint/core/slot_registry.dart';
import 'package:wukong_im_app/wk_endpoint/slots/personal_center_slots.dart';
import 'package:wukong_im_app/wk_endpoint/slots/settings_slots.dart';
import 'package:wukong_im_app/wukong_uikit/setting/setting_slot_assembly.dart';

void main() {
  test('personal center installer exposes Android ordered rows', () {
    final registry = SlotRegistry();
    final items = resolvePersonalCenterMenus(
      registry,
      const PersonalCenterSlotContext(hasNewVersion: true),
      openSettings: () {},
      openNotifications: () {},
      openWebLogin: () {},
      showWebLoginEntry: true,
    );

    expect(
      items.map((item) => item.sid),
      <String>[
        'personal_center_currency',
        'personal_center_new_msg_notice',
        'personal_center_web_login',
      ],
    );
    expect(items.first.isNewVersion, isTrue);
  });

  test('settings installer groups cells into stable ordered sections', () {
    final registry = SlotRegistry();
    final sections = resolveSettingsSections(
      registry,
      SettingsSlotContext(
        darkModeStatus: 'Follow system',
        imageCacheSize: '2 MB',
        hasNewVersion: true,
        openThemeSettings: () {},
        openLanguageSettings: () {},
        openFontSizeSettings: () {},
        openChatBackgroundSettings: () {},
        clearImageCache: () {},
        openAppModules: () {},
        openThirdPartySharing: () {},
        openErrorLogs: () {},
        openAbout: () {},
        logout: () {},
      ),
    );

    expect(sections.map((section) => section.id), <String>[
      'settings.appearance',
      'settings.cache',
      'settings.modules',
      'settings.about',
      'settings.account',
    ]);
    expect(sections.last.cells.single.style, SettingsCellStyle.dangerCentered);
  });
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/modules/user/user_page_slot_assembly_test.dart test/wukong_uikit/setting/setting_page_slot_assembly_test.dart`
Expected: FAIL with missing assembly helpers

- [ ] **Step 3: Implement the default personal-center and settings installers**

```dart
// lib/modules/user/user_slot_assembly.dart
import '../../widgets/wk_reference_assets.dart';
import '../../wk_endpoint/core/slot_entry.dart';
import '../../wk_endpoint/core/slot_registry.dart';
import '../../wk_endpoint/slots/personal_center_slots.dart';
import '../../wukong_base/endpoint/entity/personal_info_menu.dart';

void ensurePersonalCenterSlots(SlotRegistry registry) {
  if (registry.containsId(personalCenterSlot, 'personal_center_currency')) {
    return;
  }

  registry.register(
    personalCenterSlot,
    SlotEntry<PersonalCenterSlotContext, PersonalInfoMenu>(
      id: 'personal_center_currency',
      priority: 2,
      build: (context) => PersonalInfoMenu(
        sid: 'personal_center_currency',
        imgResource: WKReferenceAssets.setting,
        text: 'General',
        isNewVersion: context.hasNewVersion,
      ),
    ),
  );
  registry.register(
    personalCenterSlot,
    SlotEntry<PersonalCenterSlotContext, PersonalInfoMenu>(
      id: 'personal_center_new_msg_notice',
      priority: 3,
      build: (context) => PersonalInfoMenu(
        sid: 'personal_center_new_msg_notice',
        imgResource: WKReferenceAssets.notice,
        text: 'Notifications',
      ),
    ),
  );
  registry.register(
    personalCenterSlot,
    SlotEntry<PersonalCenterSlotContext, PersonalInfoMenu>(
      id: 'personal_center_web_login',
      priority: 1000,
      build: (context) => PersonalInfoMenu(
        sid: 'personal_center_web_login',
        imgResource: WKReferenceAssets.webLogin,
        text: 'Web login',
      ),
    ),
  );
}

List<PersonalInfoMenu> resolvePersonalCenterMenus(
  SlotRegistry registry,
  PersonalCenterSlotContext context, {
  required VoidCallback openSettings,
  required VoidCallback openNotifications,
  required VoidCallback openWebLogin,
  required bool showWebLoginEntry,
}) {
  ensurePersonalCenterSlots(registry);
  final items = registry.resolve(personalCenterSlot, context);
  return items
      .where((item) => showWebLoginEntry || item.sid != 'personal_center_web_login')
      .map((item) {
        if (item.sid == 'personal_center_currency') {
          return PersonalInfoMenu(
            sid: item.sid,
            imgResource: item.imgResource,
            text: item.text,
            isNewVersion: item.isNewVersion,
            onClick: (_) => openSettings(),
          );
        }
        if (item.sid == 'personal_center_new_msg_notice') {
          return PersonalInfoMenu(
            sid: item.sid,
            imgResource: item.imgResource,
            text: item.text,
            isNewVersion: item.isNewVersion,
            onClick: (_) => openNotifications(),
          );
        }
        return PersonalInfoMenu(
          sid: item.sid,
          imgResource: item.imgResource,
          text: item.text,
          isNewVersion: item.isNewVersion,
          onClick: (_) => openWebLogin(),
        );
      })
      .toList(growable: false);
}
```

```dart
// lib/wukong_uikit/setting/setting_slot_assembly.dart
import '../../wk_endpoint/core/slot_entry.dart';
import '../../wk_endpoint/core/slot_registry.dart';
import '../../wk_endpoint/slots/settings_slots.dart';

void ensureSettingsSections(SlotRegistry registry) {
  if (registry.containsId(settingsSectionSlot, 'settings.appearance')) {
    return;
  }

  registry.register(
    settingsSectionSlot,
    SlotEntry<SettingsSlotContext, SettingsSectionItem>(
      id: 'settings.appearance',
      priority: 100,
      build: (context) => SettingsSectionItem(
        id: 'settings.appearance',
        cells: <SettingsCellItem>[
          SettingsCellItem(
            id: 'settings.dark_mode',
            title: 'Dark mode',
            value: context.darkModeStatus,
            onTap: context.openThemeSettings,
          ),
          SettingsCellItem(
            id: 'settings.language',
            title: 'Language',
            onTap: context.openLanguageSettings,
          ),
          SettingsCellItem(
            id: 'settings.font_size',
            title: 'Font size',
            onTap: context.openFontSizeSettings,
          ),
          SettingsCellItem(
            id: 'settings.chat_background',
            title: 'Chat background',
            onTap: context.openChatBackgroundSettings,
          ),
        ],
      ),
    ),
  );
  registry.register(
    settingsSectionSlot,
    SlotEntry<SettingsSlotContext, SettingsSectionItem>(
      id: 'settings.cache',
      priority: 90,
      build: (context) => SettingsSectionItem(
        id: 'settings.cache',
        cells: <SettingsCellItem>[
          SettingsCellItem(
            id: 'settings.clear_cache',
            title: 'Clear image cache',
            value: context.imageCacheSize,
            onTap: context.clearImageCache,
          ),
        ],
      ),
    ),
  );
  registry.register(
    settingsSectionSlot,
    SlotEntry<SettingsSlotContext, SettingsSectionItem>(
      id: 'settings.modules',
      priority: 80,
      build: (context) => SettingsSectionItem(
        id: 'settings.modules',
        cells: <SettingsCellItem>[
          SettingsCellItem(
            id: 'settings.app_modules',
            title: 'Enterprise modules',
            onTap: context.openAppModules,
          ),
          SettingsCellItem(
            id: 'settings.third_party',
            title: 'Third-party sharing',
            onTap: context.openThirdPartySharing,
          ),
          SettingsCellItem(
            id: 'settings.error_logs',
            title: 'Error logs',
            onTap: context.openErrorLogs,
          ),
        ],
      ),
    ),
  );
  registry.register(
    settingsSectionSlot,
    SlotEntry<SettingsSlotContext, SettingsSectionItem>(
      id: 'settings.about',
      priority: 70,
      build: (context) => SettingsSectionItem(
        id: 'settings.about',
        cells: <SettingsCellItem>[
          SettingsCellItem(
            id: 'settings.about_app',
            title: 'About',
            accessory: SettingsCellAccessory.about,
            showNewVersionBadge: context.hasNewVersion,
            onTap: context.openAbout,
          ),
        ],
      ),
    ),
  );
  registry.register(
    settingsSectionSlot,
    SlotEntry<SettingsSlotContext, SettingsSectionItem>(
      id: 'settings.account',
      priority: 10,
      build: (context) => SettingsSectionItem(
        id: 'settings.account',
        cells: <SettingsCellItem>[
          SettingsCellItem(
            id: 'settings.logout',
            title: 'Log out',
            style: SettingsCellStyle.dangerCentered,
            accessory: SettingsCellAccessory.none,
            onTap: context.logout,
          ),
        ],
      ),
    ),
  );
}

List<SettingsSectionItem> resolveSettingsSections(
  SlotRegistry registry,
  SettingsSlotContext context,
) {
  ensureSettingsSections(registry);
  return registry.resolve(settingsSectionSlot, context);
}
```

- [ ] **Step 4: Wire the new installers into the user page and settings page**

```dart
// lib/modules/user/user_page.dart
import '../../wk_endpoint/providers/slot_registry_provider.dart';
import 'user_slot_assembly.dart';

@override
Widget build(BuildContext context) {
  final registry = ref.read(slotRegistryProvider);
  final menuItems = resolvePersonalCenterMenus(
    registry,
    PersonalCenterSlotContext(hasNewVersion: _hasNewVersion),
    openSettings: () => _pushPage(const SettingPage()),
    openNotifications: () => _pushPage(const NotificationSettingsPage()),
    openWebLogin: () => _pushPage(const PCLoginManagementPage()),
    showWebLoginEntry: true,
  );

  return Scaffold(
    backgroundColor: WKColors.homeBg,
    body: ListView(
      padding: EdgeInsets.zero,
      children: [
        _ProfileHeader(
          name: displayName,
          avatarUrl: userInfo?.avatar,
          onTap: () => _pushPage(const MyInfoPage()),
        ),
        for (final item in menuItems)
          _UserMenuItem(
            key: ValueKey('user_menu_${item.sid}'),
            iconAsset: item.imgResource ?? '',
            title: item.text ?? item.sid,
            showNewVersionBadge: item.isNewVersion,
            showBottomGap: item.sid == 'personal_center_web_login',
            onTap: () => item.onClick?.call(item.sid),
          ),
        const SizedBox(height: 30),
      ],
    ),
  );
}
```

```dart
// lib/wukong_uikit/setting/setting_page.dart
import '../../wk_endpoint/providers/slot_registry_provider.dart';
import '../../wk_endpoint/slots/settings_slots.dart';
import 'setting_slot_assembly.dart';

@override
Widget build(BuildContext context) {
  final registry = ref.read(slotRegistryProvider);
  final sections = resolveSettingsSections(
    registry,
    SettingsSlotContext(
      darkModeStatus: _darkModeStatus,
      imageCacheSize: _imageCacheSize,
      hasNewVersion: _hasNewVersion,
      openThemeSettings: () => _pushPage(const ThemeSettingsPage()),
      openLanguageSettings: () => _pushPage(const LanguageSettingsPage()),
      openFontSizeSettings: () => _pushPage(const FontSizeSettingsPage()),
      openChatBackgroundSettings: () => _pushPage(const ChatBackgroundSettingsPage()),
      clearImageCache: _clearImageCache,
      openAppModules: () => _pushPage(const AppModulesPage()),
      openThirdPartySharing: () => _pushPage(const ThirdPartySharingPage()),
      openErrorLogs: () => _pushPage(const ErrorLogsPage()),
      openAbout: () => _pushPage(const AboutPage()),
      logout: _logout,
    ),
  );

  return WKSubPageScaffold(
    title: 'Settings',
    body: Stack(
      children: [
        ListView(
          padding: const EdgeInsets.only(top: 20),
          children: [
            for (final section in sections) ...[
              WKSettingsGroup(
                children: [
                  for (final cell in section.cells) _buildSettingsCell(cell),
                ],
              ),
              const SizedBox(height: 10),
            ],
            const SizedBox(height: 20),
          ],
        ),
        if (_isClearingCache || _isLoggingOut)
          const Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: LinearProgressIndicator(minHeight: 2),
          ),
      ],
    ),
  );
}

Widget _buildSettingsCell(SettingsCellItem cell) {
  return WKSettingsCell(
    title: cell.title,
    value: cell.value,
    centerTitle: cell.style == SettingsCellStyle.dangerCentered,
    showArrow: cell.accessory != SettingsCellAccessory.none,
    titleColor: cell.style == SettingsCellStyle.dangerCentered
        ? WKColors.danger
        : null,
    trailing: cell.accessory == SettingsCellAccessory.about
        ? _buildAboutTrailing()
        : null,
    onTap: cell.onTap,
  );
}
```

- [ ] **Step 5: Run analysis and the new personal/settings tests**

Run: `dart analyze lib/modules/user/user_slot_assembly.dart lib/wukong_uikit/setting/setting_slot_assembly.dart lib/modules/user/user_page.dart lib/wukong_uikit/setting/setting_page.dart`
Expected: PASS with no analyzer errors

Run: `flutter test test/modules/user/user_page_slot_assembly_test.dart test/wukong_uikit/setting/setting_page_slot_assembly_test.dart`
Expected: PASS with 2 tests green

- [ ] **Step 6: Checkpoint**

```bash
git add lib/modules/user/user_slot_assembly.dart lib/wukong_uikit/setting/setting_slot_assembly.dart lib/modules/user/user_page.dart lib/wukong_uikit/setting/setting_page.dart test/modules/user/user_page_slot_assembly_test.dart test/wukong_uikit/setting/setting_page_slot_assembly_test.dart
git commit -m "refactor: move personal center and settings onto typed slots"
```

### Task 5: Rebuild The Chat Toolbar And Function Panel Assembly

**Files:**
- Create: `lib/modules/chat/chat_toolbar_slot_assembly.dart`
- Modify: `lib/modules/chat/chat_page_shell.dart`
- Test: `test/modules/chat/chat_toolbar_slot_assembly_test.dart`

- [ ] **Step 1: Write the failing chat-toolbar assembly test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/modules/chat/chat_toolbar_slot_assembly.dart';
import 'package:wukong_im_app/wk_endpoint/core/slot_registry.dart';
import 'package:wukong_im_app/wk_endpoint/slots/chat_slots.dart';

void main() {
  test('chat toolbar installer exposes Android-aligned default items', () {
    final registry = SlotRegistry();
    final context = const ChatToolbarSlotContext(
      isGroup: false,
      showEmojiPanel: false,
      showFunctionPanel: false,
    );

    final toolbarItems = resolveChatToolbarItems(registry, context);
    final functionItems = resolveChatFunctionItems(registry, context);

    expect(
      toolbarItems.map((item) => item.sid),
      <String>[
        'wk_chat_toolbar_voice',
        'wk_chat_toolbar_emoji',
        'wk_chat_toolbar_album',
        'wk_chat_toolbar_more',
      ],
    );
    expect(
      functionItems.map((item) => item.sid),
      <String>['chooseImg', 'chooseCard'],
    );
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/modules/chat/chat_toolbar_slot_assembly_test.dart`
Expected: FAIL with missing assembly helpers

- [ ] **Step 3: Implement the default chat-toolbar and function-panel installers**

```dart
// lib/modules/chat/chat_toolbar_slot_assembly.dart
import '../../widgets/wk_reference_assets.dart';
import '../../wk_endpoint/core/slot_entry.dart';
import '../../wk_endpoint/core/slot_registry.dart';
import '../../wk_endpoint/slots/chat_slots.dart';
import '../../wukong_base/endpoint/entity/chat_toolbar_menu.dart';

void ensureChatToolbarSlots(SlotRegistry registry) {
  if (registry.containsId(chatToolbarSlot, 'wk_chat_toolbar_voice')) {
    return;
  }

  registry.register(
    chatToolbarSlot,
    SlotEntry<ChatToolbarSlotContext, ChatToolBarMenu>(
      id: 'wk_chat_toolbar_voice',
      priority: 97,
      build: (context) => ChatToolBarMenu(
        sid: 'wk_chat_toolbar_voice',
        icon: WKReferenceAssets.chatToolbarVoice,
      ),
    ),
  );
  registry.register(
    chatToolbarSlot,
    SlotEntry<ChatToolbarSlotContext, ChatToolBarMenu>(
      id: 'wk_chat_toolbar_emoji',
      priority: 96,
      build: (context) => ChatToolBarMenu(
        sid: 'wk_chat_toolbar_emoji',
        icon: WKReferenceAssets.chatToolbarEmoji,
        isSelected: context.showEmojiPanel,
      ),
    ),
  );
  registry.register(
    chatToolbarSlot,
    SlotEntry<ChatToolbarSlotContext, ChatToolBarMenu>(
      id: 'wk_chat_toolbar_album',
      priority: 95,
      build: (context) => ChatToolBarMenu(
        sid: 'wk_chat_toolbar_album',
        icon: WKReferenceAssets.chatToolbarAlbum,
      ),
    ),
  );
  registry.register(
    chatToolbarSlot,
    SlotEntry<ChatToolbarSlotContext, ChatToolBarMenu>(
      id: 'wk_chat_toolbar_more',
      priority: 40,
      build: (context) => ChatToolBarMenu(
        sid: 'wk_chat_toolbar_more',
        icon: WKReferenceAssets.chatToolbarMore,
        isSelected: context.showFunctionPanel,
      ),
    ),
  );

  registry.register(
    chatFunctionSlot,
    SlotEntry<ChatToolbarSlotContext, ChatFunctionMenu>(
      id: 'chat_function.choose_img',
      priority: 100,
      build: (context) => ChatFunctionMenu(
        sid: 'chooseImg',
        icon: WKReferenceAssets.chatFunctionAlbum,
        text: 'Image',
      ),
    ),
  );
  registry.register(
    chatFunctionSlot,
    SlotEntry<ChatToolbarSlotContext, ChatFunctionMenu>(
      id: 'chat_function.choose_card',
      priority: 95,
      build: (context) => ChatFunctionMenu(
        sid: 'chooseCard',
        icon: WKReferenceAssets.chatFunctionCard,
        text: 'Card',
      ),
    ),
  );
}

List<ChatToolBarMenu> resolveChatToolbarItems(
  SlotRegistry registry,
  ChatToolbarSlotContext context,
) {
  ensureChatToolbarSlots(registry);
  return registry.resolve(chatToolbarSlot, context);
}

List<ChatFunctionMenu> resolveChatFunctionItems(
  SlotRegistry registry,
  ChatToolbarSlotContext context,
) {
  ensureChatToolbarSlots(registry);
  return registry.resolve(chatFunctionSlot, context);
}
```

- [ ] **Step 4: Replace hardcoded toolbar composition inside `ChatPageShell`**

```dart
// lib/modules/chat/chat_page_shell.dart
import '../../wk_endpoint/providers/slot_registry_provider.dart';
import 'chat_toolbar_slot_assembly.dart';

@override
Widget build(BuildContext context) {
  final composerState = ref.watch(chatComposerProvider(widget.session));
  final registry = ref.read(slotRegistryProvider);
  final slotContext = ChatToolbarSlotContext(
    isGroup: widget.channelType == WKChannelType.group,
    showEmojiPanel: composerState.showFacePanel,
    showFunctionPanel: composerState.showFunctionPanel,
  );
  final toolbarItems = resolveChatToolbarItems(registry, slotContext);
  final functionItems = resolveChatFunctionItems(registry, slotContext);

  return ChatComposer(
    child: Container(
      color: WKColors.homeBg,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (composerState.pendingReplyMessageId != null)
            _ReplyPreviewBar(
              previewText: composerState.pendingReplyPreview?.trim().isNotEmpty == true
                  ? composerState.pendingReplyPreview!.trim()
                  : _replyFallbackTitle,
              onClose: composerController.clearPendingReply,
            ),
          const Divider(height: 1, thickness: 1, color: WKColors.layoutColorSelected),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final item in toolbarItems)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _ComposerToolbarButton(
                      asset: item.icon ?? '',
                      onTap: () => _handleToolbarTap(item.sid, composerController),
                    ),
                  ),
                Expanded(
                  child: TextField(
                    controller: _textController,
                    onTap: composerController.hidePanels,
                    onChanged: composerController.updateText,
                    decoration: InputDecoration(
                      hintText: 'Message',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: WKColors.surfaceSoft,
                    ),
                    maxLines: 4,
                    minLines: 1,
                  ),
                ),
              ],
            ),
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: composerState.showFunctionPanel
                ? _buildFunctionPanel(functionItems)
                : _buildPanel(composerState),
          ),
        ],
      ),
    ),
  );
}

void _handleToolbarTap(String sid, ChatComposerController controller) {
  switch (sid) {
    case 'wk_chat_toolbar_emoji':
      controller.toggleFacePanel();
      break;
    case 'wk_chat_toolbar_more':
      controller.toggleFunctionPanel();
      break;
    case 'wk_chat_toolbar_album':
      break;
    case 'wk_chat_toolbar_voice':
      break;
  }
}

Widget _buildFunctionPanel(List<ChatFunctionMenu> items) {
  return Container(
    key: const ValueKey<String>('panel-more'),
    width: double.infinity,
    color: WKColors.homeBg,
    padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
    child: Wrap(
      spacing: 16,
      runSpacing: 16,
      children: [
        for (final item in items)
          _FunctionItem(
            asset: item.icon ?? '',
            label: item.text ?? item.sid,
          ),
      ],
    ),
  );
}
```

- [ ] **Step 5: Run analysis and the toolbar test**

Run: `dart analyze lib/modules/chat/chat_toolbar_slot_assembly.dart lib/modules/chat/chat_page_shell.dart`
Expected: PASS with no analyzer errors

Run: `flutter test test/modules/chat/chat_toolbar_slot_assembly_test.dart`
Expected: PASS with 1 test green

- [ ] **Step 6: Checkpoint**

```bash
git add lib/modules/chat/chat_toolbar_slot_assembly.dart lib/modules/chat/chat_page_shell.dart test/modules/chat/chat_toolbar_slot_assembly_test.dart
git commit -m "refactor: move chat toolbar onto typed slots"
```

### Task 6: Activate Group Detail Extension Points

**Files:**
- Create: `lib/wukong_uikit/group/group_detail_slot_assembly.dart`
- Modify: `lib/wukong_uikit/group/group_detail_page.dart`
- Test: `test/wukong_uikit/group/group_detail_slot_assembly_test.dart`

- [ ] **Step 1: Write the failing group-detail extension-point test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/wk_endpoint/core/slot_entry.dart';
import 'package:wukong_im_app/wk_endpoint/core/slot_registry.dart';
import 'package:wukong_im_app/wk_endpoint/slots/group_detail_slots.dart';
import 'package:wukong_im_app/wukong_uikit/group/group_detail_slot_assembly.dart';

void main() {
  test('group detail resolver only returns widgets for the requested point', () {
    final registry = SlotRegistry();
    registry.register(
      groupDetailExtensionSlot,
      SlotEntry<GroupDetailExtensionContext, GroupDetailExtensionItem>(
        id: 'group.msg_settings',
        priority: 20,
        predicate: (context) =>
            context.point == GroupDetailExtensionPoint.msgSettings,
        build: (context) => GroupDetailExtensionItem(
          id: 'group.msg_settings',
          builder: (_) => const Text('msg settings'),
        ),
      ),
    );

    final widgets = buildGroupDetailExtensions(
      registry: registry,
      point: GroupDetailExtensionPoint.msgSettings,
      groupId: 'g-1',
      channelType: 1,
    );

    expect(widgets, hasLength(1));
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/wukong_uikit/group/group_detail_slot_assembly_test.dart`
Expected: FAIL with missing assembly helper

- [ ] **Step 3: Implement the group-detail extension resolver**

```dart
// lib/wukong_uikit/group/group_detail_slot_assembly.dart
import 'package:flutter/material.dart';

import '../../wk_endpoint/core/slot_registry.dart';
import '../../wk_endpoint/slots/group_detail_slots.dart';

List<Widget> buildGroupDetailExtensions({
  required SlotRegistry registry,
  required GroupDetailExtensionPoint point,
  required String groupId,
  required int channelType,
}) {
  final items = registry.resolve(
    groupDetailExtensionSlot,
    GroupDetailExtensionContext(
      point: point,
      groupId: groupId,
      channelType: channelType,
    ),
  );

  return items
      .map((item) => Builder(builder: item.builder))
      .toList(growable: false);
}
```

- [ ] **Step 4: Resolve extension widgets from `GroupDetailPage`**

```dart
// lib/wukong_uikit/group/group_detail_page.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../wk_endpoint/providers/slot_registry_provider.dart';
import '../../wk_endpoint/slots/group_detail_slots.dart';
import 'group_detail_slot_assembly.dart';

@override
Widget build(BuildContext context) {
  final registry = ProviderScope.containerOf(
    context,
    listen: false,
  ).read(slotRegistryProvider);

  final msgRemindExtensions = buildGroupDetailExtensions(
    registry: registry,
    point: GroupDetailExtensionPoint.msgRemind,
    groupId: widget.channelId,
    channelType: widget.channelType,
  );
  final msgSettingsExtensions = buildGroupDetailExtensions(
    registry: registry,
    point: GroupDetailExtensionPoint.msgSettings,
    groupId: widget.channelId,
    channelType: widget.channelType,
  );
  final groupAvatarExtensions = buildGroupDetailExtensions(
    registry: registry,
    point: GroupDetailExtensionPoint.groupAvatar,
    groupId: widget.channelId,
    channelType: widget.channelType,
  );
  final groupManageExtensions = buildGroupDetailExtensions(
    registry: registry,
    point: GroupDetailExtensionPoint.groupManage,
    groupId: widget.channelId,
    channelType: widget.channelType,
  );
  final chatPasswordExtensions = buildGroupDetailExtensions(
    registry: registry,
    point: GroupDetailExtensionPoint.chatPassword,
    groupId: widget.channelId,
    channelType: widget.channelType,
  );

  return WKSubPageScaffold(
    title: 'Chat info($visibleMemberCount)',
    body: Stack(
      children: [
        ListView(
          padding: EdgeInsets.zero,
          children: [
            if (_hasForbiddenReminder) _buildForbiddenReminderSection(),
            WKSettingsGroup(
              children: [
                ...msgRemindExtensions,
                _buildAndroidMembersSection(),
                _buildAndroidGroupInfoSection(),
                ...groupAvatarExtensions,
                _buildAndroidSettingsSection(),
                ...msgSettingsExtensions,
                ...groupManageExtensions,
                ...chatPasswordExtensions,
                _buildAndroidActionsSection(),
              ],
            ),
            const SizedBox(height: 30),
          ],
        ),
      ],
    ),
  );
}
```

- [ ] **Step 5: Run analysis and the group-detail test**

Run: `dart analyze lib/wukong_uikit/group/group_detail_slot_assembly.dart lib/wukong_uikit/group/group_detail_page.dart`
Expected: PASS with no analyzer errors

Run: `flutter test test/wukong_uikit/group/group_detail_slot_assembly_test.dart`
Expected: PASS with 1 test green

- [ ] **Step 6: Checkpoint**

```bash
git add lib/wukong_uikit/group/group_detail_slot_assembly.dart lib/wukong_uikit/group/group_detail_page.dart test/wukong_uikit/group/group_detail_slot_assembly_test.dart
git commit -m "refactor: add typed group detail extension points"
```

### Task 7: Add Shared-Registry Compile Coverage And Final Verification

**Files:**
- Create: `test/modules/shell/phase2_endpoint_surface_compile_test.dart`

- [ ] **Step 1: Add the shared-registry compile and idempotency test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wukong_im_app/modules/chat/chat_toolbar_slot_assembly.dart';
import 'package:wukong_im_app/modules/contacts/contacts_slot_assembly.dart';
import 'package:wukong_im_app/modules/home/home_top_menu_slot_assembly.dart';
import 'package:wukong_im_app/modules/user/user_slot_assembly.dart';
import 'package:wukong_im_app/wk_endpoint/core/slot_entry.dart';
import 'package:wukong_im_app/wk_endpoint/providers/slot_registry_provider.dart';
import 'package:wukong_im_app/wk_endpoint/slots/chat_slots.dart';
import 'package:wukong_im_app/wk_endpoint/slots/contacts_slots.dart';
import 'package:wukong_im_app/wk_endpoint/slots/group_detail_slots.dart';
import 'package:wukong_im_app/wk_endpoint/slots/home_slots.dart';
import 'package:wukong_im_app/wk_endpoint/slots/personal_center_slots.dart';
import 'package:wukong_im_app/wk_endpoint/slots/settings_slots.dart';
import 'package:wukong_im_app/wukong_uikit/group/group_detail_slot_assembly.dart';
import 'package:wukong_im_app/wukong_uikit/setting/setting_slot_assembly.dart';

void main() {
  test('phase2 installers are idempotent against one shared registry', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final registry = container.read(slotRegistryProvider);

    ensureHomeTopMenuSlots(registry);
    ensureHomeTopMenuSlots(registry);
    ensureContactsHeaderSlots(registry);
    ensureContactsHeaderSlots(registry);
    ensurePersonalCenterSlots(registry);
    ensurePersonalCenterSlots(registry);
    ensureSettingsSections(registry);
    ensureSettingsSections(registry);
    ensureChatToolbarSlots(registry);
    ensureChatToolbarSlots(registry);

    expect(registry.containsId(homeTopMenuSlot, 'home.create_group'), isTrue);
    expect(registry.containsId(contactsHeaderSlot, 'contacts.friend'), isTrue);
    expect(
      registry.containsId(personalCenterSlot, 'personal_center_currency'),
      isTrue,
    );
    expect(
      registry.containsId(settingsSectionSlot, 'settings.appearance'),
      isTrue,
    );
    expect(
      registry.containsId(chatToolbarSlot, 'wk_chat_toolbar_voice'),
      isTrue,
    );
  });

  test('group detail extension slot accepts late registrations', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final registry = container.read(slotRegistryProvider);

    registry.register(
      groupDetailExtensionSlot,
      SlotEntry<GroupDetailExtensionContext, GroupDetailExtensionItem>(
        id: 'group.msg_settings',
        predicate: (context) =>
            context.point == GroupDetailExtensionPoint.msgSettings,
        build: (_) => GroupDetailExtensionItem(
          id: 'group.msg_settings',
          builder: (_) => const SizedBox.shrink(),
        ),
      ),
    );

    final items = buildGroupDetailExtensions(
      registry: registry,
      point: GroupDetailExtensionPoint.msgSettings,
      groupId: 'g-1',
      channelType: 1,
    );
    expect(items, hasLength(1));
  });
}
```

- [ ] **Step 2: Run the full Phase 2 verification sweep**

Run: `dart analyze lib/wk_endpoint lib/modules/home lib/modules/contacts lib/modules/user lib/modules/chat lib/wukong_uikit/group lib/wukong_uikit/setting`
Expected: PASS with no analyzer errors

Run: `flutter test test/wk_endpoint/slot_registry_test.dart test/wk_endpoint/legacy_endpoint_importer_test.dart`
Expected: PASS

Run: `flutter test test/modules/home/home_top_menu_slot_assembly_test.dart test/modules/contacts/contacts_slot_assembly_test.dart`
Expected: PASS

Run: `flutter test test/modules/user/user_page_slot_assembly_test.dart test/wukong_uikit/setting/setting_page_slot_assembly_test.dart`
Expected: PASS

Run: `flutter test test/modules/chat/chat_toolbar_slot_assembly_test.dart test/wukong_uikit/group/group_detail_slot_assembly_test.dart`
Expected: PASS

Run: `flutter test test/modules/shell/phase2_endpoint_surface_compile_test.dart test/modules/profile/profile_pages_compile_test.dart test/modules/shell/android_ui_parity_shell_test.dart`
Expected: PASS

- [ ] **Step 3: Checkpoint**

```bash
git add test/modules/shell/phase2_endpoint_surface_compile_test.dart
git commit -m "test: add phase2 endpoint surface coverage"
```

## Self-Review Checklist

- Spec coverage:
  - typed endpoint kernel is covered by Task 1
  - slot contracts and legacy compatibility are covered by Task 2
  - homepage and contacts extension points are covered by Task 3
  - personal center and settings extension points are covered by Task 4
  - chat-toolbar extension points are covered by Task 5
  - group-detail extension points are covered by Task 6
  - compile and shared-registry verification are covered by Task 7
- Placeholder scan:
  - no `TODO`, `TBD`, or deferred "implement later" markers remain
  - every code-changing step contains concrete code or exact commands
- Type consistency:
  - `SlotRegistry`, `HomeTopMenuContext`, `ContactsHeaderSlotContext`, `PersonalCenterSlotContext`, `SettingsSlotContext`, `ChatToolbarSlotContext`, and `GroupDetailExtensionContext` keep stable names throughout the plan

## Expected Outcome

After this plan is implemented:

- Flutter's active Android surfaces stop hardcoding their extension menus and injected optional sections
- `wukong_im_app` gains a new typed `wk_endpoint` kernel instead of relying on raw string categories
- the dormant legacy `EndpointManager` can be imported into the new model where it still has useful registrations
- conversation and contacts top-right menus match Android's endpoint-driven popup pattern
- contacts header, personal center, settings, chat toolbar, and group detail extension points are live on the new mainline
- later parity plans can attach missing Android behaviors through typed slot installers instead of growing more page-level hardcoding

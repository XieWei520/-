# IM Phase A Repository Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Establish the first stable Repository boundary for messages, files, and client platform capabilities without changing current user-visible behavior.

**Architecture:** Add small domain interfaces under `lib/core/repositories` and concrete adapters under `lib/data/repositories`. Existing `ChatHistoryGateway` and `FileApi` remain the underlying implementation for this slice, so current screens keep working while later phases can migrate call sites gradually.

**Tech Stack:** Flutter, Dart, Riverpod, existing WuKongIM Flutter SDK, existing `FileApi`, `flutter_test`.

---

### Task 1: MessageRepository Boundary

**Files:**
- Create: `C:\Users\COLORFUL\Desktop\WuKong\lib\core\repositories\message_repository.dart`
- Create: `C:\Users\COLORFUL\Desktop\WuKong\lib\data\repositories\wk_message_repository.dart`
- Create: `C:\Users\COLORFUL\Desktop\WuKong\test\data\repositories\wk_message_repository_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
test('WkMessageRepository delegates latest, older, and around queries', () async {
  final gateway = _RecordingHistoryGateway();
  final repository = WkMessageRepository(gateway: gateway);

  await repository.loadLatest(MessagePageQuery(channelId: 'u1', channelType: 1, limit: 20));
  await repository.loadOlder(MessagePageQuery(channelId: 'u1', channelType: 1, limit: 30, anchorOrderSeq: 9000));
  await repository.loadAround(MessagePageQuery(channelId: 'u1', channelType: 1, limit: 40, anchorOrderSeq: 8800));

  expect(gateway.calls, <String>[
    'latest:u1:1:20',
    'older:u1:1:9000:30',
    'around:u1:1:8800:40',
  ]);
});
```

- [ ] **Step 2: Run RED**

Run: `flutter test test\data\repositories\wk_message_repository_test.dart`

Expected: FAIL because `MessagePageQuery` and `WkMessageRepository` do not exist.

- [ ] **Step 3: Implement minimal interface and adapter**

Create `MessagePageQuery`, `MessageRepository`, and `WkMessageRepository` that delegates to existing `ChatHistoryGateway`.

- [ ] **Step 4: Run GREEN**

Run: `flutter test test\data\repositories\wk_message_repository_test.dart`

Expected: PASS.

### Task 2: FileRepository Boundary

**Files:**
- Create: `C:\Users\COLORFUL\Desktop\WuKong\lib\core\repositories\file_repository.dart`
- Create: `C:\Users\COLORFUL\Desktop\WuKong\lib\data\repositories\file_api_repository.dart`
- Create: `C:\Users\COLORFUL\Desktop\WuKong\test\data\repositories\file_api_repository_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
test('FileApiRepository delegates chat and common uploads through injected functions', () async {
  final calls = <String>[];
  final repository = FileApiRepository(
    uploadChatFile: ({required filePath, required channelId, required channelType}) async {
      calls.add('chat:$filePath:$channelId:$channelType');
      return 'https://cdn/chat.jpg';
    },
    uploadCommonImage: ({required filePath, required uploadPath}) async {
      calls.add('common:$filePath:$uploadPath');
      return 'https://cdn/avatar.png';
    },
  );

  expect(await repository.uploadChatFile(const ChatFileUploadRequest(filePath: ' a.jpg ', channelId: 'c1', channelType: 2)), 'https://cdn/chat.jpg');
  expect(await repository.uploadCommonImage(const CommonImageUploadRequest(filePath: ' b.png ', uploadPath: '/avatars/b.png')), 'https://cdn/avatar.png');
  expect(calls, <String>[
    'chat: a.jpg :c1:2',
    'common: b.png :/avatars/b.png',
  ]);
});
```

- [ ] **Step 2: Run RED**

Run: `flutter test test\data\repositories\file_api_repository_test.dart`

Expected: FAIL because `FileRepository` and `FileApiRepository` do not exist.

- [ ] **Step 3: Implement minimal interface and adapter**

Create upload request value objects and `FileApiRepository` with injectable delegates that default to `FileApi.instance`.

- [ ] **Step 4: Run GREEN**

Run: `flutter test test\data\repositories\file_api_repository_test.dart`

Expected: PASS.

### Task 3: Client PlatformCapabilities Boundary

**Files:**
- Create: `C:\Users\COLORFUL\Desktop\WuKong\lib\core\platform\platform_capabilities.dart`
- Create: `C:\Users\COLORFUL\Desktop\WuKong\test\core\platform\platform_capabilities_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
test('platform capabilities source stays web safe', () {
  final source = File('lib/core/platform/platform_capabilities.dart').readAsStringSync();
  expect(source, isNot(contains("import 'dart:io'")));
});

test('default capabilities expose a concrete platform family', () {
  final capabilities = defaultPlatformCapabilities();
  expect(capabilities.platformFamily, isNotEmpty);
  expect(capabilities.supportsLocalSqlite || capabilities.supportsIndexedDbCache, isTrue);
});
```

- [ ] **Step 2: Run RED**

Run: `flutter test test\core\platform\platform_capabilities_test.dart`

Expected: FAIL because `platform_capabilities.dart` does not exist.

- [ ] **Step 3: Implement minimal capabilities model**

Use `kIsWeb` and `defaultTargetPlatform`; do not import `dart:io`.

- [ ] **Step 4: Run GREEN**

Run: `flutter test test\core\platform\platform_capabilities_test.dart`

Expected: PASS.

### Task 4: Repository Providers

**Files:**
- Create: `C:\Users\COLORFUL\Desktop\WuKong\lib\data\repositories\repository_providers.dart`
- Create: `C:\Users\COLORFUL\Desktop\WuKong\test\data\repositories\repository_providers_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
test('repository providers expose default production adapters', () {
  final container = ProviderContainer();
  addTearDown(container.dispose);

  expect(container.read(messageRepositoryProvider), isA<WkMessageRepository>());
  expect(container.read(fileRepositoryProvider), isA<FileApiRepository>());
  expect(container.read(clientPlatformCapabilitiesProvider).platformFamily, isNotEmpty);
});
```

- [ ] **Step 2: Run RED**

Run: `flutter test test\data\repositories\repository_providers_test.dart`

Expected: FAIL because the provider file does not exist.

- [ ] **Step 3: Implement providers**

Expose `messageRepositoryProvider`, `fileRepositoryProvider`, and `clientPlatformCapabilitiesProvider`.

- [ ] **Step 4: Run GREEN**

Run: `flutter test test\data\repositories\repository_providers_test.dart`

Expected: PASS.

### Task 5: Combined Verification

**Files:**
- Verify all files from Tasks 1-4.

- [ ] **Step 1: Format**

Run:

```powershell
dart format lib\core\repositories\message_repository.dart lib\data\repositories\wk_message_repository.dart lib\core\repositories\file_repository.dart lib\data\repositories\file_api_repository.dart lib\core\platform\platform_capabilities.dart lib\data\repositories\repository_providers.dart test\data\repositories\wk_message_repository_test.dart test\data\repositories\file_api_repository_test.dart test\core\platform\platform_capabilities_test.dart test\data\repositories\repository_providers_test.dart
```

Expected: command exits 0.

- [ ] **Step 2: Analyze**

Run:

```powershell
dart analyze lib\core\repositories\message_repository.dart lib\data\repositories\wk_message_repository.dart lib\core\repositories\file_repository.dart lib\data\repositories\file_api_repository.dart lib\core\platform\platform_capabilities.dart lib\data\repositories\repository_providers.dart test\data\repositories\wk_message_repository_test.dart test\data\repositories\file_api_repository_test.dart test\core\platform\platform_capabilities_test.dart test\data\repositories\repository_providers_test.dart
```

Expected: `No issues found!`

- [ ] **Step 3: Run targeted tests**

Run:

```powershell
flutter test test\data\repositories\wk_message_repository_test.dart test\data\repositories\file_api_repository_test.dart test\core\platform\platform_capabilities_test.dart test\data\repositories\repository_providers_test.dart
```

Expected: all tests pass.

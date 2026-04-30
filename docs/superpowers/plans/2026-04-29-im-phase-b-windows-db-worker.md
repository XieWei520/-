# IM Phase B Windows DB Worker Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Introduce a Windows DB worker boundary for heavy read-only SQLite tasks, starting with date-bucket/search DTOs before moving backup export work off the UI isolate.

**Architecture:** Add a narrow `WindowsDbWorker` facade under `lib/wk_foundation/db`. The first slice exposes request/response DTOs and a synchronous fallback implementation so call sites can be migrated behind an interface; later slices can replace the implementation with `Isolate.run` plus a separate SQLite connection.

**Tech Stack:** Flutter, Dart, sqflite_common_ffi on Windows, existing SDK SQL helpers, isolate-friendly DTOs.

---

### Task 1: Worker DTOs And Facade

**Files:**
- Create: `C:\Users\COLORFUL\Desktop\WuKong\lib\wk_foundation\db\windows_db_worker_models.dart`
- Create: `C:\Users\COLORFUL\Desktop\WuKong\lib\wk_foundation\db\windows_db_worker.dart`
- Create: `C:\Users\COLORFUL\Desktop\WuKong\test\wk_foundation\db\windows_db_worker_models_test.dart`

- [ ] **Step 1: Write failing tests**

```dart
test('ChannelSearchRequest normalizes limits and keywords', () {
  const request = ChannelSearchRequest(
    dbPath: 'C:/db/wk.db',
    channelId: 'c1',
    channelType: 1,
    keyword: ' hello ',
    page: 0,
    limit: -1,
  );

  expect(request.normalizedKeyword, 'hello');
  expect(request.safePage, 1);
  expect(request.safeLimit, 20);
});
```

- [ ] **Step 2: Run RED**

Run: `flutter test test\wk_foundation\db\windows_db_worker_models_test.dart`

Expected: FAIL because worker DTOs do not exist.

- [ ] **Step 3: Implement DTOs**

Create `DateBucketRequest`, `ChannelSearchRequest`, `MessageSearchRowDto`, `SearchDateBucketDto`, `BackupExportRequest`, and `BackupExportResultDto`.

- [ ] **Step 4: Run GREEN**

Run: `flutter test test\wk_foundation\db\windows_db_worker_models_test.dart`

Expected: PASS.

### Task 2: Isolate-Safe Facade Stub

**Files:**
- Create: `C:\Users\COLORFUL\Desktop\WuKong\lib\wk_foundation\db\windows_db_worker_stub.dart`
- Create: `C:\Users\COLORFUL\Desktop\WuKong\lib\wk_foundation\db\windows_db_worker_io.dart`
- Create: `C:\Users\COLORFUL\Desktop\WuKong\test\wk_foundation\db\windows_db_worker_test.dart`

- [ ] **Step 1: Write failing tests**

```dart
test('stub worker returns empty results without touching native sqlite', () async {
  final worker = createWindowsDbWorker();
  expect(await worker.loadDateBuckets(const DateBucketRequest(dbPath: 'missing.db', channelId: 'c1', channelType: 1)), isEmpty);
});
```

- [ ] **Step 2: Run RED**

Run: `flutter test test\wk_foundation\db\windows_db_worker_test.dart`

Expected: FAIL because worker factory does not exist.

- [ ] **Step 3: Implement factory**

Add conditional export/import. Non-Windows-compatible VM tests use a safe stub returning empty DTO lists; IO implementation is present but not wired to production call sites until the DB path and SQLite runtime are injected.

- [ ] **Step 4: Run GREEN**

Run: `flutter test test\wk_foundation\db\windows_db_worker_test.dart`

Expected: PASS.

### Task 3: Verification

Run:

```powershell
dart analyze lib\wk_foundation\db\windows_db_worker.dart lib\wk_foundation\db\windows_db_worker_models.dart lib\wk_foundation\db\windows_db_worker_stub.dart lib\wk_foundation\db\windows_db_worker_io.dart test\wk_foundation\db\windows_db_worker_models_test.dart test\wk_foundation\db\windows_db_worker_test.dart
flutter test test\wk_foundation\db\windows_db_worker_models_test.dart test\wk_foundation\db\windows_db_worker_test.dart
```

Expected: analyze has no issues and all tests pass.

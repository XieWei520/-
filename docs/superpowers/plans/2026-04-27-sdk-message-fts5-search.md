# SDK Message FTS5 Search Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Move SDK local message search toward FTS5 while keeping LIKE fallback for devices or databases where FTS is unavailable.

**Architecture:** Add pure SQL helper functions first so query shape can be tested without opening SQLite. Add an idempotent migration creating `message_fts`, and update `MessageDB.search/searchWithChannel` to prefer the FTS query when the virtual table exists.

**Tech Stack:** Dart, Flutter SDK package, sqflite, SQLite FTS5, `dart test`.

---

### Task 1: SQL Helper Tests

**Files:**
- Create: `C:\Users\COLORFUL\Desktop\TangSengDaoDao\WuKongIMFlutterSDK-master\test\db\message_fts_search_test.dart`
- Create: `C:\Users\COLORFUL\Desktop\TangSengDaoDao\WuKongIMFlutterSDK-master\lib\db\message_search_sql.dart`

- [ ] **Step 1: Write RED tests**

```dart
test('buildMessageFtsQuery escapes double quotes and appends prefix operator', () {
  expect(buildMessageFtsQuery(' alpha "beta"  '), '"alpha" "beta"*"');
});

test('global FTS SQL uses message_fts and keeps channel aggregation', () {
  expect(buildGlobalMessageFtsSearchSql(), contains('message_fts'));
  expect(buildGlobalMessageFtsSearchSql(), contains('MATCH ?'));
  expect(buildGlobalMessageFtsSearchSql(), contains('GROUP BY c.channel_id, c.channel_type'));
});
```

- [ ] **Step 2: Run RED**

Run: `dart test test/db/message_fts_search_test.dart`

Expected: FAIL because `message_search_sql.dart` and functions do not exist.

### Task 2: Migration

**Files:**
- Create: `C:\Users\COLORFUL\Desktop\TangSengDaoDao\WuKongIMFlutterSDK-master\assets\202604271430.sql`
- Modify: `C:\Users\COLORFUL\Desktop\TangSengDaoDao\WuKongIMFlutterSDK-master\assets\sql.txt`

- [ ] **Step 1: Add migration**

Create `message_fts` with FTS5 columns: `client_seq`, `message_id`, `channel_id`, `channel_type`, `searchable_word`, `content_edit`.

- [ ] **Step 2: Register migration**

Append `202604271430;` to `assets/sql.txt`.

### Task 3: MessageDB Integration

**Files:**
- Modify: `C:\Users\COLORFUL\Desktop\TangSengDaoDao\WuKongIMFlutterSDK-master\lib\db\message.dart`
- Modify: `C:\Users\COLORFUL\Desktop\TangSengDaoDao\WuKongIMFlutterSDK-master\lib\db\const.dart`

- [ ] **Step 1: Add table constant**

Add `static const tableMessageFts = 'message_fts';`.

- [ ] **Step 2: Prefer FTS search**

In `MessageDB.search` and `MessageDB.searchWithChannel`, call helper SQL if `message_fts` exists; otherwise use existing LIKE SQL.

- [ ] **Step 3: Verification**

Run:
`dart analyze test/db/message_fts_search_test.dart lib/db/message_search_sql.dart lib/db/message.dart lib/db/const.dart`

Run:
`dart test test/db/message_fts_search_test.dart`

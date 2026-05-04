# Mail List Parity Design

**Goal:** Wire the existing Flutter mail-list page to the real `user/maillist` backend and device contacts so the feature behaves like the Android reference for contact import, matching, and invite/add-friend actions.

**Context**

- `MailListPage` already exists as a presentational shell with injected callbacks, but the default load path is a no-op when `onLoadContacts` is not provided.
- Android parity for this feature is intentionally light-weight:
  - request `READ_CONTACTS`
  - read device contacts
  - normalize contact `name` and `phone`
  - upload `[{name, zone, phone}]` to `POST /v1/user/maillist`
  - fetch matched registered contacts from `GET /v1/user/maillist`
  - merge matched contacts before unmatched local contacts in memory
- The server contract is also light-weight:
  - request rows: `name`, `zone`, `phone`
  - response rows: `name`, `zone`, `phone`, `uid`, `vercode`, `is_friend`

**Approaches Considered**

1. Full Android parity with local DB cache.
   Pros: mirrors the native implementation closely and avoids re-uploading unchanged contacts.
   Cons: larger scope, adds persistence code before the end-to-end feature works in Flutter.

2. Stateless runtime import on each open.
   Pros: smallest slice that delivers the real feature, easy to test, avoids premature persistence.
   Cons: re-reads contacts when the page opens and may re-upload duplicate phones.

3. Server-only phone search per contact.
   Pros: avoids adding the `user/maillist` contract.
   Cons: not parity, risks N+1 requests, and bypasses the server feature designed for this flow.

**Selected Design**

Use approach 2.

The Flutter implementation will stay stateless for this slice. When `MailListPage` is opened without an injected `onLoadContacts`, it will call a default mail-list service that:

1. requests read-only contacts permission
2. reads device contacts from a native contacts plugin
3. normalizes contact names and phones using the Android-compatible rules
4. deduplicates by normalized phone
5. uploads the normalized contacts to `POST /v1/user/maillist`
6. fetches matched registered contacts from `GET /v1/user/maillist`
7. merges matched contacts before unmatched local contacts
8. returns `MailListContact` models for the existing UI

**Architecture**

- `MailListPage` remains presentation-first.
- `MailListContact` moves to a shared model file and is re-exported from the page to preserve current imports.
- `UserApi` gains typed mail-list upload/fetch methods plus an `ApiConfig` constant for `/v1/user/maillist`.
- A dedicated mail-list service owns:
  - permission request
  - device contact read
  - normalization and dedupe
  - backend upload/fetch
  - merge into UI-ready contacts
- Plugin access is hidden behind a small gateway so tests can inject fake contacts without touching `MethodChannel`s.

**Normalization Rules**

- `name`: trim and remove spaces, matching Android `replaceAll(" ", "")`
- `phone`: trim, remove spaces, replace `+` with `00`
- `zone`:
  - local upload rows default to `''`
  - matched rows preserve server `zone`
- rows with empty normalized phone are discarded
- duplicate normalized phones collapse to the first usable local contact

**Display / Merge Rules**

- matched registered contacts come first
- unmatched local contacts come after matched contacts
- if a local phone is present in the matched server list, only the matched server contact is kept
- existing page sorting remains:
  - registered before unregistered
  - alphabetical by pinyin section/name within each segment
  - unregistered header inserted once before the first unmatched contact

**Error Handling**

- permission denied: surface a user-visible failure message and keep the page empty
- contacts read failure: surface a user-visible failure message and keep the page empty
- upload or fetch failure: surface a user-visible failure message and keep the page empty
- desktop/unsupported platforms: return an empty list instead of crashing

**Platform Changes**

- add `flutter_contacts`
- Android: add `android.permission.READ_CONTACTS`
- iOS: add `NSContactsUsageDescription`

**Testing**

- extend `test/service/api/user_api_test.dart` for the `user/maillist` request/response contract
- add service-level tests for normalization, dedupe, and merge behavior
- extend `test/wukong_uikit/search/mail_list_page_parity_test.dart` for the default async load path and loading/error behavior

**Non-Goals For This Slice**

- recreating Android's `WKContactsDB`
- write contacts support
- address-book delta sync
- broader profile enrichment beyond fields returned by `GET /v1/user/maillist`

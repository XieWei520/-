# Spec: Chat History Pagination Fix

## Objective
Fix chat history pagination so group and personal chats are not limited to the first 50 visible messages. Users should be able to keep scrolling upward and load older pages without duplicate or newer-page results.

## Tech Stack
- Flutter / Dart SDK `^3.11.1`
- WuKongIM Flutter SDK history API
- Existing history boundary:
  - `lib/data/providers/chat_history_gateway.dart`
  - `lib/data/providers/conversation_provider.dart`
  - `lib/core/repositories/message_repository.dart`

## Commands
- Focused history tests: `flutter test test/data/providers/chat_history_gateway_test.dart test/data/providers/chat_history_gateway_web_cache_test.dart test/data/providers/conversation_provider_search_anchor_test.dart`
- Media link regression tests: `flutter test test/modules/chat/link_preview_service_test.dart test/modules/chat/message_bubble_experience_test.dart`
- Analyze touched files/project: `flutter analyze`

## Project Structure
- `lib/data/providers/chat_history_gateway.dart` -> Native SDK and Web direct history request direction.
- `test/data/providers/chat_history_gateway_test.dart` -> Paging direction regression tests.
- `test/data/providers/chat_history_gateway_web_cache_test.dart` -> Web cache fallback behavior.
- `docs/specs/chat-history-pagination-fix.md` -> This spec.

## Code Style
Keep paging direction explicit at the gateway boundary.

```dart
return _fetch(
  channelId: channelId,
  channelType: channelType,
  oldestOrderSeq: oldestOrderSeq,
  pullMode: 0,
  limit: limit,
  aroundOrderSeq: 0,
);
```

Conventions:
- Tests assert behavior and request parameters, not implementation details outside the gateway boundary.
- Keep page size at 50; do not replace pagination with one large fetch.
- Preserve existing media link rendering behavior.

## Testing Strategy
- Unit tests for `WkImChatHistoryGateway.loadMore`:
  - Native SDK path requests `pullMode: 0` for older pages.
  - Web direct path sends the older-page start sequence and `pullMode: 0`.
  - Web cache fallback for older pages reads records before the current oldest order sequence.
- Existing media tests verify mp3/video link cards still render.

## Boundaries
- Always: keep paginated loading; preserve message ordering; run focused tests before completion.
- Ask first: adding dependencies, changing message protocol, changing backend API contracts.
- Never: delete existing tests, flatten all history into one request, autoplay media in chat list.

## Success Criteria
- Initial chat open may load 50 messages, but upward scroll can request older pages.
- Older page requests use the current oldest message as an upper bound and return earlier messages.
- Web cache fallback for older pages returns messages with `orderSeq < oldestOrderSeq`.
- Existing audio/video link preview tests continue to pass.

## Open Questions
None for this fix. Content-Type detection for extensionless media URLs is a separate enhancement.

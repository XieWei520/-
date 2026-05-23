# Spec: Chat Media Link Preview

## Objective
When a group or personal chat message contains a direct media URL, the message bubble should offer an inline media experience instead of only showing a generic link card.

User stories:
- As a chat user, when I receive a direct audio link, I can tap an inline audio card to play or pause it without leaving the chat.
- As a chat user, when I receive a direct video link, I can see a compact video preview card and tap it to open a larger playback dialog.
- As a chat user, non-media links keep the existing link preview behavior.

## Tech Stack
- Flutter app using Dart SDK `^3.11.1`
- Existing dependencies:
  - `audioplayers: ^6.6.0`
  - `video_player: ^2.8.2`
  - `url_launcher: ^6.2.4`
- Existing chat UI entry point: `lib/widgets/message_bubble.dart`
- Existing link parsing service: `lib/modules/chat/link_preview_service.dart`

## Commands
- Analyze: `flutter analyze`
- Test focused widget behavior: `flutter test test/modules/chat/message_bubble_experience_test.dart`
- Test link preview service behavior: `flutter test test/modules/chat/link_preview_service_test.dart`
- Full test suite when practical: `flutter test`
- Run app: `flutter run -d windows`

## Project Structure
- `lib/modules/chat/link_preview_service.dart` -> URL normalization and media URL classification helpers.
- `lib/widgets/message_bubble.dart` -> Text message rendering and media/link preview card selection.
- `test/modules/chat/message_bubble_experience_test.dart` -> Widget tests for inline audio/video media cards.
- `test/modules/chat/link_preview_service_test.dart` -> Unit tests for URL extraction, normalization, and media type detection.
- `docs/specs/chat-media-link-preview.md` -> This living spec.

## Code Style
Prefer small, explicit helper methods and keep widget keys stable for tests.

```dart
final previewUrl = LinkPreviewService.extractFirstUrl(text);
final mediaType = LinkPreviewService.classifyDirectMediaUrl(previewUrl);

if (mediaType == DirectMediaType.audio) {
  return _InlineAudioLinkCard(url: previewUrl, isSelf: isSelf);
}
if (mediaType == DirectMediaType.video) {
  return _InlineVideoLinkCard(url: previewUrl, isSelf: isSelf);
}
return _LinkPreviewCard(url: previewUrl, isSelf: isSelf);
```

Conventions:
- Widget keys use readable `ValueKey<String>` values.
- Link/media classification should be pure and unit-tested.
- Playback widgets should fail gracefully and keep an external-open affordance.
- No autoplay with sound.

## Testing Strategy
- Unit tests:
  - `.mp3`/`.m4a`/`.aac`/`.wav`/`.ogg` URLs are classified as audio even with query strings.
  - `.mp4`/`.mov`/`.m4v`/`.webm` URLs are classified as video even with query strings.
  - Non-media URLs keep generic link preview classification.
- Widget tests:
  - Text with a supported audio URL renders an inline audio card, not the generic link preview icons.
  - Text with video URL renders an inline video preview card.
  - Tapping the video preview opens a larger playback dialog.
  - Non-media URL still renders `_LinkPreviewCard` behavior.
  - Narrow chat lanes do not overflow.
- Manual verification:
  - Run the app, send an `.mp3` URL in a group, tap play/pause.
  - Send a video URL and confirm preview card initializes without blocking the chat list.

## Boundaries
- Always:
  - Preserve existing generic link preview behavior for non-media URLs.
  - Treat URLs as untrusted input; only support `http` and `https`.
  - Avoid automatic audio/video playback.
  - Dispose playback controllers in stateful widgets.
  - Run focused tests before claiming the feature works.
- Ask first:
  - Adding new dependencies.
  - Changing message protocol/content types.
  - Fetching remote metadata server-side.
  - Auto-downloading large media files before user action.
- Never:
  - Commit secrets or tokens.
  - Remove existing message tests to make the suite pass.
  - Open arbitrary non-HTTP schemes from chat content.
  - Autoplay media in the background.

## Success Criteria
- A text message containing `https://example.com/audio.mp3`, `.m4a`, `.aac`, `.wav`, or `.ogg` renders an inline audio card with a play/pause control.
- Tapping the audio card starts playback using the existing Flutter audio stack and tapping again pauses or resumes.
- A text message containing `https://example.com/video.mp4`, `.mov`, `.m4v`, or `.webm` renders a compact video preview card with a play affordance.
- Tapping the video preview opens a larger playback dialog; video playback only starts after user interaction.
- Non-media links still render the current link preview card.
- Focused tests pass:
  - `flutter test test/modules/chat/message_bubble_experience_test.dart`
  - `flutter test test/modules/chat/link_preview_service_test.dart`

## Plan
1. Add direct media URL classification to `LinkPreviewService`.
   - Keep URL parsing pure and deterministic.
   - Match by normalized URI path extension, ignoring query string and fragment.
   - Return `audio`, `video`, or `none`.
2. Route text-message link cards by classification in `MessageBubble`.
   - Audio URLs render an inline audio card.
   - Video URLs render a compact video preview card.
   - Other URLs keep the existing generic link preview card.
3. Implement media playback UI conservatively.
   - Audio card uses the existing audio stack and only plays after tap.
   - Video card opens a dialog with a `video_player` controller and starts only after user action.
   - All controllers are disposed when widgets/dialogs close.
4. Verify with focused tests and analyzer.

Risks and mitigations:
- Some remote hosts may block browser/player range requests. The UI keeps an external-open affordance as a fallback.
- Some formats may not be supported by every platform codec. The card should show an error state rather than breaking the chat list.
- Large videos should not initialize in every list item. The bubble preview stays lightweight; controller initialization happens in the dialog.

Parallelization:
- URL classification tests and implementation can be done independently of the UI.
- Audio and video widget tests should be sequential after classification exists.

Verification checkpoints:
- Checkpoint 1: `flutter test test/modules/chat/link_preview_service_test.dart`
- Checkpoint 2: `flutter test test/modules/chat/message_bubble_experience_test.dart`
- Checkpoint 3: `flutter analyze`

## Tasks
- [x] Task: Add media URL classification to `LinkPreviewService`.
  - Acceptance: Supported audio/video extensions classify correctly with query strings and fragments; non-media URLs classify as none.
  - Verify: `flutter test test/modules/chat/link_preview_service_test.dart`
  - Files: `lib/modules/chat/link_preview_service.dart`, `test/modules/chat/link_preview_service_test.dart`

- [x] Task: Render media-specific preview cards from text-message links.
  - Acceptance: Supported audio URLs render an audio card, supported video URLs render a video preview card, and non-media URLs still render the generic link preview card.
  - Verify: `flutter test test/modules/chat/message_bubble_experience_test.dart`
  - Files: `lib/widgets/message_bubble.dart`, `test/modules/chat/message_bubble_experience_test.dart`

- [x] Task: Implement audio playback controls.
  - Acceptance: Tapping the audio card toggles play/pause, shows loading/failure state, and disposes playback resources.
  - Verify: `flutter test test/modules/chat/message_bubble_experience_test.dart`
  - Files: `lib/widgets/message_bubble.dart`, `test/modules/chat/message_bubble_experience_test.dart`

- [x] Task: Implement video preview dialog.
  - Acceptance: Tapping the video preview opens a larger dialog player; playback starts only from the dialog interaction; closing disposes the controller.
  - Verify: `flutter test test/modules/chat/message_bubble_experience_test.dart`
  - Files: `lib/widgets/message_bubble.dart`, `test/modules/chat/message_bubble_experience_test.dart`

- [x] Task: Run final verification.
  - Acceptance: Focused tests pass and analyzer reports no new errors from the edited files.
  - Verify: `flutter test test/modules/chat/link_preview_service_test.dart`; `flutter test test/modules/chat/message_bubble_experience_test.dart`; `flutter analyze`
  - Files: No additional files expected.

## Open Questions
None. The first implementation supports audio `.mp3`, `.m4a`, `.aac`, `.wav`, `.ogg`; video `.mp4`, `.mov`, `.m4v`, `.webm`; video playback uses a bubble preview plus larger dialog.

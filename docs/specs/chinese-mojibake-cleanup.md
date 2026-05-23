# Spec: Chinese Mojibake Cleanup

## Objective
Clean user-facing Chinese copy and project metadata that were corrupted by prior encoding mistakes, especially UTF-8 text that was decoded or saved through CP936/GBK and now appears as unreadable Han clusters or replacement question marks. The immediate user impact is Apple browser users seeing unreadable Chinese or missing-glyph boxes; success means the app ships readable Chinese text and has a repeatable scanner to prevent regression.

## Tech Stack
- Flutter 3.41.4 / Dart 3.11.1
- Python 3 with standard library for static text scanning
- Existing Flutter test suite for regression checks

## Commands
- Audit mojibake: `python scripts/ops/audit_chinese_mojibake.py`
- Focused tests: `flutter test test/widgets/wk_typography_web_font_policy_test.dart test/ui_text_chinese_policy_test.dart`
- Analyze: `flutter analyze`
- Web build: `flutter build web --release`

## Project Structure
- `lib/` -> Flutter application and user-facing strings
- `web/` -> Web entrypoint, manifest, service worker text
- `pubspec.yaml` -> App metadata and font declarations
- `scripts/ops/audit_chinese_mojibake.py` -> Repeatable mojibake scanner
- `test/` -> Flutter regression tests and static policy tests
- `docs/specs/chinese-mojibake-cleanup.md` -> This spec

## Code Style
Prefer explicit, readable Chinese strings in UTF-8 source files:

```dart
const title = '???';
const emptyText = '????';
const errorText = '????????????';
```

Avoid storing visibly corrupted strings such as `?????`, `???`, `???`, or replacement-character output. Do not mass-convert files with shell encoding defaults.

## Testing Strategy
- Add and run a deterministic static audit that scans tracked UTF-8 text files for conservative mojibake signatures.
- Fix strings in small slices, prioritizing app metadata, Web entry files, and active user-facing Flutter pages.
- Treat auto-repairable CP936/UTF-8 reversals separately from lossy strings containing `?`; lossy strings require context-based manual replacement.
- Keep existing Flutter tests passing after each slice.

## Boundaries
- Always: Preserve UTF-8; run the scanner after each cleanup slice; keep changes focused on corrupted text and the scanner/spec.
- Ask first: Broad localization architecture changes, adding dependencies, deleting files, changing APIs, or rewriting unrelated UI.
- Never: Blindly rewrite every non-ASCII character, edit binary assets, remove tests to make the scanner pass, or revert unrelated dirty worktree changes.

## Success Criteria
- `scripts/ops/audit_chinese_mojibake.py` exists and detects known mojibake patterns.
- First cleanup slice removes high-confidence corrupted metadata and user-facing strings.
- `python scripts/ops/audit_chinese_mojibake.py` reports fewer findings after each slice, with remaining findings documented if lossy/manual.
- `flutter analyze` passes after code changes.
- Web release build still succeeds.

## Open Questions
- Some lossy strings ending in `?` cannot be recovered mechanically; replacements will be inferred from page context.
- Full cleanup may need several slices because the repository already contains unrelated dirty worktree changes and many user-facing screens.

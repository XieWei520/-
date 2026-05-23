# Spec: Web Startup Performance

## Objective
Reduce first-open lag for the Flutter Web client on desktop browsers, Android
mobile browsers/PWA, and Apple mobile browsers/PWA, especially on mainland China
networks. Success means the first page load downloads materially less data,
repeat opens reuse cached engine/assets, and release packaging cannot accidentally
ship the 17 MB full Chinese fallback font on the Web hot path.

## Tech Stack
- Flutter 3 / Dart 3 Web app using CanvasKit by default.
- Optional Flutter WebAssembly build path for future Skwasm rollout.
- Nginx static hosting for `build/web` release artifacts.
- Custom `web/flutter_bootstrap.js` and lightweight `web/wk_pwa_service_worker.js`.

## Commands
- Analyze: `flutter analyze`
- Focused tests: `flutter test test/widgets/wk_typography_web_font_policy_test.dart test/scripts/ops/flutter_web_release_prune_test.dart test/scripts/ops/flutter_web_release_deploy_test.dart test/scripts/ops/nginx_edge_optimizations_test.dart test/web_entrypoint_cache_cleanup_test.dart test/modules/auth/auth_login_page_test.dart`
- Build: `flutter build web --release`
- Prune: `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/ops/prune_flutter_web_release.ps1 -BuildWebDir build/web`
- Mojibake audit: `python scripts/ops/audit_chinese_mojibake.py`

## Project Structure
- `lib/widgets/wk_design_tokens.dart` -> shared typography and font fallback policy.
- `lib/app/app.dart` -> app shell and startup side-effect binding.
- `lib/modules/local_monitor/local_monitor_auto_forward_coordinator.dart` ->
  lightweight coordinator shell for optional local monitor auto-forward runners.
- `lib/modules/local_monitor/local_monitor_auto_forward_runner_factory.dart` ->
  deferred runner factory that may pull in heavier local monitor modules after
  login instead of on the first Web bundle.
- `lib/modules/video_call/video_call_runtime_bridge.dart` -> lightweight app/IM
  bridge that defers WebRTC call coordinator and media service loading.
- `lib/modules/video_call/deferred_video_call_pages.dart` -> lightweight chat
  route wrapper that defers call page factories until the user opens a call.
- `web/` -> Web entrypoint, Flutter bootstrap, manifest, offline worker.
- `scripts/ops/prune_flutter_web_release.ps1` -> local release artifact pruning.
- `scripts/ops/deploy_flutter_web_release.ps1` -> release packaging and remote deploy.
- `scripts/ops/apply_nginx_edge_optimizations.sh` -> remote Nginx cache/edge rules.
- `test/app/`, `test/modules/local_monitor/`, `test/scripts/ops/`, and
  `test/widgets/` -> policy tests for startup and release safety.

## Code Style
```dart
static const List<String> webFontFamilyFallback = [
  'Noto Color Emoji',
  'WKChineseWebSubset',
  'Microsoft YaHei UI',
  'PingFang SC',
  'sans-serif',
];
```
Keep Web startup policy explicit and test guarded. Prefer boring release scripts
with dry-run support, required artifact checks, and clear rollback hints.

## Testing Strategy
- Static policy tests guard the Web typography hot path and release scripts.
- Static startup tests guard `WuKongApp` against directly importing optional
  local monitor runner implementations.
- Coordinator unit tests verify deferred runner loading only happens after the
  user is logged in and stays safe across logout/dispose races.
- Static startup tests guard app, IM, and chat providers against directly
  importing WebRTC-heavy video call implementations.
- Release build verifies Flutter still emits a valid Web app.
- Post-build pruning verifies the actual deployed artifact no longer includes
  unused renderer symbols or the full CJK font.
- Nginx tests guard cache headers for static assets and revalidation-sensitive
  entrypoints.

## Boundaries
- Always: keep full CJK fallback available for native Windows/Android builds.
- Always: self-host CanvasKit and Flutter fallback font probes for mainland China.
- Always: run release pruning before packaging `build/web` for deployment.
- Ask first: enabling `flutter build web --wasm` as the primary production build,
  because it changes artifact shape and needs browser/device rollout data.
- Never: rely on remote Google font/CDN resources for first-load correctness.
- Never: delete unrelated dirty worktree changes.

## Success Criteria
- Web runtime no longer references `WKNotoSansSC` in `main.dart.js`.
- Pruned Web release removes `assets/assets/reference_ui/fonts/noto_sans_sc_vf.ttf`.
- Largest required Web font drops from about 16.95 MB to the existing 4.02 MB subset.
- Deploy script prunes before creating the `.tar.gz`.
- Static assets under `/assets` and `/canvaskit` remain long-cacheable by Nginx.
- Optional local monitor auto-forward runner implementations are no longer
  directly imported by `lib/app/app.dart`.
- Local monitor runner loading happens only after login and can be emitted as a
  deferred Web chunk by Dart/Flutter Web.
- Video call coordinator/service/page implementations are no longer directly
  imported by app startup, IM startup, or chat scene providers.
- Current measured `main.dart.js` is 7,166,827 bytes after the deferred-loading
  phase, down from the previous 7,627,673-byte baseline.
- Current pruned Web release is about 30.69 MB and emits deferred chunks,
  including a 418,642-byte video-call chunk.
- `flutter analyze`, focused tests, `flutter build web --release`, prune command,
  and mojibake audit pass.

## Open Questions
- Whether production should switch to `flutter build web --wasm` after a device
  compatibility rollout. Flutter documents that `--wasm` can prefer Skwasm and
  fall back to CanvasKit, but Safari/iOS compatibility still needs real testing.

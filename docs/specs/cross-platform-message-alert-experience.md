# Spec: Cross-Platform Message Alert Experience

## Objective
Build a predictable message alert experience for Windows desktop, Android app,
desktop web, Android mobile web/PWA, and Apple mobile web/PWA.

When another user sends a message, the app should notify without creating alert
fatigue. The user should understand what happened, be able to open the
conversation from the alert, and retain control over sound, vibration, and
message-detail privacy.

Success means:
- Foreground users get lightweight, non-disruptive alerts.
- Background users get platform-native notifications where the platform allows
  it.
- Mobile web does not depend on page JavaScript for background sound.
- Apple mobile web behavior is explicit: reliable background notification
  requires iOS/iPadOS 16.4+ and a Home Screen web app.

## Tech Stack
- Flutter 3 / Dart 3 app shared by Windows, Android, and Web.
- Existing notification libraries:
  - `flutter_local_notifications` for Android local notifications.
  - `local_notifier` for Windows desktop notifications.
  - `audioplayers` for foreground web/app sound effects.
  - `firebase_messaging` for native Android/iOS FCM only when explicitly
    enabled for overseas or Google-services devices.
- Mainland China candidate push providers:
  - Preferred default: a push aggregator with mainland manufacturer channels.
  - Practical candidates: Getui, JPush, or Tencent Cloud Push when the product
    already has an available Tencent Cloud Push entitlement.
  - Direct vendor SDKs remain an option only when the team wants to manage every
    manufacturer credential, quota, and release process directly.
- Web platform APIs:
  - Notification API for visible browser notifications.
  - Service Worker API for background Web Push notifications.
  - Push API or Firebase Cloud Messaging for Web Push token registration.

## Commands
- Analyze: `flutter analyze`
- Unit tests: `flutter test`
- Focused alert tests: `flutter test test/wukong_push`
- Web build: `flutter build web --release`
- Android build: `flutter build apk --release`
- Windows build: `flutter build windows --release`

## Project Structure
- `lib/wukong_push/notification/`
  - Shared alert planning, web notification manager, Android alert manager,
    Windows alert manager, notification helpers.
- `lib/service/im/im_notification_bridge.dart`
  - Entry point from incoming IM messages to platform alert managers.
- `web/wk_pwa_service_worker.js`
  - PWA service worker. Should own background Web Push notification display.
- `web/manifest.json`
  - PWA install behavior for mobile browsers, including Apple Home Screen use.
- `test/wukong_push/`
  - Unit and policy tests for message alerts, platform managers, and web push
    notification behavior.
- `docs/specs/`
  - Living product and implementation specs.

## Code Style
Keep platform rules centralized and make the call site easy to read:

```dart
final plan = buildMessageAlertPlan(
  message,
  currentUid: currentUid,
  requireRedDot: shouldRequireRedDot(lifecycleState),
);
if (plan == null) {
  return;
}

await alertDispatcher.dispatch(
  plan: plan,
  lifecycleState: lifecycleState,
  surface: resolveAlertSurface(platform, lifecycleState),
);
```

Conventions:
- Do not scatter platform checks through feature UI.
- Prefer small immutable plan/decision objects over side-effect-heavy helpers.
- Keep browser-specific code behind conditional imports or web-only files.
- Do not log message bodies in production diagnostics.
- Do not use page JavaScript audio as the only background alert path on mobile
  web.

## Testing Strategy
- Unit tests:
  - Message eligibility: self messages, muted channels, deleted/internal
    messages, red-dot behavior, privacy body replacement.
  - Alert decisions: foreground vs background, current conversation vs other
    conversation, coalescing, sound/vibration flags.
  - Android notification construction: channel id, sound, vibration,
    `onlyAlertOnce`, group key, hidden detail.
  - Windows manager decisions: foreground tick vs background toast.
  - Web manager decisions: foreground audio vs browser notification vs push
    fallback.
- Static integration tests:
  - Service worker contains `push` and `notificationclick` handlers.
  - Web notifications do not set `silent: true` for message alerts.
  - Login or post-login UI exposes a user-gesture path for notification/audio
    unlock.
- Manual verification:
  - Desktop Chrome web foreground and background.
  - Android Chrome regular tab and installed PWA.
  - iPhone Safari regular tab and iOS 16.4+ Home Screen web app.
  - Windows desktop minimized and focused windows.
  - Android app foreground, background, lock screen, and notification-disabled
    states.

## Boundaries
- Always:
  - Respect global notification, sound, vibration, privacy, and mute settings.
  - Use system notifications for background alerts where available.
  - Keep foreground alerts lightweight.
  - Coalesce rapid same-conversation messages.
  - Route notification clicks to the relevant conversation.
  - Document platform limitations in user-facing setup where needed.
- Ask first:
  - Adding a new push vendor or backend device-token contract.
  - Changing server push payload format.
  - Adding a new dependency.
  - Replacing `local_notifier` with Windows App SDK notifications.
  - Changing app branding, notification icons, or default sounds.
- Never:
  - Promise custom background sounds on mobile web.
  - Bypass OS notification, focus, silent, or Do Not Disturb settings.
  - Show message content when detail privacy is disabled.
  - Treat ordinary iPhone Safari tabs as reliable background IM notification
    clients.
  - Commit push credentials, VAPID private keys, Firebase secrets, or service
    account files.

## Message Alert Behavior

### Shared Eligibility
Incoming messages should not alert when:
- The message was sent by the current user.
- The message is deleted or internal/system-only.
- The conversation is muted.
- Global new-message notification is disabled.
- The current route is already showing the same conversation and the product
  chooses "quiet current conversation" behavior.

When message details are disabled, title/body should use privacy-safe text:
- Title: app name or conversation name, depending on platform limits.
- Body: `收到一条新消息` or equivalent localized copy.

### Foreground Behavior
- Current conversation:
  - No system notification.
  - No full alert sound.
  - Optional very light tick only if product decides current conversation needs
    acknowledgement.
- Different conversation:
  - Short foreground sound if sound is enabled and the platform allows it.
  - In-app banner or badge update.
  - No system notification unless the platform cannot present a reliable
    in-app banner.

### Background Behavior
- Use platform-native notification surfaces.
- Play sound only through the platform-supported notification mechanism.
- Do not depend on foreground Flutter/Web page code being alive.
- Coalesce rapid same-conversation messages within a short window, for example:
  `3 条新消息`.

## Platform Requirements

### Mainland China Deployment Constraints
- Android push must not depend on Firebase Cloud Messaging as the primary
  delivery path. Most mainland Android devices do not ship with reliable Google
  Play services, and FCM delivery is not a safe baseline.
- Firebase Cloud Messaging can stay in the codebase as an opt-in fallback, but
  mainland production builds must not enable it as the only remote push handler.
- Android app production delivery should use one of these strategies:
  - A push aggregator with mainland manufacturer channels, for example a service
    that can route to Huawei, Xiaomi, OPPO, vivo, Honor, Meizu, and APNs.
  - Direct manufacturer push integrations if the team wants full control over
    credentials, quota, and vendor-specific behaviors.
  - FCM may remain as an overseas or Google-services fallback only.
- Recommended mainland default:
  - Choose a push aggregator first. This keeps the app code and backend contract
    stable while the aggregator handles Huawei, Honor, Xiaomi, OPPO, vivo,
    Meizu, APNs, and optional FCM routing.
  - Prefer Getui or JPush when starting a new mainland deployment and no vendor
    account already exists.
  - Use Tencent Cloud Push only if the business already has access to the
    product; Tencent Cloud documentation currently warns that TPNS has stopped
    selling to new users.
  - Use direct vendor SDKs only if delivery rate requirements justify the extra
    account setup, review, package signing, vendor SDK updates, and backend
    routing complexity.
- Mainland Android push payloads must be classified as service/communication or
  private-message notifications where the selected provider and manufacturer
  allow it. Chat messages and call invites must never be sent as marketing or
  public-broadcast categories.
- Manufacturer-channel validation must use real signed builds and real devices:
  Huawei/Honor, Xiaomi, OPPO, vivo, and Meizu at minimum. Emulator-only or FCM
  tests are insufficient for mainland release approval.
- Web Push in mainland China should be treated as best-effort:
  - Desktop Chrome/Edge behavior depends on browser push service availability
    and user/system notification settings.
  - Android mobile browser support varies by browser and OEM ROM.
  - WeChat/embedded browsers should be considered foreground-only for reliable
    IM alerts.
- For users who need dependable mobile alerts in mainland China, the product
  should recommend the native Android app or iOS app/Home Screen PWA rather than
  ordinary mobile web.
- Windows desktop client remains a strong channel because it can keep the IM
  connection alive and show local Windows notifications without relying on a
  mobile/browser push service.

### Mainland China Channel Priority
1. Native Android app with manufacturer/aggregator push for offline delivery.
2. Native Windows app with live IM connection plus local Windows notifications.
3. iOS native app through APNs, or iOS/iPadOS 16.4+ Home Screen PWA for users
   who cannot install a native iOS app.
4. Desktop web as a useful secondary surface.
5. Android mobile web/PWA and Apple ordinary browser tabs as best-effort only.

This priority should drive product copy too: when a mainland user depends on
timely alerts, guide them to install the Android/Windows native app instead of
promising reliable background sound in a mobile browser.

### Windows Desktop
- Foreground:
  - Play short tick for non-current conversations.
  - Prefer in-app banner over Windows Toast while the app is focused.
- Background/minimized:
  - Show Windows Toast through `local_notifier` or a future Windows App SDK
    implementation.
  - Notification click activates the app and opens the conversation.
  - Respect Windows Focus Assist and system notification settings.
- Sound:
  - Avoid double sound. Either the app plays sound and the toast is silent, or
    the toast uses system sound.

### Android App
- Foreground:
  - Current conversation is quiet.
  - Other conversations can use a short tick and in-app banner.
- Background/lock screen:
  - Use high-importance message notification channel.
  - Use custom message sound via Android raw resource when sound is enabled.
  - Use vibration when enabled.
  - Use `CATEGORY_MESSAGE`, group keys, and `onlyAlertOnce` for coalesced
    updates.
- Mainland offline delivery:
  - Register one provider token per installed app instance, then bind it to the
    logged-in account on the backend.
  - Server push requests must include conversation id, message id, route target,
    privacy-safe title/body, and provider-specific channel classification.
  - Click actions should open the app and route to the conversation through a
    signed or validated in-app payload; do not use arbitrary external URLs for
    IM messages.
- Permissions:
  - Request Android 13+ notification permission.
  - Provide system notification settings entry when permission/channel is off.

### Desktop Web
- Foreground visible page:
  - Use Web Audio/HTML audio only after a user gesture unlocks audio.
  - Show in-app banner for non-current conversations.
- Hidden/minimized browser:
  - Use Web Push and Service Worker notifications.
  - Do not rely on page JavaScript audio.
  - Browser/system controls sound; custom sound is not guaranteed.
- Closed browser:
  - Web Push may still display a notification if the browser/platform supports
    it and permission was granted.

### Android Mobile Web/PWA
- Foreground:
  - User must tap an "开启消息提醒" style control before audio can be reliable.
- Background:
  - Use Web Push through Service Worker.
  - Notification sound is controlled by browser/system notification settings.
  - Installed PWA is preferred over a normal tab for reliability.
- Limits:
  - Do not promise custom background audio.

### Apple Mobile Web/PWA
- Ordinary Safari tab:
  - Foreground-only behavior is the realistic baseline.
  - Background message sound and notifications are not reliable.
- Home Screen web app:
  - iOS/iPadOS 16.4+ supports Web Push for Home Screen web apps.
  - The manifest must support standalone/fullscreen display.
  - User must add the app to Home Screen, open from that icon, and grant
    notification permission from a user gesture.
  - Background sound is system-notification controlled, not custom web audio.

## Success Criteria
- A message in the currently open conversation does not create a disruptive
  system notification.
- A message in another conversation while the app is foregrounded creates a
  lightweight visible alert and, if allowed, a short sound.
- A message while Windows desktop is minimized produces a Windows notification
  and opens the correct chat when clicked.
- A message while Android app is backgrounded produces a message-channel
  notification with configured sound/vibration/privacy behavior.
- A message while desktop web or Android PWA is backgrounded is delivered
  through Service Worker/Web Push rather than page JavaScript audio.
- iPhone Safari ordinary-tab limitations are documented in product copy.
- iPhone Home Screen PWA setup is supported and documented.
- Tests cover alert eligibility, platform decision logic, privacy text, and
  notification coalescing.

## Open Questions
- Which mainland push provider should Android production use: Getui, JPush,
  Tencent Cloud Push if already available, RongCloud push routing if already
  part of the backend, or direct Huawei/Xiaomi/OPPO/vivo/Honor/Meizu
  integrations?
- Which backend push provider should web use for best-effort browser delivery:
  direct Web Push with VAPID, Firebase Cloud Messaging Web for overseas users,
  or both?
- Does the backend already accept web push tokens separately from native device
  tokens?
- Should Windows continue with `local_notifier` for this milestone, or should a
  future milestone migrate to Windows App SDK app notifications?
- What exact Chinese copy should be shown for iPhone "Add to Home Screen" and
  "Enable message alerts" guidance?
- Should current-conversation foreground messages play no sound, or a very
  subtle tick?

## Implementation Plan

### Phase 1: Fix Current Web Alert Reliability
- Remove `silent: true` from message browser notifications unless the user has
  disabled sound.
- Add tests that fail if web message notifications are forced silent.
- Add a user-gesture notification/audio unlock path after login and for
  auto-login sessions.
- Make web foreground sound failure visible in diagnostics without interrupting
  the user.

### Phase 2: Web Push Foundation
- Add a Service Worker `push` handler that parses the message payload and calls
  `registration.showNotification()`.
- Preserve the existing `notificationclick` handler and route clicks to the app.
- Add static tests for push and click handlers.
- Use direct standards-based Web Push with VAPID for Web/PWA clients:
  - `GET /v1/user/web_push/config` returns only the VAPID public key and enabled
    state.
  - `POST /v1/user/web_push/subscription` stores the browser
    `PushSubscription` in Redis under the logged-in user.
  - `DELETE /v1/user/web_push/subscription` removes the logged-in user's Web
    Push subscription.
  - The VAPID private key is read from server environment/config only and is
    never committed to the repository.
- On iOS/iPadOS, the user must open the Home Screen web app and tap the
  in-product enable control so `Notification.requestPermission()` and
  `PushManager.subscribe()` run from user interaction.
- Offline message push should send native app push as before and also attempt
  Web Push when a Redis subscription exists. A Web Push failure must not block
  native push or message delivery.

### Phase 3: Mainland Android Push Provider Contract
- Select one mainland provider:
  - Getui or JPush for a new independent mainland deployment.
  - Tencent Cloud Push only when the product already has a usable TPNS service.
  - Direct vendor SDKs only after explicitly accepting higher maintenance cost.
- Define the backend token contract:
  - `provider`: `GETUI`, `JPUSH`, `TENCENT_PUSH`, `HMS`, `HONOR`, `MI`, `OPPO`,
    `VIVO`, `MEIZU`, `APNS`, or `FCM`.
  - `token`: provider client id, registration id, or vendor token.
  - `platform`: `android`, `ios`, `web`, or `windows`.
  - `package_name`, `app_version`, `device_brand`, `os_version`.
  - `region`: `CN` or `GLOBAL`.
- Define the server push payload:
  - `message_id`, `channel_id`, `channel_type`, `sender_uid`.
  - Privacy-safe `title` and `body`.
  - `route`: app-internal conversation target.
  - Provider-specific notification category/channel fields.
- Add provider SDK integration only after credentials, privacy policy text,
  backend API fields, and real device test plan are ready.

### Phase 4: Shared Alert Decision Cleanup
- Introduce or refine a shared alert decision object for:
  - current conversation,
  - foreground other conversation,
  - background,
  - privacy body,
  - coalesced count,
  - sound/vibration flags.
- Reuse the decision across Android, Windows, and Web managers.

### Phase 5: Platform Polish
- Android: verify notification channel, sound resource, vibration, privacy, and
  permission settings entry.
- Windows: verify click routing, no double sound, minimized behavior.
- Web: verify desktop Chrome, Android Chrome/PWA, and iPhone Home Screen PWA
  documented setup.

### Phase 6: No-Remote-Push Enhancement Mode
Use this mode when Getui, JPush, FCM, APNs, Web Push token registration, and
manufacturer channels are unavailable.

Scope:
- Windows: keep the desktop process alive and show local Windows notifications
  from the active IM connection.
- Android: start a visible foreground service after login, request notification
  permission, open battery optimization settings, and show local high-priority
  message notifications while the process and IM connection are alive.
- Web: unlock audio and Notification permission from a user gesture, use page
  notifications while the browser page remains alive, and make Service Worker
  click routing safe and deterministic for future Web Push payloads.

Non-goals:
- Do not promise notification delivery after the Android process is killed.
- Do not promise delivery after a desktop or mobile browser is closed.
- Do not promise iPhone ordinary Safari background delivery.
- Do not promise custom web audio in any background mobile web state.

Verification:
- Android settings copy must clearly call this a local background alert
  enhancement, not offline push.
- Android privacy mode must hide content and use count-based generic text.
- Service Worker notification clicks must reject cross-origin targets, navigate
  existing windows to same-origin targets, post the click payload back to the
  app, and open a window only when needed.

## Source Notes
- Firebase Cloud Messaging Android clients require a device with Google Play
  Store or an emulator with Google APIs, so it is not the mainland Android
  primary channel:
  https://firebase.google.com/docs/cloud-messaging/android/get-started
- Android 13+ requires runtime `POST_NOTIFICATIONS`; Android 8+ requires
  notification channels and user-controlled channel behavior:
  https://developer.android.com/develop/ui/views/notifications/notification-permission
  and https://developer.android.com/develop/ui/views/notifications/channels
- Chrome blocks audible autoplay until user interaction or equivalent engagement,
  so web foreground sound must be unlocked from a user gesture:
  https://developer.chrome.com/blog/autoplay/
- Service Worker notification display should use
  `ServiceWorkerRegistration.showNotification()` and avoid invalid combinations
  such as `silent: true` with vibration:
  https://developer.mozilla.org/en-US/docs/Web/API/ServiceWorkerRegistration/showNotification
- Service Worker notification clicks can use `clients.openWindow()` from a
  notification click and generally require same-origin URLs:
  https://developer.mozilla.org/en-US/docs/Web/API/Clients/openWindow
- Apple supports Web Push for iOS/iPadOS 16.4+ Home Screen web apps, with
  permission requested from direct user interaction:
  https://webkit.org/blog/13878/web-push-for-web-apps-on-ios-and-ipados/
- Android foreground services must show a status bar notification so users know
  the app is performing foreground work:
  https://developer.android.com/develop/background-work/services/fgs
- Getui documents online delivery through Getui and offline delivery through
  manufacturer channels when those channels are enabled:
  https://docs.getui.com/getui/start/accessGuide/
- Tencent Cloud Push documents Huawei, Honor, Xiaomi, Meizu, FCM, vivo, and
  OPPO channel access, but its product creation page warns TPNS has stopped
  selling to new users:
  https://cloud.tencent.com/document/product/548/61135
  and https://cloud.tencent.com/document/product/548/37241

## Task List

- [ ] Task: Prevent web message notifications from being forced silent.
  - Acceptance: Web notification options do not set `silent: true` when sound is
    enabled.
  - Verify: `flutter test test/wukong_push/web_notification_integration_policy_test.dart`
  - Files: `lib/wukong_push/notification/web_notification_manager_web.dart`,
    `test/wukong_push/web_notification_integration_policy_test.dart`

- [ ] Task: Add explicit web alert unlock entry point.
  - Acceptance: Auto-login users can click a visible control to request
    notification permission and unlock audio.
  - Verify: focused widget/static tests plus manual desktop web smoke test.
  - Files: login/home shell notification prompt files to be determined after
    UI context review.

- [ ] Task: Add Service Worker push notification display.
  - Acceptance: `web/wk_pwa_service_worker.js` handles `push`, shows a
    notification, and retains click routing.
  - Verify: static service worker tests and manual browser push simulation.
  - Files: `web/wk_pwa_service_worker.js`, `test/...`

- [ ] Task: Define web push token provider contract.
  - Acceptance: direct VAPID Web Push is selected; Redis subscription storage,
    public-key config, and offline message payload fields are documented.
  - Verify: `flutter test test/wukong_push/web_notification_integration_policy_test.dart`
  - Files: spec update, `lib/service/api/web_push_api.dart`,
    `lib/wukong_push/notification/web_notification_manager_web.dart`,
    `.codex-backend-work/src/modules/user/api.go`,
    `.codex-backend-work/src/modules/webhook/push_webpush.go`.

- [ ] Task: Select mainland Android push provider.
  - Acceptance: provider is selected, credential checklist is complete, privacy
    policy text is drafted, and backend token/payload contract is approved.
  - Verify: signed APK receives offline notifications on at least Huawei/Honor,
    Xiaomi, OPPO, vivo, and Meizu test devices.
  - Files: spec update, backend API contract, Android Gradle/manifest files,
    provider handler files after provider approval.

- [ ] Task: Normalize foreground/current-conversation decisions.
  - Acceptance: current conversation is quiet; other foreground conversations
    produce lightweight alerts.
  - Verify: alert policy tests.
  - Files: `lib/wukong_push/notification/*policy*.dart`, related tests.

- [ ] Task: Platform verification pass.
  - Acceptance: documented manual results for Windows, Android app, desktop web,
    Android PWA, iPhone ordinary Safari, and iPhone Home Screen PWA.
  - Verify: `flutter analyze`, focused tests, platform smoke checklist.
  - Files: docs and any fixes found during verification.

# Windows Message Notifications Design

Date: 2026-05-01
Status: Approved for planning

## Context

The Windows desktop client should alert the user when an incoming IM message arrives. When the app is visible and active, the alert should be lightweight and sound-only. When the app is minimized, hidden, or not the active app, the alert should appear as a Windows notification card.

The existing project already has Web message alert planning in `lib/wukong_push/notification/web_message_alert_plan.dart` and routes incoming realtime messages through `IMService._handleNewMessages` in `lib/service/im/im_service.dart`. Windows push registration is not currently part of `PushService`; mobile push remains Android/iOS-focused. For Windows desktop, the correct first implementation path is therefore local alerts from the realtime IM message callback.

Because Windows has no mobile-style push fallback in the current app, the Windows IM session must remain connected while the window is minimized or hidden. Existing mobile lifecycle disconnect behavior should remain unchanged.

Microsoft's notification guidance says notifications should be informative and valuable, should not be noisy, and should be used for cases where the user is not currently inside the app. This design follows that model: system cards are reserved for background/minimized states, while foreground messages use a short, unobtrusive sound.

Reference: https://learn.microsoft.com/en-us/windows/apps/design/shell/tiles-and-notifications/toast-ux-guidance

## Goals

- Play a message sound on Windows when an eligible incoming message arrives.
- Show a Windows system notification card when the app is minimized, hidden, or not focused.
- Avoid noisy notification storms by coalescing frequent messages from the same conversation.
- Reuse existing message preview and mute/self-message filtering semantics where possible.
- Keep the Windows realtime IM connection alive while minimized so local alerts can be delivered.
- Keep mobile push behavior and Web notification behavior unchanged.

## Non-Goals

- No cloud push registration for Windows in this iteration.
- No custom in-app overlay notification while the app is minimized.
- No quick reply, mention-specific routing, or notification action buttons in the first pass.
- No changes to the current Android, iOS, macOS, Linux, or Web alert behavior unless needed for shared tests.

## Recommended Approach

Create a small Windows desktop notification layer that is invoked from `IMService._handleNewMessages` after existing content filtering and realtime publication work.

The layer should have three separable responsibilities:

1. Alert planning
   - Convert a `WKMsg` into a reusable message alert plan.
   - Use the same eligibility rules as the Web alert plan: skip deleted messages, internal messages, self messages, messages without red-dot intent, and muted channels.
   - Use the existing message preview resolver for notification body text.
   - Resolve title from sender, group, or conversation metadata.

2. Presentation policy
   - If the platform is not Windows, do nothing.
   - On Windows, do not disconnect the realtime IM session only because the app is minimized or hidden.
   - If the app is focused and visible, play only a short foreground tick.
   - If the app is minimized, hidden, or unfocused, show a Windows notification card and play the normal message sound through the notification system or local audio fallback.
   - If focus/minimized state cannot be read, prefer the less disruptive foreground behavior when the app lifecycle says resumed, and background behavior when lifecycle is hidden/paused.

3. Rate limiting and coalescing
   - Same conversation: allow one visible card immediately, then coalesce additional messages for a short window, approximately 2 seconds.
   - If multiple messages arrive in the coalescing window, update the notification body to a summary such as "N new messages" while preserving the conversation title.
   - Different conversations: allow separate notification cards, with a small global cooldown to avoid rapid bursts.
   - Notification IDs/tags should be stable per conversation so Windows Notification Center remains tidy.

## Sound Design

Use the existing bundled assets:

- `assets/audio/im_tick.wav` for focused foreground messages.
- `assets/audio/im_message.wav` for background/minimized message alerts.

The sound should be short, soft, and recognizable, following mainstream IM behavior: a crisp tick in the foreground and a slightly more noticeable message cue when the user is outside the app. Volume should be conservative by default, and errors from audio playback must be swallowed after debug logging so message delivery is never blocked by sound playback.

## Windows Notification Card Behavior

The notification content should be simple:

- Title: sender name for personal chat; sender plus group/conversation for group chat where available.
- Body: compact preview text, capped to the same length as the existing alert plan.
- Icon: app icon when supported by the chosen Windows notification implementation.
- Activation: clicking the card should eventually open the related conversation if the platform implementation exposes payload activation. If activation is not practical in the first pass, the notification must still show reliably and leave the payload structure ready for activation later.

## Implementation Shape

Likely files:

- Add a shared alert planner or generalize `web_message_alert_plan.dart` so Windows can reuse the same logic without Web naming.
- Add `lib/wukong_push/notification/desktop_message_alert_manager.dart` with a conditional stub and Windows implementation if platform-specific APIs are needed.
- Wire `IMService._handleNewMessages` to call the desktop manager when `defaultTargetPlatform == TargetPlatform.windows && !kIsWeb`.
- Add tests for planner eligibility, title/body construction, Windows-only dispatch, and coalescing policy.

The implementation should avoid putting Windows-specific imports in cross-platform Dart files unless guarded by conditional exports or dependency-injected interfaces.

## Testing

Use TDD for the implementation:

- Planner tests: incoming personal and group messages produce expected title/body.
- Eligibility tests: self, muted, deleted, internal, and non-red-dot messages do not alert.
- Dispatch tests: non-Windows platforms do not call the desktop presenter.
- Policy tests: foreground state plays only sound; background/minimized state requests a card.
- Coalescing tests: repeated messages from one conversation within the throttle window collapse into one update/summary.

Manual verification after tests:

- Run Windows desktop build.
- With app focused, send a message and confirm only a short sound plays.
- Minimize the app, send one message, and confirm a Windows notification card appears.
- Send several rapid messages in one conversation and confirm cards do not spam.
- Confirm muted conversation and self-sent messages do not alert.

## Open Decisions

The implementation plan must choose the Windows notification backend after checking current package support and the app's unpackaged/packaged build constraints. Preferred order:

1. Use a maintained Flutter-compatible Windows toast plugin if it supports this app shape and payload activation cleanly.
2. Use a small native Windows runner bridge if plugin support is insufficient.
3. Fall back to app audio plus taskbar/system attention only if reliable toast delivery is blocked, but this is not the target outcome.

## Acceptance Criteria

- Eligible Windows incoming messages produce sound.
- Eligible Windows messages show a system notification card when minimized or unfocused.
- Foreground messages do not show system cards.
- Notification frequency is controlled per conversation and does not produce a card per rapid message.
- Existing Web notification tests remain green.
- New Windows alert tests cover filtering and coalescing behavior.

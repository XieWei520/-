# Manual E2E Cloud Joint Test Plan

> **For testers:** This plan is manual-first. Client pass/fail must come from real UI interaction on the running app. SSH is allowed only for cloud observability, log correlation, and evidence capture.

**Goal:** Complete full-function manual coverage for the currently exposed WuKongIM Flutter app using direct app operation plus cloud-server joint debugging on `42.194.218.158`.

**Architecture:** Use Windows desktop as the primary manual driver, Android as the real-time peer device, and Web/desktop browser as the third session endpoint. Every scenario is validated in the UI first, then correlated with Nginx, TSDD API, WuKongIM, LiveKit, and call-gateway evidence on the cloud server.

**Tech Stack:** Flutter Windows/Android/Web, WuKongIM, TSDD API, Nginx, MySQL, Redis, LiveKit, Coturn, SSH

---

## Current Environment Snapshot

- Date verified: `2026-04-09` (Asia/Shanghai)
- App API base URL in current source: `http://42.194.218.158`
- App IM address in current source: `42.194.218.158:5100`
- Historical README still mentions `5200`, so port drift must be treated as an environment watchpoint, not an app defect by default.
- SSH access is working: `ssh ubuntu@42.194.218.158`
- Verified server-side listeners:
  - `80/tcp` Nginx
  - `443/tcp` Nginx
  - `5001/tcp` API loopback only
  - `5100/tcp` WuKongIM external
  - `5200/tcp` WuKongIM external
  - `3478/tcp+udp` Coturn
  - `7881/tcp` LiveKit RTC
- Verified HTTP health:
  - `GET http://42.194.218.158/v1/ping` returns `{"status":200}`
  - `GET /` returns `404`, which is acceptable and should not be logged as a defect
- Verified HTTPS status:
  - `https://42.194.218.158` timed out on `2026-04-09 14:21 CST`
  - All Web login, QR confirmation, secure-browser, and RTC browser scenarios must be tested with this risk explicitly tracked
- Verified cloud containers currently in play:
  - `wukongim_prod-nginx-1`
  - `wukongim_prod-tsdd-api-1`
  - `wukongim_prod-wukongim-1`
  - `wukongim_prod-livekit-1`
  - `wukongim_prod-callgateway-1`

## Scope Rules

- Use direct manual interaction only for client validation.
- Do not use Flutter widget tests, CLI assertions, or mock scripts as acceptance evidence.
- Use SSH only to observe logs, ports, health, and persistence after UI actions.
- Cover all currently visible or reachable user-facing functionality in the app.
- Treat README "already implemented" and "pending" lists as historical hints only; the actual current source and runtime UI are the truth.
- Any standalone page that exists in source but is not exposed in the main nav still needs at least a route-open smoke check if the app provides an entry path.

## Test Devices And Roles

- `Client A`: Windows desktop app, primary operator, main evidence recorder
- `Client B`: Android phone, second peer for real-time messaging, permissions, push, scan, and call
- `Client C`: Browser session or second desktop/mobile device, used for Web login, device list, cross-session eviction, and three-party/group edge cases
- `Client D` optional: spare account for blacklist, stranger, and invite-only cases when three users are not enough

## Test Accounts And Seed Data

- `Account A`: group owner, primary desktop user
- `Account B`: normal friend and normal group member
- `Account C`: stranger first, then friend, then Web/PC session holder
- `Account D` optional: blocked user / negative-path actor
- Seed one personal conversation: `A <-> B`
- Seed one normal group: owner `A`, members `B` and `C`
- Seed one invite-only group: owner `A`, member `B`, outsider `C`
- Seed one blacklist relation: `A` blocks `D`
- Seed one searchable history set:
  - text messages with distinct keywords
  - image messages
  - voice messages
  - link-preview message
  - favorite candidate message
  - one message from each member in the group
- Seed one moments dataset:
  - text-only post
  - image post
- Seed one reportable target:
  - user
  - group
  - message or moment if the UI exposes it

## Evidence Standards

- Every case needs a UI verdict:
  - pass screenshot or screen recording for critical flows
  - defect screenshot plus timestamp for failures
- Every cross-device case needs correlation evidence:
  - sender UI
  - receiver UI
  - cloud logs or server state when relevant
- Use timestamped filenames under `docs/superpowers/artifacts/` during execution.
- Prefer one evidence bundle per scenario:
  - `before`
  - `action`
  - `after`
  - `server-log`

## Cloud Observability Console Set

- Console 1:
  - `ssh ubuntu@42.194.218.158 "docker logs -f wukongim_prod-nginx-1"`
- Console 2:
  - `ssh ubuntu@42.194.218.158 "docker logs -f wukongim_prod-tsdd-api-1"`
- Console 3:
  - `ssh ubuntu@42.194.218.158 "docker logs -f wukongim_prod-wukongim-1"`
- Console 4:
  - `ssh ubuntu@42.194.218.158 "docker logs -f wukongim_prod-livekit-1"`
- Console 5:
  - `ssh ubuntu@42.194.218.158 "docker logs -f wukongim_prod-callgateway-1"`
- On-demand health check:
  - `ssh ubuntu@42.194.218.158 "ss -lntp | egrep '80|443|5001|5100|5200|3478|7881'"`

## Phase 0: Preflight And Baseline

- [ ] Confirm the desktop app is pointed at `http://42.194.218.158` and `42.194.218.158:5100` from the active build.
- [ ] Confirm `GET http://42.194.218.158/v1/ping` succeeds before any client-side testing.
- [ ] Record the current state of all five cloud containers and their last 50 log lines.
- [ ] Open Windows app and verify launch path:
  - splash/loading
  - login or home redirect
  - no startup crash, white screen, or endless spinner
- [ ] Open Android app and verify the same startup path.
- [ ] Open browser entry used for Web or PC login verification.
- [ ] Record baseline screenshots for:
  - desktop app launch
  - Android app launch
  - browser session page

## Phase 1: Authentication And Session Management

- [ ] Username registration
  - create new account
  - validate required-field prompts
  - validate duplicate-account rejection
- [ ] Password login
  - correct password
  - wrong password
  - logout and relogin
- [ ] Verification-code and reset-password entry flows
  - page open
  - form validation
  - backend response handling
- [ ] Third-party login page smoke
  - open page
  - verify no crash or dead controls
- [ ] Profile completion path
  - first-login completion
  - required-field validation
- [ ] Device session list
  - desktop sees Android/Web sessions
  - current device is clearly marked
  - remote logout removes the target session only
- [ ] Web login confirm
  - scan QR or open confirm route
  - approve
  - reject
  - timeout / invalid token
- [ ] PC/Web quit path
  - current session survives when "quit other PC/Web sessions" is used

Expected server evidence:

- Nginx and API logs for login, register, device list, bind, login status, grant, and quit flows
- realtime session events should remain stable with no auth loop

## Phase 2: Core IM Messaging

- [ ] Conversation list
  - initial load
  - pull to refresh
  - unread badge changes
  - latest message and timestamp refresh
  - conversation enter/exit
- [ ] Personal chat text
  - send
  - receive
  - read status
  - offline to online sync
- [ ] Group chat text
  - send from A, receive on B and C
  - unread count and read-back behavior
- [ ] Emoji input
  - picker open/close
  - send emoji-only message
- [ ] Image messaging
  - camera/gallery selection if exposed
  - send image
  - thumbnail render
  - full-screen preview
- [ ] Voice messaging
  - permission prompt
  - record cancel
  - record success
  - playback
  - replay after app relaunch
- [ ] Link preview
  - send URL
  - preview generation
  - open target
- [ ] Message long-press actions
  - copy
  - reply
  - forward
  - favorite
  - reaction
  - delete / recall if the UI exposes them
- [ ] Draft persistence
  - type, leave chat, return
- [ ] Mentions and typing indicators if exposed

Expected server evidence:

- API logs for message sync and read endpoints
- WuKongIM logs show stable message fan-out with no repeated disconnect/reconnect storm

## Phase 3: Search And Retrieval

- [ ] Global search
  - friend
  - group
  - message keyword
- [ ] Chat-scoped search
  - keyword
  - date
  - member
  - image/media collection
- [ ] Search result to chat locate
  - open result
  - jump to exact message
  - highlight state is correct
- [ ] Empty-state and no-result behavior
- [ ] Long history performance
  - large result set does not freeze desktop UI

Expected server evidence:

- API logs for global search and message search endpoints
- UI jumps must match returned conversation and message context

## Phase 4: Contacts, Friends, And User Profile

- [ ] Contacts list load
  - alphabetical grouping
  - search / filter
- [ ] Add friend
  - by search
  - by QR if exposed
  - duplicate request handling
- [ ] New friend requests
  - approve
  - refuse
  - status refresh on both ends
- [ ] User detail
  - open from contacts
  - open from chat avatar
  - open from group member list
- [ ] User remark / alias update
- [ ] My profile
  - avatar update
  - nickname update
  - profile persistence after relaunch
- [ ] Blacklist
  - add to blacklist
  - blocked user can no longer complete friend/chat actions as designed
  - remove from blacklist

Expected server evidence:

- API logs for friend apply, approve, refuse, user info, blacklist sync, and blacklist mutation

## Phase 5: Groups And Advanced Collaboration

- [ ] Create group
  - create with multiple members
  - landing into group chat
- [ ] Group detail page
  - header
  - settings area
  - member list
  - scroll behavior on desktop
- [ ] Invite members
  - owner invite
  - normal-member behavior under invite-only rules
- [ ] Join group
  - direct join if allowed
  - invite-only rejection path
  - scan join path if exposed
- [ ] Group notice
  - create/update
  - history view
- [ ] Group remark / group name update
- [ ] Group QR
  - display
  - scan and route correctly
- [ ] Delete/remove members
  - owner/admin path
  - blocked path for unauthorized role
- [ ] Owner/admin/member permission boundaries
- [ ] Saved groups and all-members pages if exposed
- [ ] Group reminder flows if exposed
- [ ] Feishu bot config page open and save path if enabled in deployment

Expected server evidence:

- API logs for group create, members, invite, join, setting, notice, and permission-changing routes
- Existing historical evidence around normal-member invite flow and scan-active flow should be reused as baseline, then revalidated through fresh runtime interaction

## Phase 6: Scan, Device, And Cross-Endpoint Flows

- [ ] Scan page open
  - camera permission
  - invalid code
  - expired code
- [ ] Active member scan flow
  - scan
  - land in group or chat correctly
- [ ] Removed member scan flow
  - blocked or redirected as designed
- [ ] Internal join and external join variations if both exist
- [ ] Device management page
  - list devices
  - lock suspicious device if exposed
  - logout all except current device if exposed
- [ ] Browser confirm page
  - desktop app approves Web login
  - app rejects Web login
  - browser state changes correctly

Expected server evidence:

- API logs for device bind, device list, login UUID, login status, grant login, and PC/Web quit
- prior evidence files under `docs/superpowers/artifacts/2026-04-08-*scan*` should be treated as baseline only; fresh proof is still required during the full pass

## Phase 7: Favorites, Moments, Tags, Report, And Settings

- [ ] Favorites
  - add favorite from message action
  - view favorite list
  - remove favorite
- [ ] Moments
  - publish text
  - publish image
  - open detail page
  - refresh list after publish
- [ ] Tags
  - open tag management
  - create tag if exposed
  - rename / delete if exposed
- [ ] Report
  - open report page
  - load categories
  - submit report
- [ ] Settings
  - account security
  - privacy
  - notifications
  - theme
  - language
  - font size
  - chat background
  - about
  - error logs
  - help and feedback

Expected server evidence:

- API logs for favorites, moments, report categories, reports, and user settings
- any local-only settings must survive app restart

## Phase 8: Audio And Video Calls

- [ ] Personal chat audio call
  - start from A
  - ring on B
  - accept
  - reject
  - hang up from caller
  - hang up from callee
- [ ] Personal chat video call
  - permission request
  - caller/callee connect
  - camera toggle
  - microphone toggle
  - speaker route if supported
- [ ] Duplicate-call prevention
  - initiating a second call while one is active is blocked
- [ ] Call interruption handling
  - app background/foreground
  - network switch
  - permission denied
- [ ] Call history page
  - records successful and missed calls

Expected server evidence:

- API logs should show `/v1/extra/call/room`
- LiveKit logs should show room/session activity without repeated negotiation failure
- call-gateway logs should correlate invite, answer, and end-of-call events

## Phase 9: Reliability, Recovery, And Desktop/Android Regression

- [ ] Windows-specific behavior
  - resize
  - maximize
  - restore
  - long list scroll
  - focus order with keyboard only
- [ ] Android-specific behavior
  - background/foreground
  - permission denial and retry
  - notification receipt if deployment is configured
- [ ] Network recovery
  - disconnect and reconnect
  - app resumes syncing without duplicate messages
- [ ] Crash-resistance
  - rapid tab switching
  - rapid conversation switching
  - repeated media open/close
- [ ] Relaunch persistence
  - login state
  - drafts
  - favorites/settings
  - chat history

## Priority Order

- `P0`: startup, login, conversation list, personal chat send/receive, group send/receive, scan/login confirm, device session management, audio/video call basic connect, no-crash baseline
- `P1`: image, voice, search, contacts, new friends, group management, favorites, moments, settings persistence
- `P2`: tags, report, advanced group reminder/bot flows, long-history performance, keyboard-only desktop traversal

## Defect Classification

- `Blocker`: cannot launch, cannot log in, cannot send/receive core messages, cannot enter core group/chat, call path crashes, scan/login confirm completely unusable
- `Critical`: data loss, wrong recipient, session eviction affecting current device, unread/read corruption, severe cross-device inconsistency
- `Major`: one feature path broken with workaround, repeated 4xx/5xx tied to normal user action, permission flow dead-end
- `Minor`: visual defect, wrong copy, layout overlap, non-blocking stale badge

## Exit Criteria

- All `P0` cases pass on real devices with evidence
- No `Blocker` or `Critical` defects remain open
- All `P1` failures are either fixed or explicitly accepted by product/engineering
- Cloud logs show no unexplained repeated `5xx`, reconnect storms, or RTC negotiation loops during normal execution
- The final report contains:
  - pass/fail summary by phase
  - defect list by severity
  - evidence links
  - exact server timestamps for all major failures

## Known Watchpoints Before Execution

- Current source uses `5100`; README examples still mention `5200`
- `https://42.194.218.158` timed out on `2026-04-09`, so Web and RTC browser validation may expose environment defects first
- Previous Windows runtime captures showed synthetic mouse input could be unreliable in this environment; manual human interaction or keyboard fallback should be preferred when collecting evidence
- Root `/` on the server returns `404`, so health verification must use `/v1/ping`, not `/`

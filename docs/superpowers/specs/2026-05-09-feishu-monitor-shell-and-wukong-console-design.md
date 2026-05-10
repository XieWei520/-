# Feishu Monitor Shell And WuKong Console Design

## Goal

Reshape the current Feishu monitoring product into a two-part system:

1. A standalone local Feishu monitor shell that is responsible only for login, runtime message capture, local queueing, and health recovery.
2. A WuKongIM desktop management surface that absorbs the current forwarding tool's configuration and operations features into the existing Feishu Monitor Center.

The target user experience is:

- The operator installs or launches a dedicated Feishu monitor shell on a Windows machine.
- The operator logs in to Feishu Web once inside that shell.
- WuKongIM's Feishu monitor center becomes the single management console for discovered conversations, routing rules, content policies, delivery status, logs, and shell health.
- The operator no longer needs a separate full-featured forwarding console app. The standalone shell keeps running; WuKongIM manages it.

## Why this reshape

The existing product shape mixes two concerns:

- A runtime concern: keep a Feishu session alive, receive messages, recover from login/session failures, and deliver observed events.
- A management concern: configure routes, inspect conversations, define policies, view logs, and test destinations.

Those concerns age differently.

- The runtime needs to be isolated, restartable, and stable under 24-hour unattended operation.
- The management experience belongs inside WuKongIM, where routing and destination concepts already live and where users already expect to manage IM behavior.

The split should therefore become:

```text
Standalone Feishu Monitor Shell
  -> runtime kernel
  -> no business configuration ownership

WuKongIM Feishu Monitor Center
  -> control plane
  -> routes, policies, destinations, logs, diagnostics
```

## Scope

This design covers:

- the final product split between the standalone shell and WuKongIM
- the runtime capture strategy for many Feishu conversations
- the local control interface between WuKongIM and the shell
- the migration of the current second forwarding program's pages and functions
- health, recovery, queueing, and operations behavior

This design does not require in this phase:

- reverse engineering or relying on Feishu private protocol as the primary message source
- Windows service packaging
- macOS or Linux parity
- replacing existing cloud monitor APIs unless the local control plane and route semantics require additions

## User constraints and assumptions

Confirmed constraints from the discussion:

- Message source is ordinary Feishu account conversations, including ordinary groups.
- The system runs on a Windows machine.
- The machine can stay logged in and not sign out.
- Rare manual re-login by scan code is acceptable if Feishu forces it.
- The user is willing to stop using the current A-mode visible-browser route for day-to-day operations.
- The user wants the standalone monitoring runtime to remain separate, while the current forwarding tool's management features move into WuKongIM.

## Current state summary

The repository already contains useful building blocks:

- local Windows monitor agent flow
- isolated Chromium profile handling
- browser automation with Puppeteer
- route creation and destination models
- local realtime listener loop
- local delivery logs and queue behavior
- a WuKongIM-side Feishu Monitor Center UI

The current main limitation is architectural:

- the browser side is still centered around "open or select a conversation and extract messages"
- the management surface is spread across a separate forwarding tool rather than being absorbed into WuKongIM

## Recommended final architecture

Use a two-process design:

```text
WuKongIM Desktop App
  -> Feishu Monitor Center
  -> local control client
  -> route and policy management
  -> logs and diagnostics view

Standalone Feishu Monitor Shell
  -> embedded Feishu Web runtime
  -> runtime hook layer
  -> local event normalization
  -> local queue and retry
  -> health supervisor
  -> local control server

Cloud monitor/backend APIs
  -> route assignment and persistence
  -> destination credential storage
  -> forwarding to WuKong IM / Feishu OpenAPI / other targets
  -> cloud delivery records
```

### Responsibility split

#### Standalone Feishu Monitor Shell owns

- Feishu Web login
- persistent isolated profile
- embedded page runtime
- runtime JS hook injection
- capture of global incoming conversation/message events
- local normalization and dedupe
- local pending queue and retry
- shell-local logs
- hook/page/login health checks
- restart/reload/relogin flows
- local control interface for WuKongIM

#### WuKongIM Feishu Monitor Center owns

- conversation discovery UI
- rule management UI
- destination selection UI
- content policy configuration
- shell status dashboard
- log viewer and error triage
- operator actions such as reconnect, restart listener, re-login, pause routes

## Standalone shell design

### Product shape

The standalone shell is a small dedicated app, not a second full management console.

Recommended shell pages:

- login page
- runtime status page
- debug log page
- lightweight tools page with:
  - open embedded console
  - reload page
  - clear login state
  - show current account

It should not own:

- route editing
- webhook or destination management
- word replacement and watermark policy management
- full conversation operations table

Those belong in WuKongIM.

### Embedded runtime

The shell should host Feishu Web in an embedded Chromium-based runtime.

Preferred direction:

- Electron shell with embedded Chromium runtime

Acceptable fallback:

- WebView2 shell if Electron is blocked for packaging reasons

Reasoning:

- the user's reference product looks like a dedicated single-window Web host
- the desired product shape is "one Feishu window, no visible browser tabs"
- runtime hook plus embedded host is a better fit than an external visible browser

### Capture strategy

Use a three-layer capture stack, in order of importance:

1. Runtime hook layer
2. CDP/network helper layer
3. DOM fallback layer

#### Layer 1: runtime hook

Primary source of truth.

The shell injects code early enough to observe Feishu Web runtime behavior and capture incoming conversation/message events without requiring the operator to open each target conversation.

Expected capture sources:

- fetch
- XMLHttpRequest
- WebSocket-related message handling surroundings
- internal event bus or store subscriptions when discoverable
- conversation/message cache change notifications

The shell should turn raw runtime events into a stable local message shape before routing.

#### Layer 2: CDP/network helper

Used for:

- diagnostics
- identifying message flow regressions
- download and media assistance
- confirming shell runtime health

This layer must not be the only truth source for business behavior.

#### Layer 3: DOM fallback

Used for:

- image/file/card enrichment
- last-resort extraction if the runtime hook loses some structured content
- validating whether the embedded page is alive and rendering expected sessions

This replaces the current DOM-first model as a fallback, not the primary approach.

### Local normalized event model

All capture sources should map into one local event shape:

```json
{
  "account_id": "string",
  "conversation_key": "string",
  "conversation_name": "string",
  "conversation_type": "group|dm|bot",
  "message_id": "string",
  "sender_id": "string",
  "sender_name": "string",
  "message_type": "text|link|image|file|card",
  "text": "string",
  "attachments": [],
  "sent_at": "2026-05-09T12:34:56Z",
  "observed_at": "2026-05-09T12:34:57Z",
  "capture_source": "runtime_hook",
  "raw_payload": {}
}
```

Everything downstream works from this normalized shape.

### Conversation handling model

The shell should operate in:

- global receive mode

That means:

- capture as many synchronized incoming conversations/messages as the logged-in Feishu Web runtime surfaces
- do not depend on a specific selected conversation as the primary model
- let route matching and filtering decide which messages are forwarded

This is a major shift from the current "monitor one selected chat" model.

### Local queue and retry

The shell must write messages to a local pending queue before reporting delivery success.

Recommended files:

```text
runtime/pending-queue.jsonl
runtime/dedupe-store.jsonl
runtime/delivery-log.jsonl
runtime/health-status.json
runtime/conversation-cache.json
runtime/last-error.json
```

Retry model:

- exponential backoff for failed delivery
- keep accepting new messages while retrying old ones
- never block all message intake on one failed route or one failed target

### Dedupe model

Primary key:

```text
account_id + conversation_key + message_id
```

Fallback key when message_id is absent or unstable:

```text
conversation_key + sender_id + sent_at + content_hash
```

### Health supervisor

The shell should run a supervisor loop independent from the business queue.

Health states to track:

- shell process alive
- embedded page alive
- Feishu login alive
- runtime hook alive
- message flow active
- queue consumer healthy

Recovery order:

1. reattach or reinstall hook
2. reload embedded Feishu page
3. restart shell runtime
4. require manual re-login

### Login and recovery behavior

Expected recoveries:

- Hook silent but page alive: reinstall hook
- Page blank or drifted: soft reload
- Runtime crash: restart embedded runtime
- Login expired: pause intake, save screenshot, show operator alert, wait for manual scan login

## WuKongIM integration design

### Core principle

WuKongIM becomes the only full management console.

The current second forwarding program's functionality should be migrated into WuKongIM's Feishu Monitor Center instead of building a second rich standalone control surface.

### Existing forwarding program function migration

Map current forwarding tool areas into WuKongIM as follows:

- `account-status` -> `connection-health`
- `runtime-logs` -> `monitor-logs`
- `forwarding-rules` -> `route-management`
- `conversation-list` -> `conversation-discovery`
- `global-settings` -> split into `delivery-channels` + `system-settings`
- `watermark-settings` -> `content-processing`

### WuKongIM Feishu Monitor Center information architecture

Recommended top-level sections:

1. `overview`
2. `connection-health`
3. `conversation-discovery`
4. `route-management`
5. `monitor-logs`
6. `content-processing`
7. `delivery-channels`
8. `system-settings`

#### 1. overview

Default landing page.

Show:

- standalone shell online/offline
- current Feishu account
- hook status
- messages received today
- deliveries succeeded/failed today
- pending queue size
- last incoming message time
- top recent errors

Actions:

- open login shell
- reconnect shell
- restart capture
- pause all forwarding
- resume all forwarding

#### 2. connection-health

Replaces the old `account-status` page.

Show the full chain:

- shell process state
- Feishu login state
- runtime hook state
- queue worker state
- target delivery channel health
- last re-login time
- last hook reinstall time
- recent drop count

Actions:

- recheck login
- reconnect shell
- reinstall hook
- restart forwarding runtime
- open shell window
- show recent errors

#### 3. conversation-discovery

This becomes a core page, evolved from the current `conversation-list`.

The page is no longer only a cache viewer. It becomes a conversation onboarding center.

Recommended columns:

- conversation name
- type
- conversation id
- recent message time
- messages today
- monitor status
- route bound or not
- target destination
- last forwarding result
- actions

Actions:

- enable monitoring
- create route from this conversation
- open recent observed messages
- pause
- ignore
- copy id

Filters:

- all / monitored / unmonitored / ignored
- group / dm / bot
- active / stale

#### 4. route-management

This evolves from the current `forwarding-rules` page.

It must become a runtime rule table rather than a static webhook table.

Recommended columns:

- enabled
- rule name
- source conversation
- destination channel
- destination display target
- content policy tags
- forwarded today
- last hit time
- last status
- actions

Actions:

- edit
- pause/resume
- duplicate
- test route
- view route logs
- delete

This page should no longer assume webhook as the primary target model.

#### 5. monitor-logs

This evolves from the current black terminal-like `runtime-logs`.

Requirements:

- structured log rows
- source labels:
  - shell
  - WuKong client
  - delivery worker
  - media processor
- severity:
  - info
  - success
  - warn
  - error
  - alert
- business context fields:
  - route
  - conversation
  - destination
  - message id

Actions:

- jump to route
- jump to conversation
- retry selected failed delivery
- reconnect shell
- reinstall hook

#### 6. content-processing

Merge old:

- replacement rules
- blocked words
- text-to-image
- image watermark

Each policy should support scope:

- global
- selected routes
- selected source conversations
- selected destination types

Each policy should support:

- preview
- effective target count
- last modified and last applied metadata

#### 7. delivery-channels

Pull target configuration out of `global-settings`.

Sections:

- WuKong IM group destinations
- Feishu OpenAPI destinations
- DingTalk webhook destinations if still needed
- future extension channels

Credentials should show:

- encrypted-at-rest notice
- test result
- last test time
- minimal masked display

#### 8. system-settings

Keep true global runtime defaults here:

- auto start
- log retention
- cleanup policy
- default retry behavior
- alert settings
- shell control endpoint preferences

Do not keep route-specific or destination-credential-specific content here.

## Local control interface between WuKongIM and the shell

The standalone shell should expose a local control plane on the same machine.

Recommended shape:

- local HTTP server on loopback
- optional named-pipe transport later if desired

Minimum endpoints:

```text
GET  /status
GET  /health
GET  /conversations
GET  /logs
GET  /queue
POST /capture/start
POST /capture/stop
POST /hook/reinstall
POST /runtime/reload
POST /runtime/restart
POST /login/recheck
POST /login/clear
POST /shell/show
```

Optional route-aware endpoints:

```text
GET  /routes/effective
POST /routes/reload
POST /delivery/retry
```

Control-plane security expectations:

- bind only to `127.0.0.1`
- require a local token or per-install shared secret
- redact secrets from all logs

## Destination model

Preserve and extend the current destination abstraction.

Destination types should include:

- `wukong_im_group`
- `feishu_openapi_chat`
- `dingtalk_webhook`
- later extension types

Rules should refer to destination records, not store raw secrets directly inside each rule.

## Routing model

Use:

- global receive
- rule filter

That means:

- shell captures all available synchronized incoming messages
- WuKongIM route config decides which messages should forward where

Recommended route fields:

- route id
- rule name
- source conversation key
- source conversation name
- destination type
- destination id
- content policy set
- status
- recent health metadata

## Operations and alerting

### Alert classes

Use four operator-facing classes:

- P1 login invalid or security verification required
- P2 delivery continuously failing
- P3 hook/page unhealthy but auto-recovery still trying
- P4 queue growth or resource pressure warning

Alert destinations:

- local WuKongIM monitor center
- optional WuKongIM ops group message

### Logging expectations

Persist both:

- shell-local logs
- structured logs consumed by WuKongIM

The goal is not just to display terminal text, but to support diagnosis by route/conversation/time.

## Migration from the existing second forwarding program

### Keep temporarily

During migration, keep the existing second program only long enough to:

- preserve current operator workflow
- verify the new WuKongIM monitor center parity
- compare feature completeness

### Remove from final user path

Once WuKongIM monitor center reaches parity:

- stop treating the second forwarding tool as the operator console
- keep only the standalone shell runtime as the second program
- retire or minimize the old forwarding UI

### Migration order

1. Standalone shell runtime minimal product
2. WuKongIM health and shell-control integration
3. WuKongIM conversation discovery parity
4. WuKongIM route management parity
5. WuKongIM content policy parity
6. WuKongIM structured log parity
7. deprecate old second forwarding tool UI

## Testing strategy

### Unit tests

- route matching
- dedupe key behavior
- queue retry and backoff
- control-plane client parsing
- content policy preview logic

### Integration tests

- shell local control API
- shell status reflected in WuKongIM UI
- route create/update/pause reflected in runtime behavior
- conversation discovery synchronization
- failed target delivery appears in logs and queue

### Manual acceptance

1. Launch WuKongIM and standalone shell on Windows.
2. Log in to Feishu inside the shell.
3. Open WuKongIM Feishu Monitor Center.
4. Confirm shell online, login valid, and hook healthy.
5. Confirm discovered conversation list appears in WuKongIM.
6. Create a route from one discovered Feishu group to a WuKongIM group.
7. Send a new Feishu message without manually opening that group.
8. Confirm the message is captured and forwarded.
9. Pause the route and confirm forwarding stops.
10. Trigger a login invalid state and confirm the monitor center reports it clearly.
11. Re-login and confirm automatic resume.

## Risks and mitigations

### Risk: Feishu runtime internals change

Mitigation:

- keep runtime hook modular
- keep CDP and DOM fallback paths available
- include health detection for silent hook failure

### Risk: global receive from runtime is incomplete for some message types

Mitigation:

- keep attachment enrichment via network/DOM helpers
- record raw payloads and enrichment failures
- let route logs expose capture-source confidence

### Risk: WuKongIM UI becomes overloaded

Mitigation:

- keep the shell lightweight
- make `overview` the primary page
- keep advanced processing in dedicated sections, not on the landing page

### Risk: users confuse shell state with route state

Mitigation:

- separate `connection-health` from `route-management`
- display chain health and rule health distinctly

## Final recommendation

Adopt the following final product split:

- Standalone Feishu monitor shell as the runtime kernel
- WuKongIM Feishu Monitor Center as the sole full management console

Within the runtime kernel, prefer:

- embedded Chromium-based host
- runtime hook as primary capture
- CDP/network helper as secondary
- DOM as fallback

Within WuKongIM, restructure the monitor center around:

- overview
- health
- conversations
- routes
- logs
- content policies
- destinations
- system settings

This direction best matches:

- the user's preferred product shape
- the observed capabilities of the reference tool
- the repository's existing monitor foundation
- the long-running operational needs of a 24-hour Windows machine

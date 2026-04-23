# Robot Official Webhook Mode And Avatar Action Layout Design

**Status:** Approved in-thread based on the user's confirmation to add a dual-mode robot configuration page, fix avatar action alignment, and support official Feishu/DingTalk webhook domain validation only. This design explicitly excludes syncing official-webhook traffic back into IM groups.

## Goal

Close two concrete product gaps in the group robot settings flow:

- fix the avatar action area so `上传头像` and `清空头像` are visually aligned
- add an `官方 Webhook` mode so operators can store and validate official Feishu or DingTalk webhook URLs in the IM settings page without being blocked by current WuKongIM-generated inbound webhook domains

## Scope

This design includes:

- a dual-mode robot settings page for both Feishu and DingTalk
- mode-specific UI and validation rules
- backend storage for the currently selected mode plus official webhook credentials
- summary copy that makes the selected mode obvious during testing
- an aligned avatar action row in the shared robot identity section

## Non-Goals

This design explicitly does not include:

- forwarding official Feishu webhook traffic back into WuKongIM groups
- forwarding official DingTalk webhook traffic back into WuKongIM groups
- generating official provider webhook URLs from WuKongIM
- changing upstream provider robot identity on Feishu or DingTalk
- replacing the existing WuKongIM-generated inbound webhook mode

## Product Shape

Each robot page exposes a top-level `接入模式` selector with two options:

- `IM 接收 Webhook`
- `官方 Webhook`

The page behavior depends on the selected mode.

### IM 接收 Webhook

This is the current behavior and remains the default for existing robot configs.

- show the WuKongIM-generated inbound webhook URL
- show the generated sign secret
- show regenerate, enable, test, and delete actions
- keep the existing IM-only display name and display avatar section

### 官方 Webhook

This is a new storage-and-validation mode for operators whose external tools reject non-official domains.

- show editable fields for official webhook URL and official secret
- validate the URL against the provider's official domain rules
- keep the IM-only display name and display avatar section visible, because it still belongs to the robot record
- hide or disable IM-specific actions that only make sense for WuKongIM inbound webhooks

The page must explicitly state that this mode only stores official provider endpoints for configuration convenience and compatibility. Messages sent to those official endpoints are not synced into WuKongIM groups in this release.

## User Experience Rules

### Mode visibility

The selected mode must be visible in three places:

- the `接入模式` control itself
- the summary section status chips or summary text
- the helper copy near the webhook fields

This avoids ambiguity during QA and prevents operators from assuming they are editing the same transport path in both modes.

### Avatar action alignment

The shared avatar action area currently mixes button styles, which creates visible baseline and height mismatch. The replacement layout should:

- use a single horizontal action row
- use the same button family for both actions
- keep both buttons vertically centered
- wrap only when the available width is genuinely insufficient

The goal is a stable desktop-first layout rather than a loosely flowing button cluster.

## Architecture

The change stays additive on top of the existing Feishu and DingTalk robot config paths.

### Backend

Both robot config records keep the current WuKongIM-generated inbound webhook fields unchanged. New fields are added for:

- active webhook mode
- official webhook URL
- official secret

The existing webhook receivers and generated webhook token logic continue to operate only for `IM 接收 Webhook` mode.

### Flutter

The existing robot config models and pages are extended with:

- mode enum or mode string
- official webhook URL
- official secret
- mode-aware field rendering
- mode-aware validation and save payloads

The shared `GroupRobotIdentitySection` is updated so its avatar action row uses a consistent layout and button treatment for both providers.

## Data Model Changes

### Flutter models

Add the following transport fields to both:

- `GroupFeishuRobotConfig`
- `GroupDingTalkRobotConfig`

New fields:

- `webhookMode`
- `officialWebhookUrl`
- `officialSecret`

`webhookMode` should resolve to:

- `im_generated` when absent on old records
- `official` only when the backend explicitly returns it

### Backend storage

Add additive fields to the existing Feishu and DingTalk robot tables:

- `webhook_mode`
- `official_webhook_url`
- `official_secret`

The existing generated webhook and generated secret fields remain intact. This lets operators switch modes without losing the previously generated WuKongIM webhook values.

## API Contract Changes

Extend existing Feishu and DingTalk robot config CRUD requests and responses with:

- `webhook_mode`
- `official_webhook_url`
- `official_secret`

Behavior rules:

- if `webhook_mode == "im_generated"`, the existing generated webhook response fields remain authoritative
- if `webhook_mode == "official"`, the backend returns the stored official fields and preserves generated webhook fields for future switching

No new routes are required. Existing robot CRUD routes remain the integration surface.

## Validation Rules

Validation is mode-specific and enforced at save time.

### Feishu official mode

Allowed host:

- `open.feishu.cn`

Rejected examples:

- WuKongIM-generated local webhook URLs
- arbitrary third-party proxy domains
- empty values when official mode is selected

### DingTalk official mode

Allowed hosts:

- `oapi.dingtalk.com`
- `api.dingtalk.com`

Rejected examples:

- WuKongIM-generated local webhook URLs
- arbitrary third-party proxy domains
- empty values when official mode is selected

### IM-generated mode

No official-domain validation is applied. The page continues to operate on the existing generated webhook path.

## UI Design

### Summary section

Add an explicit mode summary:

- `当前模式：IM 接收 Webhook`
- `当前模式：官方 Webhook`

When official mode is active, the summary should also display a short warning:

- official webhook traffic is not synced into WuKongIM groups in the current release

### Webhook section behavior

#### IM-generated mode

Show:

- generated webhook URL
- generated secret
- regenerate actions
- test-send action

#### Official mode

Show:

- official webhook URL input
- official secret input
- validation hint with the allowed official domains

Hide or disable:

- regenerate webhook
- regenerate secret
- test-send action that injects a message into the IM group

This avoids a misleading UI where an operator thinks the official endpoint is already connected to IM inbound delivery.

### Shared avatar section

Replace the loose wrap-only action cluster with a stable horizontal action row:

- `上传头像`
- `清空头像`

Both should use matching button height, padding, and icon/text alignment.

## Error Handling

### Official mode save errors

- empty official URL: show direct field-level or snackbar feedback
- invalid official host: show a provider-specific validation message
- save failure from backend: preserve the typed values in place and show the backend error

### Mode switching

- switching modes must not silently erase the other mode's stored values
- unsaved local edits can be discarded only when the operator explicitly saves or reloads the page

### Avatar actions

- clearing an empty avatar should continue to show a small no-op message
- upload failure must not alter the currently displayed saved avatar URL

## Testing Strategy

This change should be implemented test-first.

### Flutter widget tests

Add or extend tests for both robot pages to cover:

- mode selector renders both `IM 接收 Webhook` and `官方 Webhook`
- switching to official mode reveals the official webhook URL and official secret inputs
- Feishu official mode accepts `open.feishu.cn` and rejects non-official hosts
- DingTalk official mode accepts `oapi.dingtalk.com` and `api.dingtalk.com` and rejects non-official hosts
- IM-generated mode still submits the old payload shape without requiring official URL fields

Add a shared UI test or page-specific test to cover:

- avatar action row renders both actions in the same aligned row with the same button family

### Flutter model tests

Add model tests to cover:

- parsing and serializing `webhook_mode`
- parsing and serializing `official_webhook_url`
- parsing and serializing `official_secret`
- defaulting old records to `im_generated`

### Backend tests

Add focused robot backend tests to cover:

- new response fields in Feishu and DingTalk config responses
- update handlers accepting and persisting official mode fields
- generated-mode updates preserving official fields
- official-mode updates preserving generated webhook fields

## Risks

- operators may assume that an official webhook stored in the IM page automatically bridges messages back into IM; the UI copy must explicitly prevent this misunderstanding
- reusing the same robot record for both modes requires clear persistence rules so switching modes does not wipe the inactive mode's values
- if mode-specific UI is not explicit enough, QA can misread a hidden generated webhook as a broken config rather than an inactive mode
- the current workspace is not a git worktree, so this spec can be saved locally but cannot be committed from this environment

## Recommended Implementation Slice

Implement in this order:

1. extend backend records and CRUD contracts with dual-mode fields
2. extend Flutter robot models and API methods
3. update Feishu and DingTalk pages with mode-aware sections and official-domain validation
4. align the shared avatar action row
5. run focused backend and Flutter regression tests

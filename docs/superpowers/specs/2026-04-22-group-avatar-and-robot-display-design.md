# Group Avatar And Robot Display Design

**Status:** Approved in-thread based on the user's confirmation to implement only IM-side group avatar editing, IM-side robot display name/avatar customization, and a documented external proxy compatibility path for strict third-party webhook domain validation.

## Goal

Close three concrete product gaps without expanding into official Feishu or DingTalk app-bridge integration:

- allow group owners or admins to change the group avatar from the desktop IM client
- allow Feishu and DingTalk group robots to expose a custom display name and display avatar inside WuKongIM only
- keep the current WuKongIM-generated inbound webhook mode, while documenting that strict third-party domain validation must be handled by an external proxy outside the IM product

## Scope

This design includes:

- desktop group-detail avatar edit flow wired to the existing backend group avatar upload endpoint
- local cache refresh after group avatar change so the new avatar propagates to group detail, chat header, and conversation list
- new IM-side robot display metadata for Feishu and DingTalk robot configs
- robot config UI updates so operators can edit a display name and display avatar in addition to the existing webhook and secret controls
- robot message rendering updates so inbound robot messages use the custom IM-side identity
- documentation and UI copy that explain the external proxy compatibility strategy for third-party tools that reject non-official webhook domains

## Non-Goals

This design explicitly does not include:

- official Feishu app-mode webhook bridging back into IM groups
- official DingTalk app-mode webhook bridging back into IM groups
- changing robot identity on Feishu or DingTalk themselves
- modeling robots as real group members in the IM member list
- bundling or shipping a proxy service inside this repo
- bypassing strict third-party whitelist checks purely from the IM client when the external tool validates the final host or certificate chain

## Product Shape

### Group avatar editing

The group detail page already shows the group avatar. This design makes that avatar interactive for users who can manage the group:

- click the group avatar in group detail
- choose a local image
- upload it through the existing group avatar endpoint
- update the current page immediately
- refresh the local group channel cache so the new avatar appears consistently in:
  - group detail
  - chat page header
  - conversation list

Users without permission keep the current read-only avatar behavior.

### Robot IM-side identity

Both Feishu and DingTalk robot settings pages gain two new IM-only fields:

- display name
- display avatar

These fields only affect how the robot appears inside WuKongIM. They do not affect the upstream robot identity on Feishu or DingTalk.

The customized identity is used in:

- inbound robot message bubbles
- conversation preview identity where robot-originated messages surface
- robot settings page summary card

Robots remain configuration objects, not real group members.

### External proxy compatibility

The current product keeps the existing WuKongIM-generated inbound webhook mode. Some third-party automation tools reject webhook URLs unless they belong to official Feishu or DingTalk domains. This design does not attempt to fake or replace that validation in the IM product.

Instead, WuKongIM presents a clear compatibility note:

- the generated webhook is a WuKongIM inbound webhook
- if a third-party tool only accepts official domains, the operator must deploy an external proxy that forwards requests to the WuKongIM webhook
- the proxy must preserve request body, headers, and query parameters needed by the existing integration mode

This keeps the IM product honest about what it can and cannot solve.

## Architecture

The work stays additive and local to the current app and existing robot tables.

### Group avatar path

Backend already exposes group avatar upload and avatar update event handling. The missing part is the desktop client flow.

Implementation shape:

- add a group avatar picker flow in `group_detail_page.dart`
- reuse the existing file upload pattern already used for user avatars
- call the backend group avatar upload endpoint
- refresh group info after upload
- update local `WKIM.shared.channelManager` cache with the new avatar

### Robot display identity path

Robot configs already exist independently for Feishu and DingTalk. This design extends those records with IM-side display metadata and keeps transport behavior unchanged.

Implementation shape:

- add display metadata to both Flutter models and backend DB models
- extend robot CRUD APIs to read and write the new fields
- update robot settings pages to edit the fields
- update inbound message mapping so robot-originated messages resolve sender identity from robot config first

## Data Model Changes

### Flutter models

Add the following fields to both:

- `GroupFeishuRobotConfig`
- `GroupDingTalkRobotConfig`

New fields:

- `displayName`
- `displayAvatar`

The fields are optional in transport and resolve with these rules:

- if `displayName` is empty, use the current provider default label
- if `displayAvatar` is empty, use the current robot/default avatar behavior

### Backend DB models

Add matching columns to:

- `robot_feishu_group`
- `robot_dingtalk_group`

New columns:

- `display_name varchar(80) not null default ''`
- `display_avatar varchar(500) not null default ''`

These are pure IM presentation fields and must not alter webhook validation or upstream provider behavior.

## API Contract Changes

Extend existing Feishu and DingTalk config CRUD responses and update payloads.

### New request fields

- `display_name`
- `display_avatar`

### New response fields

- `display_name`
- `display_avatar`

No route changes are required for robot settings.

### Group avatar upload

Do not invent a new group avatar contract. Reuse the existing backend route already present in the server:

- `POST /v1/groups/:group_no/avatar`

The Flutter client needs a dedicated API helper for this route if one does not already exist in `GroupApi`.

## UI Design

### Group detail page

The group avatar block becomes clickable for authorized users.

Required states:

- idle avatar with edit affordance
- uploading busy state
- success feedback
- failure feedback

Permission behavior:

- owners and admins can upload
- normal members see the avatar without edit affordance

### Feishu and DingTalk robot pages

Add a new IM presentation section above or near the existing credentials section.

Fields:

- robot display name text field
- robot display avatar picker
- avatar preview
- reset-to-default option

The settings page should clearly label these values as IM-only to avoid implying that they will modify Feishu or DingTalk itself.

Copy semantics:

- one label for IM-only display name
- one label for IM-only display avatar
- one helper sentence that explicitly says the change only affects WuKongIM presentation and does not modify Feishu or DingTalk itself

## Identity Resolution Rules

Robot-originated inbound messages should resolve sender presentation in this order:

1. robot config `display_name` and `display_avatar`
2. provider-specific default label and fallback avatar
3. existing low-level fallback behavior

This keeps current behavior stable for existing robot configs while allowing IM-side branding when configured.

## External Proxy Guidance

The product must not promise that every third-party tool can be made compatible from the IM side alone.

Documented guidance should state:

- WuKongIM-generated webhook URLs are intended for inbound delivery into IM groups
- some third-party tools reject any non-official provider domain before sending
- in those cases, the operator must place an external proxy in front of the WuKongIM webhook
- the proxy is out of scope for this codebase

The proxy guidance should remain short and operational rather than architectural. This release is not a proxy feature release.

## Error Handling

### Group avatar

- invalid image selection: show immediate client feedback
- upload failure: keep old avatar, show error
- post-upload refresh failure: upload still counts as success, but trigger a best-effort local refresh and show a mild warning if needed

### Robot display metadata

- blank display name is allowed and falls back to provider defaults
- blank display avatar is allowed and falls back to existing avatar behavior
- invalid avatar upload or URL failure must not block the rest of the robot config from saving unless the user explicitly chose a custom avatar and that upload failed

## Testing Strategy

This work should be implemented test-first.

### Group avatar

Add tests covering:

- group detail page shows edit affordance only for users with permission
- avatar upload action calls the expected API helper
- success path refreshes visible avatar state
- failure path preserves old avatar and shows feedback

### Robot display metadata

Add tests covering:

- Feishu config model parses and serializes display metadata
- DingTalk config model parses and serializes display metadata
- Feishu settings page renders display name and display avatar controls
- DingTalk settings page renders display name and display avatar controls
- message identity resolution prefers robot display metadata when present

### Regression verification

Run focused Flutter tests for:

- group detail page parity and settings
- Feishu robot page
- DingTalk robot page
- message bubble or chat identity resolution tests touched by the change

Rebuild and relaunch the Windows desktop app for manual QA after tests pass.

## Risks

- the external proxy path is operationally useful but not guaranteed against every third-party whitelist implementation
- robot identity rendering may touch multiple presentation paths, so cache invalidation and fallback order must be kept explicit
- group avatar success depends on reusing the exact backend route and cache refresh semantics already present on the server
- the current workspace is not a git worktree, so this spec can be saved locally but cannot be committed from this environment

## Implementation Slice Recommendation

Implement in this order:

1. group avatar desktop flow
2. robot model and API field extensions
3. robot settings UI for display name and avatar
4. message identity rendering with robot display metadata
5. copy updates for external proxy guidance

This keeps the highest user-visible issue first and isolates robot transport from robot presentation changes.

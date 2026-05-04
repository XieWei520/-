# Unified Robot Card Design

**Status:** Approved in-thread based on the user's confirmation to use a dedicated internal `robot_card` message type, a premium display-only card style, and whole-card click behavior when a link is present.

## Goal

Unify Feishu and DingTalk text-like robot messages into one internal IM card experience so that:

- robot messages look premium and intentional inside group chat
- the visible card content only shows the user-requested message content
- Feishu and DingTalk share one high-end visual language instead of provider-native skins
- conversation preview, search, reply, pin, and collection flows remain stable and text-based

## Scope

This design includes:

- a new dedicated internal IM message type for robot cards
- server-side normalization from Feishu and DingTalk incoming payloads into one shared card schema
- Flutter decoding and rendering for the new robot card message type
- unified preview, search, reply, pin, and collection fallback rules
- graceful downgrade behavior when parsing or rendering is incomplete
- test and observability requirements for server and Flutter

## Non-Goals

This design explicitly does not include:

- migrating historical robot messages
- changing existing contact-card semantics for `card=7`
- turning robot image messages into the new card format in v1
- introducing multiple runtime-selectable robot card skins
- adding multi-button or workflow-style action panels
- requiring all clients to upgrade at the same time before new robot traffic works

## Current Constraints

The current product shape has two hard boundaries that make direct reuse unsafe:

- the server robot send path in [api.go](C:/Users/COLORFUL/Desktop/WuKongIM/TangSengDaoDao/TangSengDaoDaoServer-main/modules/robot/api.go) currently only accepts `Text`
- the Flutter `card` content type is already used for contact sharing and must remain dedicated to contact cards

Because of this, the new robot card must be additive and isolated rather than implemented as a silent extension of the existing contact-card path.

## Product Decisions Locked In-Thread

The following choices were explicitly confirmed by the user:

- implementation route: add a new dedicated `robot_card` type rather than reusing `card=7`
- visual direction: the premium display-only card style shown as `方案 1`
- click behavior: when a link exists, the whole card is clickable
- implementation scope: text-like robot messages only in v1

## Message Type Allocation

The new internal IM content type is fixed as:

- `robot_card = 22`

Rationale:

- `7` remains reserved for contact cards
- `20` and `21` are already used
- `22` is close to existing custom content values without colliding with current in-app assignments

Both server and Flutter must use `22` consistently.

## Unified Message Contract

### Top-Level Schema

All normalized robot cards use a single additive payload contract:

```json
{
  "type": 22,
  "schema": "robot_card.v1",
  "platform": "feishu",
  "origin_type": "interactive",
  "robot": {
    "id": "robot_xxx",
    "provider": "feishu",
    "name": "飞书机器人",
    "avatar": "https://example.com/robot.png"
  },
  "card": {
    "style": "showcase",
    "title": "消息通知",
    "body": "feishu-link-test-001",
    "badge": "LINK",
    "link_url": "https://example.com/detail",
    "link_mode": "whole_card"
  },
  "plain_text": "消息通知 feishu-link-test-001"
}
```

### Field Rules

- `type` is always `22`
- `schema` is always `robot_card.v1`
- `platform` is one of `feishu` or `dingtalk`
- `origin_type` keeps the provider-native source type for observability and debugging
- `robot.name` is the IM-visible robot name
- `robot.avatar` is the IM-visible robot avatar when configured
- `card.style` is fixed to `showcase` in v1
- `card.title` is the primary visible heading
- `card.body` is the visible user-requested content body
- `card.badge` is a short uppercase label such as `LINK`, `NOTICE`, or `ALERT`
- `card.link_url` is optional
- `card.link_mode` is fixed to `whole_card`
- `plain_text` is the canonical preview and search string

### Content Rules

- the card body must not include provider noise such as `[Feishu Robot]`, `[card message]`, or other synthetic source labels
- the visible card content must prefer extracted human-readable text over provider raw JSON
- `plain_text` must be concise, searchable, and sufficient for previews even if card rendering fails

## Normalization Scope

Version 1 only cardifies text-like robot messages.

### Feishu

Normalize the following inbound types into `robot_card.v1`:

- `text`
- `post` and other link-like textual payloads
- `interactive`

### DingTalk

Normalize the following inbound types into `robot_card.v1`:

- `text`
- `markdown`
- `link`
- `actionCard`

### Explicit Exclusion

These stay on their existing paths in v1:

- robot images
- robot files
- any future rich attachments that do not clearly map to a concise title/body card

## Architecture

### Server Data Flow

The server flow becomes:

`Feishu/DingTalk webhook -> provider-specific parser -> RobotCardPayload normalizer -> IM message with type 22 -> persistence/distribution -> Flutter robot_card renderer`

The key rule is that provider-specific variance ends at the normalization layer. IM-internal transport, storage, preview generation, and rendering all operate on the shared `robot_card.v1` contract.

### Flutter Data Flow

Flutter introduces a dedicated `WKRobotCardContent` path for content type `22`.

- decode the normalized JSON into a typed model
- render the premium card only inside the chat page
- use `plain_text` for preview, indexing, and lightweight surfaces

## Chat Page Rendering Rules

The robot card is a chat message, not a detached mini-app panel.

### Placement

- render the card in the normal left-side incoming message flow
- keep the standard group sender name area above the card
- the group sender display name should resolve to the robot display name, such as `飞书机器人` or `钉钉机器人`

### Layout

- desktop target width: stable max width around `420-460px`
- mobile width: scale with the chat column while preserving the premium layout
- rounded corners: `22-24`
- shadow: stronger than a normal incoming bubble, but lighter than a floating modal or dashboard panel

### Visual Style

The style is locked to the approved premium showcase direction:

- dark graphite-blue card base
- subtle warm highlight or edge accent
- refined, dense information hierarchy rather than a flat text block
- no provider-native full-surface blue skins

### Internal Card Hierarchy

- eyebrow: very small supporting label such as `Robot Brief` or `Message Notice`
- title: the most prominent line, approximately `18-20`
- body: the actual requested content, approximately `14-15`
- badge: short label at the top-right, such as `LINK`, `NOTICE`, or `ALERT`
- footer: IM-visible robot name and time, such as `飞书机器人 · 13:14`

### Link Interaction

- when `card.link_url` is present, the whole card is clickable
- when `card.link_url` is absent or invalid, the card remains display-only
- there is no dedicated CTA button in v1

### Hover and Pressed Feedback

Desktop interaction should feel polished but restrained:

- hover: slight lift and brightness increase
- pressed: slight compression or shadow reduction
- no over-animated or glossy effect that makes the card feel like a separate application surface

## Provider Differentiation Rules

Feishu and DingTalk must share the same card body style. Provider distinction is intentionally light.

Provider differences are allowed only in:

- robot avatar
- a very subtle source hint through footer wording or robot identity metadata

Provider differences are explicitly not allowed in:

- full card skin replacement
- separate provider-specific layout structures
- provider-colored background dominance

### Avatar Resolution

- if the robot has an IM-configured avatar, use it
- if not, fall back to a provider-aware default glyph avatar
  - Feishu fallback glyph: `飞`
  - DingTalk fallback glyph: `钉`

## Preview and Search Rules

The premium card only appears in the chat page. Every lightweight surface stays text-based.

### Conversation List

- show a one-line textual preview only
- the preview source is `plain_text`
- in groups, prefix with the robot name when available
- do not render badge, card shell, or provider noise in the conversation list

Expected example:

- `飞书机器人: 消息通知 feishu-link-test-001`

### Search Indexing

Index the following combined text:

- `robot.name`
- `card.title`
- `card.body`
- `plain_text`

### Search Results

- search result rows stay text-based
- opening a robot-card hit must jump to the original message location in the chat
- the result must not open a blank conversation state or lose the message anchor

### Reply, Pin, Collection, and Similar Lightweight Surfaces

These surfaces use `plain_text` only:

- reply preview
- pinned-message banner and sheet
- collection/favorite summaries
- other narrow preview strips

They must not render the full premium card.

## Error Handling and Downgrade Rules

### Server Downgrade

- if normalization to `robot_card.v1` fails but visible text can still be extracted, send a plain text IM message instead of dropping the message
- only drop the inbound message when there is neither valid card structure nor visible text
- log the downgrade path explicitly

### Client Downgrade

- if Flutter recognizes content type `22` but the payload is incomplete, prefer `plain_text` as the fallback visible text
- if `plain_text` is unavailable, render `[机器人卡片]`
- if avatar loading fails, fall back to the default provider glyph avatar
- if `link_url` is invalid or empty, keep the card visible but disable click behavior

## Compatibility Strategy

This change must be forward-enhancing rather than simultaneously mandatory across every client.

- historical messages are not backfilled or migrated
- only new incoming text-like robot messages use the new type
- older clients must still be able to see a safe textual fallback rather than a blank bubble
- the server contract must therefore preserve enough plain text for non-upgraded or partial clients

## Observability

Server logs for normalized robot traffic should include:

- `platform`
- `origin_type`
- `normalized_type=robot_card`
- `fallback=text` when downgrade occurs
- `group_no`
- `robot_id`

Two failures are especially important during rollout:

- webhook accepted but normalization failed
- normalization succeeded but the client treated the payload as unknown or non-renderable

## Testing Strategy

This feature should be implemented test-first.

### Server Tests

Add targeted normalization tests that verify:

- Feishu `text`, link-like messages, and `interactive` normalize into `robot_card.v1`
- DingTalk `text`, `markdown`, `link`, and `actionCard` normalize into `robot_card.v1`
- duplicated or synthetic provider labels are not injected into the visible card body
- downgrade to plain text happens when card shaping fails but visible text exists

### Flutter Tests

Add unit and widget coverage for:

- content type `22` decode into `WKRobotCardContent`
- conversation preview uses `plain_text`
- search preview uses `plain_text`
- chat page renders the premium card shell
- whole-card click behavior is enabled only when `link_url` exists
- incomplete payload fallback stays readable and non-empty

### Interactive QA Acceptance

The feature is accepted when all of the following pass:

- Feishu `text`, link-like content, and `interactive` messages render as the unified premium card in group chat
- DingTalk `text`, `markdown`, `link`, and `actionCard` messages render as the same premium card in group chat
- the visible card content only shows the intended user content
- links open from whole-card click when present
- conversation list previews are readable and stable
- search can find `title`, `body`, and `plain_text`, then locate the original message
- reply, pin, and collection views show lightweight text previews instead of broken card fragments
- missing avatar, empty link, or partial payload never produce a blank or crashing message row
- robot image delivery continues to work on its existing path

## Implementation Notes

This design deliberately keeps v1 small and disciplined:

- one new content type
- one normalized schema
- one premium visual style
- one click behavior

That constraint is intentional. It creates a clean base for later additions such as image-card variants or richer robot alerts without polluting the existing contact-card path or destabilizing preview and search behavior.

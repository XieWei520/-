# Login Branding Design

**Status:** Approved in-thread based on the user's confirmation to adopt the `A` flagship-brand direction, rename the product to `信息平权`, and use the slogan `让全天下的人没有信息差`.

## Goal

Upgrade the login experience from a generic IM entry screen into a premium branded entry point that:

- presents the product externally as `信息平权`
- makes the slogan `让全天下的人没有信息差` the core brand statement
- improves the perceived quality of the login page without changing the verified auth behavior
- keeps desktop, mobile, and narrow-window login experiences visually consistent

## Scope

This design includes:

- product-name replacement in login-visible branding surfaces
- login-page brand-panel redesign using the approved flagship layout
- copy refresh for login, register, and reset auth surfaces where branding is visible
- responsive layout refinement for desktop split view and compact stacked view
- focused regression coverage for title, slogan, brand chips, and auth-page rendering

## Non-Goals

This design does not include:

- any change to auth APIs or login request payloads
- any change to password, SMS code, or validation rules
- any rewrite of status-banner logic, remember-password logic, or API URL controls
- a full app-wide rebrand of every legacy `WuKongIM` string outside the auth experience
- new onboarding, marketing animation, or promotional carousel behavior

## Current Context

The current auth experience already has the right structural primitives:

- `AuthPageScaffold` supports a branded split-panel desktop layout and a stacked compact layout
- `AuthLoginPage` already passes brand eyebrow, title, description, and highlights into the scaffold
- `AuthCopy` is the current source of auth copy, but it contains mojibake in multiple strings and is no longer reliable as a long-term copy source without cleanup

This means the redesign should reuse the existing shell instead of introducing a new auth page architecture.

## Product Decisions Locked In-Thread

The following decisions were explicitly confirmed by the user:

- product name: `信息平权`
- slogan: `让全天下的人没有信息差`
- visual tone: high-end product feel
- layout direction: `A` flagship-brand direction
- implementation priority: preserve existing login behavior and only upgrade presentation

## Design Summary

### Desktop Layout

Desktop keeps the split-panel structure, but the left brand panel becomes the first visual focus instead of a secondary helper area.

The left side is fixed to a four-part hierarchy:

1. eyebrow
2. brand title
3. standalone slogan
4. concise brand chips

The right side remains the operational area for auth form entry and feedback.

### Compact Layout

On mobile-width or narrow desktop windows, the page collapses into a stacked structure:

- brand block first
- auth form second

The compact brand block stays recognizable and still surfaces `信息平权` before the form begins.

## Brand Copy

### Left Brand Panel

The approved copy structure is:

- eyebrow: `INFORMATION EQUITY`
- title: `信息平权`
- slogan: `让全天下的人没有信息差`

The slogan must appear as its own line and must not be buried in a paragraph.

### Brand Chips

The approved brand chips are fixed to these short statements:

- `真实信息更快抵达`
- `统一可信入口`
- `桌面 / 移动 / Web 一致体验`

These stay concise and should not become full-sentence marketing blurbs.

### Right Form Copy

The auth form should remain operational and restrained. The recommended login copy is:

- title: `欢迎登录`
- subtitle: `使用手机号和密码进入信息平权`

Register and reset surfaces should inherit the same naming tone, but they must not compete visually with the main login brand statement.

## Visual Direction

The approved visual direction is premium and restrained rather than loud or promotional.

### Palette

- primary base: deep navy / graphite blue
- accent: restrained warm gold
- supporting surfaces: low-contrast blue-gray overlays

Disallowed visual traits:

- bright consumer-app gradients
- colorful marketing blocks
- purple-led default SaaS styling
- overly flat white-card-on-white-background treatment

### Typography and Hierarchy

- the brand title should be noticeably larger and stronger than the form title
- the slogan should feel deliberate and premium, not like helper copy
- form labels and helper text should remain readable and lower in hierarchy than the left-side brand statement

### Atmosphere

The page should feel like a high-end product entry screen, not a back-office system and not a marketing landing page.

## Component Boundaries

Implementation should remain inside the existing auth presentation surface.

### Expected File Scope

Primary implementation is expected in:

- `lib/core/config/app_config.dart`
- `lib/modules/auth/presentation/widgets/auth_copy.dart`
- `lib/modules/auth/presentation/widgets/auth_page_scaffold.dart`
- `lib/modules/auth/presentation/pages/auth_login_page.dart`

Secondary auth surfaces may need limited copy updates if they still expose the product name directly.

### Structural Rule

Do not replace `AuthPageScaffold` with a new page shell. Extend and refine the existing shell so that:

- desktop split behavior remains intact
- compact stacked behavior remains intact
- current auth-flow wiring does not move

## Error Handling and Safety

This redesign is intentionally presentation-only, so safety means avoiding behavioral regressions.

Required safeguards:

- no change to submit handlers
- no change to validation branching
- no change to status-banner trigger logic
- no change to remember-password or auto-login persistence logic
- no change to API endpoint override availability

Copy cleanup in `AuthCopy` must preserve all existing user-visible validation and action messages unless the change is clearly brand-related.

## Encoding Cleanup

`AuthCopy` currently contains mojibake in multiple auth strings. This redesign should use the branding change as the opportunity to normalize the touched auth copy into maintainable UTF-8 source text.

Constraints:

- only normalize strings that are part of the touched auth experience
- do not introduce accidental wording drift in unrelated features
- ensure Chinese strings remain readable in source and test output

## Testing

At minimum, the implementation plan must cover:

- widget or presentation tests that assert the login page shows `信息平权`
- widget or presentation tests that assert the slogan `让全天下的人没有信息差` is visible
- checks that the approved brand chips render in the login experience
- regression verification that the login form still renders phone field, password field, agreement block, and primary action

Manual verification should include:

- Windows desktop launch
- narrow-width auth layout
- login page brand-panel appearance
- register and reset pages still rendering correctly after copy cleanup

## Success Criteria

This design is successful when:

- the login page clearly presents `信息平权` as the product name
- the slogan is visible, premium, and easy to recognize
- the left-side branding feels significantly more intentional than the current helper-copy block
- no previously verified login behavior regresses
- the touched auth strings are no longer stored as mojibake

## Open Risks

- `AuthCopy` cleanup may surface more legacy corrupted strings than the branding change strictly requires
- visual improvements may look correct on desktop but feel too tall on compact windows unless spacing is tuned carefully
- if product-name replacement is applied too broadly in this pass, it may create an unintended partial rebrand outside auth

## Recommended Implementation Order

1. Lock copy and app-name constants.
2. Refine brand-panel layout and spacing in the existing scaffold.
3. Update login page wiring to use the approved branding fields.
4. Add focused presentation tests.
5. Run targeted auth and Windows verification.

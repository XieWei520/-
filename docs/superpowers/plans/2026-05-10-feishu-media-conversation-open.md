# Feishu Media Conversation Open Plan

> Workflow: superpowers:executing-plans + superpowers:test-driven-development.

## Goal

Allow the Feishu monitor shell to enter the matching Feishu conversation only when a configured source group feed card shows a pending image preview, so the shell can extract the real image and forward it to the mapped WuKongIM group.

## Policy

- Text forwarding stays feed-list based.
- The shell may open a Feishu conversation only for a pending media feed card.
- The shell must not auto-open the newest ordinary feed card on text/feed changes.
- The forwarding service may send `dom_probe` image attachments only when the attachment is prepareable outside the Feishu WebView (`data:image`, http(s), or local file).
- `body_text_probe` media remains blocked.
- `[Image]` / image placeholder text without an attachment remains skipped.
- `blob:` image attachments remain deferred/skipped because WuKongIM cannot prepare them outside the Feishu WebView.
- Routing and dedupe protections stay unchanged: only configured routes are eligible, ambiguous routes are skipped, and repeated media fingerprints are deduped.

## Tasks

- [ ] Update shell policy tests from strict no-DOM to controlled media conversation opening.
- [ ] Update forwarding tests so routed `dom_probe` images can be sent while `body_text_probe`, blob, and placeholder-only events stay blocked.
- [ ] Implement the shell policy: enable pending media feed opening, keep ordinary latest-feed opening disabled.
- [ ] Implement the forwarding policy: allow prepareable `dom_probe` image attachments.
- [ ] Run focused tests and rebuild/restart the shell and WuKongIM desktop app for joint testing.

# 2026-04-05 New Friends Status Alignment Design

## Scope

This spec covers a focused bugfix for Flutter `NewFriendsPage` behavior so it matches Android's effective interaction rules for friend requests.

It does not change the deployed backend contract.
It does not attempt to repair server-side stale friend-apply rows.
It does not include unrelated conversation or group request optimizations.

## Problem

Current Flutter behavior allows stale or already-processed friend requests to remain actionable.

Observed mismatch:

- Backend can return historical `friend/apply` rows whose `status` is no longer pending.
- Current Flutter UI only treats `status == 1` as processed.
- `status == 2` rows can still show an approve button.
- Requests can also remain pending in the list even when the two users are already friends.

Android reference behavior is effectively:

- Only pending requests are actionable.
- Accepted requests are shown as processed.
- If a pending request now corresponds to an existing friend relationship, it is normalized to accepted for presentation.
- Tapping into user detail is only enabled for processed/accepted entries.

## Chosen Approach

Use a small client-side normalization layer and strict pending-only action guards.

Why this approach:

- It fixes the confirmed root cause without depending on backend cleanup.
- It aligns with Android interaction semantics.
- It keeps stale production data from surfacing invalid actions.

## Design

### 1. Request State Rules

Friend request presentation will follow these rules:

- `status == 0`: pending, actionable
- `status == 1`: accepted, non-actionable
- `status == 2`: processed/non-actionable in Flutter UI
- pending request + existing friend relationship: present as accepted

### 2. UI Rules

`NewFriendsPage` row behavior:

- Only pending requests show the approve button.
- Accepted and rejected requests show a passive processed label.
- User detail navigation remains available only for accepted/normalized-accepted requests.

### 3. Provider Rules

`FriendRequestListNotifier.handleRequest` will reject any non-pending request before calling the API.

This prevents stale tokens from being sent for already-processed rows.

### 4. Data Normalization

The contacts/new-friends surface will normalize request presentation against the current friend list:

- if request is pending and `fromUid` already exists in current friends, mark it as accepted in UI state

This mirrors Android's local reconciliation step without mutating backend data.

## Testing

Add targeted tests that fail first for:

- `status == 2` request does not show approve action
- non-pending request is rejected by provider before API call
- pending request with existing friend relationship is rendered/treated as accepted
- pending request without friendship remains actionable

## Risks

- Android original code only models `0/1` explicitly, while Flutter now receives `2` from server. We will treat all non-pending states as non-actionable to stay safe.
- This is a presentation fix, not a backend cleanup. Historical rows may still exist on the server.

## Verification

Success means:

- stale rejected rows cannot trigger `friend/sure`
- already-friends rows no longer surface as actionable requests
- targeted widget/provider/model tests pass

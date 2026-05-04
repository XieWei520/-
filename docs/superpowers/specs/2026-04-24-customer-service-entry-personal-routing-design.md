# Customer Service Entry Personal Routing Design

**Date:** 2026-04-24

## Goal

When a normal user enters chat from the customer-service entry, and the server
has already resolved a real customer-service account UID, the client must open
that chat as a normal personal conversation instead of a
`WKChannelType.customerService` conversation. This ensures the customer-service
account sees one independent conversation per user in its own conversation
list.

## Current Problem

The current customer-service entry flow already requests
`/v1/user/customerservices` and resolves a real customer-service account UID.
However, after resolution it still opens:

- `channelId = resolved customer-service uid`
- `channelType = WKChannelType.customerService`

That mismatches the desired business model. The user is no longer talking to a
virtual shared customer-service channel. The user is talking directly to a
specific customer-service account.

Because the conversation is opened with the customer-service channel type
instead of the personal channel type, the message and conversation semantics do
not align with ordinary user-to-user chat. The result is that the
customer-service account side does not reliably accumulate one visible
conversation entry per visiting user in the standard conversation list.

## Requirement Confirmed

- If the customer-service entry resolves a real customer-service account UID,
  chat must open as a direct personal conversation with that account.
- Different users who message the same customer-service account must each
  appear as separate sessions in the customer-service account's conversation
  list.
- The legacy fallback path must remain compatible:
  - if no real customer-service account can be resolved
  - and the app falls back to the placeholder `customer_service`
  - then the existing `WKChannelType.customerService` path stays unchanged

## Approaches Considered

### Recommended: Switch only the resolved route to `WKChannelType.personal`

- Keep `/v1/user/customerservices` as the source of the resolved account UID
- If `uid` is a real account:
  - open `ChatPage(channelId: uid, channelType: WKChannelType.personal)`
- If the app falls back to the placeholder `customer_service`:
  - keep `WKChannelType.customerService`

Why this is the recommended approach:

- It matches the intended business rule exactly: user talks to a real
  customer-service account.
- It avoids changing server contracts.
- It avoids changing SDK-level customer-service semantics.
- It minimizes the change surface to one routing decision and a few regression
  tests.

### Rejected: Keep `WKChannelType.customerService` and split conversations later

This keeps the current mismatch between the resolved UID and the channel type.
It would require extra mapping logic on the conversation layer and still leaves
message semantics ambiguous.

### Rejected: Redesign server or SDK customer-service channel semantics

This is larger than the problem. The existing system already has enough
information to open a direct personal chat. Reworking server or SDK semantics
would create unnecessary risk.

## Selected Design

### Routing Rule

The customer-service entry will use the following branching:

- Resolved customer-service account path:
  - `channelId = resolved uid`
  - `channelType = WKChannelType.personal`
- Legacy fallback placeholder path:
  - `channelId = 'customer_service'`
  - `channelType = WKChannelType.customerService`

The branching decision is based on whether the route is using a real resolved
account or the placeholder fallback.

### Data Flow

1. User taps the customer-service entry.
2. The client calls `/v1/user/customerservices`.
3. If the response includes a non-empty real UID:
   - open the chat as a personal conversation to that UID
4. If the request fails or no valid UID is returned:
   - open the legacy placeholder customer-service conversation

### Expected Runtime Effect

After this change:

- messages sent from the customer-service entry to a resolved account are
  emitted on ordinary personal conversation semantics
- the customer-service account sees each user as a normal personal
  conversation peer
- the customer-service account conversation list shows separate sessions for
  different visiting users

## File Scope

### Flutter production files

- `C:\Users\COLORFUL\Desktop\WuKong\lib\modules\contacts\contacts_page.dart`
  - change the resolved customer-service route to use
    `WKChannelType.personal`
  - keep the legacy placeholder route on
    `WKChannelType.customerService`

### Flutter tests

- `C:\Users\COLORFUL\Desktop\WuKong\test\modules\contacts\contacts_page_parity_test.dart`
  - add a regression test that proves a resolved customer-service account opens
    a personal chat
  - add or update a regression test that proves the legacy placeholder still
    opens the customer-service channel type

## Testing Strategy

### Required regression coverage

- resolved account route:
  - server returns at least one valid customer-service account
  - entry opens chat with that UID
  - channel type is `WKChannelType.personal`

- legacy fallback route:
  - server request fails or returns no valid account
  - entry opens fallback `customer_service`
  - channel type remains `WKChannelType.customerService`

### Manual verification target

Use two ordinary test users and one user flagged as customer service:

1. log in as user A and enter customer service
2. send a message
3. log in as user B and enter customer service
4. send a message
5. log in as the customer-service account
6. verify the conversation list shows separate sessions for user A and user B

## Risks And Constraints

- This fix assumes the backend has already resolved customer-service routing to
  a real account UID correctly.
- The legacy placeholder path remains in place, so old fallback behavior is not
  broken.
- This change intentionally does not alter:
  - customer-service badges
  - public category normalization
  - admin customer-service assignment logic
  - server-side `/v1/user/customerservices` response structure

## Non-Goals

- redesigning the customer-service backend routing model
- changing the SDK conversation model
- removing the placeholder `customer_service` fallback
- adding load balancing or queueing between multiple customer-service accounts

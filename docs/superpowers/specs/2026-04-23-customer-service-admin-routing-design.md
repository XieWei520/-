# Customer Service Admin Routing Design

**Date:** 2026-04-23

**Goal:** Add customer-service assignment to the admin user list, support one
default customer-service account with deterministic fallback, and make all
customer-service users display a unified `客服` identity tag to normal users.

## Design Summary

The Flutter client already has a customer-service entry, but it currently
depends on `/v1/user/customerservices` and simply opens the first returned
account. The backend already supports querying users by customer-service
category, yet the admin system has no action to assign or manage customer
service, and there is no formal routing order for multiple customer-service
accounts.

This design formalizes the feature across three layers:

1. The server keeps customer-service membership in the existing user category
   model and adds an explicit routing order.
2. The admin backend exposes actions in `用户列表 > 更多` to assign, remove, and
   promote customer-service users, while showing customer-service badges in the
   list.
3. The user-facing client keeps its current "take the first customer-service
   account" behavior, but the server guarantees that the first result is the
   correct routing target.

The design intentionally separates internal routing semantics from public user
identity:

- Admins can see `客服` and `默认客服`
- Normal users only see `客服`
- Routing still honors the default customer-service account and fallback order

## Confirmed Current State

- Flutter client:
  - `lib/modules/contacts/contacts_page.dart`
    - `_openCustomerServiceAsync()` calls `UserApi.instance.getCustomerServices()`
    - it opens the first service account with a non-empty `uid`
  - `lib/service/api/user_api.dart`
    - `getCustomerServices()` calls `/v1/user/customerservices`
  - multiple UI surfaces already render user/category identity tags:
    - contact list
    - conversation list
    - user detail page
- Server:
  - remote `modules/user/api.go`
    - `/v1/user/customerservices` already exists
    - it currently returns all `category = customerService` users
  - remote `modules/user/const.go`
    - existing internal category constant: `CategoryCustomerService = "customerService"`
- Admin backend:
  - remote `modules/user/api_manager.go`
    - user list and more-actions exist
    - no customer-service management route exists today
  - production manager frontend already exposes a user-list `更多` dropdown and
    VIP badge handling
  - the deployed manager frontend on the server is a built `dist`, not a local
    source tree

## Requirements Confirmed With The User

- Multiple customer-service users are allowed
- One of them must be the default customer-service account
- If the default customer-service account becomes unavailable, routing must
  automatically fall back to another available customer-service account
- When a user is assigned as customer service:
  - the admin user list must show a customer-service badge
  - other normal users must also see a unified `客服` tag for that account
- Normal users must not see `默认客服`

## Approaches Considered

### Recommended: Reuse `category` and add `customer_service_rank`

- Keep customer-service membership on `user.category`
- Add `user.customer_service_rank`
- Sort `/v1/user/customerservices` by rank
- Treat rank `1` as the default customer-service account

Why this approach:

- It matches the existing backend and client architecture with minimal runtime
  disruption.
- It keeps membership and routing in a single source of truth.
- It allows deterministic fallback without extra lookup tables.
- It lets the Flutter client remain unchanged for the customer-service entry:
  the server just returns the correct first record.

### Rejected: Keep `category`, add only `default_customer_service_uid`

This is smaller initially but splits state into two places: the customer-service
user set and a separate default pointer. Fallback order remains underspecified
unless another rule is added later.

### Rejected: Create a dedicated customer-service routing table

This is the cleanest long-term data model if the system later needs workload
balancing, skill groups, or online-aware assignment. For the current scope it
adds unnecessary schema, query, and admin complexity.

## Selected Design

### Membership And Routing Model

- Internal customer-service membership remains:
  - `user.category = 'customerService'`
- Add:
  - `user.customer_service_rank INT NOT NULL DEFAULT 0`

Rules:

- `customer_service_rank = 0`
  - not part of customer-service routing
- `customer_service_rank = 1`
  - default customer-service account
- `customer_service_rank = 2..N`
  - fallback order after the default account

Availability rules:

- Only users satisfying all of the following are routable:
  - `category = 'customerService'`
  - `customer_service_rank > 0`
  - `status = 1`
  - `is_destroy = 0`

### Routing Behavior

`GET /v1/user/customerservices` becomes the formal source of customer-service
routing targets.

Response behavior:

- return only routable customer-service users
- order by `customer_service_rank ASC`
- each row includes:
  - `uid`
  - `name`

Client behavior:

- Flutter continues to open the first returned account
- because the server returns results in ranked order:
  - the default customer-service account is chosen first
  - if it is unavailable, the next ranked account is chosen automatically

If no routable customer-service accounts exist:

- return an empty list
- the client keeps its current empty/legacy fallback behavior

## Admin Contract

### User List Response

Extend `/v1/manager/user/list` and the compatible admin alias response so each
user row includes:

- `category`
- `customer_service_rank`
- `is_customer_service`
- `is_default_customer_service`

These fields are admin-only state and do not belong in the public user-facing
contract.

### Admin Actions

Add customer-service management endpoints:

- `POST /v1/manager/user/set_customer_service`
- `POST /api/admin/set_customer_service`

Request body:

```json
{
  "uid": "user-001",
  "enabled": true,
  "is_default": false
}
```

Behavior rules:

- `enabled = true, is_default = false`
  - if the user is not already customer service:
    - set `category = customerService`
    - append to the end of the ranked queue
  - if already customer service:
    - keep current rank unchanged
- `enabled = true, is_default = true`
  - ensure the user is customer service
  - move the user to `customer_service_rank = 1`
  - shift previous ranked users back by one
- `enabled = false`
  - remove customer-service membership
  - set `category = ''`
  - set `customer_service_rank = 0`
  - compact the remaining ranks to keep them contiguous

All ranking updates must run in one transaction so the system never exposes:

- two default customer-service accounts
- duplicate ranks
- rank gaps caused by partial writes

### Admin UI

Add the following items under `用户列表 > 更多`:

- `设为客服`
- `取消客服`
- `设为默认客服`

Interaction rules:

- if the row is not customer service:
  - show `设为客服`
  - show `设为默认客服`
- if the row is customer service but not default:
  - show `取消客服`
  - show `设为默认客服`
- if the row is already default customer service:
  - show `取消客服`
  - hide or disable `设为默认客服`

If a non-customer-service user clicks `设为默认客服`:

- assign the user as customer service
- immediately promote the user to rank `1`

### Admin Badges

The admin user list must display customer-service identity badges next to the
nickname, at the same visual level as the existing VIP badge.

Badge rules:

- normal customer-service account:
  - show `客服`
- default customer-service account:
  - show `默认客服`
- VIP and customer-service badges can coexist
- only one customer-service badge is shown at a time:
  - `默认客服` takes precedence over `客服`

## Public User Contract

### Public Identity Semantics

All customer-service users must expose a unified public identity tag to normal
users:

- public label: `客服`
- public users must not see `默认客服`
- public users must not receive rank metadata

### Category Normalization

The server currently stores the internal category as `customerService`, while
some Flutter surfaces normalize category values such as:

- `customerservice`
- `customer_service`
- `service`

To make the tag consistent across all user-facing screens, the public user
contract should normalize customer-service category output to one stable value:

- public category: `customer_service`

This normalization must be applied anywhere user/category data is returned to
the Flutter client, including user detail, friend/contact, and conversation
adjacent data flows that already render category-based tags.

### Public Badge Surfaces

The unified `客服` tag must appear anywhere the client already displays
user-identity/category badges, including:

- contact list
- conversation list
- user detail page
- any other badge surface driven by public `category`

## Data Migration

Add a new user-table migration:

- `ALTER TABLE user ADD COLUMN customer_service_rank INT NOT NULL DEFAULT 0`

Backfill rules for existing customer-service users:

- identify rows with `category = 'customerService'`
- assign ranks deterministically using:
  - `created_at ASC`
  - then `id ASC` as a stable tie-breaker

This ensures an upgrade does not produce random routing order for existing
customer-service accounts.

## Error Handling And Edge Cases

- Reassigning an already customer-service user as customer service is idempotent
- Re-promoting the already default customer-service user is idempotent
- Removing customer-service status from a non-customer-service user succeeds as
  a no-op
- If the default customer-service user becomes disabled or destroyed:
  - keep stored ranks unchanged
  - exclude the user from routable results
  - route to the next available ranked user
- If all customer-service users are unavailable:
  - `/v1/user/customerservices` returns `[]`
- Public client payloads must not leak:
  - `customer_service_rank`
  - `is_default_customer_service`

## Architecture And File Targets

### Server

Remote targets:

- `/opt/wukongim-prod/src/modules/user/api.go`
- `/opt/wukongim-prod/src/modules/user/api_manager.go`
- `/opt/wukongim-prod/src/modules/user/db.go`
- `/opt/wukongim-prod/src/modules/user/db_manager.go`
- `/opt/wukongim-prod/src/modules/user/sql/*`
- related user/admin tests under `modules/user/*_test.go`

Responsibilities:

- store customer-service membership and rank
- expose ranked customer-service query results
- expose admin management routes
- normalize public category output for the Flutter client

### Admin Frontend

Remote deployed targets:

- `/opt/wukongim-prod/src/deploy/production/manager/dist/static/js/user*.js`
- `/opt/wukongim-prod/src/deploy/production/manager/dist/static/js/userlist*.js`

Responsibilities:

- render `客服` / `默认客服` badges in the admin user list
- add customer-service actions to the `更多` dropdown
- refresh the row/list after successful mutation

### Flutter Client

Repo-visible targets likely affected by the public contract:

- `C:\Users\COLORFUL\Desktop\WuKong\lib\data\models\friend.dart`
- `C:\Users\COLORFUL\Desktop\WuKong\lib\data\models\user.dart`
- `C:\Users\COLORFUL\Desktop\WuKong\lib\widgets\wk_conversation_item.dart`
- `C:\Users\COLORFUL\Desktop\WuKong\lib\modules\contacts\widgets\contacts_list_viewport.dart`
- `C:\Users\COLORFUL\Desktop\WuKong\lib\wukong_uikit\user\user_detail_page.dart`

Responsibilities:

- consume normalized public customer-service category values
- render the unified `客服` badge consistently
- keep customer-service entry logic unchanged

## Testing Strategy

### Server Tests

- add admin-route tests for:
  - assign customer service
  - promote default customer service
  - remove customer service
- verify DB state after each mutation:
  - category
  - rank
  - compacted ordering
- add public route tests for `/v1/user/customerservices`
  - returns only routable customer-service users
  - sorted by rank ascending
  - falls back when the default customer-service user is unavailable
- add response-shape tests for `/v1/manager/user/list`
  - includes customer-service fields
- add public response tests where user/category payloads are exposed
  - customer-service users normalize to public `customer_service`

### Admin UI Verification

- the user list shows `客服` or `默认客服` badge immediately after mutation
- the `更多` menu shows the correct actions for each row state
- a non-customer-service user can become default customer service in one action

### Flutter Verification

- contact list shows `客服`
- conversation list shows `客服`
- user detail page shows `客服`
- the customer-service entry opens the ranked first user returned by
  `/v1/user/customerservices`

## Non-Goals

- workload balancing among multiple customer-service users
- online-aware or least-busy assignment
- customer-service skill groups or queue routing
- exposing default-customer-service status to normal users
- changing the existing Flutter customer-service entry flow beyond consuming the
  ranked server results

# Database Cache Optimization Design

**Date:** 2026-04-23

## Objective

Reduce the next-stage production risk on the IM message and conversation paths by fixing the highest-impact database index gaps and cleaning up low-risk Redis cache hygiene issues, without changing the existing client/server contract or the online-status consistency model.

## Observed Production Facts

### MySQL

- `slow_query_log=ON`
- `long_query_time=0.2`
- `log_output=FILE`
- Message data is sharded across `message`, `message1`, `message2`, `message3`, `message4`.
- The `message*` shards only expose `PRIMARY(id)` plus `UNIQUE(message_id)`.
- `message_extra` only has `channel_idx(channel_id, channel_type)`, `from_uid_idx(from_uid)`, and `UNIQUE(message_id)`.
- `conversation_extra` only has `UNIQUE(uid, channel_id, channel_type)` plus `uid_idx(uid)`.
- `channel_offset*` keeps `UNIQUE(uid, channel_id, channel_type)` only.

### Query Hotspots

- `modules/message/db.go` computes `MAX(message_seq)` per channel from `message*` without a `(channel_id, channel_type, message_seq)` index.
- `modules/message/db_message_extra.go` syncs by `(channel_id, channel_type, version)` but sorts by `version` without a supporting composite index.
- `modules/message/db_conversation_extra.go` syncs by `(uid, version)` without a matching range index.
- `modules/message/db_channel_offset.go` uses `(uid=? OR uid='')` with `ORDER BY message_seq DESC` and `MAX(message_seq)` group-by patterns; this is structurally inefficient but not the first low-risk change to land.

### Redis

- Live usage is small: about `4.29M`, `543` keys, high hit ratio.
- Source-of-truth online status is not Redis-backed; it is persisted and read from MySQL `user_online`.
- Critical Redis paths currently include auth/session keys, device-session state, read-receipt staging, `messageExtraVersion:*`, and `lm-friends:*`.
- `lm-friends:*` and `messageExtraVersion:*` do not currently expire, so stale keys accumulate.
- The `readedCount:*` worker still uses `GetKeys(...)`; improving that is desirable, but the backing Redis wrapper boundary is not fully local to this repository.

## Design Scope

### In Scope Now

1. Add production-safe MySQL indexes that directly support the current hot query shapes.
2. Add TTL refresh to `lm-friends:*` friend caches.
3. Add TTL refresh to `messageExtraVersion:*` hashes.
4. Capture rollout evidence, migration evidence, and post-change verification in a dedicated report.

### Explicitly Deferred

1. Replacing `GetKeys(...)` with `SCAN` in this slice, unless the required Redis wrapper surface is confirmed to be fully editable in the current repo.
2. Moving online-status truth into Redis.
3. Broad user/group/profile cache-aside layers, which need wider invalidation design.
4. Channel-setting cache-aside, because write paths are split between service and direct DB callers and would benefit from a dedicated follow-up slice.
5. Query rewrites like `channel_offset` `UNION ALL` or `member_readed` join collapse; these remain good candidates after the index baseline is in place.

## Proposed Changes

### MySQL Index Package

Add one new message-module migration with:

- `idx_msg_channel_type_seq` on each of `message`, `message1`, `message2`, `message3`, `message4`
- `idx_msg_extra_channel_type_version` on `message_extra(channel_id, channel_type, version)`
- `idx_conversation_uid_version` on `conversation_extra(uid, version)`

This directly supports:

- `MAX(message_seq)` by channel
- channel message sync ordered by `version`
- conversation extra sync by `uid + version`

### Redis TTL Hygiene

Add bounded TTL and refresh-on-write behavior for:

- `lm-friends:*`
- `messageExtraVersion:*`

The read path already safely falls back to DB or client-provided versions on cache miss, so expiring these keys does not change correctness.

## Rollout Strategy

1. Capture baseline evidence and create file/code backups on the remote host.
2. Add the migration file and TTL code changes.
3. Rebuild and recreate the affected backend services.
4. Verify:
   - new row in `gorp_migrations`
   - expected indexes visible in `information_schema.statistics`
   - services healthy after recreate
   - Redis keys for the touched cache families now carry TTLs
5. Record before/after evidence and rollback notes.

## Risks

- MySQL `ALTER TABLE ... ADD INDEX` still touches storage; run only after backups and verify shard sizes before execution.
- TTLs that are too short could create avoidable DB churn. Use conservative multi-day TTLs.
- Migration ordering must remain monotonic with the current `gorp_migrations` state.

## Success Criteria

- Message and conversation sync paths now have direct supporting indexes for their dominant range/sort conditions.
- Friend and message-extra version caches no longer accumulate indefinitely.
- `gorp_migrations` records the new migration and post-change health remains green.

# Database Cache Optimization Rollout Report

## Baseline

### MySQL
```text
slow_query_log	ON
slow_query_log_file	/var/lib/mysql/245fd9458c97-slow.log
long_query_time	0.200000
log_output	FILE
conversation_extra	PRIMARY	0	1	id
conversation_extra	uid_channel_idx	0	1	uid
conversation_extra	uid_channel_idx	0	2	channel_id
conversation_extra	uid_channel_idx	0	3	channel_type
conversation_extra	uid_idx	1	1	uid
message	message_id	0	1	message_id
message	PRIMARY	0	1	id
message1	message_id	0	1	message_id
message1	PRIMARY	0	1	id
message2	message_id	0	1	message_id
message2	PRIMARY	0	1	id
message3	message_id	0	1	message_id
message3	PRIMARY	0	1	id
message4	message_id	0	1	message_id
message4	PRIMARY	0	1	id
message_extra	channel_idx	1	1	channel_id
message_extra	channel_idx	1	2	channel_type
message_extra	from_uid_idx	1	1	from_uid
message_extra	message_id	0	1	message_id
message_extra	PRIMARY	0	1	id
```

### Redis
```text
used_memory_human:4.29M
maxmemory_human:0B
maxmemory_policy:noeviction
mem_fragmentation_ratio:1.74
---
expired_keys:35
evicted_keys:0
keyspace_hits:122623
keyspace_misses:1525
---
# Keyspace
db0:keys=543,expires=464,avg_ttl=1982954251,subexpiry=0
```

## Backups

- rollback directory: `/opt/wukongim-prod/rollback_snapshots/task_db_cache_20260423_214856`
- backed up: `/opt/wukongim-prod/src/modules/user/webhook.go`
- backed up: `/opt/wukongim-prod/src/modules/user/db_friend.go`
- backed up: `/opt/wukongim-prod/src/modules/message/api.go`
- backed up if present: `/opt/wukongim-prod/src/modules/message/sql/message-20260423-02.sql`
- final apply backup: `/opt/wukongim-prod/rollback_snapshots/task_db_cache_apply_20260423_221626`

## Applied Changes

- Added migration `/opt/wukongim-prod/src/modules/message/sql/message-20260423-02.sql`.
- Added `idx_msg_channel_type_seq(channel_id, channel_type, message_seq)` to `message`, `message1`, `message2`, `message3`, and `message4`.
- Added `idx_msg_extra_channel_type_version(channel_id, channel_type, version)` to `message_extra`.
- Added `idx_conversation_uid_version(uid, version)` to `conversation_extra`.
- Updated `/opt/wukongim-prod/src/modules/user/webhook.go` to refresh `lm-friends:*` TTL on cache hit and cache fill.
- Updated `/opt/wukongim-prod/src/modules/user/db_friend.go` to refresh `lm-friends:*` TTL on friend set writes.
- Updated `/opt/wukongim-prod/src/modules/message/api.go` to refresh `messageExtraVersion:*` TTL after hash writes.
- Rebuilt and recreated `tsdd-api` and `callgateway` with `docker compose --env-file .env up -d --build --force-recreate tsdd-api callgateway`.

## Post-Change Verification

### Service Health

```text
2026-04-23 22:20 CST docker compose ps
- wukongim_prod-tsdd-api-1: Up (healthy)
- wukongim_prod-callgateway-1: Up (healthy)
```

### Migration And Index Presence

```text
gorp_migrations:
message-20260423-02.sql    2026-04-23 22:20:56

new indexes:
conversation_extra idx_conversation_uid_version (uid, version)
message            idx_msg_channel_type_seq     (channel_id, channel_type, message_seq)
message1           idx_msg_channel_type_seq     (channel_id, channel_type, message_seq)
message2           idx_msg_channel_type_seq     (channel_id, channel_type, message_seq)
message3           idx_msg_channel_type_seq     (channel_id, channel_type, message_seq)
message4           idx_msg_channel_type_seq     (channel_id, channel_type, message_seq)
message_extra      idx_msg_extra_channel_type_version (channel_id, channel_type, version)
```

### Query Plan Improvement

Before rollout:
- `message` max-seq lookup on `(channel_id, channel_type)` was observed as a full scan.
- `message_extra` sync on `(channel_id, channel_type, version)` was observed as filesort / non-covering access.
- `conversation_extra` sync on `(uid, version)` lacked a composite index.

After rollout:

```text
message max(message_seq):
- EXPLAIN result: Select tables optimized away

message_extra sync:
- key: idx_msg_extra_channel_type_version
- Extra: Using index condition

conversation_extra sync:
- key: idx_conversation_uid_version
- Extra: Using index condition
```

### Redis TTL Verification

End-to-end verified via a real authenticated request to `POST https://wemx.cc/v1/message/extra/sync` using probe source `codex-ttl-probe-20260423`.

```text
HTTP_STATUS=200
RESPONSE_BODY=[]
CACHE_KEY=messageExtraVersion:056304019bc34cb298da61c74e1098b2codex-ttl-probe-20260423
CACHE_TTL=604800
CACHE_HLEN=1
```

Observed existing pre-rollout keys:
- legacy `lm-friends:*` samples remained `TTL=-1`
- legacy `messageExtraVersion:*` samples remained `TTL=-1`

Interpretation:
- the new TTL logic is active for fresh writes and future hits
- old hot keys are not backfilled retroactively
- no synthetic online/offline event was forced for `lm-friends:*` because that would perturb live user sessions

## Rollback Notes

- Restore file backups from `/opt/wukongim-prod/rollback_snapshots/task_db_cache_apply_20260423_221626`.
- If rollback happens after migration application, run the `Down` section of `message-20260423-02.sql` to drop:
  - `idx_conversation_uid_version`
  - `idx_msg_extra_channel_type_version`
  - `idx_msg_channel_type_seq` on `message`, `message1`, `message2`, `message3`, `message4`
- Remove or replace `/opt/wukongim-prod/src/modules/message/sql/message-20260423-02.sql` as needed.
- Recreate `tsdd-api` and `callgateway` after restoring files.

## Non-Goals

- No IM protocol contract change in this slice.
- No online-status source-of-truth change.
- No Flutter local database change.
- No channel-setting cache-aside rollout in this slice.

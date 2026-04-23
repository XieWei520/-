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

## Applied Changes

## Post-Change Verification

## Rollback Notes

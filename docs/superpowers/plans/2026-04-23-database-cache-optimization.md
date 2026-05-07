# Database Cache Optimization Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Harden the IM database and Redis layers by adding the missing production indexes for current message/conversation query shapes and by expiring non-critical cache families that currently grow without bounds.

**Architecture:** This slice is intentionally conservative. It avoids changing the online-status source-of-truth or introducing broad cache-aside layers. Instead it lands one message-module migration, two bounded TTL changes in backend code, and a rollout report that proves the migration and cache behavior on production.

**Tech Stack:** Go, MySQL 8, Redis 7, sql-migrate, Docker Compose, PowerShell, SSH

---

## File Structure

- Create: `C:\Users\COLORFUL\Desktop\WuKong\.worktrees\database-cache-optimization\docs\superpowers\artifacts\2026-04-23-database-cache-optimization-rollout.md`
  Responsibility: capture baseline evidence, backup paths, applied migration id, cache TTL verification, and rollback steps
- Create remotely: `/opt/wukongim-prod/src/modules/message/sql/message-20260423-02.sql`
  Responsibility: add the low-risk message/conversation indexes through the existing migration runner
- Modify remotely: `/opt/wukongim-prod/src/modules/user/webhook.go`
  Responsibility: refresh TTL for `lm-friends:*` when friend membership is loaded or hit
- Modify remotely: `/opt/wukongim-prod/src/modules/user/db_friend.go`
  Responsibility: refresh TTL for `lm-friends:*` on friend-set writes
- Modify remotely: `/opt/wukongim-prod/src/modules/message/api.go`
  Responsibility: refresh TTL for `messageExtraVersion:*` after writes to the per-user hash

### Task 1: Capture Baseline And Create Backups

**Files:**
- Create: `C:\Users\COLORFUL\Desktop\WuKong\.worktrees\database-cache-optimization\docs\superpowers\artifacts\2026-04-23-database-cache-optimization-rollout.md`

- [ ] **Step 1: Create the rollout report scaffold**

```markdown
# Database Cache Optimization Rollout Report

## Baseline

## Backups

## Applied Changes

## Post-Change Verification

## Rollback Notes
```

- [ ] **Step 2: Capture MySQL and Redis baseline facts**

Run:

```powershell
$cmd = @'
docker exec -i wukongim_prod-mysql-1 sh -s <<'SH'
MYSQL_PWD="$MYSQL_ROOT_PASSWORD" mysql -uroot -N -B "$MYSQL_DATABASE" <<'SQL'
SHOW VARIABLES LIKE 'slow_query_log';
SHOW VARIABLES LIKE 'slow_query_log_file';
SHOW VARIABLES LIKE 'long_query_time';
SHOW VARIABLES LIKE 'log_output';
SELECT table_name, index_name, non_unique, seq_in_index, column_name
FROM information_schema.statistics
WHERE table_schema = DATABASE()
  AND table_name IN ('message','message1','message2','message3','message4','message_extra','conversation_extra')
ORDER BY table_name, index_name, seq_in_index;
SQL
SH
'@
ssh ubuntu@42.194.218.158 $cmd
```

Expected:
- `slow_query_log` is `ON`
- `long_query_time` is `0.200000`
- `message*` only show `PRIMARY` plus `message_id`

- [ ] **Step 3: Back up every remote file that will be modified in this slice**

Run:

```powershell
$ts = Get-Date -Format 'yyyyMMdd_HHmmss'
$backupDir = "/opt/wukongim-prod/rollback_snapshots/task_db_cache_$ts"
ssh ubuntu@42.194.218.158 "sudo mkdir -p $backupDir && sudo cp -a /opt/wukongim-prod/src/modules/user/webhook.go $backupDir/webhook.go.bak && sudo cp -a /opt/wukongim-prod/src/modules/user/db_friend.go $backupDir/db_friend.go.bak && sudo cp -a /opt/wukongim-prod/src/modules/message/api.go $backupDir/message_api.go.bak && if [ -f /opt/wukongim-prod/src/modules/message/sql/message-20260423-02.sql ]; then sudo cp -a /opt/wukongim-prod/src/modules/message/sql/message-20260423-02.sql $backupDir/message-20260423-02.sql.bak; fi && echo $backupDir"
```

Expected:
- backup directory path is printed
- file backups exist

- [ ] **Step 4: Record baseline and backup paths in the rollout report**

- [ ] **Step 5: Commit the initial rollout report**

```bash
git add docs/superpowers/artifacts/2026-04-23-database-cache-optimization-rollout.md
git commit -m "docs: capture database cache optimization baseline"
```

### Task 2: Add The Low-Risk Message And Conversation Indexes

**Files:**
- Create remotely: `/opt/wukongim-prod/src/modules/message/sql/message-20260423-02.sql`
- Modify: `C:\Users\COLORFUL\Desktop\WuKong\.worktrees\database-cache-optimization\docs\superpowers\artifacts\2026-04-23-database-cache-optimization-rollout.md`

- [ ] **Step 1: Create the new migration file**

```sql
-- +migrate Up
ALTER TABLE `message`  ADD INDEX `idx_msg_channel_type_seq` (`channel_id`,`channel_type`,`message_seq`);
ALTER TABLE `message1` ADD INDEX `idx_msg_channel_type_seq` (`channel_id`,`channel_type`,`message_seq`);
ALTER TABLE `message2` ADD INDEX `idx_msg_channel_type_seq` (`channel_id`,`channel_type`,`message_seq`);
ALTER TABLE `message3` ADD INDEX `idx_msg_channel_type_seq` (`channel_id`,`channel_type`,`message_seq`);
ALTER TABLE `message4` ADD INDEX `idx_msg_channel_type_seq` (`channel_id`,`channel_type`,`message_seq`);
ALTER TABLE `message_extra` ADD INDEX `idx_msg_extra_channel_type_version` (`channel_id`,`channel_type`,`version`);
ALTER TABLE `conversation_extra` ADD INDEX `idx_conversation_uid_version` (`uid`,`version`);

-- +migrate Down
ALTER TABLE `conversation_extra` DROP INDEX `idx_conversation_uid_version`;
ALTER TABLE `message_extra` DROP INDEX `idx_msg_extra_channel_type_version`;
ALTER TABLE `message4` DROP INDEX `idx_msg_channel_type_seq`;
ALTER TABLE `message3` DROP INDEX `idx_msg_channel_type_seq`;
ALTER TABLE `message2` DROP INDEX `idx_msg_channel_type_seq`;
ALTER TABLE `message1` DROP INDEX `idx_msg_channel_type_seq`;
ALTER TABLE `message` DROP INDEX `idx_msg_channel_type_seq`;
```

- [ ] **Step 2: Recreate the backend image consumers so startup migration runs**

Run:

```powershell
ssh ubuntu@42.194.218.158 "cd /opt/wukongim-prod/src/deploy/production && docker compose --env-file .env up -d --build --force-recreate tsdd-api callgateway && docker compose --env-file .env ps"
```

Expected:
- `tsdd-api` and `callgateway` return healthy/up

- [ ] **Step 3: Verify the migration row and index presence**

Run:

```powershell
$cmd = @'
docker exec -i wukongim_prod-mysql-1 sh -s <<'SH'
MYSQL_PWD="$MYSQL_ROOT_PASSWORD" mysql -uroot -N -B "$MYSQL_DATABASE" <<'SQL'
SELECT * FROM gorp_migrations WHERE id='message-20260423-02.sql';
SELECT table_name, index_name, seq_in_index, column_name
FROM information_schema.statistics
WHERE table_schema = DATABASE()
  AND (
    (table_name IN ('message','message1','message2','message3','message4') AND index_name='idx_msg_channel_type_seq')
    OR (table_name='message_extra' AND index_name='idx_msg_extra_channel_type_version')
    OR (table_name='conversation_extra' AND index_name='idx_conversation_uid_version')
  )
ORDER BY table_name, index_name, seq_in_index;
SQL
SH
'@
ssh ubuntu@42.194.218.158 $cmd
```

Expected:
- one row for `message-20260423-02.sql`
- all expected indexes appear

- [ ] **Step 4: Record migration evidence in the rollout report**

- [ ] **Step 5: Commit the report update for index rollout**

```bash
git add docs/superpowers/artifacts/2026-04-23-database-cache-optimization-rollout.md
git commit -m "docs: record database index rollout"
```

### Task 3: Add TTL Hygiene To Redis Cache Families

**Files:**
- Modify remotely: `/opt/wukongim-prod/src/modules/user/webhook.go`
- Modify remotely: `/opt/wukongim-prod/src/modules/user/db_friend.go`
- Modify remotely: `/opt/wukongim-prod/src/modules/message/api.go`
- Modify: `C:\Users\COLORFUL\Desktop\WuKong\.worktrees\database-cache-optimization\docs\superpowers\artifacts\2026-04-23-database-cache-optimization-rollout.md`

- [ ] **Step 1: Add conservative TTL constants**

Use:

```go
const friendCacheTTL = 7 * 24 * time.Hour
const messageExtraVersionCacheTTL = 7 * 24 * time.Hour
```

- [ ] **Step 2: Refresh `lm-friends:*` on cache hit and load**

Update `modules/user/webhook.go` so `getFriendUidsAndSetCache`:
- refreshes TTL when `SMembers` returns members
- refreshes TTL after populating with `SAdd`

- [ ] **Step 3: Refresh `lm-friends:*` on friend writes**

Update `modules/user/db_friend.go` so each `SAdd` / `SRem` path also calls `Expire(friendKey, friendCacheTTL)`.

- [ ] **Step 4: Refresh `messageExtraVersion:*` after hash writes**

Update `modules/message/api.go` so `setMessageExtraVersion(...)`:
- keeps the current `Hset`
- then calls `Expire(cacheKey, messageExtraVersionCacheTTL)`

- [ ] **Step 5: Rebuild and recreate the affected backend image consumers**

Run:

```powershell
ssh ubuntu@42.194.218.158 "cd /opt/wukongim-prod/src/deploy/production && docker compose --env-file .env up -d --build --force-recreate tsdd-api callgateway && docker compose --env-file .env ps"
```

- [ ] **Step 6: Verify TTL behavior**

Run:

```powershell
ssh ubuntu@42.194.218.158 "cd /opt/wukongim-prod/src/deploy/production && REDIS_PASSWORD=\$(sed -n 's/^REDIS_PASSWORD=//p' .env) && docker exec wukongim_prod-redis-1 redis-cli --no-auth-warning -a \"\$REDIS_PASSWORD\" TTL lm-friends:test-miss-safe && echo --- && docker exec wukongim_prod-redis-1 redis-cli --no-auth-warning -a \"\$REDIS_PASSWORD\" --scan --pattern 'messageExtraVersion:*' | head"
```

Expected:
- command succeeds
- key family scan works without service errors

- [ ] **Step 7: Record TTL rollout evidence in the report**

- [ ] **Step 8: Commit the report update**

```bash
git add docs/superpowers/artifacts/2026-04-23-database-cache-optimization-rollout.md
git commit -m "docs: record redis ttl hygiene rollout"
```

### Task 4: Final Verification And Rollback Notes

**Files:**
- Modify: `C:\Users\COLORFUL\Desktop\WuKong\.worktrees\database-cache-optimization\docs\superpowers\artifacts\2026-04-23-database-cache-optimization-rollout.md`

- [ ] **Step 1: Re-run final verification**

Run:

```powershell
$cmd = @'
docker exec -i wukongim_prod-mysql-1 sh -s <<'SH'
MYSQL_PWD="$MYSQL_ROOT_PASSWORD" mysql -uroot -N -B "$MYSQL_DATABASE" <<'SQL'
SELECT * FROM gorp_migrations WHERE id='message-20260423-02.sql';
SHOW INDEX FROM message;
SHOW INDEX FROM message_extra;
SHOW INDEX FROM conversation_extra;
SQL
SH
'@
ssh ubuntu@42.194.218.158 $cmd
ssh ubuntu@42.194.218.158 "cd /opt/wukongim-prod/src/deploy/production && docker compose --env-file .env ps"
```

- [ ] **Step 2: Add before/after summary and rollback section**

Include:
- migration id applied
- new indexes present
- service health green
- rollback = restore file backups, remove the migration file if needed, drop the new indexes if rollback must be completed after migration already ran, then recreate `tsdd-api` and `callgateway`

- [ ] **Step 3: Note non-goals**

Include:
- no IM protocol contract changes
- no online-status source-of-truth change
- no Flutter SDK local database change
- no channel-setting cache-aside in this slice

- [ ] **Step 4: Commit final rollout report**

```bash
git add docs/superpowers/artifacts/2026-04-23-database-cache-optimization-rollout.md
git commit -m "docs: finalize database cache optimization rollout"
```

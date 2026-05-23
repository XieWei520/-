# archive-server

## Repository Snapshot

- Local source: `C:\Users\COLORFUL\Desktop\WuKong\.codex_tmp\wildfirechat\archive-server`
- Branch: `main`
- Commit inspected: `d6c9a74`
- Main parts:
  - Spring Boot archive sync/query service.
  - MySQL and MongoDB source adapters.
  - ClickHouse archive repository.
  - Client-facing query APIs.
  - Health and admin status APIs.
  - ClickHouse initialization SQL.

## Responsibility

`archive-server` is a message archive service for querying historical WildfireChat messages from a ClickHouse archive.

It is not an IM callback service. It reads existing IM message tables from the source database and writes denormalized archive rows into ClickHouse.

Confirmed architecture:

- One sync node with `archive.task.enabled=true`.
- Multiple query nodes with `archive.task.enabled=false`.
- Source database can be MySQL or MongoDB.
- Archive database is ClickHouse.
- Query APIs authenticate users with IM `authCode`.

## Build and Run

Requirements from README:

```text
Java 11+
MySQL 8.0+ or MongoDB
ClickHouse 21.8+
Maven 3.6+
```

Build:

```text
mvn package
```

Initialize ClickHouse:

```text
clickhouse-client -d default < src/main/resources/sql/init-clickhouse.sql
```

Run examples:

```text
java -jar target/wf-message-archive-server-1.0.0.jar --spring.profiles.active=sync
java -jar target/wf-message-archive-server-1.0.0.jar --server.port=8081 --archive.task.enabled=false
```

## Stack

- Java 11.
- Spring Boot `2.7.18`.
- Spring Web.
- Spring Validation.
- Spring JDBC.
- Spring Data MongoDB.
- MySQL Connector/J `8.0.33`.
- ClickHouse JDBC `0.9.7`.
- Caffeine `3.1.8`.
- WildfireChat Java SDK `1.4.4`.
- Gson.
- Lombok.

Startup entry:

```text
cn.wildfirechat.archive.ArchiveApplication.main
```

## Configuration

Default config highlights:

```text
server.port=8088
archive.source-type=mysql
archive.mysql.url=jdbc:mysql://localhost:3306/wfchat...
archive.mongodb.uri=mongodb://wfc:123456@localhost:27017/wfchat
archive.clickhouse.url=jdbc:clickhouse:http://localhost:8123/wfchat
archive.task.enabled=true
archive.task.quiet-time-start=02:00
archive.task.quiet-time-end=01:00
archive.task.batch-size=500
archive.task.batch-interval-ms=1000
archive.task.batches-per-cycle=10
archive.task.sync-history-days=0
archive.task.sync-group-enabled=true
im.admin-url=http://localhost:18080
im.secret=123456
```

`IMConfig` maps:

```text
im.adminUrl
im.secret
```

`AuthFilter` initializes the Java Admin SDK with:

```text
AdminHttpUtils.init(im.adminUrl, im.secret)
```

## ClickHouse Tables

`init-clickhouse.sql` creates:

- `message_archive`: per-user archive rows.
- `archive_progress`: sync progress by source table name.
- `group_message_archive`: group/super-group archive rows.
- `v_sync_progress`: progress view for user-message tables.
- `v_archive_stats`: aggregate progress stats.
- `v_group_sync_progress`: progress view for group-message tables.

`message_archive` uses:

```text
ENGINE = ReplacingMergeTree(_version)
PARTITION BY user_hash
ORDER BY (user_id, message_dt, mid)
```

`group_message_archive` uses:

```text
ENGINE = ReplacingMergeTree(_version)
PARTITION BY group_hash
ORDER BY (gid, conv_line, mid)
```

Both archive tables define a `tokenbf_v1` index on `searchable_key`.

## Sync Flow

```mermaid
sequenceDiagram
  participant Sync as archive-server sync node
  participant Source as IM source DB
  participant CH as ClickHouse

  Sync->>CH: read archive_progress last_mid
  Sync->>Source: scan t_user_messages_N or t_group_messages_N by _mid
  Sync->>Source: batch fetch t_messages_M by mid
  Sync->>Sync: merge user/group row with message content
  Sync->>CH: batch insert archive rows
  Sync->>CH: insert updated archive_progress
```

Source-confirmed MySQL table assumptions:

- `t_user_messages_0` through `t_user_messages_127`.
- `t_group_messages_0` through `t_group_messages_127`.
- `t_messages_0` through `t_messages_35`.

`ArchiveServiceImpl` uses a single-thread executor for sync. It runs cycles only during configured quiet time; outside quiet time it skips the current cycle.

Progress is updated only after ClickHouse write succeeds. If all source rows in a batch have missing message content, progress still advances after recording missing counters.

## Query APIs

Client-facing APIs:

```text
POST /api/messages/fetch
POST /api/messages/search
POST /api/group-messages/fetch
POST /api/group-messages/search
```

Health APIs:

```text
GET /api/health/ping
GET /api/health/check
GET /api/health/detail
GET /api/health/ready
GET /api/health/live
```

Admin/status APIs:

```text
GET /api/admin/status
GET /api/admin/progress
GET /api/admin/running
GET /api/admin/deployment
```

The client API expects:

```text
Header: authCode: <IM auth code>
```

`AuthFilter` validates the auth code with:

```text
UserAdmin.applicationGetUserInfo(authCode)
```

It sets request attribute `userId`, then query logic restricts normal message queries by `user_id`.

## Query Semantics

Normal message fetch/search:

- Filters by authenticated `userId`.
- Optional filters: convType, convTarget, convLine, contentType, startMid, before, limit.
- Single-chat target is adjusted so the client sees the requested opposite user target.
- Search uses `LIKE '%keyword%'` plus second-pass filtering to compensate for ClickHouse index false positives.

Group archive fetch/search:

- Uses `group_message_archive`.
- Requires `convTarget` for fetch.
- Search can target a specific group or all groups.

Important boundary: inspected group query methods read group archive data after only auth-code validation. They do not visibly verify group membership in the controller/service path inspected.

## Source-Confirmed Risks

- README emphasizes a single sync node, and source does not implement distributed lock/election. Running multiple nodes with `archive.task.enabled=true` can duplicate work and increase source/ClickHouse pressure.
- `AuthFilter` is a global `Filter` component in inspected source and does not visibly exclude `/api/health/*` or `/api/admin/*`. If Spring registers it globally, health and admin endpoints will also require `authCode`, contrary to README's "except health check" statement. Verify at runtime before wiring probes.
- `GroupMessageController` obtains authenticated `userId` but calls group query methods without visible membership authorization. Exposing group archive search to normal clients needs an additional permission check.
- `MySQLMessageSource.fetchGroupMessagesByMidRange()` appears to add `endTime` as the parameter for `_dt >= ?` when `startTime > 0`; this looks like a likely typo and should be reviewed before relying on time-window group sync.
- Checked-in defaults contain demo DB/admin credentials and should not be reused.
- Sync runs only during quiet time. The default `02:00` to `01:00` covers most of the day, but deployments should set this intentionally.

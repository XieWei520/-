# docs

## Repository Snapshot

- Local source: `C:\Users\COLORFUL\Desktop\WuKong\.codex_tmp\wildfirechat\docs`
- Branch: `master`
- Commit inspected: `a0b91d7`
- Primary documentation root: `md/`
- Root has no top-level README in the inspected checkout; `md/README.md` and `md/SUMMARY.md` are the main entry points.

## Responsibility

`docs` is the official WildfireChat documentation repository. It is not runtime code, but it is an important validation source for deployment topology, production hardening, API boundaries, and conceptual models.

The inspected documentation confirms the earlier source-level architecture:

- `im-server` is the core IM service.
- `app-server` or a customer business server owns registration/login and exchanges authenticated users for IM tokens through Server/Admin API.
- Client SDKs connect to `im-server` with `userId` and IM token, then handle reconnect and synchronization.
- Push, robot, channel, object storage, AV/Janus, open platform, organization platform, and admin console are optional or adjunct services around the IM core.

## Main Documentation Areas

Important directories and pages inspected or indexed:

```text
md/architecture/README.md
md/quick_start/server.md
md/base_knowledge/connect.md
md/base_knowledge/message.md
md/base_knowledge/storage_and_sync.md
md/server/server_port.md
md/server/server_config.md
md/server/db_config.md
md/server/event_callback.md
md/server/oss.md
md/server/oss_bucket.md
md/server/admin_api/README.md
md/server/admin_api/conference_api.md
md/server/robot_api/README.md
md/server/channel_api/README.md
md/blogs/IM服务安全防护指南.md
md/blogs/上线检查事项.md
md/blogs/野火音视频高级版的一些知识.md
md/blogs/音视频高级版的单端口化和强制TCP化.md
```

The repository also includes client integration docs, WebRTC/TURN tools, websocket test tooling, FAQ pages, open-platform docs, commercial server notes, performance-test docs, privacy/agreement docs, and many operational blog posts.

## Official Architecture Confirmations

The architecture page describes these components:

- Client SDK has a functional protocol layer plus UI SDK layer.
- Application client is demo/application UI on top of SDK.
- Application server handles registration/login and obtains IM tokens from IM service.
- IM service handles IM, groups, optional hosted user info, and optional hosted friend relationships.
- Push service receives push tasks from IM and dispatches to APNS, Huawei, Xiaomi, and other vendor channels.
- Robot service receives robot messages and replies through IM.
- Object storage stores images, voice, video, files, portraits, group portraits, moments resources, and favorites.
- AV requires TURN service or WildfireChat advanced AV service.
- Open platform, daily-report demo, management console, channel service, and organization service are surrounding systems.

The docs explicitly describe `app-server` and several application/client repos as demo or reference implementations, while treating SDKs and the IM service as the stable core.

## Ports and Network Boundary

The server-port documentation splits ports into external and internal groups:

- Native clients use IM `80` for HTTP and `1883` for TCP/MQTT.
- Web and mini-program clients use IM `80` for HTTP and `8083` for WebSocket; production HTTPS/WSS deployments commonly add `443`.
- Robot API and Channel API use IM public HTTP, normally `80` or `443`.
- Server/Admin API is internal-only, default `18080`, and has highest privilege.

Important production implication: `18080` must not be reachable from the public Internet. Only trusted business services such as `app-server`, push/object-storage integrations, admin tooling, or other internal backends should reach it.

## Server Configuration

Key official configuration guidance:

- Set `server.ip`, `http_port`, `port`, and `websocket_port`; `server.ip` must be a reachable public/LAN address or domain, not `127.0.0.1` or `localhost`.
- The docs state `80` should not be changed for the standard client deployment path.
- Change `http.admin.secret_key` everywhere that calls Server/Admin API.
- Change `token.key`; it is used by the server to generate and verify IM tokens and is not a client secret.
- Configure object storage through the `media.*` settings.
- Configure callback URLs for message forwarding, user online state, group info/member changes, relation changes, and user info changes as needed.
- Configure JVM heap in `bin/wildfirechat.sh`; the docs warn that leaving default JVM memory can waste memory or cause OOM.

## Database Guidance

The DB page confirms:

- H2 is for quick trials and very small deployments only.
- Community edition supports H2 and MySQL.
- Professional edition supports more relational databases and can combine relational DB with MongoDB for message/user message storage.
- MySQL should be 5.7+ with `utf8mb4`; MySQL 8 is recommended over 5.7.
- MySQL transaction isolation should be changed to `READ COMMITTED` to avoid high-pressure transaction timeout issues.
- Flyway manages table creation/migration for supported databases except some professional-edition databases that require dedicated scripts.
- Production should size DB connection limits by `c3p0` max connections times IM node count.
- MySQL backups need `--hex-blob` because some stored data is binary.

This validates the earlier note that H2 is not a production database for WildfireChat.

## Admin, Robot, and Channel APIs

Official API boundary:

- Server/Admin API:
  - `POST` only.
  - JSON request body, not query-string parameters.
  - Headers are lowercase `nonce`, `timestamp`, and `sign`.
  - Signature is `sha1(nonce + "|" + SECRET_KEY + "|" + timestamp)`.
  - `timestamp` is milliseconds.
  - Requests outside the allowed time window are rejected unless the debug-time check is disabled.
  - Response shape is `{ code, msg, result }`.

- Robot API:
  - Uses public IM HTTP port, not `18080`.
  - Adds `rid` header.
  - Uses robot-specific secret.
  - Can send/update/recall/reply messages, read robot/user info, set callback URL, and send conference requests.

- Channel API:
  - Uses public IM HTTP port, not `18080`.
  - Adds `cid` header.
  - Uses channel-specific secret.
  - Can send channel messages, manage profile/menu/callback, subscribe/unsubscribe users, query subscribers, recall and republish messages.

The docs reinforce that Admin API secrets belong only in backend services. Robot and channel secrets are lower-privilege than Admin API but still production credentials.

## Events and Callbacks

The event callback page documents:

- Message receive/forward callback.
- User online/offline callback.
- Group info changes.
- Group member changes.
- User relation changes.
- User info changes.
- Channel subscription changes.
- Chatroom join/exit.
- Conference lifecycle callbacks: create, destroy, join, leave, publish, unpublish.

Important operational warning from the docs: IM uses a single-threaded push path for event callbacks; slow receiver services can delay callbacks and drag IM performance. Callback receivers should be in the same internal network when possible, handle work asynchronously, and return quickly.

## Object Storage Model

Official object-storage guidance:

- Media messages upload files to object storage first, then send a message containing the URL.
- Community edition supports built-in storage and Qiniu.
- Professional edition supports Aliyun OSS, Tencent COS, Huawei OBS, AWS S3, JD Cloud/compatible S3, WildfireChat private storage, and the WildfireChat object-storage gateway.
- The built-in storage is only for quick validation/development and does not support commercial object-storage features or HTTPS.
- Web deployments need object-storage CORS configuration.
- If Web IM uses HTTPS, object storage must support HTTPS downloads.
- Docs repeatedly warn not to force HTTPS for some standard mobile/PC upload paths because protocol stacks may upload with HTTP while data is encrypted.

Bucket categories map to SDK media types:

```text
0 GENERAL
1 IMAGE
2 VOICE
3 VIDEO
4 FILE
5 PORTRAIT
6 FAVORITE
7 STICKER
8 MOMENTS
```

The docs recommend separating long-lived resources such as portraits/favorites from short-lived chat media, and ideally using separate buckets for each media type.

## AV and Conference Guidance

The advanced AV docs confirm:

- WildfireChat advanced AV is SFU-based.
- The AV service forwards media streams and does not mix streams server-side.
- IM service owns AV signaling, so advanced AV is deeply coupled to the professional IM signaling stack.
- Products can include 1:1 calls, multi-party calls, audio rooms, meetings, live interaction, and online classrooms.
- `AVEngineKit` is the global AV entry point and `CallSession` represents the current call/meeting session.
- Meetings have publisher/anchor and audience concepts. Capacity pressure depends heavily on number of publishers and number of subscribed streams.
- Complexity is roughly `O(M x N)` where `M` is publisher count and `N` is total users.
- Large/small video streams and manual stream subscription are important optimization tools.
- Super conference spreads published streams across multiple AV servers so a single room can use cluster-wide capacity.
- `audioOnly` and `advance` must be consistent between meeting creation and joining.
- Recording stores per-publisher streams, commonly audio/large-video/small-video, then post-processing converts Janus `.mjr` files and combines media with ffmpeg.

Single-port and forced-TCP AV deployment:

- Implemented through TURN relay in front of Janus.
- Janus can be internal-only while TURN exposes TCP/UDP `3478`.
- Forced TCP is done by adding `?transport=tcp` to TURN URI.
- The docs warn TCP mode is only suitable when high-quality network conditions exist; UDP remains the default best fit for real-time media.

## Production Hardening Checklist

Official security and launch docs add these non-negotiable production controls:

- Do not expose `18080` to the public Internet.
- Change `http.admin.secret_key`; suggested production length is at least 32 characters.
- Keep `http.admin.no_check_time=false` in production.
- Change `token.key`.
- Close or hide version probing with `http.close_api_version=true`.
- Consider encrypted configuration via `secret_key_encrypt`.
- Consider encrypted message content storage with `message.encrypt_message_content=true` and disabling remote search.
- Enable TLS when compliance requires it.
- Restrict dangerous client-side operations and move them into business-server-reviewed Server API flows:
  - user search,
  - friend requests,
  - group operations,
  - sensitive message types,
  - stranger chat,
  - sensitive user properties.
- Prefer UUID-style IDs (`id.use_uuid=true`) to reduce enumeration risk.
- IM server should be deployed independently and not mixed with unrelated services.
- Community edition should avoid nginx in front of IM because long/short connection behavior is complex; professional edition has separate nginx guidance.
- Use a separate app database; do not put app-server tables in the IM database.
- Remove or harden `sms.super_code` in `app-server`.
- Client should call `connect` only once after app start; the SDK owns reconnect and network transitions.
- On `keymismatch`, `tokenincorrect`, or `logout`, clients should return to login.
- Client tokens are sensitive and should be stored more securely than default SharedPreferences/NSUserDefaults when possible.

## Notes for This Analysis

The official docs validate these existing project notes:

- `im-server` should be treated as core infrastructure; business customization should prefer Admin API, callbacks, robots, channels, custom messages, or app-server-side logic.
- `app-server` is a demo/reference business server, not an architectural requirement if a customer already has their own business backend.
- Admin API is high privilege and must stay internal.
- Robot and channel APIs are intended to be public-internet-capable extension APIs, but their secrets still need credential handling.
- Object storage is part of the media-message send path and must be planned before Web/production launch.
- Advanced AV requires coordinated IM signaling, Janus/AV service, TURN/network ports, and client-side stream control.

Open point: the docs include many more FAQ/blog pages than this pass inspected. Those pages are useful for incident-specific debugging but are not required for the core architecture map.

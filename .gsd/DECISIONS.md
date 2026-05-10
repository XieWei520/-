# DECISIONS

## 2026-05-04: Phase 4 Redis Streams 解耦接口采用 Outbox + Relay

Phase 4 选择方案 C（客户端 + 远端服务端 + 生产部署验证），但生产窗口只有 1-5 分钟。Redis Streams 解耦采用 Outbox + Relay，而不是直接在消息入库后裸 `XADD`，也不是把发消息请求整体改成 Redis 命令队列。

理由：Outbox + Relay 让核心消息持久化和 ACK 语义保持稳定，同时把 push、unread、reaction 等副作用移出发消息接口。Redis 短暂不可用时，outbox 保留待投递事件，恢复后补投；消费者用 `event_id` 幂等，失败进入 DLQ。

事件边界：Stream key 为 `im:message:effects:v1`，消费者组为 `push-workers`、`unread-workers`、`reaction-workers`，事件以 `event_id` 作为跨消费者幂等键。

## 2026-05-04: Phase 4 multipart API 保持 /v1/file/multipart/* 兼容增强

分片上传继续使用现有 `/v1/file/multipart/init`、`/part`、`/complete`、`/abort` 路径，不做破坏性改名。增强点通过 additive fields 实现：`fingerprint`、`uploaded_parts`、`expires_at`、part checksum 和真实 HTTP 错误码。

理由：本地 Flutter 客户端和远端 TS/业务 API 已经存在这些路径。保持路径兼容能降低生产切换风险，同时仍能补齐并发 3、8MB 分片、断点续传和服务端校验。

## 2026-05-04: Phase 4 通话 Telemetry 与状态机分离

`CallStateMachine` 只负责状态转换，不做网络上报。新增 Telemetry reporter 订阅状态变化和 LiveKit engine 状态，调用 `POST /v1/extra/call/telemetry`。Telemetry 上报失败不影响通话主流程。

理由：状态机必须可测试、确定、无副作用；Telemetry 是可丢弃/可重试的观测副作用。分离后可以用单元测试覆盖非法转换和失败原因映射，也可以单独限流 telemetry，避免排障系统影响通话体验。
- 2026-05-06: Feishu monitoring next slice will first prove Agent pairing and heartbeat online status with a Dart CLI Windows Agent before implementing Feishu Web message capture. See docs/superpowers/specs/2026-05-06-feishu-agent-pairing-heartbeat-design.md.

## 2026-05-08: Monitor robot/OpenAPI credentials are centralized by platform

Feishu OpenAPI enterprise-app credentials and later DingTalk credentials will be stored once per user/platform in the management system, then referenced by reusable monitor destinations. Monitor routes should reference a destination/channel instead of duplicating AppSecret or webhook secrets per group.

Reason: one AppID/AppSecret can serve many Feishu target groups after the app is authorized and added where required. Centralization supports masked display, test connection, rotation, audit logging, and future multi-platform senders while preserving the current local Agent listener.

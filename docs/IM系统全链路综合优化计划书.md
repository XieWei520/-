


这份优化方案将**计划书1（运维管控与执行优先级）**的“止血与排期逻辑”与**计划书2（代码深挖与极致架构）**的“硬核技术细节”进行了深度融合。

它既是一份给项目经理/技术总监的**排期与风控指南**，也是一份给一线 Flutter/Go 研发的**代码重构说明书**。

---

# IM系统全链路综合优化战略与技术落地白皮书

> **版本日期**：2026-05-02
> **文档受众**：技术总监（把控节奏与风险）、项目经理（排期与门禁）、Flutter 客户端研发（代码重构与性能）、Go 后端与运维（高并发与基建）。
> **核心战略**：先排除高危线上风险（止血） -> 再打散重构客户端单体巨石（治病） -> 深入底层优化性能与存储（强身） -> 最后打磨高级体验与监控（冲刺）。

---

## 0. 执行摘要与当前画像

当前系统已具备 Flutter 多端、Riverpod、WuKongIM、Go 后端、LiveKit 等完整技术栈。**现状不是“缺乏基础”，而是“系统处于危险的亚健康状态”**：
1. **安全与运维危机**：日志明文泄露 Token，Nginx 拦截验证脚本，Coturn 证书配置瘫痪。
2. **客户端单点瓶颈**：`IMService` 是超过 2000 行的“上帝类”，代码极度耦合；Web 端离线存储实质为内存假缓存。
3. **性能隐患**：通话 Fallback 每 2 秒疯狂轮询后端；大量全屏 Riverpod 状态刷新导致大历史会话卡顿。

**不要盲目扩容服务器，资源足够。按以下优先级的融合方案，从止血到重构，逐步打造能支撑十万级会话的工业级 IM。**

---

## Phase 1：生产止血与高危风险解除（P0 级，第 1 周）

*目标：立即排除安全隐患，切断无效的服务端并发，确保基础链路与发布验证可信。*

### 1.1 修复安全与发布链路 (DevOps & Backend)
*   **Token 明文泄露（最高危）**：禁止在日志中打印 `actToken`、`password` 原文。所有校验失败日志必须脱敏，仅输出 `hash前缀`、`UID`、`设备ID` 和 `阶段`。
*   **清理敏感配置**：彻底清查后端生产环境变量（移除写死的测试验证码、管理员密码等），改用 Vault 或环境变量注入。
*   **修复 Nginx 308 拦截**：将发布验证的 `smoke/perf` 脚本请求 Base URL 从 HTTP 修正为 HTTPS，确保每次发布的自动化验证真实可信。

### 1.2 修复 Coturn 音视频基建 (Ops)
*   **解决 TLS/DTLS 不可用**：校正容器内 Coturn 证书私钥的挂载路径和权限，移除报 `bad format` 的不兼容配置项。
*   **验证闭环**：补充 STUN/TURN 连通性测试脚本，通话功能上线前必须证明移动网络下真实 Join 成功。

### 1.3 根治 Fallback HTTP 死亡轮询 (Flutter & Backend)
*   **病灶**：客户端 `CallApi.getPendingCalls` 存在固定的 2 秒轮询，且后端 `fallback=1` 参数语义混乱，导致大量无效 DB 查询。
*   **处方（指数退避策略）**：通话信令必须以 WS / Realtime 为主。仅当 WS 降级超过 6 秒时，启用 HTTP 轮询，并加入指数退避与 Jitter 抖动机制。
```dart
// 客户端指数退避伪代码
Duration nextRetryDelay(int retryCount) {
  final seconds = switch (retryCount) {
    0 => 2,
    1 => 5,
    2 => 15,
    3 => 30,
    _ => 60, // 最大兜底 60s
  };
  return Duration(seconds: seconds);
}
```

---

## Phase 2：客户端 IM 核心重构与状态管理（P1 级，第 2-3 周）

*目标：把 2000 行的 `IMService` 上帝类大卸八块，彻底解决 Flutter 端状态刷新带来的卡顿。*

### 2.1 拆分 `IMService` 巨石
不要一次性全拆，按以下 Riverpod Provider 职责进行切片分离：
1.  **`ConnectionCoordinator`**：负责长连接初始化、前后台生命周期、断网重连。
2.  **`MessageSyncCoordinator`**：负责历史拉取、缺口（Gap）补偿、消息 ACK。
3.  **`CommandDispatcher`**：系统命令（撤回、编辑、踢人）副作用分发，隔离业务逻辑。
4.  **`AttachmentPipeline`**：专门处理富媒体（图片/文件）的上传、重试和断点续传。

### 2.2 Riverpod 状态切片优化（解决大列表卡顿）
*   **病灶**：整个聊天页 `watch` 一个大列表，单条消息的状态（已读/发送中）变化导致百条消息的大面积 `rebuild`。
*   **处方（精确订阅）**：列表仅监听 `identity`，气泡内部自行 `select` 监听专属状态。
```dart
// ❌ 禁止：导致整页重绘
final viewport = ref.watch(chatViewportProvider(session));

// ✅ 推荐：列表只关心 ID，只建骨架
final identities = ref.watch(
  chatViewportProvider(session).select((s) => s.identities),
);

// ✅ 推荐：单条气泡精准监听自己的状态
final status = ref.watch(
  messageSendStatusProvider((session: session, identity: identity)),
);
```

### 2.3 统一消息 Envelope（信封）与出件箱模型
客户端必须建立强一致性的 `message_outbox` 表，并统一字段语义，确保弱网下的绝对幂等。
*   `client_msg_no`：客户端本地生成的幂等 UUID，防重复发送。
*   `server_msg_id` / `message_seq`：服务端确认后的全局唯一标识与绝对排序依据。
*   `order_seq`：客户端本地展示的临时排序顺序。

---

## Phase 3：大历史、底层存储与 Web 突破（P1/P2 级，第 4-6 周）

*目标：证明十万级历史消息下的丝滑体验，让 Web 端彻底摆脱“刷新就丢记录”的残疾状态。*

### 3.1 落地 Web 端 IndexedDB 真缓存
抛弃现有的 `MemoryChatStorage`（500条假缓存），基于 `platform_capabilities.dart` 按平台分离存储仓：
*   构建 `IndexedDbChatStorage`，创建对应的 Object Store：
    *   `messages`：索引包含 `byServerMsgId`、`byClientMsgNo`、`byMessageSeq`。
    *   `conversations` / `messageExtra`。
*   **体验标准**：Web 刷新浏览器、断网重启后，最近会话 100% 可秒开。

### 3.2 桌面端/移动端 SQLite 极致性能
*   **建立高频查询索引**：
    ```sql
    CREATE INDEX IF NOT EXISTS idx_msg_channel_seq ON message(channel_id, channel_type, message_seq DESC);
    ```
*   **Windows 端 Isolate 改造**：SQLite 数据库连接不要在 UI Isolate 中执行。使用 `SendPort`/`ReceivePort` 将大量消息的分页查询、JSON 解析（转为 `TransferableTypedData`）移入后台 Worker Isolate，保证桌面端 UI 满帧运行。

### 3.3 图片内存与 UI Jank（掉帧）控制
*   聊天页图片必须**严格限制解码尺寸**：`CachedMediaImage(width: 180, maxWidth: 360)`，大图不进列表的一级缓存。
*   注册 `SchedulerBinding.instance.addTimingsCallback` 监控 `buildDuration`，超过 8ms 触发 Jank 报警。

---

## Phase 4：服务端解耦与富媒体/通话强化（P2 级，第 7-10 周）

*目标：应对高并发场景，打磨音视频和文件传输的工业级体验。*

### 4.1 Go 服务端：Redis Streams 副作用解耦
当 DAU 上升时，不要让核心发消息接口去处理杂活。使用 Redis Streams 承接异步操作：
*   生产者：消息入库后，发送 Event 到 Stream。
*   消费者组（Consumer Groups）：分为 `push-workers`（推送）、`unread-workers`（未读数）、`reaction-workers`（表情表态同步）。

### 4.2 大文件分片与弱网断点续传
*   关闭 Nginx 的 Request Buffering。
*   建立 `/v1/file/multipart/init` -> `/parts/{part_no}` -> `/complete` 的标准分片上传规范。
*   客户端策略：8MB 分片，并发 3 线程，失败指数退避，App 重启可根据本地 Upload Session 恢复。

### 4.3 音视频 LiveKit 通话状态机补齐
摒弃随意的布尔值判断，建立严谨的通话状态机闭环并上传 Telemetry 日志以便排障：
`idle` -> `ringing` -> `connecting` -> `connected` -> `reconnecting` -> `ended/failed`。
*   失败原因（如：被拒、ICE 穿透失败、Token 无效）必须全部收集，用于在 Dashboard 监控成功率。

---

## Phase 5：视觉体验、监控与长效治理（P3 级，持续进行）

*目标：把 IM 做到“好用”，并建立严格的质量生命线。*

### 5.1 视觉动效体系 (Motion Tokens)
*   统一 `MotionTokens`：规范动画弹性和时间（如 `fast: 120ms`, `normal: 220ms`）。
*   **进场动画**：新消息出现采用轻微向上的位移 + 透明度渐变（不要对历史大列表做整体动画）。
*   **发送按钮**：点击时有 `0.92x` 的弹性缩放（Spring 动画）；发送状态显示时钟 -> 单灰勾 -> 双灰勾 -> 双蓝勾。

### 5.2 质量门禁体系 (CI / CD)
*   **客户端静态分析**：`flutter analyze` 必须零 Error / 零 Warning 才能合并 PR（目前有 64 个 Issue，必须清零）。
*   **服务端 SQL 门禁**：修复 Go 代码中通过字符串拼接 SQL 的注入隐患，改用参数化查询；开启 DB 慢查询日志（>100ms 必须有 Fingerprint 告警）。
*   **自动化验证**：发布生产前，`docker-compose` 配置检查、Nginx 语法的自动化 Test、端到端 Smoke 脚本**三者缺一不可**。

---

## 🚫 治理红线：不建议现在做的事

在 Phase 1-3 未彻底完成、系统未完全收敛前，**严禁开展以下工作**：
1.  **盲目加购服务器/升配**：当前瓶颈在客户端状态管理和网络重试逻辑，加机器不能解决代码死循环。
2.  **强制加入 E2EE (端到端加密)**：E2EE（Signal Double Ratchet）极度复杂，会彻底破坏现有的群聊同步和审核逻辑，架构未稳前不要触碰。
3.  **继续给 `IMService` 加功能**：在没有将其拆分为独立 Coordinator 之前，禁止在这个 2000 行的类中写入任何新特性。
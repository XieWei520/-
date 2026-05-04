# IM 系统全链路综合优化计划书

审查日期：2026-04-27  
审查范围：Flutter 客户端（Android / Windows / Web）、WuKongIM/TangSengDaoDaoServer 服务端、Nginx 边缘层、MySQL/Redis/MinIO/LiveKit/Coturn 生产部署。

## 0. 审查结论摘要

当前系统已经具备可运行的 IM 主链路：客户端基于 Flutter + Riverpod + GoRouter，IM 能力由 `wukongimfluttersdk` 提供；服务端以 Docker Compose 部署 Nginx、WuKongIM、TangSengDaoDao API、MySQL、Redis、MinIO、LiveKit、Coturn。消息同步已经按 `message_seq` 做频道拉取，本地 SQLite 也已经补过 `channel_id/channel_type/order_seq/message_seq` 方向的索引；实时控制协议正在从 JSON 向 protobuf envelope + ack/gap repair 迁移。

真正影响下一阶段增长的瓶颈不在“是否能聊天”，而在“大量历史消息、富媒体、大文件、弱网多端一致性、暴露面治理”这些会把系统推到边界的地方。下面计划按先止血、再重构、最后扩展能力的顺序推进。

## 1. 现状诊断报告：最致命的 5 个瓶颈

### 1.1 文件上传链路存在内存放大与对象存储权限风险

证据：

- 服务端 `/v1/file/upload` 已在 Nginx 关闭请求缓冲，这是正确方向：`/opt/wukongim-prod/src/deploy/production/nginx/default.conf.template:159`。
- 但 Go 侧 MinIO 实现仍在 `ServiceMinio.UploadFile` 中用 `bytes.NewBuffer` 承接完整文件，再 `PutObject`：`/opt/wukongim-prod/src/modules/file/service_minio.go:39`。
- 新建桶时设置的策略包含匿名 `s3:PutObject/DeleteObject`：`/opt/wukongim-prod/src/modules/file/service_minio.go:84`。

风险：

- 100MB 文件并发 50 个时，仅上传缓冲就可能吃掉 5GB 以上内存。
- 匿名写对象存储会把 MinIO 变成可滥用上传入口，风险高于普通性能问题。

优先级：P0。

### 1.2 WS/TCP 暴露面过宽，噪声流量已经进入 WuKongIM 协议层

证据：

- Docker 当前公开 `5100/tcp`、`5200/tcp`，同时 Nginx 也提供 `/ws` 反代到 `wukongim:5200`。
- WuKongIM 日志已经出现 HTTP 请求打到原生 TCP 协议端口的情况，例如 `frameType is not CONNECT`。
- Nginx 对扫描路径和登录有 `limit_req`，但 `/ws` 和直连 `5200/5100` 的策略还需要收口：`/opt/wukongim-prod/src/deploy/production/nginx/default.conf.template:110`。

风险：

- 扫描流量持续进入协议解析层，带来无意义 CPU/日志 IO。
- 直连端口绕过统一 TLS、鉴权、限流、观测与封禁策略。

优先级：P0。

### 1.3 本地历史消息与搜索能支撑当前规模，但还不能支撑十万级会话历史

证据：

- SDK 已有覆盖索引迁移：`assets/202604111000.sql`、`assets/202604251100.sql`。
- SDK 初始化数据库时没有配置 WAL、`synchronous=NORMAL`、`busy_timeout`：`C:\Users\COLORFUL\Desktop\TangSengDaoDao\WuKongIMFlutterSDK-master\lib\db\wk_db_helper.dart:23`。
- 本地全文检索仍是 `%LIKE%`：`C:\Users\COLORFUL\Desktop\TangSengDaoDao\WuKongIMFlutterSDK-master\lib\db\message.dart:1272`。
- 拉取一页消息后，reaction、成员、发送人信息装配使用多层循环：`C:\Users\COLORFUL\Desktop\TangSengDaoDao\WuKongIMFlutterSDK-master\lib\db\message.dart:319`。

风险：

- 十万级消息时，LIKE 搜索会退化为表扫描。
- Windows sqflite FFI 和移动端 sqflite 如果在 UI isolate 上做大查询/大反序列化，会造成明显卡顿。

优先级：P0/P1。

### 1.4 实时控制协议迁移已经起步，但还需要完整的上线门禁与事件模型边界

证据：

- 客户端默认倾向 protobuf 控制协议：`C:\Users\COLORFUL\Desktop\WuKong\lib\service\im\im_service.dart:67`。
- 服务端已有 protobuf envelope：`/opt/wukongim-prod/src/pkg/rtproto/realtime.proto:7`。
- 服务端 Redis ZSet 支持 `pull_after_seq` 与 ack trim：`/opt/wukongim-prod/src/modules/user/api_session_delta.go:301`、`/opt/wukongim-prod/src/modules/user/api_session_compat.go:200`。
- 客户端有 gap repair 与退避重连：`C:\Users\COLORFUL\Desktop\WuKong\lib\realtime\session\session_runtime.dart:184`。

风险：

- 当前实时控制更像“设备会话事件通道”，还没有被统一为所有 IM 控制事件的稳定总线。
- envelope 缺少一等字段 `event_id/aggregate_id/schema_version`，现在部分字段塞在 payload 里，不利于去重、审计和灰度回滚。

优先级：P1。

### 1.5 Flutter UI 层已经有优化痕迹，但还存在可预测的线性重建热点

证据：

- 聊天列表用了 `ListView.builder(reverse: true, cacheExtent: 1200)`：`C:\Users\COLORFUL\Desktop\WuKong\lib\modules\chat\chat_page_shell.dart:1506`。
- 消息合并已经从 `indexWhere` 改成 `ChatMessageMatchIndex` 哈希索引：`C:\Users\COLORFUL\Desktop\WuKong\lib\data\providers\conversation_provider.dart:1005`。
- 但 viewport controller 的 `_findExistingIndex` 仍使用 `items.indexWhere`：`C:\Users\COLORFUL\Desktop\WuKong\lib\modules\chat\chat_viewport_controller.dart:259`。
- 图片缓存已有 L1/L2 思路，但 L1 按条目数限制而不是按估算字节限制：`C:\Users\COLORFUL\Desktop\WuKong\lib\core\cache\media_cache_manager.dart:21`。

风险：

- 高速收发、reaction 刷新、长列表定位消息时，UI 层仍会出现可见抖动。
- 低内存 Android 设备容易被大图 decoded cache 压垮。

优先级：P1。

## 2. 五大维度详细优化方案

## 2.1 架构优化

### 2.1.1 前后端通信协议：长连接 + 短连接职责拆清

目标模型：

- 长连接：只承载实时事件通知、轻量命令、在线状态、typing、设备踢下线、通话信令唤醒。
- 短连接：承载历史拉取、消息补洞、文件上传、搜索、资料同步、管理接口。
- 本地落库：客户端收到长连接事件后，只做“拉取/补洞触发”，最终以 HTTP 拉取结果落库，避免长连接消息和 HTTP 消息双写冲突。

推荐消息 ID 语义：

| 字段 | 作用 | 生成方 | 约束 |
| --- | --- | --- | --- |
| `client_msg_no` | 客户端幂等发送键 | 客户端 | 同一账号内全局唯一，重试不变 |
| `message_id` | 服务端全局消息 ID | 服务端 | 雪花/号段，唯一 |
| `message_seq` | 频道内严格递增序号 | WuKongIM | `(channel_id, channel_type, message_seq)` 唯一 |
| `order_seq` | 本地 UI 排序键 | 客户端 SDK | `message_seq * factor + local_offset` |
| `session_event_seq` | 设备会话控制事件序号 | API/Redis | 单设备会话递增 |

服务端协议建议：

```protobuf
message RealtimeEnvelope {
  uint64 event_seq = 1;
  string event_type = 2;
  bytes payload = 3;
  uint64 ack_seq = 4;
  string device_id = 5;
  uint64 issued_at_ms = 6;
  string event_id = 7;
  string aggregate_id = 8;
  uint32 schema_version = 9;
}
```

客户端处理原则：

```dart
Future<void> handleRealtimeEvent(RealtimeEvent event) async {
  if (event.seq <= localAckStore.lastAckedSeq(event.sessionId)) return;

  await gapRepairIfNeeded(event.seq);
  switch (event.type) {
    case 'message.new':
      await messageRepository.syncChannel(event.channelId, event.channelType);
    case 'message.extra.changed':
      await messageRepository.syncExtras(event.channelId, event.channelType);
    case 'device.invalidated':
      await authRepository.forceLogoutCurrentSession();
  }
  await gateway.ack(event.seq);
}
```

落地动作：

- 服务端在 `pkg/rtproto/realtime.proto` 增加字段，保留原字段兼容。
- `modules/realtime/control_stream.go` 同时读写新旧 envelope，灰度阶段用 `schema_version` 区分。
- `/v1/realtime/session/events/pull_after_seq` 返回带 `event_id` 的结构，客户端本地用 `(session_id,event_id)` 去重。
- 用环境变量控制 protobuf 百分比灰度，当前已有 `WK_REALTIME_PROTO_ROLLOUT_SPEC_JSON` 基础，可继续沿用。

### 2.1.2 边缘与端口架构：所有公网入口收敛到 443

目标：

- 公网只开放 `80/443`、通话必要的 LiveKit/Coturn UDP/TCP。
- WuKongIM `5100/5200` 改为内网 Docker network 可达，移动端和 Web 统一走 `wss://domain/ws`。
- 如果 Android 原生 TCP 必须保留，至少用安全组 allowlist 或独立域名 + TLS + 连接速率限制。

Nginx `/ws` 加固示例：

```nginx
limit_req_zone $binary_remote_addr zone=ws_limit:10m rate=60r/m;

location = /ws {
    limit_req zone=ws_limit burst=30 nodelay;
    proxy_pass http://wukongim_ws/;
    proxy_http_version 1.1;
    proxy_read_timeout 3600s;
    proxy_send_timeout 3600s;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection $connection_upgrade;
    proxy_set_header X-Real-IP $remote_addr;
}
```

### 2.1.3 Flutter 状态管理：Repository 与 UI 明确分层

当前 `IMService` 同时负责 SDK 初始化、生命周期、会话运行时、命令副作用、离线同步。建议拆成四层：

| 层 | 职责 | 示例 |
| --- | --- | --- |
| `Transport` | HTTP、WS、签名、重试 | `WkHttpClient`、`SessionEventGateway` |
| `Repository` | 消息、会话、文件、搜索 | `MessageRepository` |
| `Application Controller` | 业务流程编排 | `IMService`、`ChatComposerController` |
| `Presentation` | ViewModel 与组件 | `ChatViewportController` |

Riverpod 局部监听示例：

```dart
final chatUnreadProvider = Provider.family<int, ChatSession>((ref, session) {
  return ref.watch(
    conversationProvider.select((items) {
      final index = items.indexWhere(
        (item) => item.channelID == session.channelId &&
            item.channelType == session.channelType,
      );
      return index == -1 ? 0 : items[index].unreadCount;
    }),
  );
});
```

消息列表建议：

- `MessageListNotifier` 只维护 `List<WKMsg>` 与分页状态。
- `ChatViewportController` 维护 `List<ChatMessageViewModel>` 与 `identityToIndex`。
- `_findExistingIndex` 改为查 `identityToIndex`，只有身份规则变化时重建索引。

### 2.1.4 多端架构解耦：用 Platform Adapter 替代散落判断

目标：

- Android、Windows、Web 共享 `MessageRepository`、`ConversationRepository`、`FileRepository` 接口。
- 平台差异只存在于 adapter：文件选择、拖拽、通知、音频会话、SQLite/IndexedDB、系统托盘。

接口示例：

```dart
abstract interface class PlatformCapabilities {
  bool get supportsLocalSqlite;
  bool get supportsSystemTray;
  bool get supportsDragDrop;
  bool get supportsBrowserNotification;
}

abstract interface class LocalMessageStore {
  Future<List<WKMsg>> loadPage(MessagePageQuery query);
  Future<void> upsertMessages(List<WKMsg> messages);
  Stream<MessagePatch> watchPatches(ChatSession session);
}
```

平台导入建议：

```dart
import 'local_message_store_stub.dart'
    if (dart.library.io) 'local_message_store_sqlite.dart'
    if (dart.library.html) 'local_message_store_web.dart';
```

注意：`PlatformUtils` 当前直接 `import 'dart:io'`，建议改成 `kIsWeb/defaultTargetPlatform` + 条件导入，降低 Web 构建风险。

### 2.1.5 本地存储策略：SQLite 分层、FTS、冷热数据

目标：

- 最近 3 个月消息保留在主 `message` 表。
- 搜索走 `message_fts`。
- 冷历史可压缩归档到单独表或文件，再按会话懒加载。

SQLite 初始化建议：

```dart
_database = await openDatabase(
  path,
  version: dbVersion,
  onConfigure: (db) async {
    await db.execute('PRAGMA journal_mode=WAL');
    await db.execute('PRAGMA synchronous=NORMAL');
    await db.execute('PRAGMA busy_timeout=3000');
    await db.execute('PRAGMA temp_store=MEMORY');
  },
);
```

FTS 迁移示例：

```sql
CREATE VIRTUAL TABLE IF NOT EXISTS message_fts USING fts5(
  message_id UNINDEXED,
  channel_id UNINDEXED,
  channel_type UNINDEXED,
  searchable_word,
  content_edit,
  tokenize='unicode61'
);

CREATE TRIGGER IF NOT EXISTS trg_message_fts_insert
AFTER INSERT ON message BEGIN
  INSERT INTO message_fts(message_id, channel_id, channel_type, searchable_word)
  VALUES (new.message_id, new.channel_id, new.channel_type, new.searchable_word);
END;
```

搜索查询替换：

```sql
SELECT m.*
FROM message_fts f
JOIN message m ON m.message_id = f.message_id
WHERE f.message_fts MATCH ?
  AND f.channel_id = ?
  AND f.channel_type = ?
ORDER BY m.order_seq DESC
LIMIT ?;
```

## 2.2 性能极致调优

### 2.2.1 Flutter Android：列表、图片、键盘三件套

列表：

- 保持 `ListView.builder(reverse: true)`，但 load more 触发从 `pixels == maxScrollExtent` 改为 `extentAfter < 300`，避免浮点相等错过触发。
- `cacheExtent` 从固定 1200 改成按设备内存档位动态配置：低端 600，中端 1000，高端 1600。
- `ChatViewportController._findExistingIndex` 改成 O(1) identity lookup。

图片：

- L1 缓存从 200 条改成按估算 decoded bytes 限制，例如 32MB。
- 缩略图 URL 和原图 URL 分离，聊天列表只解码缩略图。
- `CachedNetworkImage` 的 `memCacheWidth/memCacheHeight` 根据 DPR 与气泡约束计算。

示例：

```dart
final targetWidthPx = (bubbleWidth * MediaQuery.devicePixelRatioOf(context))
    .round()
    .clamp(240, 720);
```

键盘：

- Android 聊天页外层使用 `AnimatedPadding` 绑定 `MediaQuery.viewInsets.bottom`。
- Composer 面板和软键盘互斥时统一走一个 `ChatInputPanelState`，避免 emoji 面板/键盘切换闪烁。

### 2.2.2 Windows：FFI 与数据库读写不要阻塞 UI

问题点：

- sqflite_common_ffi 本质是 FFI 调用；单页查询不大时没问题，但十万级消息搜索、备份恢复、批量导入会卡 UI。

落地：

- 新增 `MessageDbWorker`，批量解析/搜索/备份恢复走后台 isolate。
- SDK 的 `queryMessages` 装配阶段将 reaction/member/channel 映射从双层循环改为 Map。

装配优化示例：

```dart
final reactionsByMessageId = <String, List<WKMsgReaction>>{};
for (final reaction in reactions) {
  (reactionsByMessageId[reaction.messageID] ??= <WKMsgReaction>[]).add(reaction);
}

for (final msg in msgList) {
  msg.reactionList = reactionsByMessageId[msg.messageID] ?? const [];
}
```

后台执行示例：

```dart
final result = await Isolate.run(() {
  return messageArchiveParser.parseAndValidate(snapshotBytes);
});
```

### 2.2.3 Web：首屏体积、缓存、离线体验

现状：

- `web/manifest.json` 已存在，说明 PWA 基础具备。
- Nginx 对 CanvasKit 有长缓存策略。
- Web 消息历史在 `WkImChatHistoryGateway` 走直接远程同步：`C:\Users\COLORFUL\Desktop\WuKong\lib\data\providers\chat_history_gateway.dart:87`。

优化：

- Flutter Web 构建拆两套：普通用户优先 `--wasm`/`skwasm`，低兼容性浏览器回退 CanvasKit。
- `main.dart.js` 保持短缓存，`assets/canvaskit/*` 长缓存并 CDN 化。
- Web 端增加 IndexedDB 轻量消息页缓存，只缓存最近 N 个会话和每会话最近 200 条，避免刷新后完全依赖远程。

缓存键建议：

```text
message_page:{uid}:{channel_type}:{channel_id}:{start_seq}:{end_seq}
```

### 2.2.4 后端并发与延迟

数据库：

- MySQL 当前已有 `(channel_id, channel_type, message_seq)` 方向索引，应继续在每个分表保持一致。
- 给 `message_extra`、`reaction_users`、`conversation_extra` 的版本同步接口增加固定 EXPLAIN 检查。
- 慢查询阈值已是 `0.2s`，建议接入 Prometheus exporter 后按接口维度统计 p95/p99。

服务端响应装配：

- `newSyncChannelMessageResp` 中 reply payload 解析两遍，并且 reply extra 查找是消息数 × extra 数的线性扫描。
- 改成一次解析 + Map 查找；所有 `replyJson.(map[string]interface{})["message_id"].(string)` 改成安全读取，避免脏 payload panic。

Go 示例：

```go
extraByID := make(map[string]*messageExtraDetailModel, len(messageExtras))
for _, item := range messageExtras {
    extraByID[item.MessageID] = item
}

if reply, ok := payloadMap["reply"].(map[string]interface{}); ok {
    if id, ok := reply["message_id"].(string); ok {
        if extra := extraByID[id]; extra != nil {
            // apply edited reply payload
        }
    }
}
```

文件上传流式化：

```go
type UploadObject struct {
    Path        string
    ContentType string
    Size        int64
    Reader      io.Reader
}

func (sm *ServiceMinio) UploadObject(ctx context.Context, obj UploadObject) (map[string]any, error) {
    info, err := sm.client.PutObject(
        ctx,
        bucketName,
        objectName,
        obj.Reader,
        obj.Size,
        minio.PutObjectOptions{
            ContentType: obj.ContentType,
            PartSize: 10 * 1024 * 1024,
        },
    )
    return map[string]any{"path": info.Key}, err
}
```

削峰：

- 当前规模不必马上引 Kafka。
- 第一阶段用 Redis Streams 承载低频控制事件、文件转码任务、通知任务。
- 当单日消息量超过千万或群广播明显成为瓶颈，再引 Kafka/Pulsar 做消息 fanout 与审计流。

## 2.3 体验升级

### 2.3.1 Windows 桌面体验

优先能力：

- `Enter` 发送，`Shift+Enter` 换行。
- 右键消息菜单使用桌面风格 `showMenu`，移动端继续 bottom sheet。
- 文件/图片拖拽进入聊天窗口直接发送或进入预览队列。
- 系统托盘、未读角标、多窗口会话保活。

快捷键示例：

```dart
Shortcuts(
  shortcuts: {
    LogicalKeySet(LogicalKeyboardKey.enter): const SendMessageIntent(),
    LogicalKeySet(LogicalKeyboardKey.shift, LogicalKeyboardKey.enter):
        const InsertNewlineIntent(),
  },
  child: Actions(
    actions: {
      SendMessageIntent: CallbackAction(onInvoke: (_) => controller.send()),
      InsertNewlineIntent: CallbackAction(onInvoke: (_) => controller.newline()),
    },
    child: ChatComposer(...),
  ),
);
```

### 2.3.2 Web 体验

优先能力：

- 浏览器通知：登录后请求权限，后台收到 `message.new` 控制事件时显示通知。
- PWA：manifest 已有，补充 service worker 离线页、图标 maskable 校验、安装提示。
- 弱网提示：WebSocket 降级超过 10 秒显示“正在重连”，同时允许继续写草稿。

### 2.3.3 Android 体验

优先能力：

- 输入框、语音按钮、发送按钮触控热区不低于 48dp。
- 沉浸式状态栏和导航栏颜色跟随聊天背景。
- 图片选择、录音、文件发送都要有权限失败的可恢复反馈。
- 软键盘弹出时禁止整页重建，只动画 composer 区域。

### 2.3.4 核心 IM 体验：弱网假发送与恢复重发

发送状态机：

```text
draft -> local_pending -> uploading_media -> sending -> sent
                                   |           |
                                   v           v
                              upload_failed  send_failed -> retrying -> sent
```

落地：

- `client_msg_no` 在第一次点击发送时生成，并持久化到 SQLite。
- 失败重试复用同一个 `client_msg_no`，服务端按该字段幂等。
- 客户端启动后扫描 `status=sendLoading` 且超过 60 秒的消息，置为可重试。
- 多端同步时以服务端 `message_id/message_seq` 覆盖本地 pending 状态。

已读/未读：

- 会话维度使用 `conversation_extra.version` 增量同步。
- 消息维度使用 `message_extra.extra_version` 增量同步。
- UI 不直接相信本地临时 read 状态，最终以服务端版本为准。

## 2.4 能力扩展

### 2.4.1 大文件分片上传与断点续传

服务端新增表：

```sql
CREATE TABLE file_upload_session (
  upload_id VARCHAR(64) PRIMARY KEY,
  uid VARCHAR(64) NOT NULL,
  object_key VARCHAR(512) NOT NULL,
  total_size BIGINT NOT NULL,
  chunk_size INT NOT NULL,
  uploaded_chunks JSON NOT NULL,
  status TINYINT NOT NULL DEFAULT 0,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);
```

API：

- `POST /v1/file/multipart/init`
- `PUT /v1/file/multipart/{upload_id}/chunks/{index}`
- `POST /v1/file/multipart/{upload_id}/complete`
- `DELETE /v1/file/multipart/{upload_id}`

客户端：

- 小于 20MB 继续普通上传。
- 大于 20MB 使用分片，分片大小 5MB/10MB。
- SQLite/Hive 记录上传会话，断网后恢复。

### 2.4.2 语音/视频通话

现状：

- 依赖已包含 `flutter_webrtc`、`livekit_client`。
- 服务端已运行 LiveKit、Coturn、callgateway。

优化：

- 通话信令走短连接创建房间，实时事件只推 `call.invited/call.cancelled/call.ended`。
- Android 后台来电走 FCM/本地通知补偿。
- Web 端处理浏览器 autoplay/mic permission 失败路径。
- Windows 端增加音频设备切换和回声消除配置 UI。

### 2.4.3 E2EE 端到端加密

建议采用分阶段架构：

- Phase A：只做私聊 E2EE，群聊仍普通加密传输。
- Phase B：小群 Sender Key。
- Phase C：多端密钥备份与新设备安全迁移。

消息结构：

```json
{
  "type": "e2ee.v1",
  "ciphertext": "...",
  "sender_key_id": "...",
  "device_id": "...",
  "prekey_id": "...",
  "content_hint": "text"
}
```

服务端原则：

- 服务端只保存密文 payload、路由字段、撤回/删除/已读等 metadata。
- 搜索、敏感词、机器人处理对 E2EE 消息不可用，产品层需要明确标识。

### 2.4.4 高阶消息能力底层结构

建议统一消息扩展结构：

```json
{
  "reply": {"message_id": "...", "message_seq": 123, "preview": "..."},
  "mentions": [{"uid": "u_x", "offset": 0, "length": 4}],
  "reactions": [{"emoji": "👍", "uid": "u_x", "seq": 9}],
  "edit": {"version": 2, "edited_at": 1710000000},
  "recall": {"revoker": "u_x", "revoked_at": 1710000100}
}
```

数据库策略：

- `message` 存 immutable 原始消息。
- `message_extra` 存撤回、编辑、置顶、已读、全局扩展版本。
- `message_user_extra` 存个人删除、个人收藏、个人标记。
- `reaction_users` 存 reaction 明细。
- `mention_index` 可新增，提升“@我”检索。

## 2.5 动效与视觉表现

### 2.5.1 微交互

发送按钮：

- 文本为空时轻透明不可用。
- 输入内容后 spring scale 从 0.92 到 1.0。
- 点击发送时转为 180ms progress morph，发送成功恢复。

Flutter 示例：

```dart
AnimatedScale(
  scale: canSend ? 1.0 : 0.92,
  duration: const Duration(milliseconds: 180),
  curve: Curves.easeOutBack,
  child: SendButton(...),
);
```

消息气泡：

- 新消息插入：Y 方向 8px -> 0，opacity 0 -> 1。
- 本人发送 pending：气泡尾部加轻微 pulse，不要全气泡闪烁。
- 发送失败：状态图标短促 shake，一次即可。

Reaction：

- 点击 emoji 后使用 `ScaleTransition + FadeTransition`。
- 对已有 reaction 累加时只动画 reaction chip，不重建整条消息。

### 2.5.2 页面转场

Android：

- 会话列表进聊天页使用 Material shared axis 或 fade-through。
- 图片查看使用 Hero，已有 `chatImageHeroTag` 可继续扩展。

Windows：

- 侧边栏/会话详情尽量无大幅位移，使用 120ms fade + content slide 8px。
- 右键菜单、弹窗遵循桌面即时反馈，不使用移动端大 bottom sheet。

Web：

- 首屏和会话切换避免重动画；更重视响应速度和可复制链接。

### 2.5.3 骨架屏与 Loading

历史消息加载：

- 首次进入会话：显示 8 条气泡骨架，左右随机宽度但高度稳定。
- 上拉历史：列表顶部显示细条 loading，不阻断当前阅读。
- 搜索结果：显示三行 skeleton + 命中词位置占位。

避免点：

- 不要整页 `CircularProgressIndicator`。
- 不要在弱网时清空已有消息。
- 不要在加载更多时改变已有消息 key。

## 3. 分期执行路线图

## Phase 1：Quick Wins（一周内）

目标：消除 P0 风险，建立性能基线，完成低成本高回报优化。

任务：

1. 端口收口：生产安全组/Docker 暴露只保留 `80/443` 与通话必要端口，`5100/5200` 改内网或 allowlist。
2. `/ws` 限流：Nginx 增加 `ws_limit`，并为异常握手记录独立 access log。
3. MinIO 权限修复：桶策略去掉匿名 `PutObject/DeleteObject`，上传只允许服务端凭证写入，下载用只读公开或 presigned URL。
4. 上传流式化：改 `ServiceMinio.UploadFile`，避免完整文件进内存；普通上传先做到 `multipart.FileHeader.Size + io.Reader` 直传。
5. SQLite 初始化：在 `WKDBHelper.init` 加 WAL、`synchronous=NORMAL`、`busy_timeout`。
6. SDK 装配优化：`queryMessages` 中 reaction/member/from channel 用 Map 归并，去掉 N×M 循环。
7. Viewport O(1) upsert：`ChatViewportController` 使用 `identityToIndex` 查找，避免 `indexWhere`。
8. 监控基线：记录聊天页首屏、SQLite page query p95、WS reconnect、control decode error、上传内存峰值。
9. Certbot 纳入告警：当前 `certbot.service` 在 2026-04-27 12:07 CST 最近一次成功，但仍建议加到运维告警，避免证书续期静默失败。

验收指标：

- 100MB 文件上传时 API 容器 RSS 峰值不超过上传前 + 80MB。
- `/ws` 异常扫描不再进入 WuKongIM 直连端口。
- 50 条消息分页查询 p95 小于 30ms（本地中端设备）。
- 连续 200 条 reaction 刷新无明显掉帧。

## Phase 2：Core Refactoring（2-4 周）

目标：完成协议、存储、平台层的核心重构，让系统稳定支撑十万级历史消息与多端漫游。

任务：

1. Realtime envelope v2：增加 `event_id/aggregate_id/schema_version`，客户端和服务端双协议兼容。
2. 事件总线扩展：把 `message.new/message.extra.changed/conversation.changed/call.invited` 纳入 session event 模型。
3. ACK/gap repair 完整灰度：按设备、平台、版本分 cohort，失败自动回退 JSON/HTTP polling。
4. FTS5 搜索：新增 `message_fts`，搜索从 LIKE 切到 MATCH；迁移期间双写双读校验。
5. Repository 重构：抽出 `MessageRepository/FileRepository/SearchRepository/PlatformCapabilities`。
6. Web IndexedDB 近端缓存：最近会话和最近消息页缓存，刷新后可秒开。
7. Windows DB worker：批量导入、搜索、备份恢复走 isolate/worker。
8. 服务端响应装配优化：`newSyncChannelMessageResp` 一次 payload 解析，Map 查扩展，避免 panic。
9. 压测脚本：覆盖单聊、百人群、千人群、图片消息、断线重连、历史翻页。

验收指标：

- 10 万条本地消息，频道搜索 p95 小于 300ms。
- 断线 30 秒内恢复后，无重复消息、无消息洞。
- protobuf 控制协议灰度到 100% 后，decode error rate 小于 0.1%。
- Windows 历史搜索期间 UI 帧耗时 p95 小于 16ms。

## Phase 3：Future Proofing（1-2 个版本周期）

目标：完善高级 IM 能力、安全能力和视觉体验。

任务：

1. 大文件分片上传：支持暂停、恢复、秒传 hash、服务端 compose。
2. 通话体验补齐：设备切换、弱网提示、后台来电补偿、LiveKit room 生命周期观测。
3. E2EE 私聊试点：密钥生成、设备信任、密文 payload、不可搜索提示。
4. 消息高级结构：引用、编辑、撤回、reaction、@我索引、置顶统一版本模型。
5. 冷热历史归档：老消息归档压缩，按会话懒加载。
6. 动效系统：发送、气泡、reaction、页面转场、骨架屏形成统一 motion token。
7. 桌面增强：右键菜单、拖拽发送、托盘、全局快捷键、未读角标。

验收指标：

- 1GB 文件可断点续传，断网恢复后不重新上传已完成分片。
- E2EE 私聊消息服务端不可读，客户端新设备迁移有明确安全确认。
- 聊天页首屏、历史加载、搜索、reaction 的动效不改变布局稳定性。

## 4. 建议的实施顺序

第一周不要先做“大架构重写”。最值得先做的是四件事：端口收口、MinIO 权限与流式上传、SQLite WAL、线性循环改 Map。这四件事成本低，风险收益比最高。

第二阶段再推进协议 v2、FTS、Repository 解耦和 Web/Windows 存储差异化。这样客户端体验和服务端稳定性会同时提升，而且每一步都能被指标验证。

第三阶段再做 E2EE、分片上传、通话增强和精细动效。这些能力会显著提高产品上限，但都依赖前两阶段的协议、存储和平台边界足够稳定。

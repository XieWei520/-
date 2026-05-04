# IM 剩余优化任务统一收口报告

报告时间：2026-04-29 18:46 +08:00  
执行范围：Flutter 主客户端 `C:\Users\COLORFUL\Desktop\WuKong`、Flutter SDK `C:\Users\COLORFUL\Desktop\TangSengDaoDao\WuKongIMFlutterSDK-master`、生产服务器 `ubuntu@42.194.218.158`。  
结论口径：本报告只把有代码、构建、测试、部署或线上 smoke 证据的任务标记为完成；E2EE、1GB 分片续传、全量 Repository 重构等跨版本工程不做虚假完成声明。

## 1. 本阶段完成结论

本阶段已完成并验证的优化闭环：

1. 后端生产链路：消息同步响应装配优化已部署到云服务器，`tsdd-api` 与 `callgateway` 重新构建并健康运行。
2. 后端边缘安全：生产公网入口仍收敛在 Nginx `80/443`，WuKongIM 业务端口未直接公网暴露，`/ws` 入口可正常握手。
3. 客户端实时协议：Dart 端 protobuf control codec 已支持未来 v2 顶层 `event_id / aggregate_id / schema_version` 字段，并保持旧 payload 兼容。
4. SDK 本地搜索性能：FTS5 SQL helper、`message_fts` 迁移、WAL/busy_timeout、消息装配 Map 化均已存在并通过 SDK 专项测试与分析。
5. Flutter 多端性能与安全：媒体 L1 缓存按 decoded bytes 淘汰，平台检测移除共享层 `dart:io` 直接依赖。
6. 富媒体与本地文件边界：二维码图片、聊天图片、文件上传、桌面拖拽文件的路径、体积和元数据边界已纳入测试。
7. Web/PWA/通知外围体验：轻量 PWA service worker、离线页、通知点击目标解析、浏览器前台通知权限流、Web Wasm 依赖策略已验证。
8. 聊天列表性能：viewport/timeline 已使用索引化匹配路径，覆盖大批量 incoming、older page、refresh patch 的非线性扫描回归测试。

## 2. 关键代码改动

### 2.1 客户端 protobuf control codec 前向兼容

文件：

- `lib/realtime/control/control_proto_codec.dart`
- `test/realtime/control/control_proto_codec_test.dart`

完成内容：

- `RealtimeEnvelope` 增加 `eventId`、`aggregateId`、`schemaVersion` 字段。
- `ControlProtoCodec.encodeEnvelope` 写入 protobuf field `7/8/9`，分别对应未来协议字段 `event_id`、`aggregate_id`、`schema_version`。
- `ControlProtoCodec.decodeEnvelope` 能跳过未知字段，也能读取新增字段。
- `toSessionEventFrame` 优先使用顶层 `eventId/aggregateId`，没有时继续回落到 payload 内的 `event_id/aggregate_id`，再回落到 `proto_{seq}_{type}`。

验证点：

- 新增测试先 RED：旧代码不支持 `eventId` 参数和 envelope getter，编译失败。
- 实现后 GREEN：`test/realtime/control/control_proto_codec_test.dart` 4/4 通过。
- 实时回归套件：control codec、session gateway、runtime、telemetry 合计 39/39 通过。

### 2.2 生产后端消息响应装配优化

服务器文件：

- `/opt/wukongim-prod/src/modules/message/api.go`

完成内容：

- `newSyncChannelMessageResp` 对 `message_id` 去重，避免重复查询。
- payload 解析从多次解析改为每条消息最多一次解析。
- reply extra 从消息数乘 extra 数的嵌套扫描改为 `message_id -> extra` Map 查找。
- reply payload 的 `message_id` 读取改成安全读取，避免脏 payload 类型断言 panic。

部署与验证：

- `docker compose build tsdd-api callgateway` 成功。
- `docker compose up -d --no-deps tsdd-api callgateway` 成功。
- `docker compose ps tsdd-api callgateway wukongim nginx` 显示 `tsdd-api`、`callgateway`、`wukongim` 均为 healthy。
- `https://infoequity.qingyunshe.top/v1/ping` 返回 `200`。
- `wss://infoequity.qingyunshe.top/ws` 原始握手返回 `HTTP/1.1 101 Switching Protocols`。

### 2.3 SDK 搜索和本地数据库性能

SDK 文件：

- `lib/db/message_search_sql.dart`
- `lib/db/message_performance_helpers.dart`
- `lib/db/sqlite_performance_options.dart`
- `lib/db/wk_db_helper.dart`
- `lib/db/message.dart`
- `assets/202604271430.sql`
- `assets/sql.txt`
- `test/db/message_fts_search_test.dart`
- `test/db/performance_helpers_test.dart`

完成内容：

- `message_fts` FTS5 虚表迁移已注册。
- 全局搜索和频道内搜索优先走 FTS `MATCH ?`，失败或不存在时回落到 LIKE。
- LIKE fallback 对 `%`、`_`、`\` 做转义，避免误扩大扫描。
- SQLite 初始化已启用 `PRAGMA journal_mode=WAL`、`PRAGMA synchronous=NORMAL`、`PRAGMA busy_timeout=3000`。
- reaction、成员、发送人、reply extra 装配使用 Map/分组 helper，避免 N x M 扫描。

验证：

- `dart test test/db/message_fts_search_test.dart test/db/performance_helpers_test.dart`：11/11 通过。
- `dart analyze ...` SDK 指定文件：No issues found。

### 2.4 Flutter 客户端多端性能与外围能力

覆盖模块：

- 媒体缓存：`lib/core/cache/media_cache_manager.dart`
- 平台检测：`lib/core/utils/platform_utils.dart`
- 聊天 viewport：`lib/modules/chat/chat_viewport_controller.dart`
- 桌面拖拽：`lib/modules/chat/chat_desktop_drop_target.dart`
- Web 通知：`lib/wukong_push/notification/browser_notification_service.dart`
- PWA：`web/wk_pwa_service_worker.js`、`web/offline.html`、`web/index.html`
- 文件/图片边界：`lib/service/api/file_api.dart`、`lib/service/im/im_service.dart`、`lib/modules/chat/chat_media_action_service.dart`

完成内容：

- 图片 L1 缓存从条目数限制升级为 decoded byte budget 淘汰。
- Web-safe 平台检测使用 Flutter foundation 能力，避免共享工具直接导入 `dart:io`。
- 聊天列表增量插入、历史分页 append、消息刷新 patch 使用索引化匹配。
- 桌面拖拽跳过目录和不可读取文件，统一映射到聊天文件选择结构。
- 浏览器通知支持权限请求、前台通知展示、点击聚焦窗口和业务回调。
- PWA worker 只缓存轻量离线资源，不缓存 `main.dart.js` 或 CanvasKit，避免旧 Flutter SW 污染更新。
- 二维码/聊天图片读取、文件上传元数据、路径清洗、超限保护均纳入测试。

验证：

- 主仓库收口套件 `flutter test ...`：119/119 通过。
- 主仓库定向 `dart analyze ...`：No issues found。

## 3. 五大维度任务状态

| 维度 | 状态 | 证据 |
| --- | --- | --- |
| 架构优化 | 部分完成，核心风险已收口 | protobuf 客户端前向兼容、生产端口收口、SDK FTS/WAL、平台检测 Web-safe 已验证 |
| 性能调优 | Phase 1/P1 重点已完成 | 后端消息装配 Map 化、SDK Map 化、FTS5、媒体缓存 byte budget、viewport 索引化 |
| 体验升级 | 外围高收益项已完成 | 桌面拖拽、Web 通知、PWA 离线、文件/图片失败边界测试 |
| 能力扩展 | 基础边界完成，高级能力未强行上线 | 文件安全/流式上传链路已核验；分片续传、E2EE、完整 WebRTC 体验仍需独立版本 |
| 动效与视觉表现 | 已有局部体验优化，未完成统一 motion system | 当前阶段没有强行改大范围视觉系统，避免在脏工作区引入高回归风险 |

## 4. 仍不能诚实标记为“已全部完成”的项目

以下项目属于跨端、跨服务、跨产品策略的大版本能力，不适合在当前阶段通过小补丁直接宣称完成：

1. 服务端 protobuf `RealtimeEnvelope` 源 proto 与 Go generated code 增加顶层 `event_id / aggregate_id / schema_version` 并完成全链路灰度。
2. `message.new / message.extra.changed / conversation.changed / call.invited` 全量纳入 session event bus，并替换现有零散命令通道。
3. Repository 全量分层重构：`MessageRepository / FileRepository / SearchRepository / PlatformCapabilities` 的全项目迁移。
4. Web IndexedDB 近端消息缓存和 Windows DB worker/isolate 全量落地。
5. 大文件分片上传、断点续传、秒传 hash、服务端 compose。
6. 私聊 E2EE、设备信任、密钥备份、新设备迁移。
7. 完整动效 token system、统一页面转场、骨架屏全量治理。
8. 桌面系统托盘、全局快捷键、多窗口、系统级未读角标。
9. 标准化高并发压测环境与 Prometheus/Grafana 生产观测闭环。

这些不是“漏做的小任务”，而是需要需求冻结、协议兼容、数据迁移、灰度回滚和生产验收的大工程。当前阶段已经把它们的前置风险项尽量完成：协议前向兼容、搜索/数据库基础、端口与文件安全、消息装配、PWA/通知/拖拽等。

## 5. 验证命令清单

主仓库：

```powershell
flutter test test\wukong_scan\scan_qr_code_image_io_test.dart test\wukong_scan\scan_qr_code_image_stub_test.dart test\modules\chat\chat_media_action_service_test.dart test\modules\chat\chat_image_bytes_loader_io_test.dart test\service\im\im_service_test.dart test\service\api\file_api_test.dart test\service\im\local_attachment_file_io_test.dart test\scripts\ops\collect_im_performance_baseline_test.dart test\core\cache\media_cache_manager_test.dart test\core\utils\platform_utils_test.dart test\modules\chat\chat_viewport_controller_test.dart test\modules\chat\chat_desktop_drop_target_test.dart test\wukong_push\browser_notification_service_test.dart test\web_pwa_service_worker_test.dart test\web_entrypoint_cache_cleanup_test.dart test\web_dependency_wasm_policy_test.dart test\realtime\control\control_proto_codec_test.dart test\realtime\session\session_event_gateway_test.dart test\realtime\session\session_runtime_test.dart test\realtime\telemetry\realtime_rollout_telemetry_test.dart
```

结果：119/119 通过。

```powershell
dart analyze lib\realtime\control\control_proto_codec.dart test\realtime\control\control_proto_codec_test.dart lib\wukong_scan\scan_qr_code_image_limits.dart lib\wukong_scan\scan_qr_code_image_io.dart lib\wukong_scan\scan_qr_code_image_stub.dart test\wukong_scan\scan_qr_code_image_io_test.dart test\wukong_scan\scan_qr_code_image_stub_test.dart lib\modules\chat\chat_media_action_service.dart test\modules\chat\chat_media_action_service_test.dart lib\modules\chat\chat_image_bytes_loader_io.dart test\modules\chat\chat_image_bytes_loader_io_test.dart lib\service\im\im_service.dart test\service\im\im_service_test.dart lib\service\api\file_api.dart test\service\api\file_api_test.dart lib\service\im\local_attachment_file_io.dart test\service\im\local_attachment_file_io_test.dart lib\core\cache\media_cache_manager.dart test\core\cache\media_cache_manager_test.dart lib\core\utils\platform_utils.dart test\core\utils\platform_utils_test.dart lib\modules\chat\chat_viewport_controller.dart test\modules\chat\chat_viewport_controller_test.dart lib\modules\chat\chat_desktop_drop_target.dart test\modules\chat\chat_desktop_drop_target_test.dart lib\wukong_push\notification\browser_notification_service.dart test\wukong_push\browser_notification_service_test.dart test\web_pwa_service_worker_test.dart test\web_entrypoint_cache_cleanup_test.dart test\web_dependency_wasm_policy_test.dart
```

结果：No issues found。

SDK：

```powershell
dart test test/db/message_fts_search_test.dart test/db/performance_helpers_test.dart
```

结果：11/11 通过。

```powershell
dart analyze lib\db\message_search_sql.dart lib\db\message_performance_helpers.dart lib\db\sqlite_performance_options.dart lib\db\message.dart lib\db\const.dart lib\db\wk_db_helper.dart test\db\message_fts_search_test.dart test\db\performance_helpers_test.dart
```

结果：No issues found。

服务器：

```bash
cd /opt/wukongim-prod/src/deploy/production
docker compose build tsdd-api callgateway
docker compose up -d --no-deps tsdd-api callgateway
docker compose ps tsdd-api callgateway wukongim nginx
```

结果：`tsdd-api`、`callgateway`、`wukongim` healthy；Nginx 暴露 `80/443`；WuKongIM 仅 `127.0.0.1:5001` 绑定。

公网 smoke：

- `https://infoequity.qingyunshe.top/v1/ping`：`PING_STATUS=200;LEN=14`
- `wss://infoequity.qingyunshe.top/ws`：`HTTP/1.1 101 Switching Protocols`

## 6. 建议的下一步

如果继续推进，下一阶段不建议再叫“剩余小优化”，而应拆成 3 个独立工程包：

1. 协议工程包：服务端 proto v2、Go generated code、客户端 schema gate、灰度和回滚。
2. 存储工程包：Repository 全量分层、Web IndexedDB、Windows DB worker、冷热归档。
3. 高级能力工程包：分片续传、E2EE、通话体验、动效系统、桌面系统能力。

这样能保持每个工程包都有独立验收、独立回滚和清晰的生产风险边界。

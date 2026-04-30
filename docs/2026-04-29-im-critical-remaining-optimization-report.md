# IM 关键剩余优化任务完成报告

报告时间：2026-04-29 22:20 +08:00  
范围：云服务器 `ubuntu@42.194.218.158` 后端分片上传、Flutter 客户端大文件 multipart 接入、E2EE 私聊灰度安全边界。

## 1. 本轮完成结论

本轮已经把此前明确未完成的两块关键缺口推进到可部署、可测试、可接管状态：

1. 后端已经上线 `/v1/file/multipart/init`、`/v1/file/multipart/part`、`/v1/file/multipart/complete`、`/v1/file/multipart/abort` 四个鉴权路由。
2. Flutter IO 平台上传聊天文件时，达到阈值的大文件会自动走 multipart init/part/complete；小文件仍走传统 `/v1/file/upload`。
3. 大文件续传 checkpoint 已从内存升级为 `SharedPreferences` 持久化，客户端重启后可复用未完成的 upload session。
4. E2EE 已补齐“私聊试点灰度边界”：默认关闭、仅白名单私聊、必须受信 keyId，消息 payload 可识别、可解密验证、可在 UI 中显示安全 fallback。

需要明确的是：E2EE 仍未声明为生产级 Signal 双棘轮完整实现；后端 multipart 当前采用“服务端临时分片 + complete 后流式合并到现有上传服务”的兼容方案，不是对象存储原生 multipart 直传。

## 2. 后端 multipart 上传

新增/修改位置：

- 云端：`/opt/wukongim-prod/src/modules/file/api.go`
- 云端：`/opt/wukongim-prod/src/modules/file/service.go`
- 云端：`/opt/wukongim-prod/src/modules/file/multipart_temp_store.go`
- 本地镜像：`.codex_remote_tsdd/src/modules/file/*`

实现内容：

- `POST /v1/file/multipart/init` 创建 multipart session，返回 `upload_id`。
- `PUT /v1/file/multipart/part` 按 `upload_id + part_number` 写入临时分片。
- `POST /v1/file/multipart/complete` 按客户端提交的 part 顺序流式合并，并复用现有 `UploadFile` 抽象上传到当前文件服务。
- `DELETE /v1/file/multipart/abort` 主动清理未完成 session。
- `upload_id` 限定为 32 位 hex，阻断路径穿越。
- `part_number` 限定为 `1..10000`，覆盖常规大文件分片数量。
- complete 时校验 `upload_id` 绑定的 file path，避免拿一个 session 写到另一个目标路径。

后端验证：

```bash
go test ./modules/file -run 'Test(ServiceMultipartUpload|TempMultipartStore)' -count=1
```

结果：`ok github.com/TangSengDaoDao/TangSengDaoDaoServer/modules/file`

```bash
cd /opt/wukongim-prod/src/deploy/production
docker compose build tsdd-api
docker compose up -d --no-deps tsdd-api
docker compose ps tsdd-api
```

结果：`tsdd-api` 镜像构建成功，容器 `healthy`。

线上 smoke：

- `https://infoequity.qingyunshe.top/v1/ping` 返回 `200`。
- 未授权 `POST /v1/file/multipart/init` 返回 `401` 和 `token不能为空，请先登录！`，说明路由已上线并进入鉴权链路，不是 404。

## 3. 客户端大文件 multipart 接入

新增/修改位置：

- `lib/service/api/file_api.dart`
- `lib/service/api/chat_file_multipart_upload_strategy.dart`
- `lib/service/api/chat_file_multipart_upload_strategy_io.dart`
- `lib/data/upload/shared_preferences_resumable_upload_store.dart`
- `test/service/api/file_api_test.dart`
- `test/data/upload/shared_preferences_resumable_upload_store_test.dart`

实现内容：

- `FileApi.uploadChatFile` 会先生成安全对象路径，再根据文件大小判断是否 multipart。
- 默认 multipart 阈值：`64 * 1024 * 1024` bytes。
- IO 平台使用条件导入接入 `dart:io`、`FileMultipartUploadClient`、`ResumableFileUploader`。
- Web/非 IO 平台走 stub，不引入 `dart:io`，避免破坏 Web 编译。
- `SharedPreferencesResumableUploadStore` 持久化 `fingerprint/upload_id/object_path/file_size/chunk_size/uploaded_part_numbers`。
- 传统上传保留为 fallback：小文件仍使用 `/v1/file/upload`。

客户端验证：

```powershell
dart analyze lib/data/upload/shared_preferences_resumable_upload_store.dart lib/service/api/chat_file_multipart_upload_strategy.dart lib/service/api/chat_file_multipart_upload_strategy_io.dart lib/service/api/file_api.dart lib/modules/chat/message_content_preview.dart lib/wukong_crypto/crypto_exports.dart lib/wukong_crypto/e2ee/e2ee_cipher.dart lib/wukong_crypto/e2ee/e2ee_envelope.dart lib/wukong_crypto/e2ee/e2ee_message_codec.dart lib/wukong_crypto/e2ee/e2ee_rollout_policy.dart test/data/upload/shared_preferences_resumable_upload_store_test.dart test/service/api/file_api_test.dart test/wukong_crypto/e2ee/e2ee_message_codec_test.dart test/modules/chat/chat_message_mapper_test.dart test/data/upload/resumable_file_uploader_test.dart test/service/api/file_multipart_upload_client_test.dart
```

结果：`No issues found!`

```powershell
flutter test test/core/upload/multipart_upload_planner_test.dart test/service/api/file_multipart_upload_client_test.dart test/data/upload/resumable_file_uploader_test.dart test/data/upload/shared_preferences_resumable_upload_store_test.dart test/service/api/file_api_test.dart test/wukong_crypto/e2ee/aes_gcm_e2ee_cipher_test.dart test/wukong_crypto/e2ee/e2ee_message_codec_test.dart test/modules/chat/chat_message_mapper_test.dart
```

结果：`25/25` 通过。

## 4. E2EE 私聊灰度边界

新增/修改位置：

- `lib/wukong_crypto/e2ee/e2ee_rollout_policy.dart`
- `lib/wukong_crypto/e2ee/e2ee_message_codec.dart`
- `lib/wukong_crypto/crypto_exports.dart`
- `lib/modules/chat/message_content_preview.dart`
- `test/wukong_crypto/e2ee/e2ee_message_codec_test.dart`
- `test/modules/chat/chat_message_mapper_test.dart`

实现内容：

- `E2eeRolloutPolicy.disabled()` 默认禁止加密，避免误启。
- `E2eeRolloutPolicy.privateChatPreview(...)` 需要同时满足 channel type、peer 白名单、keyId 信任条件。
- `E2eeMessageCodec.tryEncryptText(...)` 在 policy 不允许时返回 `null`，不会偷偷加密。
- 加密 payload 使用 `wk.e2ee.v1`、`AES-256-GCM` envelope、上下文 AAD。
- AAD 绑定 `channelType/channelId/fromUid/peerUid/clientMsgNo`，上下文被篡改时解密失败。
- 聊天消息预览识别 `wk.e2ee.v1`，显示 `[Encrypted message]` fallback，不暴露密文 JSON。

仍未完成且不应夸大：

- 未实现 Signal 双棘轮。
- 未实现设备信任 UI。
- 未实现密钥备份/恢复。
- 未接入生产发送链路默认开启。
- 未完成多设备 prekey bundle、会话迁移和安全码验证。

## 5. 剩余风险与建议

1. 后端 multipart 当前依赖服务端磁盘临时目录 `data/multipart_uploads`，建议下一阶段增加 TTL 清理任务、磁盘水位保护、上传 session 限额。
2. 当前 complete 后才上传到对象存储，1GB 文件会在服务端临时落盘并再次流式上传；后续可升级为 MinIO/S3 原生 multipart，减少服务端磁盘压力。
3. 本轮没有登录凭证，无法做真实鉴权态端到端上传 smoke；已完成构建、部署、健康检查和未授权路由 smoke。
4. E2EE 已具备安全灰度壳和 payload codec，但上线前必须完成正式密钥协议、设备信任、审计与回滚策略。
5. 当前工作区仍有大量历史改动，本轮只增量触达上述文件，没有回滚或整理无关变更。

## 6. 接管建议

建议下一位接管者优先做三件事：

1. 用真实测试账号跑一次 `init -> part -> complete -> preview` 鉴权态端到端上传。
2. 给云端增加 multipart 临时目录清理和磁盘报警。
3. 将 E2EE 灰度策略接入一个仅内部测试账号可见的开关，不要直接开放给普通用户。

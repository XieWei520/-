# infoequity.cn 唯一域名切换设计

日期：2026-05-07
工作区：`C:\Users\COLORFUL\Desktop\WuKong\.worktrees\infoequity-cn-domain-cutover`

## 目标

将项目所有正式公开入口切换为 `infoequity.cn`，并把历史正式域名从活跃客户端配置、部署配置、运维脚本和验证用例中移除。最终正式入口为：

- Web / API：`https://infoequity.cn`
- WebSocket：`wss://infoequity.cn/ws`
- 文件/媒体：`https://infoequity.cn/minio/...` 或 `https://infoequity.cn/v1/file/...`

`127.0.0.1` Windows 本地隧道配置保留，因为它是本机调试入口，不是旧公开域名。

## 当前上下文

仓库是 Flutter 多端项目，Web、Android、Windows 共用 `lib/core/config/api_config.dart` 的默认 API/WS 配置，另有 `lib/wukong_base/config/app_config.dart` 中存在一组老配置常量。测试中大量 fixture 目前使用 `infoequity.qingyunshe.top`。部署示例中 `deploy/full-stack/tsdd.yaml` 和 `deploy/*/docker-compose.yaml` 仍有公网 IP 直连配置。生产发布文档表明当前线上 Web 曾发布到 `https://infoequity.qingyunshe.top/`，服务器上下文多次出现 `ubuntu@42.194.218.158`。

主工作区已有大量未提交改动，因此本次域名切换在独立 git worktree 中实施，避免覆盖或混合其他工作。

## 范围

### 客户端

- `ApiConfig.devBaseUrl` / `prodBaseUrl` 默认改为 `https://infoequity.cn`。
- `ApiConfig.devWsAddr` / `prodWsAddr` 默认改为 `wss://infoequity.cn/ws`。
- `AppConfig.apiBaseUrl` / `wsUrl` / prod 变体同步改为新域名。
- 相关测试 fixture 更新为新域名。
- 保持 `String.fromEnvironment` 覆盖能力，方便未来临时调试。
- 保留 Windows 桌面本地隧道常量。

### Web / Android / Windows

三端由同一 Flutter 配置驱动，不分别引入新域名配置，避免多处漂移。验证覆盖：

- `flutter test test/core/config/api_config_test.dart`
- 相关 API、IM、视频通话、头像解析测试
- `flutter analyze`
- 可选构建：Web、Android、Windows

### 云服务器 / 部署

目标服务器若确认为当前生产机，则执行：

- 确认 DNS：`infoequity.cn` 解析到生产服务器。
- 为 `infoequity.cn` 签发或安装证书。
- Nginx 只声明 `server_name infoequity.cn`；HTTP 跳 HTTPS；不再为旧域名提供跳转或服务。
- 后端外部配置使用 `https://infoequity.cn`，包括 baseURL、webLoginURL、MinIO 下载 URL、WebSocket/WSS、LiveKit/CallGateway 若存在。
- 重启或滚动重建受影响服务。
- 线上 smoke test 验证 API、Web、WSS、MinIO。

### 清理

- 活跃代码、测试、部署脚本中删除 `infoequity.qingyunshe.top` 和 `wemx.cc`。
- 历史文档可保留事实记录，但新的切换计划和运行手册必须使用 `infoequity.cn`。
- IP 地址可在 SSH/EXTERNAL_IP 等运维场景保留；不作为客户端正式公开 base URL。

## 非目标

- 不更换服务器 IP。
- 不重构登录、聊天、文件上传业务逻辑。
- 不删除历史归档文档中作为事实记录出现的旧域名。
- 不发布应用商店版本；本次只准备代码、构建产物和部署验证。

## 方案比较

### 方案 A：一次性全链路切换（采用）

客户端、部署配置、证书和线上代理在同一变更窗口完成。优点是符合“旧域名全部删除”，不会产生长期双域名状态。缺点是需要一次性验证充分，且 DNS/证书权限必须可用。

### 方案 B：新旧域名并存灰度

先让 `infoequity.cn` 生效，旧域名继续跳转一段时间。优点是回滚容易；缺点是不符合唯一域名要求，且旧域名仍可能被客户端缓存或外链继续使用。

### 方案 C：只改客户端

只发布新客户端，服务器保留旧域名配置。实现快，但文件 URL、Web 页面、服务端 appconfig 仍可能返回旧域名，不完整，不采用。

## 详细设计

### 域名常量

`infoequity.cn` 作为唯一正式域名集中体现在 Flutter 配置默认值中。API 使用 HTTPS 根路径；WebSocket 使用 `wss://infoequity.cn/ws`。测试中直接断言这些默认值，防止后续回退到旧域名。

### URL 归一化

现有 `ApiConfig.resolveUrl`、`resolveMediaUrl`、`normalizeUploadUrl` 会把自托管绝对 URL 重写到当前 `ApiConfig.baseUrl`。本次会更新测试，确保历史自托管 URL 场景经过配置后输出 `infoequity.cn`，而不是旧域名。

### 运行时覆盖

登录页/SharedPreferences 里可能保存自定义 API base URL。代码已有 runtime override 机制。本次不移除该能力，但验证默认路径必须是新域名。线上/测试设备如曾保存旧域名，需要清理应用数据或在登录设置里清空自定义 API 地址。

### 服务器

服务器侧以环境变量/渲染配置作为单一事实来源。需要检查生产目录下 `.env`、Nginx 模板、渲染后的 `wk.yaml`/`tsdd.yaml`/turnserver 等文件。所有公开 URL 设置为 `https://infoequity.cn`，证书路径指向 `/etc/letsencrypt/live/infoequity.cn/`。

### DNS 和 TLS

DNS A 记录必须指向生产 IP。证书签发前先确认 80 端口可访问 ACME challenge；签发后用 `openssl x509` 确认 SAN 包含 `DNS:infoequity.cn`。

## 验证

本地验证：

- `flutter test test/core/config/api_config_test.dart`
- `flutter test test/service/api/im_route_info_test.dart test/service/im/im_service_test.dart test/service/api/common_api_test.dart`
- `flutter test test/modules/video_call test/widgets/wk_avatar_platform_safety_test.dart`
- `flutter analyze`
- 扫描活跃代码和测试：不得出现 `infoequity.qingyunshe.top` 或 `wemx.cc`。

线上验证：

- `https://infoequity.cn/` 返回 Web 壳。
- `https://infoequity.cn/v1/ping` 返回成功。
- `https://infoequity.cn/v1/common/appconfig` 不返回旧域名。
- `wss://infoequity.cn/ws` 可握手或返回合理 WebSocket 状态，不跳旧域名。
- `https://infoequity.cn/minio/minio/health/live` 返回成功或符合当前 MinIO 健康路径行为。

## 风险与回滚

- DNS 未生效：暂停服务器切换，先修正解析。
- 证书签发失败：保留本地代码变更，不重启生产代理；检查 80 端口和 DNS。
- 线上配置错误：恢复变更前备份的 `.env` / Nginx 模板 / 渲染配置并重启服务。
- 客户端缓存旧自定义 base URL：清空本地偏好或重新安装应用。

## 用户配合点

- 提供 DNS 管理后台或按指令配置 `infoequity.cn` A 记录。
- 提供 SSH 登录方式；当前推定为 `ubuntu@42.194.218.158`，执行前必须验证。
- 如服务器需要 sudo 密码或证书邮箱，需要用户临时提供或在服务器上协助操作。

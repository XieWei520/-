# InfoEquity Windows 联合测试修复报告

时间：2026-04-25 12:50（Asia/Shanghai）
工作目录：`C:\Users\COLORFUL\Desktop\WuKong`

## 1. API / IM / MinIO 隧道地址

本次 Windows 桌面联调使用本机 SSH 端口转发，因此桌面端应访问 `127.0.0.1`：

- API：`http://127.0.0.1:15001` → 云服务器内网 `172.18.0.9:8090`
- IM：`127.0.0.1:15100` → 云服务器 wukongim 容器 `172.18.0.6:5100`
- MinIO：`http://127.0.0.1:15002` → 云服务器 MinIO 容器 `172.18.0.2:9000`

2026-04-30 复测时发现 IM / MinIO 容器 IP 已漂移；启动脚本已改为默认通过远端
`docker inspect` 自动解析当前容器 IP，并保留上述地址作为当前观测值。

代码中已保留 Windows 桌面隧道常量：`C:\Users\COLORFUL\Desktop\WuKong\lib\core\config\api_config.dart`。

## 2. 客服聊天页 VIP 商家标签

已修复会话列表进入客服聊天页后聊天头部不显示 VIP 标签的问题：

- `C:\Users\COLORFUL\Desktop\WuKong\lib\modules\conversation\conversation_list_page.dart`：进入 `ChatPage` 时传递会话行已解析出的 `vipLevel` 和 `category`。
- `C:\Users\COLORFUL\Desktop\WuKong\lib\modules\chat\chat_page.dart`：新增并向下传递 `channelCategory` / `initialVipLevel`。
- `C:\Users\COLORFUL\Desktop\WuKong\lib\modules\chat\chat_page_shell.dart`：客服通道也会读取初始 VIP 等级，并在标题区域显示 `CustomerServiceBadge` 与 VIP badge。

对应回归测试：`customer service chat shows vip merchant badge from conversation entry` 已通过。

## 3. 关于页名称

已将通用设置/关于页面的应用展示名改为 `InfoEquity`，并兼容隐藏旧名称 `wukong_im_app`：

- `C:\Users\COLORFUL\Desktop\WuKong\lib\core\config\app_config.dart`
- `C:\Users\COLORFUL\Desktop\WuKong\lib\wukong_base\config\app_config.dart`
- `C:\Users\COLORFUL\Desktop\WuKong\lib\wukong_uikit\setting\about_page.dart`

## 4. 程序图标

已使用用户提供图片作为 Windows 图标来源：

- 源图：`C:\Users\COLORFUL\Desktop\WuKong\999822 (2).png`
- 生成图标：`C:\Users\COLORFUL\Desktop\WuKong\windows\runner\resources\app_icon.ico`
- ICO SHA256：`68B3FDF94180D0D4E116CAB7CA0421F91492FD22515758B5D9DBB01AB153CA5B`
- ICO 尺寸包含：16 / 24 / 32 / 48 / 64 / 128 / 256 px，32-bit。

## 5. 程序名称

已将 Windows 程序名改为 `InfoEquity`：

- `C:\Users\COLORFUL\Desktop\WuKong\windows\CMakeLists.txt`：`project(InfoEquity)` / `BINARY_NAME "InfoEquity"`
- `C:\Users\COLORFUL\Desktop\WuKong\windows\runner\main.cpp`：窗口标题 `InfoEquity`
- `C:\Users\COLORFUL\Desktop\WuKong\windows\runner\Runner.rc`：版本信息 `ProductName` / `FileDescription` / `InternalName` / `OriginalFilename`

构建产物：

- Debug：`C:\Users\COLORFUL\Desktop\WuKong\build\windows\x64\runner\Debug\InfoEquity.exe`
- Release：`C:\Users\COLORFUL\Desktop\WuKong\build\windows\x64\runner\Release\InfoEquity.exe`

两个 exe 的版本信息均验证为 `InfoEquity` / `InfoEquity.exe`。

## 验证结果

已执行并通过：

1. `flutter analyze` 关键修改文件：No issues found。
2. Flutter 回归测试：
   - 客服 VIP 商家聊天头部标签测试：通过。
   - 品牌文案/About/API 配置测试：通过。
   - 会话列表与标签展示相关测试：通过。
3. `flutter build windows --release`：成功生成 `InfoEquity.exe`。
4. Pester 隧道脚本测试：6 passed / 0 failed。
5. 本机隧道端口：15001 / 15100 / 15002 均 `TcpTestSucceeded=True`。
6. API 健康探测：`http://127.0.0.1:15001/v1/common/appconfig` 返回 HTTP 200。
7. MinIO 健康探测：`http://127.0.0.1:15002/minio/health/live` 返回 HTTP 200。

## 当前运行状态

- Windows 桌面程序正在运行：PID `9840`，路径 `C:\Users\COLORFUL\Desktop\WuKong\build\windows\x64\runner\Debug\InfoEquity.exe`。
- 客户端日志：
  - stdout：`C:\Users\COLORFUL\Desktop\WuKong\ops\monitoring\live\windows_client.direct.debug.out.log`
  - stderr：`C:\Users\COLORFUL\Desktop\WuKong\ops\monitoring\live\windows_client.direct.debug.err.log`，当前大小 `0`。
- SSH 隧道进程：PID `36432`，正在监听 15001 / 15100 / 15002。
- 云服务器监控进程仍在运行：API / IM / Nginx / CallGateway / Host monitor 均有对应 PowerShell monitor 进程。
- 云服务器资源快照：内存 available 约 `5.8GiB`，根分区 `/` 使用率 `9%`。

## 已知说明

- 本轮没有停止 SSH 隧道，避免影响联合测试。
- 当前运行的是 Debug 版，便于持续观察 Flutter stdout/stderr；Release 版已构建完成，可用于正式分发。
- 之前全量聊天测试中存在一个与本次改动无关的旧失败：长按菜单 Android 顺序用例中 `删除` 项预期不一致；本次相关的 VIP/品牌/隧道定向测试均已通过。

# InfoEquity Windows 公网域名切换报告

时间：2026-04-25 13:18（Asia/Shanghai）
工作目录：`C:\Users\COLORFUL\Desktop\WuKong`

## 目标

将当前 Windows 桌面程序从本机 SSH 隧道切回公网域名，避免依赖这台电脑的 `127.0.0.1:15001 / 15100 / 15002`。

## 已完成

1. 已停止旧的本机隧道/旧客户端运行状态。
2. 已确认本机隧道端口不再监听：
   - `15001`：not listening
   - `15100`：not listening
   - `15002`：not listening
3. 已把本机保存的登录 API 覆盖值改为：
   - `https://infoequity.qingyunshe.top`
4. 已重新构建 Windows Debug 和 Release，构建时未使用任何 `WK_*` 的 `127.0.0.1` dart-define。
5. 已重启 Windows 桌面程序为公网配置：
   - PID：`8808`
   - 程序：`C:\Users\COLORFUL\Desktop\WuKong\build\windows\x64\runner\Debug\InfoEquity.exe`
   - API：`https://infoequity.qingyunshe.top`
   - IM：`infoequity.qingyunshe.top:5100`
   - MinIO：`https://infoequity.qingyunshe.top/minio`
   - `UsesLocalTunnel=false`

## 可分发版本

公网 Release 构建路径：

`C:\Users\COLORFUL\Desktop\WuKong\build\windows\x64\runner\Release\InfoEquity.exe`

分发给其他电脑时，应连同 Release 目录下的 `data/`、DLL 等文件一起打包，不要只复制单个 exe。

## 验证结果

- `flutter test test/core/config/api_config_test.dart`：11/11 通过。
- `flutter build windows --debug`：成功。
- `flutter build windows --release`：成功。
- DNS：`infoequity.qingyunshe.top` → `42.194.218.158`。
- HTTPS API：`https://infoequity.qingyunshe.top/v1/common/appconfig` 返回 HTTP 200。
- IM TCP：`infoequity.qingyunshe.top:5100` 连接成功，输出 `TCP_5100_OK`。
- WSS：`https://infoequity.qingyunshe.top/ws` 使用 WebSocket Upgrade 返回 `101 Switching Protocols`。
- MinIO：`https://infoequity.qingyunshe.top/minio/minio/health/live` 返回 HTTP 200。
- 当前客户端 stderr：`0` 字节。
- 当前云服务器监控已重启并运行：API / IM / Nginx / CallGateway / Host monitor 均有进程。

## 日志位置

- 客户端 stdout：`C:\Users\COLORFUL\Desktop\WuKong\ops\monitoring\live\windows_client.public.debug.out.log`
- 客户端 stderr：`C:\Users\COLORFUL\Desktop\WuKong\ops\monitoring\live\windows_client.public.debug.err.log`
- 当前客户端 PID 文件：
  - `C:\Users\COLORFUL\Desktop\WuKong\ops\monitoring\live\windows_client_public_debug_pid.json`
  - `C:\Users\COLORFUL\Desktop\WuKong\ops\monitoring\live\windows_client_direct_debug_pid.json`

## 说明

源码中的 Windows tunnel 常量和测试仍保留，用于以后临时联调；但当前构建、当前本机运行和其他设备分发版本都不再依赖本机 SSH 隧道。

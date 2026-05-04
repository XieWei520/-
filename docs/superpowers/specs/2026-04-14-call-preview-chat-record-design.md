# Call Preview And Chat Record Design

**Goal**

修复 Windows 桌面端视频通话时本地摄像头预览不显示的问题，并在通话结束后把结果写成聊天页可见的通话记录提示，补齐用户可见闭环。

**Problem Summary**

当前问题分成两条独立链路：

1. 本地视频预览
   现有 `VideoCallPage` 只会在通话状态变化或远端流回调时触发 `setState()`。而 `flutter_webrtc` 的 `RTCVideoView` 在 native 端首帧到达前通常先以 `renderVideo = false` 构建占位内容，首帧渲染后依赖 renderer 自身的 `ValueNotifier` 变化更新视图。由于页面没有订阅本地 renderer 的值变化，`RTCVideoView` 初次以空占位构建后，桌面端可能不会再因为本地首帧事件而重建，导致摄像头已经开启但本地预览仍为空白。

2. 聊天页通话记录
   现有 `CallHistoryService` 已经把通话结果保存到了本地 `shared_preferences`，但聊天页和会话列表没有消费这份记录，也没有在通话结束时插入系统消息。因此用户在会话中看不到任何“已取消视频通话 / 未接听语音通话 / 通话结束”之类的记录。

**Approach**

本次采用本地闭环修复方案，不改动服务端通话消息协议：

- 在通话页增加 renderer 值监听，让本地或远端 renderer 首帧、尺寸变化时都能驱动页面重建。
- 在视频通话服务里补充最小诊断日志，记录 `getUserMedia`、本地轨道数量、renderer 绑定和首帧/尺寸变化，便于继续联调 Windows 媒体问题。
- 新增一个专门的“通话会话系统消息落地服务”，在通话结束时把通话结果转换为本地系统消息，插入当前会话数据库并刷新 UI。

**Architecture**

### 1. Renderer Refresh Binding

新增一个轻量的多 `ValueListenable` 监听组件，职责只有一个：当任一 listenable 值变化时触发子树重建。`VideoCallPage` 用它包裹通话页主体，并订阅 `VideoCallService.localRenderer` 与 `VideoCallService.remoteRenderer`。

这样做的好处是：

- 不需要修改第三方 `flutter_webrtc` 依赖；
- 不需要把 renderer 状态提升到全局；
- 本地预览和远端画面都能在 renderer 真正拿到首帧后刷新；
- 对已有通话状态机无侵入。

### 2. Call Conversation Record Service

新增本地会话系统消息服务，输入为：

- 通话房间基础信息；
- 呼叫方向；
- 通话类型；
- 最终状态（completed / missed / canceled / rejected 等）。

输出为一条本地系统消息，写入当前会话消息表并刷新会话 UI。消息内容采用结构化 JSON，包含：

- `type`: 本地定义的通话系统提示类型；
- `content`: 供聊天页直接展示的中文提示；
- `call_type`: 语音/视频；
- `direction`: 呼入/呼出；
- `room_id`: 通话房间 ID；
- `status`: 最终状态。

聊天页无需新增特殊气泡组件，沿用现有 `system notice` 渲染路径即可。

**Data Flow**

### 视频预览

1. `VideoCallService._setupPeerConnection()` 获取本地流并绑定到 `localRenderer.srcObject`。
2. native renderer 首帧或尺寸变化后，`RTCVideoRenderer` 的 `ValueNotifier` 更新。
3. 新增的 renderer refresh 组件收到通知，重建 `VideoCallPage`。
4. `RTCVideoView` 重新构建时，`renderVideo` 已经为真，桌面端显示本地摄像头画面。

### 通话记录消息

1. `VideoCallService` 在本地挂断、远端挂断、拒绝、未接、通话完成等分支里先更新 `CallHistoryService`。
2. `VideoCallService` 再调用新服务，把该次通话结果写成会话系统消息。
3. 新消息被保存到本地消息库并触发 UI 刷新。
4. 聊天页与会话列表都能看到通话记录提示。

**Error Handling**

- renderer 日志只做诊断，不改变业务分支，不因日志失败影响通话流程。
- 系统消息写入走 best-effort，若数据库暂时不可用，只记录日志，不阻塞通话结束释放资源。
- 系统消息插入前按 `room_id + status + direction` 生成稳定去重键，避免同一次通话在多条结束路径中重复插入。

**Testing Strategy**

1. 为 renderer refresh 组件新增 widget test，验证 listenable 变化后子树会重新构建。
2. 为通话会话系统消息服务新增单元测试，验证不同状态会生成正确的中文提示和结构化 payload。
3. 为通话服务新增回归测试，验证通话结束时会请求写入聊天系统消息，而不是只保存到 `CallHistoryService`。
4. 修改完成后运行相关测试，并重启 Windows 桌面程序进行一次真实视频通话联调。

**Out Of Scope**

- 服务端生成跨设备同步的通话消息；
- 群通话消息样式扩展；
- 通话消息搜索、撤回、二次编辑；
- Flutter Web 端专门适配。

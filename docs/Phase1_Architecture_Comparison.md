# Phase 1: 架构对比大纲 — TangSengDaoDao Android vs wukong_im_app Flutter

> 生成时间: 2026-04-11 | 基于实际文件遍历与代码阅读

---

## 一、项目总览

| 维度 | TangSengDaoDao Android | wukong_im_app Flutter |
|------|----------------------|----------------------|
| **语言** | Java | Dart (Flutter 3.x, SDK ^3.11.1) |
| **模块划分** | 多 Gradle Module (wkbase/wkuikit/wklogin/wkpush/wkscan + 独立 IM SDK) | 单体 Flutter 工程, 按 `lib/` 子目录分层 |
| **IM SDK** | `WuKongIMAndroidSDK-master/wkim/` (独立 AAR) | `WuKongIMFlutterSDK-master/` (本地 path 引用) |
| **代码规模** | SDK ~120 Java 文件 + App ~300+ Java 文件 | 532 Dart 文件 (App) + 39 Dart 文件 (Flutter SDK) |
| **状态管理** | 自定义单例 Manager + Handler 回调 | flutter_riverpod + StateNotifier |
| **路由** | Activity + Fragment | go_router |
| **网络层** | xSocket (NIO) 长连接 + OkHttp/Retrofit REST | wukongimfluttersdk TCP 长连接 + Dio REST |
| **数据库** | SQLite (自封装 WKDBHelper) | sqflite + sqflite_common_ffi |
| **推送** | 华为/小米/OPPO/VIVO 厂商推送 (wkpush 模块) | Firebase Cloud Messaging + flutter_local_notifications |
| **音视频** | 未集成 (原生 App 无 RTC) | flutter_webrtc + livekit_client (已集成) |

---

## 二、核心架构层级对比

### 2.1 IM SDK 层

#### Android SDK (`wkim/`)
```
com.xinbida.wukongim/
├── WKIM.java                    # 顶级入口, 单例, 管理所有 Manager
├── WKIMApplication.java         # 全局状态 (uid/token/网络状态)
├── db/                          # 数据库层
│   ├── WKDBHelper.java          # SQLite Helper, 建表+升级
│   ├── WKDBColumns.java         # 表/列名常量
│   ├── MsgDbManager.java        # 消息读写 (核心, ~800行)
│   ├── ConversationDbManager.java # 最近会话
│   ├── ChannelDBManager.java    # 频道信息
│   ├── ChannelMembersDbManager.java
│   ├── MsgReactionDBManager.java # 消息回应
│   ├── ReminderDBManager.java   # 提醒
│   └── RobotDBManager.java      # 机器人
├── entity/                      # 数据模型 (~25个实体)
│   ├── WKMsg.java               # 消息实体
│   ├── WKChannel.java           # 频道
│   ├── WKConversationMsg.java   # 最近会话
│   ├── WKChannelMember.java     # 频道成员
│   ├── WKMsgExtra.java          # 消息扩展(已读/编辑/撤回)
│   ├── WKReminder.java          # @提醒
│   ├── WKSyncMsg/Chat/Cmd...    # 同步相关实体
│   └── ...
├── manager/                     # 业务管理器
│   ├── ConnectionManager.java   # 连接管理 (对外接口)
│   ├── MsgManager.java          # 消息管理
│   ├── ConversationManager.java # 最近会话管理
│   ├── ChannelManager.java      # 频道管理
│   ├── ChannelMembersManager.java
│   ├── CMDManager.java          # CMD指令管理
│   ├── ReminderManager.java     # 提醒管理
│   └── RobotManager.java        # 机器人管理
├── message/                     # 连接/收发核心
│   ├── WKConnection.java        # TCP 长连接核心 (~800行)
│   │   ├── xSocket NonBlockingConnection
│   │   ├── 指数退避重连 (500ms base, max 5次)
│   │   ├── 心跳管理 HeartbeatManager
│   │   ├── 网络检测 NetworkChecker
│   │   ├── ConcurrentHashMap 管理发送中消息
│   │   ├── ReentrantLock 连接锁
│   │   └── DispatchQueuePool 线程池(3线程)
│   ├── MessageHandler.java      # 消息处理器
│   ├── ConnectionClient.java    # 连接回调
│   ├── WKProto.java             # 协议编解码
│   ├── WKRead/WKWrite.java      # 读写工具
│   └── timer/                   # 定时器
│       ├── HeartbeatManager.java
│       ├── NetworkChecker.java
│       └── TimerManager.java
├── protocol/                    # 协议消息定义
│   ├── WKConnectMsg.java        # 连接消息
│   ├── WKConnectAckMsg.java     # 连接确认
│   ├── WKSendMsg.java           # 发送消息
│   ├── WKSendAckMsg.java        # 发送确认
│   ├── WKReceivedMsg.java       # 接收消息
│   ├── WKPingMsg/WKPongMsg.java # 心跳
│   └── WKDisconnectMsg.java     # 断连
├── msgmodel/                    # 消息内容模型
│   ├── WKMessageContent.java    # 基类
│   ├── WKTextContent.java
│   ├── WKImageContent.java
│   ├── WKVideoContent.java
│   ├── WKVoiceContent.java
│   └── WKMediaMessageContent.java
├── interfaces/                  # 回调接口 (~30个)
└── utils/                       # 工具类
    ├── CryptoUtils.java         # 加密
    ├── DispatchQueue/Pool.java  # 线程调度
    └── ...
```

#### Flutter SDK (`WuKongIMFlutterSDK-master/`)
```
lib/
├── wkim.dart                    # 顶级入口, 单例 WKIM.shared
├── common/                      # 配置/工具
│   ├── options.dart             # 连接配置
│   ├── crypto_utils.dart        # 加密工具
│   └── logs.dart
├── db/                          # 数据库层
│   ├── wk_db_helper.dart        # sqflite 建表/升级
│   ├── message.dart             # 消息 DAO
│   ├── conversation.dart        # 会话 DAO
│   ├── channel.dart             # 频道 DAO
│   ├── channel_member.dart
│   ├── reaction.dart
│   └── reminder.dart
├── entity/                      # 数据模型
│   ├── msg.dart                 # WKMsg
│   ├── conversation.dart        # WKUIConversationMsg
│   ├── channel.dart             # WKChannel
│   ├── channel_member.dart
│   ├── cmd.dart
│   └── reminder.dart
├── manager/                     # 业务管理器
│   ├── connect_manager.dart     # 连接管理
│   ├── message_manager.dart     # 消息管理
│   ├── conversation_manager.dart
│   ├── channel_manager.dart
│   ├── channel_member_manager.dart
│   ├── cmd_manager.dart
│   └── reminder_manager.dart
├── model/                       # 消息内容模型
│   ├── wk_message_content.dart
│   ├── wk_text_content.dart
│   ├── wk_image_content.dart
│   ├── wk_video_content.dart
│   ├── wk_voice_content.dart
│   ├── wk_card_content.dart
│   └── wk_media_message_content.dart
├── proto/                       # 协议编解码
│   ├── proto.dart               # 协议核心
│   ├── packet.dart              # 数据包定义
│   └── write_read.dart          # 字节读写
└── type/
    └── const.dart               # 常量定义
```

**SDK 对比结论**:
- Flutter SDK 与 Android SDK 结构高度一致 (1:1 映射)
- Android SDK 有 `RobotDBManager`, Flutter SDK 无对应
- Android SDK 接口回调 (~30个 Interface), Flutter SDK 用 Dart 的 Function 类型替代
- 连接层: Android 用 xSocket NIO, Flutter SDK 用 Dart 原生 TCP Socket

---

### 2.2 App 业务层

#### Android App (`TangSengDaoDaoAndroid-master/`)
```
模块                 | 职责
wkbase/             | 基础层: BaseActivity/Fragment, 网络请求(OkHttp), 
                    | 通用UI组件(rlottie, CropImage, WebView, VideoPlayer),
                    | 端点系统(EndpointManager), 主题管理, 工具类
                    | 约 300+ Java 文件, 包含:
                    |   - base/ (MVP架构: Model/View/Presenter)
                    |   - endpoint/ (模块化端点系统)
                    |   - net/ (HttpUtil, 文件上传)
                    |   - views/ (大量自定义View)
                    |   - emoji/ (表情系统)
                    |   - config/ (配置管理)
wkuikit/            | 业务UI层: 聊天/联系人/群组/搜索/设置/用户
                    |   - chat/ (聊天界面, adapter, face, msgmodel, provider, search)
                    |   - contacts/ (联系人)
                    |   - group/ (群组管理)
                    |   - search/ (全局搜索, remote搜索)
                    |   - setting/ (设置)
                    |   - user/ (用户资料)
                    |   - message/ (消息类型)
                    |   - robot/ (机器人)
                    |   - crypto/ (端到端加密 UI)
wklogin/            | 登录模块
wkpush/             | 推送模块 (华为/小米/OPPO/VIVO/FCM)
wkscan/             | 扫码模块
app/                | 主 Application, 入口 Activity
```

#### Flutter App (`wukong_im_app/lib/`)
```
目录                     | 职责                          | 对应 Android 模块
app/                    | 启动+路由                      | app/
  bootstrap/            | 应用启动流程                    | WKBaseApplication
  navigation/           | GoRouter 路由                  | Activity 导航
core/                   | 核心配置+工具                   | wkbase/config
  config/               | API/IM/App 配置                | wkbase/config
  constants/            | 常量                           | wkbase/config
  utils/                | 工具类(头像/加密/平台/存储)      | wkbase/utils
data/                   | 数据模型+Provider               | -
  models/               | 业务模型(call/friend/group...)  | wkbase/entity
  providers/            | Riverpod Provider              | -
modules/                | 业务功能模块                    | wkuikit/
  auth/                 | 认证(Clean Architecture层级)    | wklogin/
  chat/                 | 聊天核心 (~45 Dart文件)         | wkuikit/chat/
  contacts/             | 联系人                          | wkuikit/contacts/
  conversation/         | 最近会话列表                    | wkuikit/fragment/
  search/               | 搜索(Clean Architecture)        | wkuikit/search/
  settings/             | 设置                            | wkuikit/setting/
  video_call/           | 音视频通话 (LiveKit+WebRTC)     | ❌ Android 无此模块
  moments/              | 朋友圈                          | ❌ Android 无此模块
  group/                | 群组 (目录存在但空)              | wkuikit/group/
  favorites/            | 收藏                            | -
  report/               | 举报                            | -
  user/                 | 用户资料                        | wkuikit/user/
  home/                 | 主页                            | -
  location/             | 位置                            | -
  emoji_store/          | 表情商店                        | -
  tag/                  | 标签                            | -
  group_reminder/       | 群提醒                          | -
service/                | 服务层                          | -
  api/                  | REST API客户端 (~20个API文件)   | wkbase/net/
  im/                   | IM服务 (SDK封装层)              | -
realtime/               | 实时通信层                      | -
  call/                 | 通话状态机                      | ❌
  device/               | 设备身份管理                    | ❌
  session/              | 会话事件网关(WebSocket)         | ❌
wukong_base/            | Flutter 版 wkbase               | wkbase/
  base/                 | 基础组件                        | wkbase/base/
  config/               | 配置                            | wkbase/config/
  db/                   | 数据库                          | wkbase/db/
  endpoint/             | 端点系统                        | wkbase/endpoint/
  emoji/                | 表情                            | wkbase/emoji/
  msg/                  | 消息UI组件                      | wkbase/msg/
  net/                  | 网络                            | wkbase/net/
  utils/                | 工具                            | wkbase/utils/
  views/                | 通用View                        | wkbase/views/
wukong_crypto/          | 端到端加密                      | wkuikit/crypto/
wukong_push/            | 推送服务(FCM)                   | wkpush/
wukong_scan/            | 扫码                            | wkscan/
wukong_uikit/           | UIKit层                         | wkuikit/
wukong_robot/           | 机器人                          | wkuikit/robot/
wukong_login/           | 登录                            | wklogin/
```

---

### 2.3 后端服务 (服务器 42.194.218.158)

| 服务 | 状态 | 端口 | 说明 |
|------|------|------|------|
| **wukongim** | Up 5 days (healthy) | 5100 (TCP长连接), 5200, 5001(管理) | IM 核心引擎 (Go) |
| **tsdd-api** | Up 3 days (healthy) | 8090 (内部) | 唐僧叨叨业务 API (Go/Gin) |
| **nginx** | Up 3 days | 80, 443 | 反向代理+TLS+WebSocket |
| **livekit** | Up 5 days | 7881 (TCP), 50000-50100 (UDP) | WebRTC 媒体服务器 |
| **coturn** | Up 5 days | 3478 (TURN), 5349 (TURNS) | NAT 穿透 TURN 服务 |
| **callgateway** | Up 3 days (healthy) | 8091 (内部) | 通话信令网关 |
| **mysql** | Up 5 days (healthy) | 3306 (内部) | 数据库 |
| **redis** | Up 5 days (healthy) | 6379 (内部) | 缓存 |
| **minio** | Up 5 days (healthy) | 9000 (内部) | 对象存储 (头像/文件) |

**后端 API 接口活跃度**: 从日志可见以下接口正常工作:
- `/v1/conversation/sync` - 会话同步
- `/v1/message/readed` - 消息已读
- `/v1/message/reminder/sync` - 提醒同步
- `/v1/friend/sync` - 好友同步
- `/v1/friend/apply` - 好友申请
- `/v1/group/my` - 我的群组
- `/v1/users/{uid}` - 用户信息
- `/v1/users/{uid}/avatar` - 头像
- `/v1/groups/{gid}` - 群组详情
- `/v1/realtime/session/events/ws` - 实时会话事件 WebSocket
- `/v1/common/appversion/` - 版本检查

---

## 三、架构设计差异

### 3.1 状态管理
| 维度 | Android | Flutter |
|------|---------|---------|
| 模式 | 单例 Manager + Listener 回调 | Riverpod StateNotifier |
| 响应式 | 手动 addListener/removeListener | 自动依赖追踪 |
| 生命周期 | 手动管理 | Provider 自动管理 |
| 线程安全 | ConcurrentHashMap + synchronized | Dart 单线程 + Isolate |

### 3.2 连接管理
| 维度 | Android | Flutter |
|------|---------|---------|
| 传输层 | xSocket (Java NIO NonBlockingConnection) | Dart TCP Socket |
| 重连策略 | 指数退避 (500ms, max 5次, max 8s) | SDK内置重连 |
| 心跳 | HeartbeatManager (独立线程) | SDK内置 Ping/Pong |
| 线程模型 | DispatchQueuePool(3线程) + 独立单线程 Executor | Dart 单线程事件循环 |
| 网络检测 | NetworkChecker (主动探测) | 依赖平台网络状态 |

### 3.3 数据库
| 维度 | Android | Flutter |
|------|---------|---------|
| ORM | 原生 SQLite (ContentValues/Cursor) | sqflite (rawQuery) |
| 表结构 | message/channel/conversation/message_extra/channel_member/reaction/reminder/robot | 基本一致 (robot 待确认) |
| 升级策略 | WKDBUpgrade.java (版本迁移) | wk_db_helper.dart |
| 线程 | 后台线程执行 | sqflite 内部线程池 |

### 3.4 实时通信层 (Flutter 独有)
Flutter 项目额外设计了 `realtime/` 层:
- **session/** - WebSocket 会话事件网关 (连接 `/v1/realtime/session/events/ws`)
- **call/** - 通话状态机 (FSM 模式)
- **device/** - 设备身份管理与多设备同步

这是 Android 原生项目 **没有的** 架构层级, 体现了 Flutter 项目的架构进化。

---

## 四、Flutter 项目的架构亮点

1. **Clean Architecture 分层**: `auth/` 和 `search/` 模块已实现 domain/data/application/presentation 四层
2. **Riverpod 响应式**: 替代了 Android 的手动 Listener, 更安全
3. **音视频通话已集成**: LiveKit + WebRTC + 信令网关 + TURN, Android 原版无此功能
4. **设备会话管理**: 多设备在线/踢人/设备列表, 超出 Android 原版
5. **朋友圈模块**: moments 功能, Android 原版未实现
6. **会话事件 WebSocket**: 独立的实时事件通道, 不混在 IM 长连接中

---

## 五、当前风险点

1. `modules/group/` 目录为空 — 群组管理页面尚未实现
2. `wukong_crypto/` 仅有 models 和 exports — 端到端加密逻辑待补全
3. 依赖 `WuKongIMFlutterSDK-master` 本地 path 引用, 未发布独立包
4. 后端有多个测试用容器运行中 (avatar-test-*, task2-go-*) 需要清理

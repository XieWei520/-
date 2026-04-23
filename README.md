# 悟空IM - Flutter多端即时通讯应用

基于唐僧叨叨/悟空IM开源项目移植的Flutter多端IM应用，支持Android、iOS、Web、MacOS、Windows、Linux平台。

## 功能特性

### 已实现功能
- [x] 用户登录/注册
- [x] 会话列表
- [x] 聊天页面
- [x] 文本消息收发
- [x] 图片消息
- [x] 语音消息
- [x] 通讯录
- [x] 好友列表
- [x] 群聊列表
- [x] 好友申请处理
- [x] 黑名单管理

### 待实现功能
- [ ] 视频消息
- [ ] 位置消息
- [ ] 文件消息
- [ ] 名片消息
- [ ] 消息撤回/删除
- [ ] 消息搜索
- [ ] 收藏功能
- [ ] 朋友圈
- [ ] 音视频通话
- [ ] 表情商店

## 技术架构

```
lib/
├── core/                    # 核心配置
│   ├── config/             # 应用配置
│   ├── constants/          # 常量定义
│   └── utils/              # 工具类
├── data/                    # 数据层
│   ├── models/             # 数据模型
│   └── providers/         # Riverpod状态管理
├── service/                 # 服务层
│   ├── api/                # HTTP API服务
│   └── im/                 # IM服务封装
├── modules/                 # 业务模块
│   ├── auth/               # 认证模块
│   ├── chat/               # 聊天模块
│   ├── conversation/        # 会话模块
│   ├── contacts/           # 通讯录模块
│   ├── user/               # 用户模块
│   └── group/              # 群组模块
└── widgets/                 # 公共组件
```

## 快速开始

### 环境要求
- Flutter SDK >= 3.10.0
- Dart SDK >= 3.0.0

### 安装依赖

```bash
cd wukong_im_app
flutter pub get
```

### 运行应用

```bash
# Android
flutter run -d android

# iOS
flutter run -d ios

# Web
flutter run -d chrome

# Windows
flutter run -d windows

# macOS
flutter run -d macos

# Linux
flutter run -d linux
```

## 配置说明

### 修改API地址

编辑 `lib/core/config/api_config.dart` 文件：

```dart
// 开发环境API地址
static const String devBaseUrl = 'http://your-server:5001';

// WebSocket连接地址
static const String devWsAddr = 'your-server:5200';
```

### 修改IM连接地址

编辑 `lib/core/config/im_config.dart` 文件：

```dart
// IM连接地址
static const String connectAddr = 'your-server:5200';
```

## 后端部署

### WuKongIM 部署

```bash
# 1. 连接服务器
ssh root@your-server

# 2. 部署WuKongIM
cd /data/wukongim
docker-compose up -d
```

### TangSengDaoDaoServer 部署

```bash
# 1. 连接服务器
ssh root@your-server

# 2. 部署后端服务
cd /data/tsdaodao
go build -o server .
./server
```

## 项目结构

### 核心模块

| 模块 | 说明 |
|------|------|
| `core` | 核心配置、常量、工具类 |
| `data` | 数据模型、状态管理 |
| `service` | API服务、IM服务 |
| `modules` | 业务功能模块 |
| `widgets` | 公共UI组件 |

### 依赖关系

```
modules (业务层)
    ↓
service (服务层)
    ↓
data (数据层)
    ↓
core (核心层)
```

## 开发指南

### 添加新的消息类型

1. 在 `lib/core/constants/im_constants.dart` 中定义消息类型常量
2. 在 `lib/modules/chat/chat_page.dart` 的 `_buildContent` 方法中添加消息渲染逻辑
3. 在对应的消息发送逻辑中添加处理

### 添加新的页面

1. 在 `lib/modules/` 下创建新模块目录
2. 实现页面组件
3. 在路由配置中添加路由

## 开源项目引用

本项目基于以下开源项目开发：

- [WuKongIM](https://github.com/WuKongIM/WuKongIM) - 分布式IM通讯层
- [WuKongIMFlutterSDK](https://github.com/WuKongIM/WuKongIMFlutterSDK) - Flutter SDK
- [TangSengDaoDao](https://github.com/TangSengDaoDao/TangSengDaoDaoServer) - 唐僧叨叨服务端
- [TangSengDaoDaoAndroid](https://github.com/TangSengDaoDao/TangSengDaoDaoAndroid) - Android Demo
- [TangSengDaoDaoiOS](https://github.com/TangSengDaoDao/TangSengDaoiOS) - iOS Demo
- [TangSengDaoDaoWeb](https://github.com/TangSengDaoDao/TangSengDaoDaoWeb) - Web Demo

## 许可证

本项目遵循原开源项目的许可证。

## 联系方式

如有问题，请提交Issue或联系开发者。

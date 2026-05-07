# 飞书群到 IM 群同步：云端控制台 + 本地 Agent 设计

## 读者与目标

本文面向后续实现该功能的工程师、产品负责人和运维人员。读完后，读者应能把“飞书群消息实时同步到用户 IM 群”的产品拆成可实现的云端控制面、本地 Agent、消息转发与安全边界，并据此编写实施计划。

## 背景

目标用户是飞书群普通成员。他们希望把自己可见的飞书群新闻消息实时同步到自己的 IM 群。由于普通成员通常无法申请飞书开放平台的群消息敏感权限，不能依赖官方机器人 API 读取群内所有消息。因此采用客户端可见内容自动化方案：本地 Agent 使用用户自己的飞书 Web 登录态，监听用户已经能看到的群消息，再转发到用户配置的 IM 群。

该方案必须避免把飞书账号、密码、Cookie 或登录态集中保存到云端。云端只负责控制台、配置、设备管理、监控和可选消息中转。

## 目标

- 支持多用户发布使用，云服务器不为每个用户运行飞书浏览器。
- 飞书登录态保存在用户本地设备。
- 支持近实时同步飞书群文本与链接消息到 IM 群。
- 支持本地去重、失败重试和断线恢复。
- 云端可查看 Agent 在线状态、最近同步时间和错误状态。
- 默认模式下，飞书消息正文不经过云端。
- 为后续图片、文件、多群、云端 Relay、计费和企业审计保留扩展点。

## 非目标

- 不绕过飞书权限或风控。
- 不逆向飞书私有接口。
- 不读取飞书客户端本地数据库。
- 不上传飞书 Cookie、账号密码或完整浏览器 Profile。
- 第一版不保证同步所有附件、合并转发、表情包、卡片消息、撤回和编辑事件。
- 第一版不做完整 SaaS 团队权限系统。

## 推荐架构

采用控制面与数据面分离：

```text
用户设备
┌────────────────────────────┐
│ Local Agent                 │
│  - 维护飞书 Web 登录态       │
│  - 打开目标飞书群页面        │
│  - 监听新消息 DOM            │
│  - 本地去重与失败队列        │
│  - 直接转发到 IM 群          │
└──────────────┬─────────────┘
               │ 配置 / 心跳 / 指令 / 错误摘要
               ▼
云端控制台
┌────────────────────────────┐
│ Cloud Control Plane         │
│  - 用户与设备管理           │
│  - 同步规则配置             │
│  - Agent 状态监控           │
│  - 可选云端 Relay            │
└────────────────────────────┘
```

默认路径是本地直发：

```text
飞书 Web 页面 → Local Agent → IM 群 Webhook/API
```

可选企业路径是云端 Relay：

```text
飞书 Web 页面 → Local Agent → Cloud Relay → IM 群 Webhook/API
```

## 运行模式

### 本地直发模式

本地 Agent 从云端拉取同步规则，但 IM 目标密钥保存在本地，消息由 Agent 直接发到 IM 群。

优点：隐私风险最低，云端压力最小，适合面向大量普通用户发布。

限制：用户设备必须在线；本地网络必须能访问 IM 接口；云端无法统一做消息级审计。

### 云端 Relay 模式

本地 Agent 采集并标准化消息后发送到云端队列，由云端统一转发到 IM。

优点：便于统一重试、审计、限流、计费和多 IM 平台适配。

限制：飞书消息正文经过云端，必须增加数据隔离、加密、访问审计和合规说明。

第一版只实现本地直发模式。云端 Relay 作为接口和数据模型预留，不进入 MVP。


## 管理系统入口与页面信息架构

产品前台采用按平台拆分的一级入口，而不是把所有平台混在同一个“通用监控中心”里。这样更符合用户的直觉，也便于后续按平台展示不同登录方式、运行状态和使用限制。

管理系统入口建议展示为：

```text
管理系统
├─ 飞书信息监控中心
├─ 钉钉信息监控中心
├─ 小鹅通信息监控中心
└─ 其他平台信息监控中心
```

第一版只实现“飞书信息监控中心”。钉钉和小鹅通入口可以先作为预留卡片展示“即将上线”，不进入第一版开发范围。

### 飞书信息监控中心定位

飞书信息监控中心承载当前第一版能力：

```text
飞书 Web 群消息 → 悟空 IM 群
```

页面文案建议：

```text
飞书信息监控中心
实时监听你已登录飞书账号可见的群消息，并自动转发到悟空 IM 群。
```

页面需要明确提示该能力依赖用户本地 Windows Agent 和用户本人飞书 Web 登录态。不要让用户误解为云端已经获得飞书官方 API 授权。

### 飞书中心页面排版

页面排版应对齐当前管理系统和工作台风格，采用“顶部说明 + 状态卡片 + 主操作 + 规则列表 + Agent 设备 + 最近日志”的结构。

```text
飞书信息监控中心
实时监听你已登录飞书账号可见的群消息，并自动转发到悟空 IM 群。

┌────────────┐ ┌────────────┐ ┌────────────┐
│ 运行中规则  │ │ 今日转发    │ │ 异常提醒    │
│ 1          │ │ 28         │ │ 0          │
└────────────┘ └────────────┘ └────────────┘

[新建飞书监控规则] [下载 Windows Agent]

监控规则
┌────────────────────────────────────┐
│ 新闻群 → 悟空 IM 新闻群             │
│ 来源：飞书 Web 群                   │
│ 状态：运行中                        │
│ 最近转发：2026-05-06 16:32          │
│ 今日转发：28 条                     │
│ [暂停] [查看日志] [编辑]             │
└────────────────────────────────────┘

Windows Agent
┌────────────────────────────────────┐
│ COLORFUL-PC                         │
│ 平台：Windows                       │
│ 版本：0.1.0                         │
│ 状态：在线                          │
│ 最近心跳：刚刚                      │
│ [重新配对] [查看日志] [更新 Agent]   │
└────────────────────────────────────┘

最近日志
16:32 已转发 飞书新闻群 → 悟空 IM 新闻群
16:20 Agent 心跳正常
15:58 飞书 Web 登录状态正常
```

### 空状态引导

当用户还没有绑定 Agent 时，飞书中心优先展示引导卡片：

```text
还没有绑定 Windows Agent

1. 下载 Windows Agent
2. 使用配对码绑定设备
3. 扫码登录飞书 Web
4. 创建飞书群转发规则
```

当用户已经绑定 Agent 但没有规则时，展示“新建飞书监控规则”的空状态。

### 新建飞书监控规则流程

第一版使用四步向导：

```text
步骤 1：选择飞书来源
- 来源类型：飞书 Web 群
- 群名称：用户输入，例如“新闻群”

步骤 2：选择转发目标
- 目标类型：悟空 IM 群
- 目标群：从用户有权限的群里选择

步骤 3：设置转发内容
- 文本：开启
- 链接：开启
- 图片：暂不支持，显示后续支持
- 文件：暂不支持，显示后续支持

步骤 4：确认并启动
- 创建规则
- 下发配置到 Windows Agent
```

规则状态包括：运行中、已暂停、需要登录、Agent 离线、目标 IM 异常、页面结构异常。

### 平台入口与底层架构关系

虽然前台入口按平台拆分，但底层仍使用通用 Monitor 架构，避免飞书、钉钉、小鹅通各自重复实现 Agent、规则、日志、心跳和目标转发。

```text
前台页面：飞书信息监控中心 / 钉钉信息监控中心 / 小鹅通信息监控中心
底层模型：monitor_platform / monitor_connector / monitor_source / monitor_destination / monitor_route / monitor_agent
```

当前第一版平台与连接器：

```text
platform: feishu
connector_type: feishu_web_group
route_type: feishu_web_group_to_wukong_im_group
```

后续钉钉和小鹅通只新增平台入口、平台连接器和平台特有配置页，继续复用 Agent 配对、心跳、规则、队列、日志和转发目标模型。
## 本地 Agent 设计

本地 Agent 是数据面的核心。建议使用 Node.js + TypeScript + Playwright + SQLite 实现，后续用 Electron 或 Tauri 包装成桌面托盘应用。

### 模块

```text
Local Agent
├─ Browser Manager
│  ├─ 启动持久化 Chromium Profile
│  ├─ 检测飞书 Web 登录状态
│  ├─ 打开或恢复目标群页面
│  └─ 崩溃后重启浏览器
│
├─ Feishu Watcher
│  ├─ 注入 MutationObserver
│  ├─ 监听新消息节点
│  ├─ 启动时补偿最近可见消息
│  └─ 选择器版本管理
│
├─ Message Extractor
│  ├─ 提取发送人、时间、文本、链接
│  ├─ 标准化消息结构
│  ├─ 生成消息指纹
│  └─ 标记不支持的内容类型
│
├─ Local Queue
│  ├─ SQLite 持久化
│  ├─ 幂等去重
│  ├─ 指数退避重试
│  └─ 死信记录
│
├─ IM Forwarder
│  ├─ Webhook/API 发送
│  ├─ IM 平台限流适配
│  ├─ 错误分类
│  └─ 可选文件上传扩展
│
└─ Cloud Connector
   ├─ 设备配对
   ├─ 拉取配置
   ├─ 上报心跳
   ├─ 上报错误摘要
   └─ 接收暂停、恢复、更新配置等指令
```

### 浏览器运行策略

Agent 使用持久化浏览器 Profile 保存飞书 Web 登录态。首次启动时，Agent 打开登录窗口，用户自行扫码登录。登录后，Agent 自动进入目标群页面并开始监听。

浏览器可以后台运行或最小化运行，但用户设备不能休眠。锁屏通常可以继续工作；断网、休眠、飞书登录失效或页面崩溃会导致同步暂停，Agent 需要在恢复后重连。

### 消息提取策略

第一版只承诺提取：

- 群名称
- 发送人昵称
- 页面可见时间文本
- 正文文本
- 链接 URL
- 观察时间

不支持或弱支持的内容需要显式降级，例如：

- 图片：先输出“收到图片消息”，后续版本再支持截图、缩略图或下载。
- 文件：先输出文件名和可见描述，不强制下载。
- 卡片：提取可见文本，无法提取时输出“收到卡片消息”。
- 合并转发：只同步页面可见摘要。

### 幂等与去重

方案 C 不能获得官方 `message_id`，因此 Agent 生成本地指纹：

```text
fingerprint = sha256(routeId + sourceChatName + senderName + sentAtText + normalizedText + linkUrls + attachmentNames)
```

SQLite 保存最近已处理指纹。转发前先查重。发送成功后记录目标 IM 返回值。发送失败则保留在队列中重试。

### 本地数据保存

本地保存内容：

- Agent 设备凭证
- 飞书浏览器 Profile
- IM 目标密钥，使用系统安全存储或本地加密
- 同步规则缓存
- 消息指纹和发送状态
- 错误日志

默认不长期保存完整飞书消息正文。为支持失败重试，可以短期保存待发送消息，并设置保留期。

## 云端控制台设计

云端是控制面，不承担飞书浏览器运行压力。

### 模块

```text
Cloud Control Plane
├─ Console Web
│  ├─ 用户登录
│  ├─ 设备绑定
│  ├─ 同步规则配置
│  ├─ IM 目标配置向导
│  └─ Agent 状态与错误展示
│
├─ Agent Gateway
│  ├─ 配对码注册
│  ├─ Agent Token 签发
│  ├─ 配置拉取
│  ├─ 心跳接收
│  └─ 远程指令
│
├─ Config Service
│  ├─ 路由规则
│  ├─ 配置版本
│  ├─ 灰度配置
│  └─ 选择器版本发布
│
├─ Optional Relay
│  ├─ 消息入站
│  ├─ 队列
│  ├─ 去重
│  ├─ IM 转发
│  └─ 失败重试
│
└─ Observability
   ├─ Agent 在线状态
   ├─ 同步延迟
   ├─ 失败率
   ├─ 登录失效告警
   └─ 选择器失效率
```

### 云端保存的数据

默认保存：

- 用户账号
- Agent 设备 ID
- Agent 状态
- 同步规则元数据
- IM 目标的非敏感描述
- 错误码和错误摘要
- 最近心跳时间

默认不保存：

- 飞书 Cookie
- 飞书账号密码
- 浏览器 Profile
- 飞书完整消息正文
- 群内成员完整列表

## API 设计

### 通用约定

- API 版本使用路径版本：`/v1`。
- Agent 使用 Bearer Token 鉴权。
- 所有错误使用统一结构。
- 所有批量或列表接口使用游标分页。
- 可重试写请求支持 `Idempotency-Key`。

错误结构：

```json
{
  "error": {
    "code": "agent_not_found",
    "message": "Agent does not exist or is not accessible.",
    "details": {},
    "requestId": "req_abc123"
  }
}
```

### 创建设备配对码

```http
POST /v1/agent-pairing-codes
Authorization: Bearer <user-session-token>
```

请求：

```json
{
  "deviceName": "Alice Windows PC"
}
```

响应 `201 Created`：

```json
{
  "pairingCode": "ABCD-1234",
  "expiresAt": "2026-05-06T12:10:00+08:00"
}
```

### Agent 注册

```http
POST /v1/agents/register
Idempotency-Key: <uuid>
```

请求：

```json
{
  "pairingCode": "ABCD-1234",
  "deviceName": "Alice Windows PC",
  "platform": "windows",
  "agentVersion": "0.1.0"
}
```

响应 `201 Created`：

```json
{
  "agentId": "agent_123",
  "agentToken": "agt_secret_example",
  "configVersion": 1
}
```

### Agent 拉取配置

```http
GET /v1/agents/{agentId}/config
Authorization: Bearer <agent-token>
```

响应 `200 OK`：

```json
{
  "version": 12,
  "pollAfterSeconds": 30,
  "selectorPackVersion": "feishu-web-2026-05-06",
  "routes": [
    {
      "routeId": "route_001",
      "enabled": true,
      "mode": "local_direct",
      "source": {
        "type": "feishu_web",
        "chatName": "新闻群"
      },
      "destination": {
        "type": "im_webhook",
        "displayName": "新闻同步群",
        "secretPlacement": "local"
      },
      "messagePolicy": {
        "includeText": true,
        "includeLinks": true,
        "includeImages": false,
        "includeFiles": false
      }
    }
  ]
}
```

### Agent 心跳

```http
POST /v1/agents/{agentId}/heartbeat
Authorization: Bearer <agent-token>
```

请求：

```json
{
  "status": "online",
  "agentVersion": "0.1.0",
  "activeRoutes": 1,
  "lastObservedMessageAt": "2026-05-06T10:32:05+08:00",
  "lastForwardedMessageAt": "2026-05-06T10:32:06+08:00",
  "queueDepth": 0,
  "lastError": null
}
```

响应 `202 Accepted`：

```json
{
  "serverTime": "2026-05-06T10:32:10+08:00",
  "desiredConfigVersion": 12,
  "commands": []
}
```

### 上报错误摘要

```http
POST /v1/agents/{agentId}/events
Authorization: Bearer <agent-token>
```

请求：

```json
{
  "events": [
    {
      "type": "feishu_login_required",
      "severity": "warning",
      "occurredAt": "2026-05-06T10:30:00+08:00",
      "routeId": "route_001",
      "message": "Feishu Web requires login. User action is needed."
    }
  ]
}
```

响应 `202 Accepted`。

### 可选云端 Relay 入站

```http
POST /v1/relay/messages/batch
Authorization: Bearer <agent-token>
Idempotency-Key: <uuid>
```

请求：

```json
{
  "agentId": "agent_123",
  "routeId": "route_001",
  "messages": [
    {
      "source": "feishu_web",
      "sourceChatName": "新闻群",
      "senderName": "张三",
      "sentAtText": "10:32",
      "observedAt": "2026-05-06T10:32:05+08:00",
      "content": [
        { "type": "text", "text": "新闻正文" },
        { "type": "link", "url": "https://example.com" }
      ],
      "fingerprint": "sha256_example"
    }
  ]
}
```

响应 `202 Accepted`：

```json
{
  "accepted": 1,
  "duplicates": 0
}
```

该接口第一版可以只定义，不实现。

## IM 转发格式

第一版统一转成纯文本或 IM Webhook 支持的 Markdown：

```text
【飞书｜新闻群｜张三｜10:32】
新闻正文
https://example.com
```

如果目标 IM 支持结构化卡片，后续可扩展成标题、正文、链接、附件的富文本卡片。

## 用户流程

```text
1. 用户注册云端账号。
2. 用户在控制台创建设备配对码。
3. 用户下载并启动本地 Agent。
4. Agent 输入配对码并绑定账号。
5. Agent 打开飞书 Web 登录窗口。
6. 用户扫码登录飞书。
7. 用户在控制台配置飞书群名称和 IM 目标。
8. Agent 拉取配置并打开目标飞书群。
9. Agent 监听新消息并转发。
10. 控制台展示在线状态、同步延迟和错误提示。
```

## 失败处理

- 飞书未登录：Agent 暂停同步，通知云端展示“需要重新登录”。
- 目标群找不到：Agent 上报配置错误，控制台提示用户检查群名或手动选择。
- 页面选择器失效：Agent 上报选择器错误，云端可下发新选择器包。
- IM 转发失败：本地队列重试，超过阈值进入死信并告警。
- 电脑休眠或断网：Agent 恢复后重新加载群页面，并补偿最近可见消息。
- 重复消息：本地指纹去重。
- 消息格式不支持：转为可读降级提示，不阻塞后续消息。

## 安全与合规边界

- 只处理用户本人已登录且可见的飞书内容。
- 不绕过飞书权限，不破解客户端，不抓取私有 token。
- 飞书登录态只保存在本地浏览器 Profile。
- IM 密钥优先保存在用户本地系统安全存储中。
- 云端错误日志不得包含完整消息正文，除非用户显式开启诊断模式。
- 用户可在 Agent 中一键暂停同步、退出登录、清除本地数据。
- 企业版如启用云端 Relay，需要单独提供数据处理协议、审计日志和消息保留策略。

## 可观测性指标

Agent 本地：

- 浏览器运行状态
- 飞书登录状态
- 当前路由状态
- 队列深度
- 最近观察消息时间
- 最近成功转发时间
- 最近错误

云端控制台：

- Agent 在线/离线
- 配置版本
- 最近心跳时间
- 同步延迟估算
- 错误类型统计
- 选择器失效率

## MVP 范围

第一版交付：

- Windows 本地 Agent。
- 飞书 Web 持久化登录。
- 监听一个飞书群。
- 同步文本和链接。
- 保留发送人昵称、群名称和页面时间。
- 本地 SQLite 去重与失败重试。
- 本地直发到一个 IM Webhook/API。
- 云端用户账号、设备绑定、配置下发、心跳和错误摘要。

第一版不交付：

- 多群同步。
- 图片和文件完整同步。
- OCR。
- 云端 Relay 正式转发。
- 团队组织权限。
- 计费系统。
- 移动端 Agent。

## 后续演进

1. 图片同步：从页面缩略图或截图裁剪开始，逐步支持上传到 IM。
2. 文件同步：先转发文件名与可见元数据，再评估合规下载能力。
3. 多群多路由：一个 Agent 同时监听多个群。
4. Selector Pack 灰度：云端发布不同飞书 Web 选择器版本。
5. 云端 Relay：为企业用户提供统一审计、重试和多 IM 平台适配。
6. 桌面托盘 UI：显示登录状态、暂停同步、查看失败消息。
7. 自动更新：Agent 安全升级和回滚。
8. 企业部署：私有化控制台和内网 IM 适配。

## 关键决策

- 采用云端控制面 + 本地数据面的架构，避免云端为每个用户运行浏览器。
- 第一版采用本地直发，降低服务器压力和消息隐私风险。
- 使用飞书 Web 页面可见内容监听，不使用官方 API 权限绕过方案。
- 不上传飞书登录态到云端。
- 用本地指纹而不是飞书 message_id 做去重。
- 第一版聚焦文本和链接消息，附件作为后续增强。



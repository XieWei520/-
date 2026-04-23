# IM 全量交互联合测试计划

> 联测对象：Flutter 客户端 + WuKongIM 服务 + TSDD API + Web 后台管理系统

**目标：** 以人工操作 + 实时日志侦听的方式，按业务闭环验证账号鉴权、单聊、群聊、离线重连、后台管控五大模块，并在发现异常时直接定位到后端链路。

**当前环境：**
- 客户端 API 基址：`http://42.194.218.158`
- IM WS 地址：`42.194.218.158:5100`
- 线上域名 / 后台入口：`https://wemx.cc`
- 监控日志：远端 `/tmp/interactive_monitor.log`

**线上监控范围：**
- `wukongim_prod-tsdd-api-1` 容器内 `/home/logs/error.log`、`/home/logs/info.log`
- `wukongim_prod-wukongim-1` 容器内 `/root/wukongim/logs/error.log`、`/root/wukongim/logs/warn.log`、`/root/wukongim/logs/info.log`
- `wukongim_prod-mysql-1` 容器 stdout/stderr
- `wukongim_prod-nginx-1` 容器 stdout/stderr
- 每 30 秒 `top -b -n1` + `docker stats --no-stream`

## 1. 账号鉴权

### 1.1 登录主链路
- 手机号密码登录
- 用户名密码登录
- 登录成功后首页会话列表落地
- 登录成功后 IM 长连接建立成功

### 1.2 登录失败分支
- 错误密码提示
- 不存在账号提示
- 服务端限流 / 风控拦截表现

### 1.3 注册链路
- 发送注册验证码
- 验证码注册成功
- 邀请码 / 昵称补全分支
- 注册后自动进入已登录态

### 1.4 找回 / 修改密码
- 发送找回验证码
- 重置密码后重新登录
- 已登录状态下修改密码

### 1.5 登录二次验证链路
- 触发 `login/check_phone` 二次校验
- 验证码错误提示
- 验证成功后继续完成会话引导

### 1.6 Web/扫码登录桥接
- 获取登录二维码 / UUID
- 手机端确认 Web 登录
- Web 登录状态轮询成功
- 登录确认页参数 `authCode` / `encrypt` 正常透传

### 1.7 设备会话管理
- 拉取当前设备列表
- 踢出单个设备
- 一键退出 PC / Web 会话
- 踢出后本机 / 远端会话状态一致

**重点监控接口 / 日志：**
- `/v1/user/login`
- `/v1/user/usernamelogin`
- `/v1/user/register`
- `/v1/user/loginuuid`
- `/v1/user/loginstatus`
- `/v1/user/devices`
- `/v1/user/pc/quit`
- IM 侧 `auth`、`token verify fail`、`close old conn`、`设备信息不存在`

## 2. 单聊核心

### 2.1 会话初始化
- 登录后会话列表加载
- 首屏最近消息、未读数、置顶状态正确
- 打开会话后历史消息拉取正常

### 2.2 文本消息
- 发送文本
- 对端接收文本
- 会话列表最后一条消息同步刷新
- 返回会话页未读 / 已读状态正确

### 2.3 图片 / 语音消息
- 发送相册图片
- 图片预览打开
- 按住录音、松开发送
- 语音播放与未读小红点消失

### 2.4 聊天增强能力
- 回复消息
- 表情 / reaction
- 置顶消息与置顶清空
- 正在输入状态

### 2.5 消息管理
- 撤回消息
- 编辑消息
- 删除自己消息
- 双向删除消息

### 2.6 搜索与未读处理
- 全局 / 会话内消息搜索
- 清除会话未读
- 语音已读状态同步
- `syncack` 正常推进

**重点监控接口 / 日志：**
- `/v1/message/sync`
- `/v1/message/channel/sync`
- `/v1/message/revoke`
- `/v1/message/edit`
- `/v1/message/search`
- `/v1/message/typing`
- `/v1/message/extra/sync`
- `/v1/message/pinned`
- `/v1/conversation/clearUnread`

## 3. 群聊核心

### 3.1 建群与群资料
- 创建群聊
- 群详情加载
- 群头像 / 群名称 / 群公告修改
- 群二维码展示

### 3.2 群成员管理
- 拉取群成员
- 邀请成员
- 添加成员
- 移除成员

### 3.3 群权限与角色
- 设管理员 / 移除管理员
- 转让群主
- 全员禁言
- 邀请制 / 审批制相关设置

### 3.4 群消息闭环
- 群内文本发送接收
- 群内图片 / 语音发送接收
- 群内回复 / 置顶 / 提醒
- 群系统消息正确到达

### 3.5 群关系变更
- 申请入群 / 扫码入群
- 退群
- 解散群
- 公告历史、提醒事项一致性

### 3.6 群风控能力
- 群黑名单添加 / 移除
- 单成员禁言 / 解除禁言
- 历史消息可见性设置
- 成员置顶权限开关

**重点监控接口 / 日志：**
- `/v1/group/create`
- `/v1/group/my`
- `/v1/groups/{groupNo}`
- `/v1/groups/{groupNo}/members`
- `/v1/groups/{groupNo}/setting`
- `/v1/groups/{groupNo}/managers`
- `/v1/groups/{groupNo}/forbidden/*`
- `/v1/groups/{groupNo}/blacklist/*`
- 群系统消息 `memberJoin/memberQuit/memberRemoved/noticeUpdated/memberApprove`

## 4. 离线重连机制

### 4.1 冷启动恢复
- App 重启后读取本地 token
- 自动恢复已登录态
- Draft / 最近会话恢复
- 恢复期间路由不乱跳

### 4.2 弱网断线重连
- 手动断网后发送失败表现
- 恢复网络后自动重连
- 未收消息补拉成功
- 会话列表与聊天页状态恢复正常

### 4.3 多端并发与会话切换
- 同账号双端并发登录
- 新连接挤掉旧 slave 连接
- 设备会话页同步刷新
- 被踢端提示与状态清理正确

### 4.4 推送与唤起
- 收到推送后进入目标会话
- 恢复会话期间推送事件暂存
- 恢复完成后自动跳转目标聊天

### 4.5 同步补偿
- `message sync` 补偿
- `message extra sync` 补偿
- 未读、已读、语音已读一致
- 清空历史 / 清空未读后状态可持续

**重点监控接口 / 日志：**
- 长连接 connect / reconnect / auth
- `close old conn for slave`
- `message/sync`
- `message/extra/sync`
- `conversation/extra/sync`
- Push 路由桥接与 session restore 日志

## 5. 后台管控

### 5.1 管理后台可用性
- `https://wemx.cc` 登录页打开
- 后台登录成功
- 首页 / 菜单加载成功

### 5.2 用户域管理
- 用户列表查询
- 新增用户 / 编辑用户
- 用户黑名单
- 用户禁用列表

### 5.3 群域管理
- 群列表查询
- 群成员查看
- 群黑名单
- 群禁用列表

### 5.4 内容与审计
- 消息记录查询
- 举报记录查询
- 个人记录 / 操作记录查看
- 违禁词 / 安全策略生效验证

### 5.5 设备与系统设置
- 设备安全页
- App 更新配置页
- 通用设置 / Theme / Currency 等系统配置页
- 配置修改后前台联动验证

### 5.6 后台操作联动前台
- 后台拉黑用户后前台行为变化
- 后台禁用群 / 用户后前台提示
- 后台查询结果与客户端真实状态一致

**后台能力面依据：**
- `user` / `userlist` / `adduser`
- `group` / `grouplist` / `groupmembers`
- `message` / `report` / `record` / `recordpersonal`
- `userblacklist` / `groupblacklist`
- `disablelist` / `groupdisablelist`
- `devicesecurity` / `appupdate` / `setting`

## 执行顺序

1. 账号鉴权
2. 单聊核心
3. 群聊核心
4. 离线重连机制
5. 后台管控

## 当前基线结论

- 线上主链路容器均处于 `running/healthy`
- 已知历史日志中存在旧噪声：
  - TSDD: `【Webhook】没有找到toUser`、`【Friend】好友信息不存在`
  - WuKongIM: 历史 `设备信息不存在`、`token verify fail`、公网探测流量导致的异常首帧 / 非 CONNECT 告警
- 这些历史记录早于本轮联测开始时间；后续以 `/tmp/interactive_monitor.log` 的新增时间戳为准判断本轮问题

# Wukong IM Flutter 迁移真相矩阵

更新于：2026-03-30 00:48 (Asia/Shanghai)

## 1. 本轮已经真实落地的内容

### 1.1 线上头像链路已修复

- 现象：TangSengDaoDao Server 日志持续出现“下载图片失败”“组合群头像失败”。
- 根因：线上 MinIO 缺少 `avatar` 桶默认头像对象；默认头像实际路径为 `/avatar/default/test ({id}).jpg`。
- 已处理：
  - 创建 `avatar` 桶。
  - 开启匿名下载。
  - 补齐默认头像对象 `0..899`。
- 实测：
  - `GET /v1/users/0a13431ca09247439ba5aaafe8f93359/avatar`：`302 -> 200`
  - `GET /v1/users/55ef804cc8b54a79a2ba8cadf17d2981/avatar`：`302 -> 200`
  - `GET /v1/users/u_10000/avatar`：`200`
  - `GET /v1/users/fileHelper/avatar`：`200`
  - 修复后再次检查 `fullstack_tangsengdaodaoserver_1` 近 90 秒日志，未再出现头像下载失败和群头像合成失败。

### 1.2 登录/注册已补上真实设备信息上报

- 根因：服务端只有在 `device != nil` 时才会写入 `device` 表，而 Flutter 原先登录请求只发 `flag`，没有发 `device`。
- 已处理：
  - 在 [`auth_api.dart`](C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\service\api\auth_api.dart#L23) 中统一生成并上报：
    - `device_id`
    - `device_name`
    - `device_model`
  - 覆盖接口：
    - 手机号登录
    - 用户名登录
    - 手机号注册
    - 用户名注册
- 当前状态：
  - 代码已落地。
  - 当前 `flutter analyze` 已可稳定跑完，但仍有项目既有 2 个 warning、7 个 info，未到“无 error/warning/info”状态。
  - 仍需一次真实新登录回归，验证 `device` 表是否开始入库。

### 1.3 活跃入口治理已开始执行

- 第三方登录已按最新范围要求移出本次强制迁移项。
- 登录页已移除第三方登录活跃入口，不再继续暴露一个当前不需要移植的路径。
- 登录页已接入运行时能力探测：
  - 若 Web 登录地址不可达，则 `PC/Web 登录` 按钮直接禁用，并显示真实原因。
- “我的”页与 `PC/Web 登录管理` 页已补充运行态提示：
  - 即使 Web 登录入口未开放，仍可明确保留“已登录会话管理/退出”能力。

### 1.4 群资料页已从壳子推进到真实 API 闭环

- 本轮已补齐 [`group_detail_page.dart`](C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\wukong_uikit\group\group_detail_page.dart) 的真实动作，不再停留在 `TODO` 或本地切换：
  - 读取并展示服务端返回的 `mute/top/show_nick/save/remark/role/member_count`
  - 成员列表跳转用户详情
  - 添加群成员
  - 移除群成员
  - 修改我在本群的昵称（走 `PUT /v1/groups/:group_no/members/:uid`）
  - 修改群名称
  - 设置管理员
  - 移除管理员
  - 转让群主
  - 打开群二维码
  - 编辑群公告
  - 跳转聊天记录搜索
  - 退出群聊 / 群主解散群聊
- [`all_members_page.dart`](C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\wukong_uikit\group\all_members_page.dart) 已补上成员详情跳转。
- [`group.dart`](C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\data\models\group.dart) 与 [`group_api.dart`](C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\service\api\group_api.dart) 已补齐群设置字段解析、频道缓存同步和成员备注更新接口。
- 仍未假装完成的部分：
  - 更细颗粒度的权限治理与端到端线上验收

### 1.7 举报链路已补成原生 Flutter 闭环

- 本轮新增原生举报能力，不再依赖 `report.html` H5 跳转来冒充 Flutter 已迁移：
  - 新增 [`report.dart`](C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\data\models\report.dart) 解析服务端举报分类树。
  - 新增 [`report_api.dart`](C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\service\api\report_api.dart)，真实调用：
    - `GET /v1/report/categories`
    - `POST /v1/reports`
  - 新增 [`report_page.dart`](C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\modules\report\report_page.dart)，支持：
    - 一级/二级举报原因选择
    - 可选图片证据上传
    - 可选补充说明
    - 按服务端真实结果提交
  - [`file_api.dart`](C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\service\api\file_api.dart) 已补 `type=report` 图片上传。
  - [`group_detail_page.dart`](C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\wukong_uikit\group\group_detail_page.dart) 已接入“举报群聊”。
  - [`user_detail_page.dart`](C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\wukong_uikit\user\user_detail_page.dart) 已接入“举报此用户”。
- 当前仍保持真实口径：
  - 代码已接通，尚未拿线上真实账号做人工端到端提交回归。
  - 因此“举报功能”目前应记为客户端已落地、线上待回归验收，而不是直接标绿。

### 1.8 PC/Web 登录链路已补上一处真实协议缺口

- 本轮复核 [`scan_result_page.dart`](C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\wukong_scan\scan_result_page.dart) 时发现：
  - 扫码结果页此前只把 `auth_code` 传给 [`web_login_confirm_page.dart`](C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\wukong_login\web_login_confirm_page.dart)，遗漏了服务端同时返回的 `pub_key`。
  - [`grant_login`](C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\service\api\login_bridge_api.dart) 支持透传 `encrypt/pub_key`，所以这属于客户端真实协议缺口，不是文档问题。
- 已处理：
  - 扫码确认页现在会把 `pub_key` 一并传入确认登录页，避免 Web 登录确认时静默丢失加密参数。
  - 新增 [`scan_service_test.dart`](C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\test\wukong_scan\scan_service_test.dart)，覆盖 `auth_code/pub_key` 解析。
- 当前仍保持真实口径：
  - 这修的是客户端参数透传，不等于 PC/Web 登录端到端已验收完成。
  - 线上仍需一次真实扫码确认回归，验证 `grant_login -> loginstatus -> login_authcode` 全链路。

### 1.9 用户/群二维码已补上真实图片保存能力

- 本轮继续把二维码页从“只能展示和复制字符串”推进到“可真实导出 PNG 文件”：
  - 新增 [`qr_export_utils.dart`](C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\core\utils\qr_export_utils.dart)，使用现有 `qr_flutter + path_provider` 生成二维码 PNG 并保存到下载目录或应用 `downloads` 目录。
  - [`group_qr_page.dart`](C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\wukong_uikit\group\group_qr_page.dart) 已新增“保存二维码图片”入口。
  - [`user_qr_page.dart`](C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\wukong_uikit\user\user_qr_page.dart) 已新增“保存二维码图片”入口。
- 同时修复了一个真实小屏问题：
  - 用户二维码页在较小高度下会发生 `RenderFlex overflow`。
  - 现已将用户/群二维码页统一改为可滚动布局，避免移动端小屏和测试视窗下溢出。
- 当前仍保持真实口径：
  - 已完成“展示 + 复制 + 保存 PNG”闭环。
  - 仍未补“系统分享”能力，所以二维码模块仍应记为“部分完成”，不能直接标绿。

### 1.10 “帮助与反馈 / 关于应用” 已移除空入口状态

- 本轮继续治理 [`user_page.dart`](C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\modules\user\user_page.dart) 里两个原本 `onTap: () {}` 的假完成入口：
  - “帮助与反馈” 已接入 [`help_feedback_page.dart`](C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\modules\user\help_feedback_page.dart)
  - “关于应用” 已接入改造后的 [`about_page.dart`](C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\wukong_uikit\setting\about_page.dart)
- 新页面都不是静态空壳：
  - 帮助与反馈页支持复制运行诊断信息、复制反馈模板、查看当前 Web 登录/手机号搜索/短编号修改的运行态状态说明。
  - 关于应用页支持查看版本、平台、API/WS 地址、设备旗标，并可复制应用信息与打开开源许可证页。
- 当前仍保持真实口径：
  - 这次修的是“空入口”问题，不代表已经补齐外部客服系统、工单系统或应用商店评分链路。
  - 但至少主路径里已经不再存在“能点却什么都不做”的这两个入口。

### 1.11 会话转发与用户详情分享名片已改成真实动作

- 本轮继续清理活跃聊天路径里的假完成：
  - [`chat_page.dart`](C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\modules\chat\chat_page.dart) 的消息“转发”此前只是提示“已转发”，并没有真正向任何会话发送内容。
  - [`user_detail_page.dart`](C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\wukong_uikit\user\user_detail_page.dart) 的“分享名片”此前只是复制 UID，不是发送真实名片消息。
- 已处理：
  - 新增 [`message_forwarding.dart`](C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\modules\chat\message_forwarding.dart)，统一克隆可转发的消息内容类型：
    - 文本
    - 图片
    - 视频
    - 位置
    - 文件
    - 名片
  - [`ForwardMessagePage`](C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\modules\chat\chat_page.dart) 现在会真实加载联系人与群聊，并支持搜索过滤。
  - 聊天页长按消息的“转发”现在会真实把消息重新发送到所选联系人/群聊，不再伪造成功提示。
  - 聊天页“复制”也已改成真正写入系统剪贴板，不再只弹提示文案。
  - 用户详情页“分享名片”现在会打开联系人选择器，并向目标联系人发送真实 `WKCardContent` 名片消息。
- 当前仍保持真实口径：
  - 回复功能仍是明确未完成状态，未被包装成已迁移。
  - 转发当前按客户端重发内容实现，是否与参考端在“合并转发/多选转发”交互上完全一致，仍需后续继续对齐。

### 1.12 会话回复已补成真实发送与展示闭环

- 本轮继续沿会话增强主链路推进，把聊天页原本的“回复功能开发中”占位提示替换成真实闭环：
  - [`chat_page.dart`](C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\modules\chat\chat_page.dart) 现在支持在长按菜单中选择“回复”，并在输入区展示当前回复目标。
  - 发送文本、图片、视频、位置、文件、名片时，都会透传真实 `reply` 元数据，而不是只在本地做假 UI。
  - 发送成功后会自动清除回复态，支持手动取消回复。
- 同时补齐了展示层：
  - 新增 [`message_content_preview.dart`](C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\modules\chat\message_content_preview.dart)，统一处理回复摘要、作者显示和 reply 元数据构造。
  - [`message_bubble.dart`](C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\widgets\message_bubble.dart) 已新增被回复消息预览，能显示原消息发送者和摘要内容。
- 当前仍保持真实口径：
  - 这次完成的是“单条消息回复”的发送与展示闭环。
  - 还没有继续补“点击回复预览跳转到原消息”“多层回复交互细节”这类增强项，因此不能夸大为会话增强已全部完成。

### 1.13 会话草稿已补到“本地持久化 + 远端同步”闭环

- 本轮继续沿会话增强主链路推进，把草稿从“仅当前内存态”补成真实可恢复能力：
  - [`draft_manager.dart`](C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\wukong_base\msg\draft_manager.dart) 现在会按登录 UID 分 scope 持久化草稿，并记录远端同步版本号。
  - [`chat_page.dart`](C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\modules\chat\chat_page.dart) 已支持进入会话时恢复草稿、输入时防抖保存、退出时补一次快照保存。
  - [`conversation_list_page.dart`](C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\modules\conversation\conversation_list_page.dart) 会在列表中显示 `[草稿]` 预览，并用草稿时间覆盖会话摘要时间。
  - 新增 [`conversation_draft_api.dart`](C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\service\api\conversation_draft_api.dart)，真实对接：
    - `POST /v1/conversation/extra/sync`
    - `POST /v1/conversations/{channel_id}/{channel_type}/extra`
  - [`auth_provider.dart`](C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\data\providers\auth_provider.dart) 现在会在已有登录态恢复时也同步草稿 scope，不再只在新登录成功后刷新。
- 当前仍保持真实口径：
  - 当前完成的是“文本草稿内容跨重启可恢复、跨端可同步”的闭环。
  - 回复草稿里的 `replyMsgId/replyContent` 仍是 Flutter 本地增强字段，因为服务端 `conversation_extra.draft` 当前只有字符串草稿字段；这部分还不能包装成完整跨端回复草稿同步。

### 1.5 本轮验证已补齐到代码级

- [`group_test.dart`](C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\test\data\models\group_test.dart) 已新增，覆盖群详情新增字段解析与成员角色 helper。
- [`report_test.dart`](C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\test\data\models\report_test.dart) 已新增，覆盖举报分类树解析。
- [`chat_pages_compile_test.dart`](C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\test\modules\chat\chat_pages_compile_test.dart) 已新增，覆盖聊天页、转发页、联系人选择器与用户详情页的编译烟测。
- [`message_content_preview_test.dart`](C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\test\modules\chat\message_content_preview_test.dart) 已新增，覆盖回复摘要与 reply 元数据构造。
- [`message_forwarding_test.dart`](C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\test\modules\chat\message_forwarding_test.dart) 已新增，覆盖可转发消息内容克隆与目标搜索过滤。
- [`scan_service_test.dart`](C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\test\wukong_scan\scan_service_test.dart) 已新增，覆盖登录确认二维码里的 `auth_code/pub_key` 解析。
- [`qr_pages_compile_test.dart`](C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\test\wukong_uikit\qr_pages_compile_test.dart) 已新增，覆盖二维码页编译与小屏布局烟测。
- [`widget_test.dart`](C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\test\widget_test.dart) 已移除对线上运行态探测的真实网络依赖，避免启动 smoke test 被 pending timer 卡死。
- [`common_api_test.dart`](C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\test\service\api\common_api_test.dart) 已新增，覆盖 `shortno_edit_off` 与 `phone_search_off` 的运行态能力解析。
- [`draft_manager_test.dart`](C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\test\wukong_base\msg\draft_manager_test.dart) 已扩展覆盖：
  - 本地草稿持久化
  - 按 UID 隔离
  - 远端草稿合并
  - 远端草稿更新/删除回写
- 实测结果：
  - `flutter test` 通过（26 tests passed）
  - `flutter analyze` 已可稳定跑完；当前剩余 9 条问题：
    - 2 个 warning：`contacts_page.dart` 两个未引用私有方法
    - 7 个 info：二维码导出 deprecation 与 `friend_api.dart/group_api.dart` 的 null-aware 建议
  - 本轮新增草稿改动未引入新的 analyze error/warning。

### 1.6 我的资料与联系人搜索继续补齐到真实运行态能力

- [`my_info_page.dart`](C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\wukong_uikit\user\my_info_page.dart) 本轮已继续补上真实闭环：
  - 头像上传
  - 昵称修改
  - 性别修改
  - 短编号修改（受 `shortno_edit_off` 运行态能力控制）
  - 我的二维码
- 仍保持诚实只读、未假装完成的字段：
  - 用户名：服务端未提供修改接口
  - 地区：服务端未提供更新接口
  - 个性签名：服务端未提供更新接口
- [`add_friends_page.dart`](C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\lib\wukong_uikit\search\add_friends_page.dart) 已接入运行态能力：
  - 若服务端关闭手机号搜索，搜索提示和页面说明会实时收敛，不再默认宣传手机号搜索能力

## 2. 2026-03-29 线上环境实测结论

| 项目 | 实测结果 | 结论 |
|---|---|---|
| `http://103.207.68.33:8090/v1/ping` | 返回 200 | API 服务在线 |
| 容器状态 | `fullstack_tangsengdaodaoserver_1 / fullstack_wukongim_1 / fullstack_web_1 / minio / redis / mysql` 均在运行 | 基础运行环境在线，Web 静态服务已补起 |
| `/v1/common/appconfig` | 返回 `web_url: http://103.207.68.33:82` | 服务端对外宣称存在 Web 登录地址 |
| `GET http://127.0.0.1:82` | 返回 `200` | 82 端口已监听，Web 首页可达 |
| `GET http://127.0.0.1:82/api/v1/ping` | 返回 `{"status":200}` | Web 反向代理已能转发到现有 8090 API |
| `GET /v1/user/loginuuid?device_id=codexprobe456...` | 返回 `uuid + qrcode`；Redis 同时出现 `qrcode:<uuid>` 与 `deviceCacheUUID:<uuid>` | Web 登录二维码生成与设备缓存写入链路已实测成立 |
| Redis `GET deviceCacheUUID:<uuid>` | 返回 `device_id/device_name/device_model` 完整 JSON | 设备信息不是在二维码阶段丢失，后续应重点看扫码确认与最终 `login_authcode` 收口 |
| `user` 表 | 15 行 | 当前用户量较小，适合快速回归 |
| `is_upload_avatar=1` | 2 行 | 上传头像链路也已纳入验证 |
| `device` 表 | 0 行 | 设备入库链路当前仍未闭环 |
| `device` 表结构 | 仅有 `uid/device_id/device_name/device_model/last_login`，没有 `device_flag` 列 | 当前 live 库结构与此前口头假设不同，后续排查必须按真实表结构进行 |
| `device_flag` 表 | 0/1/2 分别为手机/Web/PC | 设备类型基础枚举存在，但不等于 `device` 表里已有设备记录 |
| `app_config` 表 | 仅见 RSA/super_token/revoke/search 等字段，没有 `web_url` 字段 | `web_url=:82` 不是简单来自 `app_config` 表 |
| `/data/build/TangSengDaoDaoServer/assets/web` | 仅有 `join_group.html`、`invite_detail.html`、`report.html` 等静态页 | 线上主机当前未发现可直接顶上 Web 登录的完整 Web IM 构建产物 |
| WuKongIM 日志 | 多次出现 `设备信息不存在`，主要为 `deviceFlag:1` | Web 侧设备注册/映射链路仍有问题 |

## 3. 关键技术真相

### 3.1 不能把开源 Server 直接替换线上 paid 镜像

- clean 开源源码可以构建，但替换现网 paid 镜像时启动失败。
- 已确认 paid 镜像/数据库存在开源仓库没有的 migration 记录：
  - `extra-20260326-01.sql: unknown migration in database`
- 结论：
  - 现阶段不能把“开源 Server 重编译”当成现网修复路径。
  - 后端变更只能走：
    - paid 运行时配置/存储修复
    - 拿到 paid 代码或 migration 层后再重构
    - 严格控制在不影响 paid migration 历史的范围内

### 3.2 `webLoginURL` 的来源仍未查清，但 `:82` 可达性已恢复

- `/data/fullstack/configs/tsdd.yaml` 里的 `external.webLoginURL` 当前为空。
- 但 `/v1/common/appconfig` 实际返回了 `web_url=http://103.207.68.33:82`。
- 本轮已补起 `:82` 静态 Web 服务，首页和 `/api/v1/ping` 均已实测可达。
- 结论：
  - 现在不能简单说“Web 登录地址为空”，因为 paid 运行态确实对外返回了 `:82`。
  - 也不能把“端口已可达”直接等价成“PC/Web 登录已经验收完成”。
  - 真实状态应标记为：
    - “服务端返回了 Web 登录地址，且当前 Web 服务已恢复可达”
    - “但扫码登录确认、状态轮询、PC 退出还未重新做端到端验收”

### 3.3 `web_url=:82` 当前既不是宿主配置值，也不是 `app_config` 表字段

- `fullstack_tangsengdaodaoserver_1` 当前只挂载了 `/home/configs/tsdd.yaml`、`/home/data`、`/home/logs`。
- 容器内 `/home/configs/tsdd.yaml` 与宿主机 `/data/fullstack/configs/tsdd.yaml` 一致，`external.webLoginURL` 仍为空。
- live MySQL 的 `app_config` 表也未发现 `web_url` 相关字段。
- 结论：
  - `web_url=http://103.207.68.33:82` 更可能来自 paid 运行时的默认值、二次注入或其它未暴露配置层。
  - 在没有拿到 paid 代码或更完整运行态配置前，不能声称“只要改 tsdd.yaml 就能闭环 Web 登录”。

### 3.4 Web 静态服务已恢复，但 PC/Web 登录还不能提前标绿

- 本轮已用本地 [`TangSengDaoDaoWeb-main`](C:\Users\COLORFUL\Desktop\WuKongIM\TangSengDaoDao\TangSengDaoDaoWeb-main) 成功构建 `apps/web/build`。
- 已将构建产物部署到服务器 `/data/fullstack/web/build`，并以 `nginx:1.27-alpine` 容器形式启动 [`fullstack_web_1`](C:\Users\COLORFUL\Desktop\WuKongIM\wukong_im_app\docs\migration_truth_matrix.md)：
  - 对外端口：`82 -> 80`
  - 所在 network：`fullstack_default`
  - `/api/` 已反代到 `fullstack_tangsengdaodaoserver_1:8090`
- 当前真实状态：
  - Web 首页可达
  - API 代理可达
  - Flutter 运行态探测已不应再因 `:82` 不可达而禁用入口
  - 但“扫码登录确认、状态轮询、PC 退出”的端到端场景还未重新验收，因此 PC/Web 登录仍只能记为“部分完成”

### 3.5 第三方登录已移出本次迁移范围

- 用户在 2026-03-29 明确说明：`第三方登录不需要移植`。
- 因此本轮不再把 GitHub/Gitee OAuth 当成移动端 100% 对齐阻塞项。
- 已执行动作：
  - 登录页活跃入口移除。
  - 后续不再继续投入第三方登录移植开发。
- 备注：
  - 线上服务端相关接口仍存在。
  - 如果未来重新纳入范围，需要重新评估 OAuth 配置与 Flutter 端流程。

## 4. 功能迁移矩阵

| 模块 | Flutter 当前状态 | 线上/服务端状态 | 当前判定 | 下一步 |
|---|---|---|---|---|
| 基础登录注册 | 主流程可用；本轮补上设备信息上报 | API 在线；设备入库待验证 | 部分完成 | 用真实登录验证 `device` 表写入 |
| 用户名登录 | 已实现 | API 在线 | 部分完成 | 验证设备入库与错误回归 |
| 扫码 | 已有真实扫码页与结果分流基础 | 仍需端到端验收 | 部分完成 | 验收登录/加好友/加群/分享码四类分流 |
| PC/Web 登录 | 已有二维码页、状态轮询、确认页；登录页已按运行态治理入口 | `web_url` 已返回且 `:82` 已恢复可达，但扫码登录端到端尚未复验 | 部分完成 | 重新验收扫码登录、确认、状态轮询与 PC 退出闭环 |
| 第三方登录 | 已移出本次范围 | 不纳入本轮阻塞 | 范围外 | 不继续投入 |
| 会话聊天主链路 | 文本、图片、语音、视频、文件等主链路已具备；消息转发、单条回复、草稿本地持久化与远端同步已接通真实链路 | 后端在线；草稿扩展接口已存在 | 部分完成 | 继续对齐反应、@、输入中，并补回复/转发/草稿的线上跨端回归 |
| 联系人/好友 | 主流程已具备；添加好友页已按运行态能力治理手机号搜索提示 | API 在线 | 部分完成 | 补齐申请、备注、资料闭环验收 |
| 群组管理 | 群资料页已接通成员、公告、群名、群内昵称、管理员、转让群主、二维码、搜索、举报、退群/解散真实接口 | 群头像问题已修，群设置/成员/举报接口可用 | 部分完成 | 做举报与管理员能力的线上端到端验收，并继续补更细权限治理 |
| 用户资料/我的资料 | 已接通头像、昵称、性别、短编号、二维码；用户详情已接入举报与真实分享名片；“帮助与反馈 / 关于应用” 不再是空入口；用户名/地区/签名仍保持真实只读 | 头像链路已恢复；`shortno_edit_off=0`；举报接口在线 | 部分完成 | 继续补用户详情剩余闭环与只读字段说明，并做分享名片线上回归 |
| 用户/群二维码 | 已改为真实二维码渲染，并补上复制与 PNG 保存，不再伪造网络图片 | API 基础具备 | 部分完成 | 继续补系统分享与扫码互通 |
| 推送 | 基本未落地 | 配置未见启用 | 未完成 | 先打通 token 注册，再做前后台与离线推送 |
| 音视频 | 原型/入口存在 | 未完成服务端信令对接 | 未完成 | 改接 `/call/signal` 与房间信令 |
| 表情包/反应 | 仅部分 | 缺远程数据与持久化 | 未完成 | 先做真实数据源，再做同步 |
| 工作台 | 不纳入本轮移动端阻塞 | 非本次主目标 | 范围外 | 单独建 backlog |

## 5. 当前最重要的阻塞项

### P0 已完成

- 头像 302/404 导致的群头像合成失败。

### P0 仍未完成

- `device` 表仍为 0 行。
- WuKongIM `deviceFlag:1` 设备不存在日志仍未闭环验证。
- PC/Web 登录的端到端扫码闭环还未在恢复后的 `:82` 环境下重新验收。

### P1 直接后续动作

1. 用修复后的 Flutter 客户端完成一次真实登录。
2. 验证 `device` 表是否开始写入。
3. 再看 WuKongIM `deviceFlag:1` 日志是否下降或消失。
4. 在已恢复的 `:82` Web 环境上重新验收扫码登录。
5. 继续推进用户详情剩余闭环、会话反应/@/输入中等能力，并对新接入的举报/回复能力做线上回归验收。

## 6. 执行顺序

### 阶段 A：关掉假完成

- 活跃路径只允许暴露真实可用功能。
- 若配置未到位，必须隐藏入口或明确置灰说明。

### 阶段 B：先完成环境闭环

- 恢复 Web 端可达性。
- 验证设备入库链路。
- 闭环 `deviceFlag` 相关日志问题。

### 阶段 C：再补客户端对齐

- 群详情、用户详情、我的资料全部切到真实 API 持久化。
- 会话增强逐项补齐：
  - 撤回
  - 反应
  - @成员
  - 输入中
  - 搜索
  - 收藏/转发一致性

### 阶段 D：平台能力补齐

- 推送
- 音视频
- 表情包远程数据与同步

### 阶段 E：回归与门禁

- `flutter analyze` 无 error，且 warning/info 已审计到可接受范围。
- 活跃路径无 demo 假流程。
- 线上关键日志清零或下降到可解释范围。
- 功能矩阵无红项，也没有“入口存在但不可用”的黄项。

## 7. 什么才算 100% 完成

只有同时满足以下条件，才能把“Wukong IM Flutter 全量对齐迁移”标记为完成：

1. 功能矩阵全部转绿。
2. Web 实际可达性、设备入库、推送等线上配置全部闭环。
3. 端到端必跑场景全部通过。
4. 线上不再持续出现头像失败、设备缺失、扫码登录失败等关键错误日志。
5. 不再存在“页面能点开，但实际是占位/模拟/未配置”的活跃入口。

# Spec: WildfireChat 项目全面分析

## Objective
系统分析 `wildfirechat` GitHub 组织下的开源项目，形成可长期复用的中文工程笔记。

目标读者是正在评估、部署、迁移或二次开发 WildfireChat/WuKong 风格 IM 系统的工程师。读完后应能判断：

- 哪个仓库负责哪类能力。
- 核心 IM 服务端、应用服务端、客户端和 SDK 如何组成完整系统。
- 登录、连接、消息收发、群组、推送、存储、管理后台等关键链路如何工作。
- 二次开发时应优先改哪里，哪些地方需要谨慎。

## Tech Stack
按仓库逐步确认。已确认或待确认的技术栈包括：

- Java / Maven / Spring Boot 服务端项目。
- Android Java/Kotlin 客户端。
- iOS Objective-C/Swift 客户端。
- Vue / React / UniApp / Flutter / Qt / PC 客户端。
- 多语言服务端 SDK。

## Commands
分析阶段常用命令：

- 查看当前仓库状态：`git status --short`
- 克隆仓库：`git clone --depth 1 https://github.com/wildfirechat/<repo>.git .codex_tmp/wildfirechat/<repo>`
- 查看目录：`Get-ChildItem -Force`
- 递归列文件：`Get-ChildItem -Recurse -File`
- 搜索源码：`Select-String -Path '<paths>' -Pattern '<pattern>' -CaseSensitive:$false`
- GitHub 组织页面抓取：`Invoke-WebRequest -UseBasicParsing -Uri https://github.com/orgs/wildfirechat/repositories?page=1&type=all`

具体构建和测试命令写入对应仓库笔记。

## Project Structure
本工作区新增分析资料：

- `docs/wildfirechat-analysis/SPEC.md`: 分析规格和边界。
- `docs/wildfirechat-analysis/TASKS.md`: 分阶段阅读任务。
- `docs/wildfirechat-analysis/PROJECT-NOTES.md`: 长期项目笔记入口。
- `docs/wildfirechat-analysis/repos/`: 单仓库深入笔记。
- `.codex_tmp/wildfirechat/`: 源码分析缓存，不作为业务代码变更。

## Code Style
本任务主要产出 Markdown 笔记，不产出业务代码。笔记风格示例：

```markdown
## 仓库职责
`im-server` 是核心 IM 服务端，负责长连接、消息路由、会话、群组、频道和服务端管理能力。

## 关键入口
- 启动入口：`cn.wildfirechat.server.Server.main`
- 配置入口：`config/wildfirechat.conf`
- 协议入口：MQTT topic `MS` / `MN`

## 已确认事实
- 事实必须来自源码、README、构建文件或官方仓库页面。
- 推断必须标注为“推断”。
```

## Testing Strategy
本任务是阅读和文档分析，不修改被分析项目的业务逻辑。验证方式：

- 仓库列表来自 GitHub 组织页或本地克隆结果。
- 每个仓库笔记至少交叉检查 README、构建文件、目录结构。
- 核心仓库额外检查启动入口、配置文件、关键包和测试目录。
- 笔记中区分“已确认事实”和“推断”。

## Boundaries
- Always: 只在 `docs/wildfirechat-analysis/` 和 `.codex_tmp/wildfirechat/` 下新增分析资料和源码缓存。
- Always: 记录来源和不确定性，不把推断写成事实。
- Always: 优先分析 `im-server`、`app-server`、主客户端和 SDK。
- Ask first: 修改当前 WuKong 工作区业务代码。
- Ask first: 删除已有文件或清理用户未提交改动。
- Ask first: 长时间克隆全部仓库或下载大体积二进制资源。
- Never: 提交密钥、修改第三方仓库源码、覆盖用户本地改动。

## Success Criteria
- 形成 WildfireChat 组织级仓库地图。
- 完成核心仓库 `im-server` 的源码级结构分析。
- 完成 `app-server`、服务端 SDK、主客户端的关键链路分析。
- 形成核心系统关系图和关键链路笔记。
- 形成后续阅读任务清单，能在新会话中继续接力。
- 笔记文件保存在本仓库，可被后续上下文重新读取。

## Open Questions
- 是否需要克隆并分析全部公开仓库，还是先完成主 IM 链路闭环。
- 最终输出应偏部署落地、二次开发、竞品替代方案评估，还是安全审计。
- 是否允许后续为完整分析启动更长时间的批量克隆和索引任务。

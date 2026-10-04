# AI 跨会话记忆系统部署与维护

> **这是什么**：将 `@Huiyu-Skill_memory-system` v3.9.1 蒸馏为可执行的跨会话记忆方案，覆盖项目记忆、用户画像、跨项目随行记忆、唤醒词、POST 巩固流程与 Skill 生命周期钩子。
>
> **原作者**：灰语
> **推荐度**：L2（可以参考学习）——压缩包包含完整 Skill 与模板，但本文未在所有宿主环境中独立验证自动触发、自动写回和钩子整合效果；部署前应按宿主的权限模型适配。
> **适用场景**：需要跨会话恢复项目状态、沉淀决策与避坑经验、跨项目继承用户偏好，或希望多个 Skill 共享生命周期的 AI 编程工作流。
>
> **同类对比**：
> - **特色**：这是一个“元 Skill”，重点是自动恢复、任务结束后的 POST 巩固，以及把跨项目记忆放到 Skill 目录之外；不是向量数据库检索器。
> - **优点**：文件化、可审计、无需额外数据库；用 `CLAUDE.md` 和 `memory-index.md` 提供低成本启动入口，用 `preferences.json` 和 `antibodies.md` 迁移跨项目经验。
> - **缺点**：依赖宿主支持会话注入、任务清单和文件写入；自动扫描并修改其他 Skill 的钩子存在误整合风险；与 `CLAUDE.md`、`TodoWrite` 等约定不兼容的环境需要改写。

---

## 1. 核心模型

记忆系统把信息分成三类，并用不同文件承载：

| 层级 | 主要内容 | 典型位置 | 读取时机 |
|------|----------|----------|----------|
| 项目状态 | 当前进度、关键文件、决策、避坑、下一步 | `CLAUDE.md`、`docs/memory-index.md`、`docs/decisions/` | 每次会话启动 |
| 用户与跨项目记忆 | 用户画像、偏好、跨项目抗体、项目足迹 | `docs/persona.md`、`.agent/memory-runtime/` | 首次部署、跨项目唤醒、POST-3 |
| Skill 生命周期 | 其他 Skill 的启动、首次部署和 POST 同步需求 | 各 Skill 的 `SKILL.md` 中的 hooks | 会话恢复和 POST 阶段 |

关键原则：

1. `CLAUDE.md` 是最短、最重要的启动快照；正文建议不超过 40 行。
2. `docs/memory-index.md` 是项目详细索引；建议不超过 60 行，过长内容移到 `docs/archive/`。
3. `docs/persona.md` 保存用户画像与项目足迹，不把一次性的项目细节写进用户级记忆。
4. 运行时数据不放进可分发的 Skill 目录，而放在 `.agent/memory-runtime/`。
5. 读取记忆不应顺便改写记忆；写回只发生在明确的 POST、项目切换或紧急压缩保护阶段。

## 2. 触发条件

可按以下信号触发记忆系统：

- 每次新会话的首条消息：检查是否需要恢复项目记忆。
- 用户说“部署记忆系统”“添加记忆”“初始化记忆”“开始”。
- 用户要求 AI 记住项目上下文、技术决策或个人偏好。
- 用户提到 POST、记忆巩固、会话恢复或跨项目继承。
- 用户切换到新项目，希望保留之前的偏好与经验。
- 用户说出保存在 `preferences.json` 中的唤醒词。

首次激活判断：

```text
项目根目录没有 CLAUDE.md
或 CLAUDE.md 缺少恢复指令段落
→ 视为首次激活或跨项目唤醒
```

“安装后首条消息自动部署”是原 Skill 的设计，不是所有宿主都能安全支持的默认行为。若宿主要求用户确认写入、禁止自动提交或没有 `TodoWrite`，应把这部分映射为宿主允许的流程。

## 3. 首次部署

首次部署的目标不是只创建一个记忆文件，而是建立完整的读写闭环：

1. 创建项目目录：
   - `docs/decisions/`
   - `docs/archive/`
   - `docs/templates/`
2. 从模板创建：
   - `docs/memory-index.md`
   - `docs/persona.md`
   - `docs/versions.md`
   - `docs/templates/decision.md`
   - `.agent/memory-runtime/antibodies.md`
   - `.agent/memory-runtime/preferences.json`
3. 创建项目根 `CLAUDE.md`，写入恢复指令、状态快照和避雷清单。
4. 检查已有随行记忆：有则恢复，无则进行最小人格初始化。
5. 检查并执行其他 Skill 的 `on_first_activate` 钩子。
6. 如宿主和用户授权允许，再将初始化结果纳入版本控制。

首次人格初始化只询问四项：

1. 希望如何称呼用户，以及助手如何自称；
2. 喜欢的沟通风格；
3. 技术背景；
4. 是否为助手设置跨项目唤醒词。

其余画像通过协作自然观察，不要把首次部署变成冗长问卷。

## 4. 每次会话恢复

启动时按以下顺序读取：

1. `CLAUDE.md`：确认项目状态、避雷清单和恢复指令。
2. `docs/memory-index.md`：恢复项目概况、关键文件、决策和下一步。
3. `docs/persona.md`：加载用户画像和偏好。
4. 仅在被索引引用时读取 `docs/decisions/`；只有需要历史细节时才读取 `docs/archive/`。
5. 在开始工作前自测三问：
   - 这个项目是什么，关键文件在哪里？
   - 上次交付了什么？
   - 下一步和关键约束是什么？

如果答案不完整，只补读对应文件，不要每次全量扫描项目。

## 5. POST：防止任务完成后记忆断裂

POST 是任务结束时的记忆巩固流程。最重要的操作不是“最后记得写”，而是**收到任务后就把 POST 预先写入任务清单**，防止上下文压缩后遗忘。

对于任何非纯讨论任务，先创建：

```text
DEV: [具体任务]
POST-1 更新记忆：CLAUDE.md + memory-index.md + persona.md
POST-2 持久化：versions.md + 版本控制提交
POST-3 同步随行记忆：.agent/memory-runtime/
```

每个 POST 条目必须经过“执行/跳过”判定：

- 执行：完成对应写回并标记完成。
- 跳过：在条目中写明理由后再标记完成。
- 禁止直接删除 POST 条目，禁止不判定就跳过，也不能因为上次跳过而默认本次跳过。

### POST-1：更新项目记忆

- `CLAUDE.md`：刷新版本、进度、上次交付、`likely_next_task`、相关文件和活跃避雷条目。
- `docs/memory-index.md`：记录本次改动、原因、关键文件和下一步；超过约 60 行时归档旧记录。
- `docs/persona.md`：补充明确偏好，或把尚未确认的观察标为 `[observed]`；发现持续变化时标为 `[drift]`。

### POST-2：持久化

- 在 `docs/versions.md` 顶部追加版本、日期和变更摘要。
- 如果项目使用 Git，按项目规范提交变更。
- 如果项目不使用 Git，仍执行 `versions.md` 更新，但不要擅自初始化或提交仓库。

### POST-3：同步随行记忆

将跨项目通用信息合并到 `.agent/memory-runtime/`，同时保留项目本地副本：

| 文件 | 合并策略 |
|------|----------|
| `persona.md` | 基础画像和工作特征采用最新值；项目足迹追加去重；观察笔记合并计数 |
| `antibodies.md` | 只追加标记为 `[跨项目]` 的避坑条目，并按内容去重 |
| `preferences.json` | 标量字段最新值优先；对象深度合并；数组合并去重 |

小调整可以将 POST-3 判定为跳过，但必须把理由写进任务清单；新功能、Bug 修复、项目切换和上下文即将压缩时，默认执行完整 POST。

## 6. 跨项目随行记忆与唤醒词

当新项目没有 `CLAUDE.md`，但 `.agent/memory-runtime/` 中已有记忆时，按以下顺序处理：

1. 从随行记忆恢复 `persona.md`，写入新项目的 `docs/persona.md`。
2. 将 `antibodies.md` 中适用的跨项目条目合并到新项目避雷清单。
3. 从 `preferences.json` 恢复偏好和唤醒词。
4. 创建新项目的记忆目录与 `CLAUDE.md`。
5. 展示将要沿用的关键画像，并在宿主要求时让用户确认项目级继承范围。

唤醒词同时记录在：

```text
docs/persona.md
.agent/memory-runtime/preferences.json → wake_word
```

用户说“改唤醒词”“换个名字”或明确指定新名字时，两处都要更新。唤醒词只负责触发记忆恢复，不等于额外的操作授权。

## 7. Skill 钩子系统

记忆系统可以作为元 Skill，管理其他工作流 Skill 的生命周期：

| 钩子 | 时机 | 典型用途 |
|------|------|----------|
| `on_session_start` | 项目记忆恢复后 | 加载 Skill 上下文、展示摘要 |
| `on_first_activate` | 首次部署或跨项目唤醒 | 初始化 Skill 数据、恢复可迁移知识 |
| `on_post` | POST-3 | 同步 Skill 的跨项目数据 |

发现新 Skill 时：

1. 扫描宿主允许的 Skill 目录并读取其 `SKILL.md`。
2. 优先采用它已经声明的 hooks。
3. 没有声明时，只分析三件事：是否有跨项目数据、是否需要会话恢复、是否需要首次初始化。
4. 生成或更新 hooks 后记录 Skill 名称与版本，便于变更检测。

安全约束：单个 Skill 的钩子失败不能阻塞核心记忆流程；钩子执行要留下可审计记录；不要未经授权改写第三方 Skill 或同步其中的凭据、完整聊天和项目正文。

## 8. 记忆健康维护

每约 5 次 POST 或用户主动要求时检查：

- `CLAUDE.md` 是否仍能准确描述当前状态，正文是否过长；
- `memory-index.md` 是否超过约 60 行，旧内容是否需要归档；
- `persona.md` 中 `[observed]` 是否积压，是否有可以确认或删除的观察；
- 避雷清单是否仍然有效，已修复的问题是否已移除；
- `preferences.json` 中的唤醒词是否与 `persona.md` 一致；
- 最近 POST 的 Skill 钩子是否成功；
- 已整合 Skill 的版本是否与实际 `SKILL.md` 一致；
- 跨项目数据是否已同步且没有把项目专属内容错误提升到用户级。

记忆清理规则：

- 已修复的 Bug 从活跃避雷清单移除；
- 已废弃模块从 `memory-index.md` 移除；
- 过时决策移动到 `docs/archive/`；
- 已确认的画像观察从 `[observed]` 移到对应画像字段；
- 不能为了“保持简洁”删除仍用于恢复和避坑的证据。

## 9. 建议的目录结构

```text
项目根目录/
├── CLAUDE.md
├── docs/
│   ├── memory-index.md
│   ├── persona.md
│   ├── versions.md
│   ├── decisions/
│   ├── archive/
│   └── templates/
│       └── decision.md
└── .agent/
    └── memory-runtime/
        ├── antibodies.md
        └── preferences.json
```

Skill 分发包本身只应包含空模板、参考文档和 `SKILL.md`；运行时记忆放在 `.agent/memory-runtime/`，不要随 Skill 一起打包发布。

## 10. 适配其他 Agent 宿主时的检查项

这套方案来自带有 `CLAUDE.md`、`TodoWrite` 和 Skill 目录约定的 Agent 环境，移植到 Codex、TapTap Maker 或其他模型时，先映射下列能力：

| 原方案假设 | 适配时需要确认 |
|------------|----------------|
| `CLAUDE.md` 会自动注入 | 宿主是否有等价的项目级启动文件 |
| `TodoWrite` 可以持久化任务 | 是否有任务清单、状态文件或主控协议 |
| `.agent/memory-runtime/` 跨项目可访问 | 宿主的真实持久目录是什么，是否允许写入 |
| 扫描并改写其他 Skill | 是否需要用户批准，是否存在只读或托管区域 |
| 首次消息自动部署 | 是否会绕过产品的确认、权限和人工批准停点 |
| `git init && git commit` | 是否已在 Git 仓库中，提交是否获授权 |

若宿主不支持上述能力，不要假装“自动记忆已生效”：保留文件结构和 POST 思路，改用宿主实际可用的恢复文件、任务状态和同步机制。

## 来源与版本

*素材来源：`@Huiyu-Skill_memory-system.zip`，包含 `SKILL.md`、`references/memory-workflow.md`、`references/memory-skill.md` 与 `assets/templates/`。*
*蒸馏日期：2026-10-04*
*本文是方案蒸馏，不等同于安装或启用该 Skill；部署前应在目标宿主中做最小可行验证。*

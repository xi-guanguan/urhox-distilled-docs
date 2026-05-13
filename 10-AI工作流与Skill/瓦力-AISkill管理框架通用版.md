# AI Skill 管理框架（通用版）

| 字段 | 值 |
|------|-----|
| 这是什么 | 面向 AI 编程助手的结构化 Skill 管理框架——注册表、分类编号、5 种类型、3 种触发模式、三层渐进加载、依赖管理、质量评分、版本控制、CLI 工具链、一句话复制提示词 |
| 原作者 | 瓦力 |
| 推荐度 | L2（框架设计完整且自洽，但需根据自己项目的 AI 工具链适配落地） |
| 适用场景 | 为 Claude Code / Cursor / Copilot 等 AI 编程助手搭建可管理、可扩展的 Skill 体系 |

---

## 核心概念

**Skill = 给 AI 编程助手的「标准化能力插件」**。与系统提示词的区别：

| | 系统提示词 | Skill |
|--|----------|-------|
| 粒度 | 全局规则 | 单一场景/能力 |
| 触发 | 始终生效 | 按条件触发 |
| 管理 | 一个大文件 | 独立文件 + 注册表 |
| 复用 | 复制粘贴 | 注册 → 安装 → 跨项目 |

---

## 文件结构

```
.claude/skills/
├── registry.json          # 注册表（所有 skill 的元数据索引）
├── FRAMEWORK.md           # 框架说明文档
├── skill.schema.json      # Skill 格式校验 schema
├── manage.sh              # CLI 管理工具（10 个子命令）
├── install.sh             # 安装脚本
├── validate.sh            # 校验脚本
├── templates/             # Skill 模板（按类型）
│   ├── guard.md
│   ├── workflow.md
│   ├── tool.md
│   ├── style.md
│   └── reference.md
└── <skill-name>/
    └── SKILL.md           # 单个 Skill 的完整内容
```

---

## 5 种 Skill 类型

| 类型 | 代号 | 用途 | 触发时机 | 典型示例 |
|------|------|------|---------|---------|
| **Guard** | guard | 防御性检查，阻止错误 | 写代码时自动 | API 可用性守卫、nil 空洞防护 |
| **Workflow** | workflow | 多步流程编排 | 任务开始时 | 开发验收 SOP、发布流程 |
| **Tool** | tool | 工具/API 使用指南 | 需要用某工具时 | 素材搜索、视频生成 |
| **Style** | style | 代码/设计风格规范 | 写代码时自动 | UI 创作规范、命名规范 |
| **Reference** | reference | 参考知识库 | 按需查阅 | 游戏设计原理、材质库 |

**每种类型的必选章节**：

| 类型 | 必选章节 |
|------|---------|
| guard | MUST trigger when / 检查清单 / 修复方案 |
| workflow | 步骤序列 / 输入输出 / 异常处理 |
| tool | 参数说明 / 使用示例 / 常见错误 |
| style | 规范条目 / 正反示例 / 检查清单 |
| reference | 索引结构 / 查询方式 / 更新频率 |

---

## 3 种触发模式

| 模式 | 说明 | 优先级顺序 |
|------|------|-----------|
| **auto** | 条件匹配时自动触发 | guard → workflow → style（按此顺序） |
| **manual** | 用户显式调用（`/skill-name`） | tool / reference 通常是手动 |
| **hybrid** | 自动 + 手动均可 | 兼具 |

**触发优先级**：guard > workflow > style > tool / reference

---

## 三层渐进加载

**核心目的**：节省 AI 上下文窗口。不是每个 skill 都需要全量加载。

| 层级 | 内容 | Token 开销 | 何时加载 |
|------|------|-----------|---------|
| **L1 发现层** | YAML 前置元数据（name + description） | ~50 tokens/skill | 会话开始，扫描所有 skill |
| **L2 激活层** | 触发条件 + 摘要 + 快速参考 | ~500-5000 tokens | 匹配到触发条件时 |
| **L3 执行层** | 完整内容（代码模板、详细规范） | 全量 | 确认需要执行时 |

**L1 发现层格式（YAML 前置元数据）**：

```yaml
---
name: api-guard
description: 识别不可用/已废弃的引擎 API，阻止使用并给出替代方案
type: guard
trigger: auto
category: S1-001
---
```

**必选字段**：`name`、`description`（这两个足够 AI 判断是否需要加载 L2）。

---

## 分类编号

格式：`S<类别>-<3位编号>`

| 类别 | 含义 | 示例 |
|------|------|------|
| S1 | Bug 防护 | S1-001 api-guard |
| S2 | 协作/部署 | S2-001 dev-workflow |
| S3 | 代码质量 | S3-001 lua-nil-hole-guard |
| S4 | 文档管理 | S4-001 memory-docs |
| S5 | 任务流程 | S5-001 pre-task-reflection |
| S6 | 风格规范 | S6-001 ui-rules |

---

## Skill 生命周期

```
创建（Create）
  │  使用模板 → 填写内容 → 校验格式
  ↓
注册（Register）
  │  写入 registry.json → 分配编号
  ↓
安装（Install）
  │  解析依赖 → 拓扑排序 → 复制文件
  ↓
运行时（Runtime）
  │  L1 扫描 → L2 激活 → L3 执行
  ↓
维护
     更新版本 → 重新校验 → 通知依赖方
```

---

## SKILL.md 标准格式

```markdown
---
name: my-skill
description: 一句话说明
type: guard | workflow | tool | style | reference
trigger: auto | manual | hybrid
category: S1-001
version: 1.0.0
dependencies: []
---

# Skill 标题

## 触发条件（auto/hybrid 类型必选）

MUST trigger when:
(1) 条件 1
(2) 条件 2

不触发: 条件 A、条件 B

## 核心内容

（按类型填写必选章节）

## 示例

（正反示例）

## 检查清单

- [ ] 检查项 1
- [ ] 检查项 2
```

---

## 依赖管理

### 规则

| 规则 | 说明 |
|------|------|
| 禁止循环依赖 | A→B→C→A 不允许 |
| 禁用传播 | A 依赖 B，B 被禁用 → 警告 A（不自动禁用） |
| 安装顺序 | 拓扑排序，被依赖者先安装 |

### registry.json 中的依赖声明

```json
{
  "skills": [
    {
      "name": "dev-workflow",
      "dependencies": ["memory-docs", "api-guard"],
      "enabled": true
    }
  ]
}
```

---

## 质量评分

| 维度 | 权重 | 评分标准 |
|------|------|---------|
| 完整性 | 30% | 必选章节是否齐全 |
| 可执行性 | 25% | AI 能否直接按 skill 内容执行 |
| 示例质量 | 20% | 正反示例是否清晰、可复现 |
| 触发精度 | 15% | 触发条件是否准确（无漏触发/误触发） |
| 文档质量 | 10% | 格式规范、描述清晰 |

**评分公式**：

```
总分 = 完整性×0.3 + 可执行性×0.25 + 示例×0.2 + 触发精度×0.15 + 文档×0.1
```

---

## 版本管理

采用 SemVer，三个层级独立管理：

| 层级 | 版本含义 | 示例 |
|------|---------|------|
| 仓库版本 | 整体框架版本 | v2.1.0 |
| Skill 版本 | 单个 skill 的迭代 | 1.3.0 |
| Schema 版本 | 格式定义的迭代 | 1.0.0 |

---

## CLI 工具（manage.sh）

```bash
# 10 个子命令
./manage.sh list                    # 列出所有 skill（名称、类型、状态）
./manage.sh search <keyword>        # 按关键词搜索
./manage.sh info <skill-name>       # 查看详情
./manage.sh stats                   # 统计（总数、类型分布、启用/禁用）
./manage.sh add <skill-name>        # 从模板创建新 skill
./manage.sh remove <skill-name>     # 删除 skill（含依赖检查）
./manage.sh enable <skill-name>     # 启用
./manage.sh disable <skill-name>    # 禁用（检查被依赖情况）
./manage.sh deps <skill-name>       # 查看依赖树
./manage.sh health                  # 健康检查（格式校验、依赖完整性）
```

---

## 一句话复制提示词

> 请帮我搭建一个 AI Skill 管理框架：在 `.claude/skills/` 下创建 `registry.json`（注册表）和 `manage.sh`（CLI 工具，支持 list/search/info/stats/add/remove/enable/disable/deps/health 10 个子命令）。每个 Skill 是独立目录下的 `SKILL.md`，包含 YAML 前置元数据（name/description/type/trigger/category/version/dependencies）。支持 5 种类型（guard/workflow/tool/style/reference）、3 种触发模式（auto/manual/hybrid）、三层渐进加载（L1 发现 ~50 tokens → L2 激活 ~500-5000 → L3 执行全量）。分类编号格式 `S<类别>-<3位>`（S1 Bug防护 / S2 协作 / S3 质量 / S4 文档 / S5 任务 / S6 风格）。

---

## 适用边界

| 适合 | 不适合 |
|------|--------|
| 团队共享 AI 开发规范 | 一次性脚本/小工具 |
| 跨项目复用防护策略 | 项目特定的业务逻辑 |
| 需要版本管理的 AI 规则 | 临时调试提示词 |
| 5+ 个 skill 的管理场景 | 1~2 个简单规则 |

---

## 同类对比

> 本文与 **南北绿豆「Skill制作规范」** 存在 **70% 知识点重合**（均覆盖 Skill 类型/分类、文件结构、触发模式、加载策略等核心概念），以下为优劣势对比：

| 维度 | 本文（瓦力·管理框架） | 南北绿豆·制作规范 |
|------|----------------------|-------------------|
| **定位** | 宏观管理——注册表设计、CLI 工具链、依赖管理、质量评分体系 | 微观制作——单个 Skill 怎么写、SKILL.md 格式规范、触发词设计 |
| **Skill 分类** | 5 种类型 + 编号体系（G/P/W/Q/M），适合大规模管理 | 4 种类型（guardian/workflow/knowledge/quality），更贴近实际使用 |
| **触发机制** | 3 种触发模式（auto/manual/conditional），理论完备 | 按场景给出具体触发词示例和 MUST/SKIP 设计模式，实操性更强 |
| **加载策略** | 三层渐进加载（L0/L1/L2），有工程设计感 | 未专门讨论加载策略 |
| **质量管控** | 质量评分公式 + 版本控制规范 | 10 条制作检查清单，更直接可用 |
| **独有价值** | 一句话复制提示词、依赖关系图、CLI 批量操作 | 反面案例（过度设计/范围蔓延）、Prompt 工程技巧、最小可行原则 |
| **适合谁** | Skill 体系管理者/架构师 | Skill 内容编写者/一线开发者 |

**建议阅读顺序**: 先读本文（建立管理框架认知） → 再读「Skill制作规范」（学习具体编写技巧）。两篇互补而非替代。

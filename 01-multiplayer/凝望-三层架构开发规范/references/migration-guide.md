# 三层架构迁移操作规范

> AI 执行项目诊断和迁移时的强制流程。

---

## 迁移铁律

1. **用户未明确同意前，禁止执行任何迁移操作**（移动/重命名/删除文件）
2. **迁移前必须备份**：cp -r scripts/ scripts_backup_$(date +%Y%m%d_%H%M%S)/
3. **严格按已审批的迁移方案执行**，不允许临时偏离
4. **迁移方案必须生成到 docs/ 供用户审阅**，不能只口头描述
5. **迁移失败可回滚**：备份目录未删除前，随时可恢复

---

## 阶段 1: 项目诊断（不读代码内容）

### 1.1 收集信息（仅看目录结构和文件名）

执行以下命令：

- find scripts/ -name "*.lua" | wc -l （文件数量）
- ls -la scripts/ （顶层结构）
- find scripts/ -name "*.lua" | sort | head -100 （文件列表）
- ls -d scripts/shared/ scripts/server/ scripts/client/ 2>/dev/null （是否已有三层）
- cat .project/settings.json | grep -A5 multiplayer （多人配置）

### 1.2 项目类型判定矩阵

| 条件 | 判定结果 | 后续动作 |
|------|---------|---------|
| scripts/ 不存在或 lua 文件数 <= 3 | **新项目/空项目** | 直接使用模板搭建 |
| 有 shared/ + server/ + client/ 且含 Schema/Handler/Service | **已是三层架构** | 仅检查合规性 |
| 有业务代码但不符合三层结构 | **中途改造项目** | 进入迁移流程 |

### 1.3 中途改造 → 进一步分析

**单机 vs 多人**：
- 读 .project/settings.json 的 @runtime.multiplayer.enabled
- 有 network/ 目录或 Server.lua/Client.lua → 多人项目
- 无网络相关文件 → 单机项目

**文件分类规则**（按文件名模式推断，不读代码）：

| 文件名模式 | 推测归属 |
|-----------|---------|
| *Schema.lua, *Defs.lua, *Consts.lua, *Config.lua | shared |
| *Handler.lua, *Service.lua, *PDM.lua, *Manager.lua | server |
| *Client.lua, *Screen.lua, *Panel.lua, *View.lua, *UI.lua | client |
| *Utils.lua, *Calc.lua, *Core.lua | shared（纯函数）或需人工判断 |
| main.lua, init.lua | 入口文件，保留原位或分拆 |

---

## 阶段 2: 迁移方案生成

### 2.1 输出到 docs/migration-plan.md

必须包含以下章节：

1. **项目诊断结果** — 项目类型、文件总数、现有目录结构树形图
2. **模块分析表** — 现有文件 | 推测职责 | 目标层 | 目标路径 | 备注
3. **迁移步骤**（按顺序）— 备份 → 创建目录 → 搭建单例 → 逐模块迁移 → 更新require → 验证
4. **复杂度评估** — 文件数量/模块耦合/数据层改造/总体，各评低/中/高
5. **风险与可行性** — 风险点列举 + 回滚方案
6. **用户确认区** — 复选框：已审阅 + 同意执行

### 2.2 复杂度评级标准

| 维度 | 低 | 中 | 高 |
|------|---|---|---|
| 文件数量 | <= 10 | 11-30 | > 30 |
| 模块耦合 | 各文件独立 | 有交叉 require | 循环依赖/全局状态 |
| 数据层改造 | 无持久化 | 有本地存档 | 有 serverCloud/网络同步 |
| 总体 | 1星 | 3星 | 5星 |

---

## 阶段 3: 用户审阅与调整

- 生成方案后**必须等待用户反馈**
- 用户可能要求：调整模块归属、修改迁移顺序、排除某些文件、分批迁移
- 每次调整后**更新 docs/migration-plan.md** 并再次请用户确认
- **只有用户明确说同意执行/开始迁移/可以了等肯定表述后才开始**

---

## 阶段 4: 执行迁移

### 4.1 执行前检查清单

- 确认备份存在：ls -d scripts_backup_* | tail -1
- 确认迁移方案文档存在：docs/migration-plan.md

### 4.2 执行顺序（严格）

1. **备份**：cp -r scripts/ scripts_backup_YYYYMMDD_HHMMSS/
2. **创建目录**：mkdir -p scripts/{shared/schemas,server/character,client/data}
3. **放置中心化单例**：CharacterSchema, PDM, PlayerStore
4. **逐模块迁移**：每个模块完成后立即 build 验证，失败则停止
5. **清理旧文件**：确认全部模块迁移完成且 build 通过后再删除
6. **最终验证**：完整 build + 功能验证

### 4.3 单模块迁移流程

1. 创建 shared/xxx/XxxSchema.lua + XxxConsts.lua
2. 移动/重构 server 层代码
3. 移动/重构 client 层代码
4. 更新所有 require 路径
5. build 验证 — 失败则停止，不继续下一个模块

### 4.4 回滚

任何时候发现迁移失败：
- rm -rf scripts/
- cp -r scripts_backup_YYYYMMDD_HHMMSS/ scripts/

---

## 新项目/空项目流程（无需迁移）

1. 创建目录结构：mkdir -p scripts/{shared/schemas,server/character,client/data}
2. 复制中心化单例模板（CharacterSchema + PDM + PlayerStore）
3. 按需复制 per-subsystem 模板
4. build 验证

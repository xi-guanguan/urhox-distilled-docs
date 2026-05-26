---
name: three-layer-arch
description: "UrhoX 常驻服务器（Dedicated Server）三层架构开发规范。定义三层目录架构（shared/server/client）、服务端三层分离（Handler-Service-PDM）、Schema 驱动数据定义、REPLICATED Node 同步、Dirty-Cache + BatchCommit 持久化、PDM+PlayerStore 单一数据源。Use when: (1) 在 server/ 下新建或编辑业务模块, (2) 新增 Schema 字段或子系统 Schema, (3) 编写 Handler/Service/PDM 相关代码, (4) 设计前后端数据同步方案, (5) 定义 NetworkEvents 网络事件, (6) 编写 serverCloud 持久化逻辑, (7) 创建客户端 SyncClient/PlayerStore 消费代码, (8) 用户要求新建子系统/功能模块。"
---

# 三层架构开发规范

## 首步：项目诊断（触发 skill 时必须先执行）

**触发时机**：用户要求新建子系统、改造项目架构、或首次在项目中使用三层架构时。

### 诊断流程

```
执行诊断命令（仅看目录结构，不读代码）
  |
判定项目类型
  +-- 新项目/空项目     -> 直接用模板搭建（跳过迁移）
  +-- 已是三层架构     -> 仅检查合规性
  +-- 中途改造项目     -> 进入迁移流程
        +-- 检测单机/多人（.project/settings.json）
        +-- 扫描 scripts/ 目录树（文件名模式分类）
        +-- 生成迁移方案 -> docs/migration-plan.md
        +-- 用户审阅与调整（可多轮）
        +-- 用户明确同意后 -> 备份 + 执行迁移
        +-- 验证 build
```

### 项目类型判定

| 条件 | 类型 | 后续 |
|------|------|------|
| scripts/ 不存在或 lua 文件数 <= 3 | **新项目** | 直接搭建 |
| 已有 shared/ + server/ + client/ 且含 Schema/Handler/Service | **已是三层** | 检查合规 |
| 有业务代码但不符合三层结构 | **中途改造** | 迁移流程 |

### 迁移铁律

1. **用户未明确同意前，禁止执行任何迁移操作**
2. **迁移前必须备份**：`cp -r scripts/ scripts_backup_YYYYMMDD_HHMMSS/`
3. **严格按已审批的迁移方案执行**，不允许临时偏离
4. **迁移方案必须生成到 docs/migration-plan.md** 供用户审阅
5. **逐模块迁移 + 每步 build 验证**，失败则停止
6. **随时可回滚**：从备份目录恢复

详细迁移操作规范见 **[references/migration-guide.md](references/migration-guide.md)**

---

## 架构总览

```
scripts/
+-- shared/          <- 零依赖（纯定义：Schema/Consts/Defs/纯函数）
|   +-- schemas/
|   |   +-- CharacterSchema.lua  <- 中心 Schema（全项目唯一）
|   +-- xxx/
|       +-- XxxSchema.lua        <- 子系统 Schema（注册到 CharacterSchema）
|       +-- XxxConsts.lua
+-- server/          <- 可 require shared，禁 require client
|   +-- character/
|   |   +-- PlayerDataManager.lua  <- PDM（全项目唯一）
|   +-- xxx/
|       +-- XxxHandler.lua
|       +-- XxxService.lua
+-- client/          <- 可 require shared，禁 require server
    +-- data/
    |   +-- PlayerStore.lua        <- 数据访问层（全项目唯一）
    +-- xxx/
        +-- XxxClient.lua
```

**依赖方向**：`shared <- server <- [网络] -> client -> shared`（跨层只走网络事件）

## Schema 驱动注册机制

三个中心化单例通过 CharacterSchema 联动：

```
XxxSchema.Fields  --RegisterSubsystemFields-->  CharacterSchema.Fields
                                                       |
                              +------------------------+
                              v                        v
                    PDM 动态构建键注册表       PlayerStore 动态构建 keyMap
```

**新子系统接入**只需 2 步：
1. 写 `XxxSchema.lua`，定义 `Fields`（pdmKey + type + persist）
2. 在 `CharacterSchema.lua` 底部加两行：
```lua
local XxxSchema = require("shared.xxx.XxxSchema")
CharacterSchema.RegisterSubsystemFields("Xxx", XxxSchema.Fields)
```
PDM 和 PlayerStore 自动包含新字段，无需修改。

## 模板文件

### 中心化单例模板（全项目各一份，首次搭建时使用）

| 文件 | 层 | 职责 |
|------|---|------|
| `CharacterSchema.lua` | shared | 字段注册中心 + RegisterSubsystemFields 机制 |
| `PlayerDataManager.lua` | server | 统一数据管理器：Schema 动态注册 + Provider + serverCloud 持久化 |
| `PlayerStore.lua` | client | 统一数据访问层：Schema 动态 keyMap + SyncClient 只读 |

### per-subsystem 模板（每个新子系统各一份）

| 文件 | 层 | 职责 |
|------|---|------|
| `XxxSchema.lua` | shared | 子系统字段定义 + 注册说明 |
| `XxxConsts.lua` | shared | 枚举、数值配表、网络事件名 |
| `XxxHandler.lua` | server | 网络事件入口、参数校验、调 Service、Sync+发结果 |
| `XxxService.lua` | server | 业务逻辑、调 PDM 读写（禁止网络IO） |
| `XxxClient.lua` | client | 自建事件总线、监听结果事件、SendToServer |

## 新建子系统流程

1. 复制 `assets/templates/` 下 **5 个 Xxx 模板**到对应目录，替换名称
2. 在 `XxxSchema.lua` 定义字段（pdmKey + type + persist）
3. 在 `CharacterSchema.lua` 底部 require + RegisterSubsystemFields
4. 在 `XxxConsts.lua` 定义事件名和数值
5. 实现 `XxxHandler`（网络入口）和 `XxxService`（业务逻辑，通过 PDM.SetStat/GetStat 读写）
6. 实现 `XxxClient`（事件总线 + UI 通过 PlayerStore.Get 读数据）

## 核心数据流

```
客户端请求 -> Handler -> Service -> PDM.SetStat() -> SetVar(REPLICATED) -> 客户端 PlayerStore.Get()
                                       |
                                  MarkDirty
                                       |
                          心跳/断线 -> BatchCommit -> serverCloud
```

### Handler 标准模式
```lua
function XxxHandler.OnAction(uid, data)
    local ok, err = XxxService.Action(uid, data.param)
    if not ok then return SendFail(uid, EVENT, err) end
    PDM.SyncXxx(uid)                                    -- 即时同步（MarkDirty 有延迟）
    ServerSync.SendToClient(uid, EVENT_RESULT, { ok = true })
end
```

### 持久化模型
- **SetStat/SetStruct** -> 更新内存 + SetVar + MarkDirty（不立即写 serverCloud）
- **心跳信号** -> BatchCommit 收集脏数据 -> serverCloud 批量写入
- **断线** -> SaveAll（先保存）-> UnloadPlayer（再清理）

## 铁律与避雷

开发时**必须阅读**：

- **[references/iron-rules.md](references/iron-rules.md)** -- 9 条架构铁律
- **[references/gotchas.md](references/gotchas.md)** -- P0-P3 避雷清单 + 症状速查
- **[references/migration-guide.md](references/migration-guide.md)** -- 迁移操作规范（诊断+方案+执行+回滚）
- **[references/client-sync-tolerance.md](references/client-sync-tolerance.md)** -- 客户端同步宽容度（WaitForChange 轮询模式）

### 关键铁律速览

1. **依赖单向**：shared<-server, shared<-client, 跨层只走网络事件
2. **shared 零副作用**：禁引擎 API、禁全局状态修改
3. **PDM 单一数据源**：禁客户端缓存、禁绕过 PDM 的 SendToClient
4. **Handler 不做逻辑**：逻辑全在 Service
5. **Sync 在 Send 前**：MarkDirty 有 0.1s 延迟，发结果前必须 SyncXxx
6. **断线先存后清**：SaveAll -> UnloadPlayer（反了 = 回档）
7. **cjson 是全局**：`local cjson = cjson`，禁止 require
8. **背包双写**：table.remove + ListDelete 缺一不可
9. **客户端同步宽容度**：结果事件回调中不直接读 PlayerStore，用 `WaitForChange` 等 REPLICATED 到达
10. **三层模块自建事件总线**：禁依赖 V1/V2 Client.Emit

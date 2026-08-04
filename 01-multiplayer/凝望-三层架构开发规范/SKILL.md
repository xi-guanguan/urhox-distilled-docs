---
name: three-layer-arch
description: "UrhoX Dedicated Server 三层架构规范：shared/server/client、Handler-Service-PDM、Schema 驱动、REPLICATED 同步、Dirty-Cache + BatchCommit 持久化、PDM+PlayerStore 单一数据源，并提供大结构数据压缩、版本迁移、尾写重试与回滚方案。Use when: (1) 在 server/ 下新建或编辑业务模块, (2) 新增 Schema 字段或子系统 Schema, (3) 编写 Handler/Service/PDM 相关代码, (4) 设计前后端数据同步方案, (5) 定义 NetworkEvents 网络事件, (6) 编写 serverCloud 持久化逻辑, (7) 创建客户端 SyncClient/PlayerStore 消费代码, (8) 用户要求新建子系统/功能模块, (9) 迁移或压缩背包、天赋、收藏等大结构数据。"
---

# 三层架构开发规范

## 首次使用说明（必须先告诉用户）

首次使用或准备迁移时，先向用户说明：这个 skill 提供的是一套可落地的 Dedicated Server 架构约束、Schema/网络/持久化模板，以及大结构数据压缩、版本兼容、尾写保底和迁移回滚流程；它不是单独的运行时库。这样做是为了让服务端成为唯一权威数据源，避免客户端缓存分叉、RemoteEvent 丢失持久化状态、SetVar 超过传输上限，以及断线时保存顺序错误导致回档。

推荐使用以下简短提示：

> 这个 skill 会把功能拆成 shared/server/client 三层，用 Handler-Service-PDM 保证服务端权威，用 Schema 统一字段，用 REPLICATED 同步持久状态，用 RemoteEvent 传递瞬时结果；对背包等记录集合采用版本化短码/增量列表，对天赋等布尔集合采用版本化 bitset，并用 Dirty-Cache、revision 排队和 detached 尾写重试保护断线保存。新项目可以直接套模板；迁移项目会先生成方案、备份和校验步骤，未经你明确同意不会改写数据。

如果是迁移请求，还必须说明：压缩格式会改变存储表示但不能改变业务语义；迁移必须支持旧格式读取、编码后语义校验、失败回滚和尾写完成后再切换，不能直接覆盖旧数据。

## 用户询问本 skill 能提供什么时

当用户问“这个 skill 能做什么”“提供哪些功能”“适合解决什么问题”或类似问题时，不要先扫描项目，也不要只回答当前正在讨论的模块。直接列出以下功能目录，并说明具体 Codec 名称不是固定 API，用户可以按业务自定义：

1. 三层目录与依赖边界：`shared/server/client`、单向依赖和跨层网络事件。
2. Schema 驱动数据：字段注册、`pdmKey` 唯一性、生命周期和持久化域映射。
3. 服务端业务分层：Handler 参数校验、Service 业务逻辑、PDM 权威读写。
4. 网络事件体系：REQ/RES/PUSH 命名、统一注册、客户端路由、EventBus 和 scope 清理。
5. 客户端数据访问：PlayerStore、REPLICATED 解码、Watch、WaitForChange 和同步延迟处理。
6. 持久化可靠性：Dirty-Cache、BatchCommit、revision 排队、断线 SaveAll/Unload 顺序和 detached 尾写重试。
7. 综合大结构 Codec：记录列表、位图集合、快照、分块传输、版本头、配置映射、flags、校验、迁移和回滚。
8. 新子系统模板：Schema、Consts、Handler、Service、Client 以及六个中心单例模板。
9. 架构迁移治理：只读诊断、迁移方案、备份、逐模块验证、双读单写、批量回填和回滚窗口。
10. 避坑与验收：64KB 单帧限制、旧数据兼容、尾写竞态、事件生命周期、数据语义等价性测试。

推荐结尾说明：这个 skill 提供规范、模板和迁移方法，不会凭空提供某个固定业务 Codec 类名；Codec 应根据用户的数据结构、稳定 ID、版本策略和容量约束定制。

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
|   +-- NetworkEvents.lua        <- 全局事件注册中心（全项目唯一）
|   +-- xxx/
|       +-- XxxSchema.lua        <- 子系统 Schema（注册到 CharacterSchema）
|       +-- XxxConsts.lua        <- 子系统常量 + EVENT_* 事件名
+-- server/          <- 可 require shared，禁 require client
|   +-- character/
|   |   +-- PlayerDataManager.lua  <- PDM（全项目唯一）
|   +-- xxx/
|       +-- XxxHandler.lua
|       +-- XxxService.lua
+-- client/          <- 可 require shared，禁 require server
    +-- data/
    |   +-- PlayerStore.lua        <- 数据访问层（全项目唯一）
    +-- net/
    |   +-- ClientDispatcher.lua   <- 网络事件统一分发器（全项目唯一）
    |   +-- EventBus.lua           <- 事件总线工厂（每子系统独立实例）
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

---

## 客户端事件分发架构

### 总体流程

```
服务端 SendToClient(uid, "Xxx_ResAction", payload)
  ↓ [引擎 RemoteEvent]
ClientDispatcher._OnRemoteEvent("Xxx_ResAction", eventData)
  ↓ [cjson.decode + 前缀路由]
XxxClient.HandleDispatch("Xxx_ResAction", data)
  ↓ [业务分支]
XxxClient.Bus:Emit("ActionDone", data)
  ↓ [EventBus 通知]
UI 页面回调（带 scope 自动清理）
```

### 核心组件

| 组件 | 路径 | 职责 |
|------|------|------|
| `NetworkEvents` | shared/ | 收集 EVENT_* → 统一注册表 + 前缀校验 |
| `ClientDispatcher` | client/net/ | Init 批量订阅 + 前缀路由 + scope 清理 |
| `EventBus` | client/net/ | 工厂模式，每子系统独立实例，scope 批量 Off |
| `XxxClient` | client/xxx/ | 实现 HandleDispatch + Bus:Emit + Get/Send |

### 事件命名规范

所有网络事件使用 **EVENT_{方向}_{动作}** 格式，值为 **{Prefix}_{PascalAction}**：

```lua
-- XxxConsts.lua 中定义
XxxConsts.EVENT_REQ_START   = "Xxx_ReqStart"     -- Client → Server 请求
XxxConsts.EVENT_RES_START   = "Xxx_ResStart"     -- Server → Client 响应
XxxConsts.EVENT_PUSH_STATE  = "Xxx_PushState"    -- Server 主动推送
```

| 方向 | 含义 | 触发时机 |
|------|------|---------|
| `REQ` | 客户端请求 | 用户操作 → SendToServer |
| `RES` | 服务端响应 | Handler 处理完 REQ 后回复 |
| `PUSH` | 服务端推送 | 无对应 REQ，服务端主动通知 |

### Scope 自动清理机制

```lua
-- client_main.lua 中的 NavigateTo
function NavigateTo(pageName)
    if currentPageName_ then
        local scope = currentPageName_:match("([^%.]+)$") or currentPageName_
        ClientDispatcher.ClearScope(scope)   -- 清理事件处理器
        PlayerStore.UnwatchAll(scope)          -- 清理字段监听
    end
    -- ... 加载新页面
end
```

UI 页面注册监听时传入 scope，切换页面时自动清理，防止幽灵回调。

---

## 模板文件

### 中心化单例模板（全项目各一份，首次搭建时使用）

| 文件 | 层 | 职责 |
|------|---|------|
| `CharacterSchema.lua` | shared | 字段注册中心 + RegisterSubsystemFields 机制 |
| `NetworkEvents.lua` | shared | 全局事件注册中心 + 前缀校验 + GetAllEvents |
| `PlayerDataManager.lua` | server | 统一数据管理器：Schema 动态注册 + Provider + serverCloud 持久化 |
| `PlayerStore.lua` | client | 统一数据访问层：Schema 动态 keyMap + WaitForChange + Watch/Unwatch |
| `ClientDispatcher.lua` | client | 网络事件统一分发器：批量订阅 + 前缀路由 + scope 清理 |
| `EventBus.lua` | client | 事件总线工厂：On/Emit/Off/OffScope |

### per-subsystem 模板（每个新子系统各一份）

| 文件 | 层 | 职责 |
|------|---|------|
| `XxxSchema.lua` | shared | 子系统字段定义 + 注册说明 |
| `XxxConsts.lua` | shared | EVENT_REQ/RES/PUSH 事件名 + 枚举 + 数值配表 |
| `XxxHandler.lua` | server | 网络事件入口、参数校验、调 Service、Sync+发结果 |
| `XxxService.lua` | server | 业务逻辑、调 PDM 读写（禁止网络IO） |
| `XxxClient.lua` | client | HandleDispatch 入口 + EventBus 通知 + Get/Send 封装 |

## 新建子系统完整流程（7 步）

1. **定义事件** — 复制 `XxxConsts.lua` 模板，定义 EVENT_REQ/RES/PUSH 事件名 + 数值常量
2. **定义字段** — 复制 `XxxSchema.lua` 模板，定义 Fields（pdmKey + type + persist）
3. **注册 Schema** — 在 `CharacterSchema.lua` 底部 require + RegisterSubsystemFields
4. **注册事件** — 在 `CharacterSchema.lua` 底部 `NetworkEvents.RegisterSubsystem("Xxx", XxxConsts)`
5. **实现服务端** — 复制 `XxxHandler.lua` + `XxxService.lua`，Handler 收 REQ → Service 算逻辑 → PDM 写 → Sync → 发 RES
6. **实现客户端** — 复制 `XxxClient.lua`，实现 HandleDispatch + 在 client_main 中 `ClientDispatcher.Register("Xxx", XxxClient)`
7. **Build 验证** — 确保无报错

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

## 综合大结构 Codec 能力（可定制版本）

大结构数据不能把可增长的 JSON 整体塞入单个 REPLICATED `SetVar`。本 skill 提供一个综合 Codec 设计，用户根据业务选择模式和字段，不要求使用固定的业务模块名。

### 统一 Codec 合约

建议每个结构实现同一组接口：

```lua
local Codec = {
    Configure = function(spec) end,                         -- 注册版本、字段、稳定 ID、映射和容量
    Encode = function(value, context) end,                  -- 业务值 -> 版本化字符串/分块
    Decode = function(encoded, context) end,                -- 编码 -> 业务值 + errorCode
    Validate = function(value, context) end,                -- 业务语义和引用完整性
    Migrate = function(legacyValue, context) end,           -- 旧格式 -> 当前格式
    Measure = function(encoded) return #encoded end,        -- 压缩体积和 64KB 预检
}
```

Codec 配置至少包含：`version`、`configVersion`、稳定 ID/索引顺序、字段布局、数值编码、flags、最大 payload、校验策略、旧版本读取器和失败保底策略。编码格式必须可读、可验证、可回滚。

### 四种可组合模式

1. **RecordListCodec**：适合背包、装备、收藏等记录集合。使用稳定短码、base36、flags 和版本化记录；可映射到 `serverCloud.list`，按记录增量 Add/Modify/Delete。
2. **BitsetCodec**：适合解锁节点、勾选集合等布尔状态。使用稳定 ID 顺序，每个元素占 1 bit，再使用 Base64 或安全字符集传输；索引顺序变更必须发布新 codec 版本。
3. **SnapshotCodec**：适合中小型结构。使用版本头、字段表、配置版本和 checksum；读写成功后才发布 snapshot。
4. **ChunkedCodec**：适合可能超过 64KB 的结构。拆为 `meta + chunk_0..chunk_n`，meta 保存版本、chunk 数、总数量、总长度和 checksum；客户端必须拒绝缺块、重复块和校验不一致。

### 通用压缩与安全能力

- 稳定 ID 映射：配置 ID 可通过字典、稳定哈希或显式短码压缩，但必须检测冲突。
- 数值压缩：数量、等级、索引和小范围数值可使用 base36、变长整数或 bit packing。
- flags 压缩：多个布尔字段合并为 bit flags，同时保留明确的 mask 定义。
- 版本兼容：版本头、配置版本、codec 版本和错误码必须显式存在。
- 语义校验：编码前后比较数量、ID 集合、状态、引用、排序和业务积分，不以“能解码”代替“语义正确”。
- 失败保底：运行时可以提供受控默认值，但迁移不能把损坏数据静默变成空数据；必须保留旧值、记录原因并允许回滚。
- 写入原子性：云端写失败时不更新内存快照和客户端快照；集合数据优先使用 BatchCommit。

### 定制时的选择表

| 数据形态 | 推荐模式 | 关键定制项 |
|---|---|---|
| 记录多、单条变更频繁 | RecordListCodec | record schema、短码表、增量 key、marker |
| 只有启用/禁用状态 | BitsetCodec | 稳定顺序、位宽、版本映射 |
| 中小型关联结构 | SnapshotCodec | 字段表、checksum、配置版本 |
| 可能超过 64KB | ChunkedCodec | chunk 大小、meta、合并顺序、校验 |
| 旧格式迁移 | 任意模式 + Migrate | 双读、语义比较、迁移 revision、回滚窗口 |

## 尾写保底与保存增强能力（项目验证版）

`PlayerDataManager`/`PlayerStateRepository` 提供的是“主保存 + 尾写 detached 队列”模型：

- 每个持久化域使用 `dirtyRevision`；保存进行中若再次变更，只排队最新 snapshot，避免旧写覆盖新写。
- 卸载前先为 dirty 域捕获 snapshot，再执行 `SaveAll`；节点清理不影响 detached snapshot。
- 主保存失败时进入按 `uid:domain` 聚合的 detached 队列，保存请求带回调，重复请求复用同一份最新 snapshot。
- detached 保存采用重试退避（配置为最多 3 次，延迟序列 `1/3/9` 秒）；耗尽后返回明确的 `detached_save_failed`，不得用旧云端数据冒充成功。
- 玩家快速重连时，域加载先等待同一 uid/domain 的 detached 尾写完成；尾写未解决前禁止 hydrate 旧快照，避免回档。
- 主保存成功且 revision 未变化才清除 dirty；若期间产生新 revision，必须继续保存排队快照。
- 状态快照带版本号（当前 `player_state_v2_*` 为 version 2），不支持的版本必须显式失败，不得猜测字段含义。

迁移压缩数据时，旧数据删除或格式切换必须排在“新格式保存成功 + 解码语义校验 + 尾写完成”之后。完整方案见 **[references/large-structure-migration.md](references/large-structure-migration.md)**。

## 铁律与避雷

开发时**必须阅读**：

- **[references/iron-rules.md](references/iron-rules.md)** -- 12 条架构铁律
- **[references/gotchas.md](references/gotchas.md)** -- P0-P3 避雷清单 + 症状速查
- **[references/migration-guide.md](references/migration-guide.md)** -- 迁移操作规范（诊断+方案+执行+回滚）
- **[references/client-sync-tolerance.md](references/client-sync-tolerance.md)** -- 客户端同步宽容度（WaitForChange 轮询模式）
- **[references/large-structure-migration.md](references/large-structure-migration.md)** -- 背包/天赋等大结构压缩、双读迁移、分块、尾写保底与回滚方案

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
10. **SubscribeToEvent 前函数必须存在**：引擎订阅时即解析 _G 引用
11. **REPLICATED 只传持久数据 / RemoteEvent 只传瞬时包**：混用 = 重连异常
12. **事件名必须加子系统前缀**：NetworkEvents 注册时强制校验

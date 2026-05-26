# 三层架构开发规范（完整版）

> 作者：凝望 | 级别：L1（实操） | 蒸馏自 TapTap 论坛
>
> 适用场景：UrhoX 常驻服务器（Dedicated Server）多人游戏的架构设计与实现。
> 定义三层目录架构（shared/server/client）、Handler-Service-PDM 服务端分层、Schema 驱动注册、REPLICATED Node 同步、Dirty-Cache + BatchCommit 持久化。

---

## 目录

1. [架构总览](#1-架构总览)
2. [Schema 驱动注册机制](#2-schema-驱动注册机制)
3. [新建子系统流程](#3-新建子系统流程)
4. [核心数据流](#4-核心数据流)
5. [九条铁律](#5-九条铁律)
6. [避雷清单（P0-P3）](#6-避雷清单p0-p3)
7. [客户端同步宽容度（WaitForChange）](#7-客户端同步宽容度waitforchange)
8. [迁移操作规范](#8-迁移操作规范)
9. [模板代码](#9-模板代码)

---

## 1. 架构总览

```
scripts/
├── shared/          ← 零依赖（纯定义：Schema/Consts/Defs/纯函数）
│   ├── schemas/
│   │   └── CharacterSchema.lua  ← 中心 Schema（全项目唯一）
│   └── xxx/
│       ├── XxxSchema.lua        ← 子系统 Schema（注册到 CharacterSchema）
│       └── XxxConsts.lua
├── server/          ← 可 require shared，禁 require client
│   ├── character/
│   │   └── PlayerDataManager.lua  ← PDM（全项目唯一）
│   └── xxx/
│       ├── XxxHandler.lua
│       └── XxxService.lua
└── client/          ← 可 require shared，禁 require server
    ├── data/
    │   └── PlayerStore.lua        ← 数据访问层（全项目唯一）
    └── xxx/
        └── XxxClient.lua
```

**依赖方向**（单向，不可逆）：
```
shared ← 零依赖（不 require 任何层）
server ← 可 require shared，禁止 require client
client ← 可 require shared，禁止 require server
```

跨层调用只能通过**网络事件**（`SendToClient` / `SendToServer`），禁止通过 `require` 绕过层级边界。

### 各层职责

| 层 | 允许 | 禁止 |
|---|---|---|
| **shared** | Schema 定义、常量/枚举/数据表、纯函数 | 引擎 API、require 其他层、全局状态修改 |
| **server** | 业务逻辑、PDM 读写、serverCloud 持久化 | require client、直接操作客户端 |
| **client** | 读取 PlayerStore、UI 展示、发送请求 | require server、自行缓存服务端数据 |

---

## 2. Schema 驱动注册机制

三个中心化单例通过 CharacterSchema 联动：

```
XxxSchema.Fields  ──RegisterSubsystemFields──>  CharacterSchema.Fields
                                                       │
                              ┌────────────────────────┘
                              ▼                        ▼
                    PDM 动态构建键注册表       PlayerStore 动态构建 keyMap
```

**新子系统接入只需 2 步**：
1. 写 `XxxSchema.lua`，定义 `Fields`（pdmKey + type + persist）
2. 在 `CharacterSchema.lua` 底部：
```lua
local XxxSchema = require("shared.xxx.XxxSchema")
CharacterSchema.RegisterSubsystemFields("Xxx", XxxSchema.Fields)
```

PDM 和 PlayerStore 自动包含新字段，**无需修改这两个文件**。

### 字段定义格式

```lua
fieldKey = {
    pdmKey  = "VarName",          -- PDM SetVar/GetVar 键名（全局唯一）
    type    = "scalar"|"string"|"json",
    persist = { via = "cloud"|"money"|"list", cloudKey = "xxx" } | false,
    desc    = "说明",
}
```

**持久化策略**：
| `persist.via` | 含义 | 后端 |
|---|---|---|
| `"cloud"` | serverCloud scores/iscores | 标量/字符串/JSON |
| `"money"` | serverCloud.money API | 由 ServerMoney provider 管理 |
| `"list"` | serverCloud.list API | 由 ListManager provider 管理 |
| `false` | sync-only | 仅 REPLICATED 同步，不持久化 |

---

## 3. 新建子系统流程

1. 复制 **5 个 Xxx 模板**到对应目录，替换名称
2. 在 `XxxSchema.lua` 定义字段（pdmKey + type + persist）
3. 在 `CharacterSchema.lua` 底部 require + RegisterSubsystemFields
4. 在 `XxxConsts.lua` 定义事件名和数值
5. 实现 `XxxHandler`（网络入口）和 `XxxService`（业务逻辑）
6. 实现 `XxxClient`（事件总线 + UI 通过 PlayerStore.Get 读数据）

### 模板文件一览

| 文件 | 层 | 职责 |
|------|---|------|
| `CharacterSchema.lua` | shared | 字段注册中心（全项目唯一） |
| `PlayerDataManager.lua` | server | 统一数据管理器（全项目唯一） |
| `PlayerStore.lua` | client | 统一数据访问层（全项目唯一） |
| `XxxSchema.lua` | shared | 子系统字段定义 |
| `XxxConsts.lua` | shared | 枚举、数值配表、网络事件名 |
| `XxxHandler.lua` | server | 网络事件入口、参数校验、调 Service |
| `XxxService.lua` | server | 业务逻辑、调 PDM 读写 |
| `XxxClient.lua` | client | 自建事件总线、监听结果事件 |

---

## 4. 核心数据流

```
客户端请求 → Handler → Service → PDM.SetStat() → SetVar(REPLICATED) → 客户端 PlayerStore.Get()
                                       │
                                  MarkDirty
                                       │
                          心跳/断线 → BatchCommit → serverCloud
```

### Handler 标准模式

```lua
function XxxHandler.OnAction(uid, data)
    -- 1. 参数校验
    if not data or not data.param then
        return SendFail(uid, EVENT, "missing_param")
    end
    -- 2. 调用 Service
    local ok, err = XxxService.Action(uid, data.param)
    if not ok then return SendFail(uid, EVENT, err) end
    -- 3. 即时同步（MarkDirty 有 0.1s 延迟）
    PDM.SyncXxx(uid)
    -- 4. 发送结果事件
    ServerSync.SendToClient(uid, EVENT_RESULT, { ok = true })
end
```

### 持久化模型（Dirty-Cache + BatchCommit）

```
SetStat/SetStruct → 更新内存 + SetVar(同步客户端) + MarkDirty(标记脏)
心跳信号 → BatchCommit → 收集所有脏数据 → serverCloud 批量写入
断线 → SaveAll(先保存) → UnloadPlayer(再清理)
```

### 断线保存时序（不可逆反）

```
断线信号到达
  → PDM.SaveAll(uid)       ← 先保存（数据仍在内存）
  → PDM.UnloadPlayer(uid)  ← 再清理（释放内存）
```

**反过来 = 写入空数据 = 玩家回档**

---

## 5. 九条铁律

> 违反任何一条 = 架构退化，必须立即修复。

### 铁律 1：依赖单向

```
shared ← 零依赖
server ← 可 require shared，禁止 require client
client ← 可 require shared，禁止 require server
```

### 铁律 2：shared 层零副作用

shared 层只允许：Schema 定义、常量/枚举、纯函数（输入→输出）。
禁止：引擎 API 调用、require 其他层、全局状态修改。

### 铁律 3：服务端权威 + PDM 单一数据源

- 所有游戏状态变更必须在**服务端**发生
- 服务端数据统一通过 **PDM** 管理：`Handler → Service → PDM.SetXxx()`
- 客户端**禁止自行维护缓存变量**：

```lua
-- ❌ 禁止
local goldTickets_ = 0
function OnGoldUpdate(data) goldTickets_ = data.value end

-- ✅ 正确
local gold = PlayerStore.Get("currency", "goldTickets")
```

### 铁律 4：禁止绕过 PDM

- 禁止 `SendToClient` 推送可由 PDM 自动同步的数据
- 禁止通过 V2 旧桥接层传递三层架构模块的数据
- `SendToClient` 仅用于**结果事件**（操作成功/失败通知）

### 铁律 5：Handler-Service 分离

| 层 | 职责 | 禁止 |
|---|---|---|
| Handler | 接收网络事件、参数校验、调用 Service、发送结果 | 业务逻辑、直接操作 PDM |
| Service | 业务逻辑、调用 PDM 读写 | 网络 IO、直接 Send |

### 铁律 6：REPLICATED Node 同步规则

- 数据同步只走 `SetVar`/`GetVar`
- 服务端写：`playerNode:SetVar("hp", Variant(currentHp))`
- 客户端读：`playerNode:GetVar("hp"):GetInt()`（自动同步）

### 铁律 7：SetVar 单帧 64KB 硬限制（静默丢包）

引擎 WebSocket 传输层单帧消息上限 65535 字节。超限时**静默丢弃**，不报脚本层错误。

```
❌ 禁止：对可增长的集合数据直接 PDM.SetStruct(uid, key, bigTable) 整体写入
✅ 必须：通过分包函数写入，将大 table 拆分为多个 chunk
```

**分包模式**：
```lua
-- 将 N 条记录拆为 ceil(N / CHUNK_SIZE) 个块
-- 每块独立 pdmKey: "XxxRegistry_0", "XxxRegistry_1", ...
-- 附加 meta 块: "XxxRegistry_meta" = { chunks = n, total = m }
-- 客户端按 meta.chunks 逐块读取并合并
```

**收口原则**：模块内部集合数据写入应统一收口到一个分包同步函数，禁止散落直接 `PDM.SetStruct` 调用。

### 铁律 8：Schema 唯一性 + 命名规范

- pdmKey 全局唯一，不同子系统不可复用
- 新代码不加 V1/V2 后缀
- require 路径使用三层架构路径（`server.xxx`、`client.xxx`、`shared.xxx`）

### 铁律 9：cjson 全局变量 + ChildNode Dispose

```lua
-- cjson 是全局变量
local cjson = cjson  -- ✅ 正确
-- local cjson = require("cjson")  -- ❌ 报错

-- 子节点清理用 Dispose
BattleService.Dispose(uid)  -- ✅ 正确
-- battleNode:Remove()       -- ❌ 错误
```

---

## 6. 避雷清单（P0-P3）

### P0 — 数据丢失/服务崩溃

| 问题 | 错误做法 | 正确做法 |
|------|---------|---------|
| 断线时序反转 → 回档 | UnloadPlayer → SaveAll | SaveAll → UnloadPlayer |
| 写时即存耗尽配额 | SetStat 时立即 serverCloud | MarkDirty → BatchCommit |
| 背包删除不完整 → 幽灵条目 | 只 table.remove(内存) | table.remove + ListDelete 双写 |
| 重复 LoadPlayer → 被踢 | ServerSync.OnCharacterSelected 调 LoadPlayer | 由 ServerCharacter 完成，禁重复调用 |

### P1 — 静默失败

| 问题 | 错误做法 | 正确做法 |
|------|---------|---------|
| 客户端缓存绕过 PDM | 本地变量接收推送 | PlayerStore.Get() 读取 |
| MarkDirty 延迟 → UI 不更新 | SetStat → 直接 SendResult | SetStat → SyncXxx → SendResult |
| V1 Client.Emit 不存在 | require V1 Client 调 Emit | 自建事件总线 |
| 结果事件读旧值 | 回调中直接读 PlayerStore | WaitForChange 等 REPLICATED 到达 |
| PreBattleGateway 阻断未调 onCancel | 阻断时只 return | 必须调 opts.onCancel() |

### P2 — 逻辑错误

| 问题 | 要点 |
|------|------|
| selfDamage 下限 | `math.max(1, damage)` 不是 0 |
| DoT tick 缺 skillStyle | layer/buff 上存储 skillStyle |
| HeartService 字段名 | 用 `slot.id` 不是 `slot.methodId` |
| QuotaProvider.Add 返回值 | 必须检查 `result.ok` |
| AdHandler OnWatchComplete | 必须同步 callback() |

### P3 — 架构违规

| 问题 | 要点 |
|------|------|
| 新模块数据链路经过 V2 桥接 | 消除依赖，用 PDM+PlayerStore |
| 在 V2 模块上修字段名适配 | 重建独立链路 |

### 症状 → 原因速查

| 症状 | 首先检查 |
|------|---------|
| 客户端数据不刷新 | 漏调 Sync*？用了本地缓存？ |
| 断线后数据回档 | SaveAll/UnloadPlayer 时序反了？ |
| 功能静默失败 | 字段名前后端不匹配？绕过 PDM？ |
| 首次登录被踢 | 重复调用 LoadPlayer？ |
| serverCloud 配额耗尽 | 写时即存而非 BatchCommit？ |
| 操作成功但 UI 无响应 | SendToClient 在 Sync 之前？ |
| 结果事件读到旧数据 | REPLICATED 延迟，用 WaitForChange |
| 三层模块调 Emit 报错 | 引用了 V1 Client？用自建事件总线 |
| 客户端加载超时无报错 | SetVar 超 64KB 静默丢包 |

---

## 7. 客户端同步宽容度（WaitForChange）

### 问题

REPLICATED 变量同步延迟 50-80ms，结果事件先于数据到达。客户端在事件回调中读 PlayerStore 拿到旧值。

### 时序图

```
T0  服务端: PDM.SetStat() + SetVar() + SyncXxx() + SendToClient(RESULT)
T1  客户端: 收到 RESULT 事件（~20ms）
    └→ UI 调 PlayerStore.Get() → ❌ 旧值
T2  客户端: REPLICATED 变量到达（~50-80ms）
    └→ PlayerStore 数据更新 → ❌ 没人再读了
```

### 解决方案：WaitForChange API

```lua
--- 等待 PlayerStore 某个字段变化
---@param key string       监听的 PlayerStore 键名
---@param opts table       { timeout, onChange, onTimeout, compare }
---@return function cancel 取消函数
function PlayerStore.WaitForChange(key, opts) end
```

### 使用模式

```lua
-- 1. 注册等待（发请求前）
local cancel = PlayerStore.WaitForChange("Gold", {
    timeout = 5.0,
    onChange = function(newVal, oldVal)
        -- REPLICATED 数据已到达，安全刷新 UI
        self:RefreshGoldDisplay(newVal)
    end,
    onTimeout = function()
        -- 兜底：超时后强制读一次
        self:RefreshGoldDisplay(PlayerStore.Get("Gold"))
    end,
})

-- 2. 发送请求
Client.SendToServer(NetworkEvents.REQUEST_BUY_ITEM, { itemId = itemId })

-- 3. 页面关闭时取消（防泄漏）
function Panel:Destroy()
    if cancel then cancel() end
end
```

### 多字段同时等待

```lua
local cancel1 = PlayerStore.WaitForChange("Gold", {
    onChange = function(v) self:RefreshGold(v) end,
})
local cancel2 = PlayerStore.WaitForChange("Equipment", {
    onChange = function(v) self:RefreshEquipList(v) end,
})
Client.SendToServer(NetworkEvents.REQUEST_FORGE, { ... })
```

### JSON struct 比较策略

```lua
-- table 类型无法直接 ~= 比较
PlayerStore.WaitForChange("Equipment", {
    compare = function(old, new)
        if type(old) ~= "table" or type(new) ~= "table" then return old ~= new end
        return #old ~= #new  -- 数量变了就算变了
    end,
    onChange = function(newVal) self:RefreshEquipList(newVal) end,
})
```

### 设计决策

| 决策 | 选择 | 原因 |
|------|------|------|
| 比较粒度 | 原始值（_GetRaw） | table 无法 ~=，string/number 零开销 |
| 轮询频率 | per-frame | 50-80ms 延迟最多多等 1 帧 |
| Update 订阅 | 按需注册/注销 | 无 watcher 时零开销 |
| 超时默认值 | 5.0s | 覆盖极端网络波动 |
| 取消机制 | 返回 cancel 函数 | 防止回调在已销毁 UI 上执行 |
| 回调保护 | pcall 包裹 | 回调报错不影响其他 watcher |

### 不适用场景

- **首次数据加载**：用 `SyncClient.IsReady()` + `NodeEvents.OnReady()`
- **连续高频更新**（实时位置）：直接每帧读 PlayerStore
- **服务端推送（无请求）**：用 `RegisterRemoteEvent` + `SubscribeToEvent`

---

## 8. 迁移操作规范

### 项目诊断流程

```
执行诊断命令（仅看目录结构）
  │
判定项目类型
  ├── 新项目/空项目     → 直接用模板搭建
  ├── 已是三层架构     → 仅检查合规性
  └── 中途改造项目     → 进入迁移流程
```

### 项目类型判定

| 条件 | 类型 | 后续 |
|------|------|------|
| lua 文件数 <= 3 | 新项目 | 直接搭建 |
| 已有 shared/server/client + Schema/Handler/Service | 已是三层 | 检查合规 |
| 有业务代码但不符合三层 | 中途改造 | 迁移流程 |

### 迁移铁律

1. **用户未明确同意前，禁止执行任何迁移操作**
2. **迁移前必须备份**：`cp -r scripts/ scripts_backup_$(date +%Y%m%d_%H%M%S)/`
3. **方案必须生成到 `docs/migration-plan.md`** 供用户审阅
4. **逐模块迁移 + 每步 build 验证**，失败则停止
5. **随时可回滚**：`cp -r scripts_backup_xxx/ scripts/`

### 文件分类规则（按文件名模式推断）

| 文件名模式 | 推测归属 |
|-----------|---------|
| *Schema.lua, *Defs.lua, *Consts.lua | shared |
| *Handler.lua, *Service.lua, *PDM.lua | server |
| *Client.lua, *Screen.lua, *Panel.lua, *UI.lua | client |
| *Utils.lua, *Calc.lua | shared 或需人工判断 |

### 执行顺序（严格）

1. **备份** → 2. **创建目录** → 3. **放置中心化单例** → 4. **逐模块迁移（每步 build）** → 5. **清理旧文件** → 6. **最终验证**

---

## 9. 模板代码

### 9.1 CharacterSchema.lua（shared/schemas/）

```lua
-- 角色核心字段统一定义（全项目唯一，中心化单例）
local CharacterSchema = {}

CharacterSchema.Fields = {
    level = {
        pdmKey = "Level",
        type   = "scalar",
        persist = { via = "cloud", cloudKey = "player_level" },
        desc   = "等级",
    },
    exp = {
        pdmKey = "Exp",
        type   = "scalar",
        persist = { via = "cloud", cloudKey = "player_exp" },
        desc   = "经验",
    },
    gold = {
        pdmKey = "Golds",
        type   = "scalar",
        persist = { via = "money", cloudKey = "gold" },
        desc   = "黄金",
    },
    uid = {
        pdmKey = "Uid",
        type   = "scalar",
        persist = false,
        desc   = "用户 ID（sync-only）",
    },
}

--- 注册子系统 Schema 字段
---@param schemaName string
---@param fields table<string, table>
function CharacterSchema.RegisterSubsystemFields(schemaName, fields)
    local count = 0
    for fieldKey, def in pairs(fields) do
        if CharacterSchema.Fields[fieldKey] then
            print(string.format("[CharacterSchema] WARN: 字段冲突 key=%s，跳过", fieldKey))
        else
            CharacterSchema.Fields[fieldKey] = def
            count = count + 1
        end
    end
    print(string.format("[CharacterSchema] %s → %d fields merged", schemaName, count))
end

--- 按持久化后端过滤
function CharacterSchema.GetFieldsByPersist(via)
    local result = {}
    for key, def in pairs(CharacterSchema.Fields) do
        if via == false then
            if def.persist == false then result[key] = def end
        elseif type(def.persist) == "table" and def.persist.via == via then
            result[key] = def
        end
    end
    return result
end

--- 获取 pdmKey → 字段定义映射
function CharacterSchema.GetPdmKeyMap()
    local result = {}
    for _, def in pairs(CharacterSchema.Fields) do
        result[def.pdmKey] = def
    end
    return result
end

return CharacterSchema
```

### 9.2 PlayerDataManager.lua（server/character/）

```lua
-- 统一数据管理器（PDM 核心，全项目唯一）
-- 职责：唯一 serverCloud 读写入口、管理 PlayerNode(REPLICATED)、
--       从 CharacterSchema 动态构建键注册表、Provider 注册机制
local PlayerDataManager = {}
local CharacterSchema = require("shared.schemas.CharacterSchema")

-- 从 Schema 动态构建键注册表
PlayerDataManager.SCALAR_KEYS = {}
PlayerDataManager.STRING_KEYS = {}
PlayerDataManager.JSON_KEYS   = {}

do
    for _, def in pairs(CharacterSchema.Fields) do
        local cloudKey = false
        if def.persist and type(def.persist) == "table" and def.persist.via ~= "money" then
            cloudKey = def.persist.cloudKey
        end
        local bucket = def.type == "scalar" and PlayerDataManager.SCALAR_KEYS
            or def.type == "string" and PlayerDataManager.STRING_KEYS
            or def.type == "json"   and PlayerDataManager.JSON_KEYS or nil
        if bucket then bucket[def.pdmKey] = cloudKey end
    end
end

-- Provider 注册机制
local providers_ = {}

function PlayerDataManager.RegisterProvider(name, provider, opts)
    providers_[name] = { provider = provider, deferred = opts and opts.deferred or false }
end

-- 货币/列表代理
function PlayerDataManager.AddMoney(uid, moneyKey, amount, callbacks)
    local e = providers_["money"]
    return e and e.provider.Add and e.provider.Add(uid, moneyKey, amount, callbacks)
end

function PlayerDataManager.GetMoney(uid, moneyKey)
    local e = providers_["money"]
    return e and e.provider.Get and e.provider.Get(uid, moneyKey) or 0
end

-- 核心 API
function PlayerDataManager.Setup(scene, server) end
function PlayerDataManager.LoadPlayer(uid, charId, connection, onComplete) end
function PlayerDataManager.RemovePlayer(uid, skipSave) end
function PlayerDataManager.SetStat(uid, varName, value) end
function PlayerDataManager.GetStat(uid, varName) end
function PlayerDataManager.AddStat(uid, varName, delta) end
function PlayerDataManager.SetStruct(uid, varName, value) end
function PlayerDataManager.GetStruct(uid, varName) end
function PlayerDataManager.GetNode(uid) end
function PlayerDataManager.SavePlayer(uid) end
function PlayerDataManager.Tick() end

return PlayerDataManager
```

### 9.3 PlayerStore.lua（client/data/）

```lua
-- 客户端统一数据访问层（全项目唯一）
-- 从 CharacterSchema 动态构建 keyMap，统一读取 SyncClient 数据
local PlayerStore = {}
local CharacterSchema = require("shared.schemas.CharacterSchema")

local syncClient_, ready_, keyMap_ = nil, false, {}

function PlayerStore.Init(opts)
    syncClient_ = opts.syncClient
    keyMap_ = {}
    for fieldKey, def in pairs(CharacterSchema.Fields) do
        keyMap_[fieldKey] = { pdmKey = def.pdmKey, type = def.type }
    end
    ready_ = true
end

function PlayerStore.Get(key)
    local entry = keyMap_[key]
    if not entry or not syncClient_ then return nil end
    if entry.type == "scalar" or entry.type == "string" then
        return syncClient_.GetStat(entry.pdmKey)
    elseif entry.type == "json" then
        return syncClient_.GetStruct(entry.pdmKey)
    end
end

function PlayerStore.GetMany(keys)
    local result = {}
    for _, key in ipairs(keys) do result[key] = PlayerStore.Get(key) end
    return result
end

function PlayerStore.IsReady()
    return ready_ and syncClient_ ~= nil and syncClient_.IsReady()
end

function PlayerStore.Cleanup() syncClient_ = nil; ready_ = false end

return PlayerStore
```

### 9.4 XxxSchema.lua（shared/xxx/）

```lua
-- 子系统 Schema 定义（注册到 CharacterSchema 后自动生效）
local XxxSchema = {}

XxxSchema.Fields = {
    xxxLevel = {
        pdmKey  = "XxxLevel",
        type    = "scalar",
        persist = { via = "cloud", cloudKey = "xxx_level" },
        desc    = "子系统等级",
    },
    xxxConfig = {
        pdmKey  = "XxxConfig",
        type    = "json",
        persist = { via = "cloud", cloudKey = "xxx_config" },
        desc    = "子系统配置数据",
    },
    xxxCurrency = {
        pdmKey  = "XxxCurrency",
        type    = "scalar",
        persist = { via = "money", cloudKey = "xxx_currency" },
        desc    = "子系统货币",
    },
    xxxDerived = {
        pdmKey  = "XxxDerived",
        type    = "json",
        persist = false,
        desc    = "派生数据（仅同步）",
    },
}

function XxxSchema.Defaults()
    return { xxxLevel = 1, xxxConfig = {}, xxxCurrency = 0, xxxDerived = {} }
end

return XxxSchema
```

### 9.5 XxxConsts.lua（shared/xxx/）

```lua
-- 常量/枚举/事件名（纯数据，零依赖）
local XxxConsts = {}

XxxConsts.State = { IDLE = "idle", ACTIVE = "active", DONE = "done" }

XxxConsts.Config = { MAX_LEVEL = 100, BASE_COST = 10, COOLDOWN_SEC = 60 }

XxxConsts.Events = {
    C2S_DO_ACTION     = "Xxx:DoAction",
    C2S_UPGRADE       = "Xxx:Upgrade",
    S2C_ACTION_RESULT = "Xxx:ActionResult",
    S2C_UPGRADE_RESULT = "Xxx:UpgradeResult",
}

return XxxConsts
```

### 9.6 XxxHandler.lua（server/xxx/）

```lua
-- 网络事件入口（参数校验 + 调 Service + 发送结果）
-- 禁止：业务逻辑、直接操作 PDM
local XxxService = require "server.xxx.XxxService"
local XxxConsts  = require "shared.xxx.XxxConsts"
local PDM        = require "server.sync.PDM"
local ServerSync = require "server.sync.ServerSync"

local E = XxxConsts.Events
local XxxHandler = {}

function XxxHandler.Init()
    ServerSync.On(E.C2S_DO_ACTION, XxxHandler.OnDoAction)
    ServerSync.On(E.C2S_UPGRADE,   XxxHandler.OnUpgrade)
end

function XxxHandler.OnDoAction(uid, data)
    if not data or not data.param1 then
        return ServerSync.SendToClient(uid, E.S2C_ACTION_RESULT, { ok = false, err = "missing_param" })
    end
    local ok, err = XxxService.DoAction(uid, data.param1)
    if not ok then
        return ServerSync.SendToClient(uid, E.S2C_ACTION_RESULT, { ok = false, err = err })
    end
    PDM.SyncXxx(uid)
    ServerSync.SendToClient(uid, E.S2C_ACTION_RESULT, { ok = true })
end

function XxxHandler.OnUpgrade(uid, data)
    local ok, err = XxxService.Upgrade(uid)
    if not ok then
        return ServerSync.SendToClient(uid, E.S2C_UPGRADE_RESULT, { ok = false, err = err })
    end
    PDM.SyncXxx(uid)
    ServerSync.SendToClient(uid, E.S2C_UPGRADE_RESULT, { ok = true })
end

return XxxHandler
```

### 9.7 XxxService.lua（server/xxx/）

```lua
-- 业务逻辑层（读写 PDM，纯逻辑计算）
-- 禁止：网络 IO、直接 Send、直接操作 serverCloud
local XxxSchema = require "shared.xxx.XxxSchema"
local XxxConsts = require "shared.xxx.XxxConsts"
local PDM       = require "server.sync.PDM"

local XxxService = {}

function XxxService.DoAction(uid, param1)
    local level = PDM.GetStat(uid, XxxSchema.Fields.xxxLevel.pdmKey)
    if level >= XxxConsts.Config.MAX_LEVEL then
        return false, "max_level_reached"
    end
    PDM.SetStat(uid, XxxSchema.Fields.xxxLevel.pdmKey, level + 1)
    return true
end

function XxxService.Upgrade(uid)
    local config = PDM.GetStruct(uid, XxxSchema.Fields.xxxConfig.pdmKey)
    -- 业务逻辑...
    PDM.SetStruct(uid, XxxSchema.Fields.xxxConfig.pdmKey, config)
    return true
end

function XxxService.AddItem(uid, item)
    local items = PDM.GetList(uid, "XxxItems")
    table.insert(items, item)
    PDM.SetList(uid, "XxxItems", items)
end

--- 删除列表项（必须双写：内存 + 持久化）
function XxxService.RemoveItem(uid, index)
    local items = PDM.GetList(uid, "XxxItems")
    local item = items[index]
    if not item then return false, "not_found" end
    table.remove(items, index)                    -- 内存
    PDM.ListDelete(uid, "XxxItems", item.id)      -- 持久化
    return true
end

return XxxService
```

### 9.8 XxxClient.lua（client/xxx/）

```lua
-- 客户端同步模块（监听结果事件 → 通知 UI）
-- 禁止：require server 层、自行维护缓存变量
local XxxConsts = require "shared.xxx.XxxConsts"
local PlayerStore = require "client.store.PlayerStore"

local E = XxxConsts.Events
local XxxClient = {}

-- 自建事件总线（禁依赖 V1/V2 Client.Emit）
local listeners_ = {}

function XxxClient.On(event, callback)
    listeners_[event] = listeners_[event] or {}
    table.insert(listeners_[event], callback)
end

local function emit(event, data)
    for _, cb in ipairs(listeners_[event] or {}) do cb(data) end
end

function XxxClient.Init(syncClient)
    syncClient:OnServerEvent(E.S2C_ACTION_RESULT, function(data)
        emit(data.ok and "ActionDone" or "ActionFail", data)
    end)
    syncClient:OnServerEvent(E.S2C_UPGRADE_RESULT, function(data)
        emit(data.ok and "UpgradeDone" or "UpgradeFail", data)
    end)
end

function XxxClient.DoAction(param1)
    PlayerStore.SendToServer(E.C2S_DO_ACTION, { param1 = param1 })
end

function XxxClient.Upgrade()
    PlayerStore.SendToServer(E.C2S_UPGRADE, {})
end

-- 读数据一律走 PlayerStore（禁止本地缓存）
function XxxClient.GetLevel() return PlayerStore.Get("xxxLevel") or 1 end
function XxxClient.GetConfig() return PlayerStore.Get("xxxConfig") or {} end

return XxxClient
```

---

## 10. GateManager 门控与操作队列

### 操作队列（OpQueue）

每个玩家一个操作队列，handler 自动入队，同一玩家的请求按顺序串行。

- handler 签名：`function(uid, eventData, done)`
- **每个执行路径末尾必须调用 `done()`**（含错误分支和异步回调的 ok/error）
- 忘记 `done()` → 该玩家操作队列**永久阻塞**

### GateManager 门控

为每个玩家维护命名门控锁，防止同一玩家同一资源的并发异步操作。

| 决策 | 选择 |
|------|------|
| 纯同步操作 | `Server.On` — 操作队列已保证串行 |
| 含异步回调（serverCloud/money） | `Server.OnGated` — 防回调期间同类请求并发 |

```lua
-- 纯同步 handler（操作队列保证串行）
server.On(NetworkEvents.REQUEST_XXX, function(uid, eventData, done)
    local data = XxxService.GetAll(uid)
    -- 业务校验...
    XxxService.SaveAll(uid, data)
    Server_.SendToClient(uid, EVT, { Ok = true })
    done()  -- 必须调用！
end)

-- 含异步操作的 handler（GateManager 防并发）
server.OnGated(NetworkEvents.REQUEST_BUY, "shop",
    NetworkEvents.BUY_RESULT, function(uid, eventData, done)
        PDM.AddMoney(uid, "gold", -cost, {
            ok = function()
                XxxService.AddItem(uid, item)
                done()  -- 异步回调中也必须 done()
            end,
            error = function(err)
                Server_.SendToClient(uid, EVT, { Ok = false, err = err })
                done()  -- 错误分支也必须 done()
            end,
        })
    end)
```

### Handler `done()` 检查清单

- [ ] 正常返回路径有 `done()`
- [ ] 每个 `return SendFail(...)` 前/后有 `done()`
- [ ] 异步回调的 ok 分支有 `done()`
- [ ] 异步回调的 error 分支有 `done()`
- [ ] 条件分支不存在漏掉 `done()` 的路径

# 三层架构铁律

> 违反任何一条 = 架构退化，必须立即修复。

## 1. 依赖方向（单向，不可逆）

```
shared ← 零依赖（不 require 任何层）
server ← 可 require shared，禁止 require client
client ← 可 require shared，禁止 require server
```

- 跨层调用只能通过**网络事件**（SendToClient / SendToServer）
- 禁止通过 `require` 绕过层级边界

## 2. shared 层约束

shared 层只允许：
- Schema 定义（字段表、pdmKey、persist 配置）
- 常量/枚举/数据表（Consts、Defs）
- 纯函数（输入→输出，无副作用）

**禁止**：
- 任何引擎 API 调用（`scene`, `node`, `network` 等）
- 任何 `require` 其他层的模块
- 任何全局状态修改或副作用

## 3. 数据流铁律

### 3.1 服务端权威
所有游戏状态变更必须在**服务端**发生。客户端只读取、展示、发送请求。

### 3.2 PDM 单一数据源
服务端数据统一通过 **PDM**（Player Data Manager）管理：
```
Handler（收请求）→ Service（算逻辑）→ PDM.SetXxx()（写数据）
```

### 3.3 禁止客户端缓存
客户端**禁止自行维护缓存变量**接收服务端推送数据。所有数据从 `PlayerStore.Get()` 读取。

```lua
-- ❌ 禁止
local goldTickets_ = 0
function OnGoldUpdate(data) goldTickets_ = data.value end

-- ✅ 正确
local gold = PlayerStore.Get("currency", "goldTickets")
```

### 3.4 禁止绕过 PDM
- 禁止 `SendToClient` 推送可由 PDM 自动同步的数据
- 禁止通过 V2 旧桥接层传递三层架构模块的数据
- `SendToClient` 仅用于**结果事件**（操作成功/失败通知）

## 4. Handler-Service 分离

| 层 | 职责 | 禁止 |
|---|---|---|
| Handler | 接收网络事件、参数校验、调用 Service、发送结果 | 业务逻辑、直接操作 PDM |
| Service | 业务逻辑、调用 PDM 读写 | 网络 IO、直接 Send |

```lua
-- Handler 模板
function XxxHandler.OnDoSomething(uid, data)
    local ok, err = XxxService.DoSomething(uid, data.param)
    if not ok then return SendFail(uid, EVENT, err) end
    PDM.SyncXxx(uid)  -- 即时同步
    SendToClient(uid, EVENT_RESULT, { ok = true })
end
```

## 5. REPLICATED Node 同步规则

### 5.1 数据同步只走 REPLICATED
服务端→客户端的**数据同步**只通过 REPLICATED Node 的 `SetVar`/`GetVar`：
```lua
-- 服务端写
playerNode:SetVar("hp", Variant(currentHp))

-- 客户端读（自动同步）
local hp = playerNode:GetVar("hp"):GetInt()
```

### 5.2 Dirty-Cache + BatchCommit
PDM 写入采用**脏标记缓存**模式，不是写时即存：
```
SetStat/SetStruct → 更新内存 + SetVar(同步客户端) + MarkDirty(标记脏)
心跳/断线 → BatchCommit → 收集所有脏数据 → serverCloud 持久化
```

### 5.3 SetVar 单帧 64KB 硬限制（静默丢包）

引擎 WebSocket 传输层对单帧消息有 **65535 字节**硬上限。`SetVar` 序列化后超限时**引擎静默丢弃，不报脚本层错误**，仅引擎日志有 `WebSocketTransport::Send - message size exceeds maximum 65535`。

**通用规则**：
```
❌ 禁止：对可增长的集合数据直接 PDM.SetStruct(uid, key, bigTable) 整体写入
✅ 必须：通过分包函数写入，将大 table 拆分为多个 chunk，每个 chunk 独立 SetVar
```

**分包模式**：
```lua
-- 将 N 条记录拆为 ceil(N / CHUNK_SIZE) 个块
-- 每块独立 pdmKey: "XxxRegistry_0", "XxxRegistry_1", ...
-- 附加 meta 块: "XxxRegistry_meta" = { chunks = n, total = m }
-- 客户端按 meta.chunks 逐块读取并合并
```

**必须检查的写入点**：
| 写入场景 | 是否需要分包 |
|---------|------------|
| LoadAll / OnLoad（首次全量加载） | ✅ 必须走分包 |
| 增量操作（Add/Remove/Modify 单条后整体同步） | ✅ 必须走分包（整体同步时数据量同样可能超限） |
| 数据迁移 / 批量导入 | ✅ 必须走分包 |
| 单条 scalar / 小 struct | ❌ 不需要 |

**收口原则**：模块内部对集合数据的 PDM 写入应**统一收口到一个分包同步函数**（如 `syncToPDM`），禁止在 LoadAll、增量回调、迁移逻辑中散落直接 `PDM.SetStruct` 调用。

**症状**：客户端加载超时 / 数据丢失，服务端用户脚本日志无报错。

### 5.4 断线保存时序（不可逆反）
```
断线信号到达
  → PDM.SaveAll(uid)       ← 先保存（数据仍在内存）
  → PDM.UnloadPlayer(uid)  ← 再卸载（清理内存）
```
**反过来 = 写入空数据 = 玩家回档**

## 6. Schema 唯一性

- 字段定义通过 Schema 获取，禁止硬编码重复定义
- pdmKey 在全局唯一，不同子系统不可复用
- 新增字段必须在 Schema 中声明 persist 配置

## 7. 命名规范

- 新代码**不加** V1/V2 后缀
- require 路径使用三层架构路径（`server.xxx`、`client.xxx`、`shared.xxx`）
- 禁止引用转发桩（`v2/client/xxx` 等过渡模块）

## 8. cjson 全局变量

```lua
-- ❌ 绝对禁止（会报错）
local cjson = require("cjson")

-- ✅ 正确（cjson 是全局变量）
local cjson = cjson
```

## 9. ChildNode 必须 Dispose

战斗、秘境等子节点使用 `Dispose()` 清理，不要用 `Remove()`：
```lua
-- ❌ 错误
battleNode:Remove()

-- ✅ 正确
BattleService.Dispose(uid)  -- 内部 cleanup + Remove
```

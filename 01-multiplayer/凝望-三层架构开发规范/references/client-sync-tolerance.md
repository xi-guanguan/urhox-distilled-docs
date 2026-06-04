# 客户端同步宽容度（Client Sync Tolerance）

> REPLICATED 变量同步延迟 50-80ms，结果事件先于数据到达，
> 客户端在事件回调中读 PlayerStore 拿到旧值。

## 问题时序

```
T0   服务端: PDM.SetStat() + SetVar() + SyncXxx() + SendToClient(RESULT)
T1   客户端: 收到 RESULT 事件（~20ms）
     └→ UI 调 PlayerStore.Get() → ❌ 旧值（REPLICATED 尚未到达）
T2   客户端: REPLICATED 变量到达（~50-80ms）
     └→ PlayerStore 数据更新 → ❌ 没人再读了
```

## 解决方案：WaitForChange 轮询模式

**核心思路**：发请求前注册 per-frame 轮询，检测目标字段变化，变化即回调，超时兜底。

### API 设计

```lua
--- 等待 PlayerStore 某个字段变化
---@param key string       要监听的 PlayerStore 键名
---@param opts table       配置项
---@return function cancel 取消函数
--
-- opts 字段：
--   timeout    number   超时秒数（默认 5.0）
--   onChange   function(newVal, oldVal)  变化回调
--   onTimeout  function()               超时回调（可选）
--   compare    function(old, new)->bool  自定义比较（可选，返回 true 表示"变了"）
--
function PlayerStore.WaitForChange(key, opts) end
```

### 使用模式

```lua
local PlayerStore = require("client.data.PlayerStore")

-- 1. 注册等待（发请求前）
local cancel = PlayerStore.WaitForChange("Gold", {
    timeout = 5.0,
    onChange = function(newVal, oldVal)
        -- REPLICATED 数据已到达，安全刷新 UI
        self:RefreshGoldDisplay(newVal)
    end,
    onTimeout = function()
        -- 兜底：超时后强制读一次（可能已经到了只是比较逻辑不对）
        local val = PlayerStore.Get("Gold")
        self:RefreshGoldDisplay(val)
    end,
})

-- 2. 发送请求
Client.SendToServer(NetworkEvents.REQUEST_BUY_ITEM, { itemId = itemId })

-- 3. 页面关闭时取消（防泄漏）
function Panel:Destroy()
    if cancel then cancel() end
end
```

### JSON struct 字段的比较

table 类型无法直接 `~=` 比较。两种策略：

```lua
-- 策略 A：默认用原始 string 比较（推荐，零开销）
-- PlayerStore 内部实现会从 SyncClient 读原始 Variant string
-- 不需要 decode 后做 deep equal

-- 策略 B：比较特定子字段（精准）
PlayerStore.WaitForChange("Equipment", {
    compare = function(old, new)
        if type(old) ~= "table" or type(new) ~= "table" then
            return old ~= new
        end
        return #old ~= #new  -- 数量变了就算变了
    end,
    onChange = function(newVal)
        self:RefreshEquipList(newVal)
    end,
})
```

### 实现要点

```lua
-- =============================================
-- PlayerStore 内部实现参考
-- =============================================

local activeWatchers_ = {}  -- { key, oldValue, opts, elapsed, id }
local watcherIdSeq_ = 0
local updateSubscribed_ = false

function PlayerStore.WaitForChange(key, opts)
    opts = opts or {}
    opts.timeout = opts.timeout or 5.0

    watcherIdSeq_ = watcherIdSeq_ + 1
    local id = watcherIdSeq_

    local watcher = {
        id       = id,
        key      = key,
        oldValue = PlayerStore._GetRaw(key),  -- 快照原始值（string 级别）
        opts     = opts,
        elapsed  = 0,
    }

    table.insert(activeWatchers_, watcher)

    -- 有 watcher 时才订阅 Update，避免空转
    if not updateSubscribed_ then
        SubscribeToEvent("Update", "HandlePlayerStoreWatcherUpdate")
        updateSubscribed_ = true
    end

    -- 返回取消函数
    return function()
        for i = #activeWatchers_, 1, -1 do
            if activeWatchers_[i].id == id then
                table.remove(activeWatchers_, i)
                break
            end
        end
        if #activeWatchers_ == 0 and updateSubscribed_ then
            UnsubscribeFromEvent("Update")
            updateSubscribed_ = false
        end
    end
end

function HandlePlayerStoreWatcherUpdate(eventType, eventData)
    local dt = eventData["TimeStep"]:GetFloat()

    for i = #activeWatchers_, 1, -1 do
        local w = activeWatchers_[i]
        w.elapsed = w.elapsed + dt

        -- 检测变化
        local newRaw = PlayerStore._GetRaw(w.key)
        local changed = false

        if w.opts.compare then
            -- 自定义比较：传入 decode 后的新旧值
            local newDecoded = PlayerStore.Get(w.key)
            changed = w.opts.compare(w.oldValue, newDecoded)
        else
            -- 默认：原始值比较（string/number）
            changed = (newRaw ~= w.oldValue)
        end

        if changed then
            table.remove(activeWatchers_, i)
            local newVal = PlayerStore.Get(w.key)
            if w.opts.onChange then
                local ok, err = pcall(w.opts.onChange, newVal, w.oldValue)
                if not ok then
                    print("[PlayerStore] WaitForChange onChange error: " .. tostring(err))
                end
            end
        elseif w.elapsed >= w.opts.timeout then
            table.remove(activeWatchers_, i)
            if w.opts.onTimeout then
                local ok, err = pcall(w.opts.onTimeout)
                if not ok then
                    print("[PlayerStore] WaitForChange onTimeout error: " .. tostring(err))
                end
            end
        end
    end

    -- 全部完成，取消订阅
    if #activeWatchers_ == 0 and updateSubscribed_ then
        UnsubscribeFromEvent("Update")
        updateSubscribed_ = false
    end
end
```

### 关键设计决策

| 决策 | 选择 | 原因 |
|------|------|------|
| 比较粒度 | 原始值（`_GetRaw`） | table 无法 `~=`，string/number 零开销 |
| 轮询频率 | per-frame（~16ms@60fps） | 50-80ms 延迟最多多等 1 帧 |
| Update 订阅 | 按需注册/注销 | 无 watcher 时零开销 |
| 超时默认值 | 5.0s | 覆盖极端网络波动，正常 < 100ms 内完成 |
| 取消机制 | 返回 cancel 函数 | 页面销毁时调用，防止回调在已销毁 UI 上执行 |
| 回调保护 | pcall 包裹 | 回调报错不影响其他 watcher |

### 典型场景

| 场景 | 监听字段 | 超时 |
|------|---------|------|
| 购买物品 | `"Gold"` | 5s |
| 装备变更 | `"Equipment"` | 5s |
| 升级 | `"Level"`, `"Exp"` | 5s |
| 技能学习 | `"Skills"` | 5s |
| 锻造装备 | `"Equipment"` + `"Gold"` | 5s |

### 多字段同时等待

```lua
-- 锻造：同时等 Gold 和 Equipment 变化
local cancel1 = PlayerStore.WaitForChange("Gold", {
    onChange = function(v) self:RefreshGold(v) end,
})
local cancel2 = PlayerStore.WaitForChange("Equipment", {
    onChange = function(v) self:RefreshEquipList(v) end,
})

Client.SendToServer(NetworkEvents.REQUEST_FORGE, { ... })

-- 统一取消
function Panel:Destroy()
    if cancel1 then cancel1() end
    if cancel2 then cancel2() end
end
```

### 与现有机制的关系

| 机制 | 用途 | WaitForChange 替代？ |
|------|------|---------------------|
| SyncClient 脏读保护 | 防闪回（值短暂回退） | ❌ 互补，不替代 |
| PlayerStore Push 缓存 | ComputedStats 等推送缓存 | ❌ 互补 |
| PDM.SyncXxx | 服务端即时同步到引擎 | ❌ 前置条件 |
| NodeAdded 延迟一帧 | 首次节点到达 | ❌ 不同场景 |

**WaitForChange 解决的是**："结果事件到了，但 REPLICATED 数据还没到"这个 50-80ms 窗口。

### 不适用的场景

- **首次数据加载**：用 SyncClient.IsReady() + NodeEvents.OnReady()
- **连续高频更新**（如实时位置）：直接每帧读 PlayerStore，不需要事件驱动
- **服务端推送（无客户端请求）**：用 RegisterRemoteEvent + SubscribeToEvent

### _GetRaw 实现说明

`_GetRaw` 需要从 SyncClient 读取原始 Variant 值，避免 decode 开销：

```lua
--- 获取原始值（string/number 级别，用于比较）
function PlayerStore._GetRaw(key)
    local var = SyncClient.GetVar(key)
    if not var or var:IsEmpty() then return nil end
    if var:GetTypeName() == "String" then
        return var:GetString()
    else
        return var:GetInt()  -- scalar 直接比较数值
    end
end
```

-- ============================================================================
-- PlayerStore.lua — 客户端统一数据访问层（全项目唯一）
-- 路径: client/data/PlayerStore.lua
--
-- 职责:
--   1. 从 CharacterSchema 动态构建 keyMap（零硬编码）
--   2. 统一读取 SyncClient 数据，屏蔽 pdmKey 细节
--   3. 只读接口（客户端不写数据）
--   4. WaitForChange — 一次性等待字段变化（结果事件回调用）
--   5. Watch/Unwatch/UnwatchAll — 持久字段监听（scope 自动清理）
--
-- 数据同步原理:
--   服务端 PDM.SetStat → node:SetVar(REPLICATED)
--   → 引擎自动同步到客户端 PlayerNode
--   → PlayerStore.Get(key) → SyncClient.GetStat/GetStruct → node:GetVar
--
-- 新增子系统接入方式:
--   1. 在 CharacterSchema.Fields 中声明新字段
--   2. PlayerStore 自动注册，无需修改本文件
--   3. UI 层通过 PlayerStore.Get("fieldKey") 读取
-- ============================================================================

local PlayerStore = {}

local CharacterSchema = require("shared.schemas.CharacterSchema")

-- ============================================================================
-- 内部状态
-- ============================================================================

local syncClient_  ---@type table SyncClient 模块引用
local ready_ = false
local keyMap_ = {} ---@type table<string, { pdmKey: string, type: string }>

-- WaitForChange 一次性监听
local activeWatchers_ = {} ---@type table[]
local updateSubscribed_ = false

-- Watch 持久监听
local persistentWatchers_ = {} ---@type table<integer, table>
local persistentIdSeq_ = 0

-- ============================================================================
-- 初始化
-- ============================================================================

--- 初始化 PlayerStore（App 启动时调用一次）
---@param opts table { syncClient: SyncClient }
function PlayerStore.Init(opts)
    syncClient_ = opts.syncClient

    -- 从 CharacterSchema 动态构建 keyMap
    keyMap_ = {}
    for fieldKey, def in pairs(CharacterSchema.Fields) do
        keyMap_[fieldKey] = {
            pdmKey = def.pdmKey,
            type   = def.type,  -- "scalar" | "string" | "json"
        }
    end

    ready_ = true
end

-- ============================================================================
-- 数据读取（核心 API）
-- ============================================================================

--- 获取单个字段值
---@param key string 业务键名（CharacterSchema.Fields 中的 key）
---@return any
function PlayerStore.Get(key)
    local entry = keyMap_[key]
    if not entry or not syncClient_ then return nil end

    if entry.type == "scalar" or entry.type == "string" then
        return syncClient_.GetStat(entry.pdmKey)
    elseif entry.type == "json" then
        return syncClient_.GetStruct(entry.pdmKey)
    end
end

--- 获取原始值（用于 Watch 变化检测）
---@param key string
---@return any
function PlayerStore._GetRaw(key)
    local entry = keyMap_[key]
    if not entry or not syncClient_ then return nil end
    return syncClient_.GetStat(entry.pdmKey)
end

--- 批量获取多个字段值
---@param keys string[]
---@return table<string, any>
function PlayerStore.GetMany(keys)
    local result = {}
    for _, key in ipairs(keys) do
        result[key] = PlayerStore.Get(key)
    end
    return result
end

-- ============================================================================
-- WaitForChange — 一次性等待字段变化（配合结果事件使用）
-- ============================================================================

--- 注册一次性变化监听（REPLICATED 到达后触发一次即移除）
---@param key string 要监听的字段
---@param opts table { onChange: function(newVal), timeout?: number, onTimeout?: function }
function PlayerStore.WaitForChange(key, opts)
    local watcher = {
        key       = key,
        onChange  = opts.onChange,
        onTimeout = opts.onTimeout,
        timeout   = opts.timeout or 5.0,
        elapsed   = 0,
        lastRaw   = PlayerStore._GetRaw(key),
    }
    table.insert(activeWatchers_, watcher)

    if not updateSubscribed_ then
        SubscribeToEvent("Update", "HandlePlayerStoreWatcherUpdate")
        updateSubscribed_ = true
    end
end

-- ============================================================================
-- Watch — 持久字段监听（scope 自动清理）
-- ============================================================================

--- 注册持久字段监听（每帧轮询 raw 值变化）
---@param key string 要监听的字段
---@param callback function(newVal, oldRaw) 变化回调
---@param scope string? 所属页面/模块 scope（用于 UnwatchAll 自动清理）
---@return integer watcherId 用于手动 Unwatch
function PlayerStore.Watch(key, callback, scope)
    assert(type(key) == "string", "[PlayerStore] Watch: key 必须是 string")
    assert(type(callback) == "function", "[PlayerStore] Watch: callback 必须是 function")

    persistentIdSeq_ = persistentIdSeq_ + 1
    local id = persistentIdSeq_
    persistentWatchers_[id] = {
        key      = key,
        scope    = scope,
        callback = callback,
        lastRaw  = PlayerStore._GetRaw(key),
    }

    if not updateSubscribed_ then
        SubscribeToEvent("Update", "HandlePlayerStoreWatcherUpdate")
        updateSubscribed_ = true
    end

    return id
end

--- 移除单个持久监听
---@param watcherId integer Watch 返回的 ID
function PlayerStore.Unwatch(watcherId)
    persistentWatchers_[watcherId] = nil
    PlayerStore._CheckUnsubscribe()
end

--- 移除指定 scope 下所有持久监听（页面切换时自动调用）
---@param scope string
---@return integer count 移除数量
function PlayerStore.UnwatchAll(scope)
    assert(type(scope) == "string", "[PlayerStore] UnwatchAll: scope 必须是 string")
    local count = 0
    for id, w in pairs(persistentWatchers_) do
        if w.scope == scope then
            persistentWatchers_[id] = nil
            count = count + 1
        end
    end
    PlayerStore._CheckUnsubscribe()
    if count > 0 then
        print("[PlayerStore] UnwatchAll('" .. scope .. "'): removed " .. count .. " watchers")
    end
    return count
end

--- 检查是否需要取消 Update 订阅
function PlayerStore._CheckUnsubscribe()
    if #activeWatchers_ == 0 and not next(persistentWatchers_) and updateSubscribed_ then
        UnsubscribeFromEvent("Update")
        updateSubscribed_ = false
    end
end

-- ============================================================================
-- Update 轮询（WaitForChange + Watch 共用）
-- ============================================================================

function HandlePlayerStoreWatcherUpdate(eventType, eventData)
    local dt = eventData["TimeStep"]:GetFloat()

    -- 1) WaitForChange 一次性监听
    local i = 1
    while i <= #activeWatchers_ do
        local w = activeWatchers_[i]
        local newRaw = PlayerStore._GetRaw(w.key)
        if newRaw ~= w.lastRaw then
            local newVal = PlayerStore.Get(w.key)
            table.remove(activeWatchers_, i)
            pcall(w.onChange, newVal)
        else
            w.elapsed = w.elapsed + dt
            if w.elapsed >= w.timeout then
                table.remove(activeWatchers_, i)
                if w.onTimeout then pcall(w.onTimeout) end
            else
                i = i + 1
            end
        end
    end

    -- 2) Watch 持久监听
    for id, w in pairs(persistentWatchers_) do
        local newRaw = PlayerStore._GetRaw(w.key)
        if newRaw ~= w.lastRaw then
            local oldVal = w.lastRaw
            w.lastRaw = newRaw  -- 先更新，防止回调内再次触发
            local newVal = PlayerStore.Get(w.key)
            local ok, err = pcall(w.callback, newVal, oldVal)
            if not ok then
                print(string.format("[PlayerStore] Watch callback error (key=%s, id=%d): %s",
                    w.key, id, tostring(err)))
            end
        end
    end

    -- 3) 无活跃监听时取消 Update 订阅
    if #activeWatchers_ == 0 and not next(persistentWatchers_) and updateSubscribed_ then
        UnsubscribeFromEvent("Update")
        updateSubscribed_ = false
    end
end

-- ============================================================================
-- 状态查询
-- ============================================================================

--- 是否已就绪
---@return boolean
function PlayerStore.IsReady()
    return ready_ and syncClient_ ~= nil and syncClient_.IsReady()
end

-- ============================================================================
-- 清理
-- ============================================================================

function PlayerStore.Cleanup()
    syncClient_ = nil
    ready_ = false
    activeWatchers_ = {}
    persistentWatchers_ = {}
    if updateSubscribed_ then
        UnsubscribeFromEvent("Update")
        updateSubscribed_ = false
    end
end

return PlayerStore

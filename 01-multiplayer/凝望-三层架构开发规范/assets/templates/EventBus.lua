-- ============================================================================
-- EventBus.lua — 轻量事件总线工厂（每子系统独立实例）
-- 路径: client/net/EventBus.lua
--
-- 用法:
--   local EventBus = require("client.net.EventBus")
--   local bus = EventBus.New()  -- 每个 XxxClient 持有独立实例
--
--   -- UI 页面注册监听（带 scope）
--   bus:On("ActionDone", callback, "BattlePage")
--
--   -- XxxClient.HandleDispatch 中触发
--   bus:Emit("ActionDone", data)
--
--   -- 页面切换时清理（由 NavigateTo 自动调用）
--   bus:OffScope("BattlePage")
--
-- 设计原则:
--   - 每个子系统持有独立 bus 实例，互不干扰
--   - scope 机制确保页面切换时自动清理监听，防止幽灵回调
--   - Off(id) 支持手动移除单个监听
-- ============================================================================

local EventBus = {}
EventBus.__index = EventBus

local idSeq_ = 0

--- 创建新的事件总线实例
---@return table EventBus instance
function EventBus.New()
    local self = setmetatable({}, EventBus)
    self._listeners = {}  ---@type table<string, table[]>
    return self
end

--- 注册事件监听
---@param event string 事件名
---@param callback function 回调函数
---@param scope string? 所属 scope（用于 OffScope 批量清理）
---@return integer listenerId 用于 Off(id) 手动移除
function EventBus:On(event, callback, scope)
    assert(type(event) == "string", "[EventBus] event 必须是 string")
    assert(type(callback) == "function", "[EventBus] callback 必须是 function")

    idSeq_ = idSeq_ + 1
    local id = idSeq_

    self._listeners[event] = self._listeners[event] or {}
    table.insert(self._listeners[event], {
        id       = id,
        callback = callback,
        scope    = scope,
    })

    return id
end

--- 触发事件（同步调用所有监听者）
---@param event string 事件名
---@param data any? 传递给回调的数据
function EventBus:Emit(event, data)
    local list = self._listeners[event]
    if not list then return end

    for _, entry in ipairs(list) do
        local ok, err = pcall(entry.callback, data)
        if not ok then
            print(string.format("[EventBus] callback error (event=%s, id=%d): %s",
                event, entry.id, tostring(err)))
        end
    end
end

--- 移除单个监听
---@param listenerId integer On() 返回的 ID
function EventBus:Off(listenerId)
    for event, list in pairs(self._listeners) do
        for i, entry in ipairs(list) do
            if entry.id == listenerId then
                table.remove(list, i)
                return
            end
        end
    end
end

--- 移除指定 scope 下所有监听（页面切换时调用）
---@param scope string
---@return integer count 移除数量
function EventBus:OffScope(scope)
    assert(type(scope) == "string", "[EventBus] scope 必须是 string")
    local count = 0
    for event, list in pairs(self._listeners) do
        local i = 1
        while i <= #list do
            if list[i].scope == scope then
                table.remove(list, i)
                count = count + 1
            else
                i = i + 1
            end
        end
    end
    return count
end

--- 移除所有监听（模块卸载时调用）
function EventBus:Clear()
    self._listeners = {}
end

return EventBus

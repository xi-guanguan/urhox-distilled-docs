-- ============================================================================
-- ClientDispatcher.lua — 客户端网络事件统一分发器（全项目唯一）
-- 路径: client/net/ClientDispatcher.lua
--
-- 职责:
--   1. Init() 时从 NetworkEvents 获取所有事件 → 批量 SubscribeToEvent
--   2. 收到远程事件 → 按前缀路由到对应 XxxClient.HandleDispatch
--   3. 维护 scope→callbacks 映射，支持页面切换时 ClearScope
--
-- 铁律:
--   - _G 函数必须在 SubscribeToEvent 之前创建（引擎订阅时即解析引用）
--   - 每个事件只订阅一次（subscribedEvents_ 去重）
-- ============================================================================

local NetworkEvents = require("shared.NetworkEvents")
local cjson = cjson  -- 全局变量，禁止 require

local ClientDispatcher = {}

local subscribedEvents_ = {} ---@type table<string, boolean>
local handlers_ = {}         ---@type table<string, table>  prefix → { module, scope }[]

-- ============================================================================
-- 初始化
-- ============================================================================

--- 初始化分发器：订阅所有已注册的远程事件
function ClientDispatcher.Init()
    local allEvents = NetworkEvents.GetAllEvents()
    for _, eventName in ipairs(allEvents) do
        ClientDispatcher._SubscribeEvent(eventName)
    end
    print("[ClientDispatcher] Init: subscribed " .. #allEvents .. " events")
end

--- 内部：订阅单个远程事件
---@param eventName string
function ClientDispatcher._SubscribeEvent(eventName)
    if subscribedEvents_[eventName] then return end

    network:RegisterRemoteEvent(eventName)

    -- 🔴 铁律 #10: 先创建全局函数，再订阅（引擎订阅时即解析 _G 引用）
    local funcName = "HandleClientDispatcherEvent_" .. eventName
    _G[funcName] = function(eventType, eventData)
        ClientDispatcher._OnRemoteEvent(eventName, eventData)
    end

    SubscribeToEvent(eventName, funcName)

    subscribedEvents_[eventName] = true
end

-- ============================================================================
-- 事件路由
-- ============================================================================

--- 内部：远程事件到达 → 解码数据 → 按前缀路由
---@param eventName string
---@param eventData table
function ClientDispatcher._OnRemoteEvent(eventName, eventData)
    -- 解码 payload
    local raw = eventData["Data"] and eventData["Data"]:GetString() or ""
    local data = {}
    if #raw > 0 then
        local ok, decoded = pcall(cjson.decode, raw)
        if ok then data = decoded end
    end

    -- 按前缀路由
    local prefix = NetworkEvents.GetPrefix(eventName)
    if not prefix then
        print("[ClientDispatcher] 未知事件前缀: " .. eventName)
        return
    end

    local handlerList = handlers_[prefix]
    if handlerList then
        for _, entry in ipairs(handlerList) do
            local ok, err = pcall(entry.module.HandleDispatch, eventName, data)
            if not ok then
                print(string.format("[ClientDispatcher] HandleDispatch error (%s): %s",
                    eventName, tostring(err)))
            end
        end
    end
end

-- ============================================================================
-- 子系统注册
-- ============================================================================

--- 注册子系统处理模块（通常在 XxxClient 初始化时调用）
---@param prefix string 子系统前缀（如 "Battle"）
---@param module table 必须有 HandleDispatch(eventName, data) 方法
---@param scope string? 所属 scope（用于 ClearScope 自动清理）
function ClientDispatcher.Register(prefix, module, scope)
    assert(type(module.HandleDispatch) == "function",
        "[ClientDispatcher] module 必须实现 HandleDispatch(eventName, data)")
    handlers_[prefix] = handlers_[prefix] or {}
    table.insert(handlers_[prefix], { module = module, scope = scope })
end

--- 清理指定 scope 的所有处理器（页面切换时自动调用）
---@param scope string
function ClientDispatcher.ClearScope(scope)
    local count = 0
    for prefix, list in pairs(handlers_) do
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
    if count > 0 then
        print("[ClientDispatcher] ClearScope('" .. scope .. "'): removed " .. count .. " handlers")
    end
end

return ClientDispatcher

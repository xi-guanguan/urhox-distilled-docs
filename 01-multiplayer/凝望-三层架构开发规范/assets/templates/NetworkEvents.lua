-- ============================================================================
-- NetworkEvents.lua — 全局网络事件注册中心（全项目唯一）
-- 路径: shared/NetworkEvents.lua
--
-- 职责:
--   1. 收集所有子系统的 EVENT_* 事件名到统一注册表
--   2. 前缀冲突校验（同一事件名不可被两个子系统注册）
--   3. 提供 GetAllEvents() 供 ClientDispatcher 批量订阅
--   4. 提供 GetPrefix(eventName) 供路由时提取前缀
--
-- 接入方式:
--   在 CharacterSchema.lua 底部（子系统注册区域）调用：
--   NetworkEvents.RegisterSubsystem("Battle", BattleConsts)
--
-- 收集规则:
--   遍历 constsModule 中所有 key 以 "EVENT_" 开头的字段
--   值必须是 string 且以 "{prefix}_" 开头（否则 error）
-- ============================================================================

local NetworkEvents = {}

local registry_ = {}     ---@type table<string, string>  eventName → subsystemPrefix
local prefixMap_ = {}    ---@type table<string, string>  prefix → subsystem name (for debug)

--- 注册一个子系统的所有事件
---@param prefix string 子系统前缀（如 "Battle"），事件值必须以此开头
---@param constsModule table XxxConsts 模块（收集所有 EVENT_* 字段）
function NetworkEvents.RegisterSubsystem(prefix, constsModule)
    assert(type(prefix) == "string" and #prefix > 0, "[NetworkEvents] prefix 不能为空")
    assert(type(constsModule) == "table", "[NetworkEvents] constsModule 必须是 table")

    if prefixMap_[prefix] then
        error("[NetworkEvents] 前缀 '" .. prefix .. "' 已被注册，不可重复")
    end
    prefixMap_[prefix] = prefix

    local expectedPrefix = prefix .. "_"
    local count = 0

    for key, value in pairs(constsModule) do
        -- 只收集 EVENT_ 开头的键
        if type(key) == "string" and key:sub(1, 6) == "EVENT_" then
            assert(type(value) == "string",
                string.format("[NetworkEvents] %s.%s 的值必须是 string，实际是 %s",
                    prefix, key, type(value)))
            assert(value:sub(1, #expectedPrefix) == expectedPrefix,
                string.format("[NetworkEvents] %s.%s = '%s' 必须以 '%s' 开头",
                    prefix, key, value, expectedPrefix))

            -- 冲突检测
            if registry_[value] then
                error(string.format(
                    "[NetworkEvents] 事件名冲突: '%s' 已被 '%s' 注册，'%s' 不可重复注册",
                    value, registry_[value], prefix))
            end

            registry_[value] = prefix
            count = count + 1
        end
    end

    print(string.format("[NetworkEvents] 注册子系统 '%s': %d 个事件", prefix, count))
end

--- 获取所有已注册事件名列表
---@return string[]
function NetworkEvents.GetAllEvents()
    local list = {}
    for eventName, _ in pairs(registry_) do
        table.insert(list, eventName)
    end
    return list
end

--- 从事件名提取前缀（用于路由）
---@param eventName string 如 "Battle_ReqStart"
---@return string? prefix 如 "Battle"，未注册返回 nil
function NetworkEvents.GetPrefix(eventName)
    return registry_[eventName]
end

--- 获取注册统计信息（调试用）
---@return table { total: number, subsystems: string[] }
function NetworkEvents.GetStats()
    local subsystems = {}
    for prefix, _ in pairs(prefixMap_) do
        table.insert(subsystems, prefix)
    end
    local total = 0
    for _ in pairs(registry_) do total = total + 1 end
    return { total = total, subsystems = subsystems }
end

return NetworkEvents

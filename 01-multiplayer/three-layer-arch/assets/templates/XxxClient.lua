------------------------------------------------------------------------
-- client/xxx/XxxClient.lua
-- 客户端同步模块（监听 REPLICATED 变量 + 结果事件 → 通知 UI）
-- 禁止：require server 层、自行维护缓存变量
------------------------------------------------------------------------
local XxxSchema = require "shared.xxx.XxxSchema"
local XxxConsts = require "shared.xxx.XxxConsts"
local PlayerStore = require "client.store.PlayerStore"

local E = XxxConsts.Events
local XxxClient = {}

--- 内部事件总线（三层架构模块禁止依赖 V1/V2 Client.Emit）
local listeners_ = {}

--- 注册事件监听
function XxxClient.On(event, callback)
    listeners_[event] = listeners_[event] or {}
    table.insert(listeners_[event], callback)
end

--- 触发事件
local function emit(event, data)
    for _, cb in ipairs(listeners_[event] or {}) do
        cb(data)
    end
end

--- 初始化：监听服务端结果事件
function XxxClient.Init(syncClient)
    syncClient:OnServerEvent(E.S2C_ACTION_RESULT, function(data)
        if data.ok then
            emit("ActionDone", data)
        else
            emit("ActionFail", { err = data.err })
        end
    end)

    syncClient:OnServerEvent(E.S2C_UPGRADE_RESULT, function(data)
        if data.ok then
            emit("UpgradeDone", data)
        else
            emit("UpgradeFail", { err = data.err })
        end
    end)
end

--- 发送请求到服务端
function XxxClient.DoAction(param1)
    PlayerStore.SendToServer(E.C2S_DO_ACTION, { param1 = param1 })
end

function XxxClient.Upgrade()
    PlayerStore.SendToServer(E.C2S_UPGRADE, {})
end

--- 读取数据（从 PlayerStore，禁止本地缓存）
function XxxClient.GetLevel()
    return PlayerStore.Get("xxx", "level") or 1
end

function XxxClient.GetConfig()
    return PlayerStore.Get("xxx", "config") or {}
end

function XxxClient.GetItems()
    return PlayerStore.Get("xxx", "items") or {}
end

return XxxClient

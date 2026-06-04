------------------------------------------------------------------------
-- client/xxx/XxxClient.lua
-- 客户端子系统模块（事件分发入口 + UI 通知 + 请求发送）
--
-- 职责:
--   1. 实现 HandleDispatch(eventName, data)（由 ClientDispatcher 路由调用）
--   2. 通过 EventBus 向 UI 层广播业务事件
--   3. 提供 SendXxx() 封装向服务端发请求
--   4. 提供 GetXxx() 从 PlayerStore 读数据（禁止本地缓存）
--
-- 禁止：require server 层、自行维护缓存变量、依赖 V1/V2 Client.Emit
------------------------------------------------------------------------
local XxxConsts   = require("shared.xxx.XxxConsts")
local PlayerStore = require("client.data.PlayerStore")
local EventBus    = require("client.net.EventBus")

local XxxClient = {}

--- 子系统专属事件总线（独立实例，scope 自动清理）
XxxClient.Bus = EventBus.New()

-- ============================================================================
-- ClientDispatcher 分发入口（必须实现）
-- ============================================================================

--- 由 ClientDispatcher 根据前缀路由调用
---@param eventName string 完整事件名（如 "Xxx_ResDoAction"）
---@param data table 反序列化后的数据
function XxxClient.HandleDispatch(eventName, data)
    if eventName == XxxConsts.EVENT_RES_DO_ACTION then
        if data.ok then
            XxxClient.Bus:Emit("ActionDone", data)
        else
            XxxClient.Bus:Emit("ActionFail", { err = data.err })
        end

    elseif eventName == XxxConsts.EVENT_RES_UPGRADE then
        if data.ok then
            XxxClient.Bus:Emit("UpgradeDone", data)
        else
            XxxClient.Bus:Emit("UpgradeFail", { err = data.err })
        end

    elseif eventName == XxxConsts.EVENT_PUSH_STATE_CHANGE then
        XxxClient.Bus:Emit("StateChanged", data)
    end
end

-- ============================================================================
-- 请求接口（供 UI 页面调用）
-- ============================================================================

function XxxClient.DoAction(param1)
    local ServerSync = require("client.net.ServerSync")  -- 延迟 require 避免循环
    ServerSync.SendToServer(XxxConsts.EVENT_REQ_DO_ACTION, { param1 = param1 })
end

function XxxClient.Upgrade()
    local ServerSync = require("client.net.ServerSync")
    ServerSync.SendToServer(XxxConsts.EVENT_REQ_UPGRADE, {})
end

-- ============================================================================
-- 数据读取（从 PlayerStore，禁止本地缓存）
-- ============================================================================

function XxxClient.GetLevel()
    return PlayerStore.Get("xxxLevel") or 1
end

function XxxClient.GetItems()
    return PlayerStore.Get("xxxItems") or {}
end

return XxxClient

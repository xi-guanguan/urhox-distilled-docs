------------------------------------------------------------------------
-- server/xxx/XxxHandler.lua
-- 网络事件入口（参数校验 + 调 Service + 发送结果）
-- 禁止：业务逻辑、直接操作 PDM
------------------------------------------------------------------------
local XxxService = require "server.xxx.XxxService"
local XxxConsts  = require "shared.xxx.XxxConsts"
local PDM        = require "server.sync.PDM"            -- 仅用于 Sync
local ServerSync = require "server.sync.ServerSync"      -- SendToClient

local E = XxxConsts.Events
local XxxHandler = {}

--- 初始化：注册网络事件监听
function XxxHandler.Init()
    ServerSync.On(E.C2S_DO_ACTION, XxxHandler.OnDoAction)
    ServerSync.On(E.C2S_UPGRADE,   XxxHandler.OnUpgrade)
end

--- 处理 DoAction 请求
---@param uid string
---@param data table {param1:any, param2:any}
function XxxHandler.OnDoAction(uid, data)
    -- 1. 参数校验
    if not data or not data.param1 then
        return ServerSync.SendToClient(uid, E.S2C_ACTION_RESULT, { ok = false, err = "missing_param" })
    end

    -- 2. 调用 Service（所有业务逻辑在 Service 中）
    local ok, err = XxxService.DoAction(uid, data.param1)
    if not ok then
        return ServerSync.SendToClient(uid, E.S2C_ACTION_RESULT, { ok = false, err = err })
    end

    -- 3. 即时同步（MarkDirty 有 0.1s 延迟，发送结果前必须 Sync）
    PDM.SyncXxx(uid)

    -- 4. 发送结果事件
    ServerSync.SendToClient(uid, E.S2C_ACTION_RESULT, { ok = true })
end

--- 处理 Upgrade 请求
function XxxHandler.OnUpgrade(uid, data)
    local ok, err = XxxService.Upgrade(uid)
    if not ok then
        return ServerSync.SendToClient(uid, E.S2C_UPGRADE_RESULT, { ok = false, err = err })
    end
    PDM.SyncXxx(uid)
    ServerSync.SendToClient(uid, E.S2C_UPGRADE_RESULT, { ok = true })
end

return XxxHandler

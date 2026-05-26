------------------------------------------------------------------------
-- server/xxx/XxxService.lua
-- 业务逻辑层（读写 PDM，纯逻辑计算）
-- 禁止：网络 IO、直接 Send、直接操作 serverCloud
------------------------------------------------------------------------
local XxxSchema = require "shared.xxx.XxxSchema"
local XxxConsts = require "shared.xxx.XxxConsts"
local PDM       = require "server.sync.PDM"

local XxxService = {}

--- 执行动作
---@param uid string
---@param param1 any
---@return boolean ok, string? err
function XxxService.DoAction(uid, param1)
    -- 1. 读取当前状态
    local level = PDM.GetStat(uid, XxxSchema.Fields.level.pdmKey)

    -- 2. 业务校验
    if level < XxxConsts.Config.MAX_LEVEL then
        -- 可以执行
    else
        return false, "max_level_reached"
    end

    -- 3. 计算新值（纯逻辑）
    local newLevel = level + 1

    -- 4. 写入 PDM（自动 SetVar 同步客户端 + MarkDirty）
    PDM.SetStat(uid, XxxSchema.Fields.level.pdmKey, newLevel)

    return true
end

--- 升级
---@param uid string
---@return boolean ok, string? err
function XxxService.Upgrade(uid)
    local config = PDM.GetStruct(uid, XxxSchema.Fields.config.pdmKey)
    -- ... 业务逻辑 ...
    PDM.SetStruct(uid, XxxSchema.Fields.config.pdmKey, config)
    return true
end

--- 列表操作示例
---@param uid string
---@param item table
function XxxService.AddItem(uid, item)
    local items = PDM.GetList(uid, XxxSchema.Fields.items.pdmKey)
    table.insert(items, item)
    -- 列表必须同时更新内存和持久化
    PDM.SetList(uid, XxxSchema.Fields.items.pdmKey, items)
end

--- 删除列表项（必须双写：内存 + 持久化）
---@param uid string
---@param index number
function XxxService.RemoveItem(uid, index)
    local items = PDM.GetList(uid, XxxSchema.Fields.items.pdmKey)
    local item = items[index]
    if not item then return false, "not_found" end

    -- ❌ 只删内存 → 幽灵条目
    -- table.remove(items, index)

    -- ✅ 双写
    table.remove(items, index)                             -- 内存
    PDM.ListDelete(uid, XxxSchema.Fields.items.pdmKey, item.id)  -- 持久化
    return true
end

return XxxService

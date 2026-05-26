-- ============================================================================
-- PlayerStore.lua — 客户端统一数据访问层（全项目唯一）
-- 路径: client/data/PlayerStore.lua
--
-- 职责:
--   1. 从 CharacterSchema 动态构建 keyMap（零硬编码）
--   2. 统一读取 SyncClient 数据，屏蔽 pdmKey 细节
--   3. 只读接口（客户端不写数据）
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
    -- 特殊键处理（如 chapter 需要重组两个标量为 table）
    -- if key == "chapter" then ... end

    local entry = keyMap_[key]
    if not entry or not syncClient_ then return nil end

    if entry.type == "scalar" or entry.type == "string" then
        return syncClient_.GetStat(entry.pdmKey)
    elseif entry.type == "json" then
        return syncClient_.GetStruct(entry.pdmKey)
    end
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
end

return PlayerStore

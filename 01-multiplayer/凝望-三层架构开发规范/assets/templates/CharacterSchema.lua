-- ============================================================================
-- CharacterSchema.lua — 角色核心字段统一定义（全项目唯一，中心化单例）
-- 路径: shared/schemas/CharacterSchema.lua
--
-- 职责:
--   1. 定义角色核心字段（等级、经验、货币、章节等）
--   2. 提供 RegisterSubsystemFields() 让子系统 Schema 注入字段
--   3. PDM / PlayerStore 遍历 Fields 动态构建注册表 → 零硬编码
--
-- 字段定义格式:
--   fieldKey = {
--     pdmKey  = "VarName",          -- PDM SetVar/GetVar 键名
--     type    = "scalar"|"string"|"json",
--     persist = { via = "cloud"|"money"|"list", cloudKey = "xxx" } | false,
--     desc    = "说明",
--   }
--
-- 持久化策略:
--   via="cloud"  → serverCloud scores/iscores（标量/字符串/JSON）
--   via="money"  → serverCloud.money API（由 ServerMoney provider 管理）
--   via="list"   → serverCloud.list API（由 ListManager provider 管理）
--   false        → sync-only，仅 REPLICATED 同步，不持久化
-- ============================================================================

local CharacterSchema = {}

CharacterSchema.Fields = {
    -- ====================================================================
    -- 角色核心属性（示例，按项目需要增减）
    -- ====================================================================

    level = {
        pdmKey = "Level",
        type   = "scalar",
        persist = { via = "cloud", cloudKey = "player_level" },
        desc   = "等级",
    },
    exp = {
        pdmKey = "Exp",
        type   = "scalar",
        persist = { via = "cloud", cloudKey = "player_exp" },
        desc   = "经验",
    },

    -- 货币 — money API 持久化
    gold = {
        pdmKey = "Golds",
        type   = "scalar",
        persist = { via = "money", cloudKey = "gold" },
        desc   = "黄金",
    },

    -- sync-only — 不持久化（由其他系统派生）
    uid = {
        pdmKey = "Uid",
        type   = "scalar",
        persist = false,
        desc   = "用户 ID",
    },
}

-- ========================================================================
-- 子系统 Schema 注册机制
-- ========================================================================

--- 注册子系统 Schema 字段到 CharacterSchema.Fields
--- PDM / PlayerStore 遍历 Fields 时自动包含所有已注册的子系统字段
---@param schemaName string 子系统名称（日志用）
---@param fields table<string, table> 与 Fields 格式一致的字段表
function CharacterSchema.RegisterSubsystemFields(schemaName, fields)
    local count = 0
    for fieldKey, def in pairs(fields) do
        if CharacterSchema.Fields[fieldKey] then
            print(string.format("[CharacterSchema] WARN: RegisterSubsystemFields(%s) 字段冲突 key=%s，跳过",
                schemaName, fieldKey))
        else
            CharacterSchema.Fields[fieldKey] = def
            count = count + 1
        end
    end
    print(string.format("[CharacterSchema] RegisterSubsystemFields: %s → %d fields merged",
        schemaName, count))
end

-- ========================================================================
-- 子系统 Schema 注册（在此处 require + 注册所有子系统）
-- ========================================================================

-- local HeartSchema = require("shared.schemas.HeartSchema")
-- CharacterSchema.RegisterSubsystemFields("Heart", HeartSchema.Fields)
--
-- local XxxSchema = require("shared.xxx.XxxSchema")
-- CharacterSchema.RegisterSubsystemFields("Xxx", XxxSchema.Fields)

-- ========================================================================
-- 工具函数
-- ========================================================================

--- 按持久化后端过滤
---@param via string|false "cloud"|"money"|"list"|false
---@return table<string, table>
function CharacterSchema.GetFieldsByPersist(via)
    local result = {}
    for key, def in pairs(CharacterSchema.Fields) do
        if via == false then
            if def.persist == false then result[key] = def end
        elseif type(def.persist) == "table" and def.persist.via == via then
            result[key] = def
        end
    end
    return result
end

--- 获取 pdmKey → 字段定义映射
---@return table<string, table>
function CharacterSchema.GetPdmKeyMap()
    local result = {}
    for _, def in pairs(CharacterSchema.Fields) do
        result[def.pdmKey] = def
    end
    return result
end

return CharacterSchema

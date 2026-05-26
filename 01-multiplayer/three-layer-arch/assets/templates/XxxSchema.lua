------------------------------------------------------------------------
-- shared/xxx/XxxSchema.lua
-- 子系统 Schema 定义（纯数据，零依赖）
--
-- 注册方式:
--   在 CharacterSchema.lua 底部添加:
--     local XxxSchema = require("shared.xxx.XxxSchema")
--     CharacterSchema.RegisterSubsystemFields("Xxx", XxxSchema.Fields)
--
--   注册后 PDM / PlayerStore 自动包含这些字段，无需修改 PDM / PlayerStore
------------------------------------------------------------------------
local XxxSchema = {}

--- 字段定义表（与 CharacterSchema.Fields 格式一致）
--- type: "scalar" = 数值, "string" = 字符串, "json" = JSON 结构体
--- persist.via: "cloud" = serverCloud 标量, "money" = Money API, "list" = List API, false = sync-only
XxxSchema.Fields = {
    -- 示例：数值标量（cloud 持久化）
    xxxLevel = {
        pdmKey  = "XxxLevel",
        type    = "scalar",
        persist = { via = "cloud", cloudKey = "xxx_level" },
        desc    = "子系统等级",
    },
    -- 示例：JSON 结构体（cloud 持久化）
    xxxConfig = {
        pdmKey  = "XxxConfig",
        type    = "json",
        persist = { via = "cloud", cloudKey = "xxx_config" },
        desc    = "子系统配置数据",
    },
    -- 示例：货币字段（Money API 持久化）
    xxxCurrency = {
        pdmKey  = "XxxCurrency",
        type    = "scalar",
        persist = { via = "money", cloudKey = "xxx_currency" },
        desc    = "子系统货币",
    },
    -- 示例：sync-only（不持久化，由服务端计算后同步）
    xxxDerived = {
        pdmKey  = "XxxDerived",
        type    = "json",
        persist = false,
        desc    = "派生数据（仅同步）",
    },
}

--- 默认值工厂（LoadPlayer 时无持久化数据则使用）
function XxxSchema.Defaults()
    return {
        xxxLevel    = 1,
        xxxConfig   = {},
        xxxCurrency = 0,
        xxxDerived  = {},
    }
end

return XxxSchema

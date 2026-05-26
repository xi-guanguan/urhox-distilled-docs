------------------------------------------------------------------------
-- shared/xxx/XxxConsts.lua
-- 子系统常量与数值配表（纯数据，零依赖）
------------------------------------------------------------------------
local XxxConsts = {}

--- 状态枚举
XxxConsts.State = {
    IDLE    = "idle",
    ACTIVE  = "active",
    DONE    = "done",
}

--- 数值配表（可按需拆分为 XxxDefs.lua）
XxxConsts.Config = {
    MAX_LEVEL       = 100,
    BASE_COST       = 10,
    COOLDOWN_SEC    = 60,
}

--- 网络事件名（前后端共用，保证一致性）
XxxConsts.Events = {
    -- Client → Server
    C2S_DO_ACTION    = "Xxx:DoAction",
    C2S_UPGRADE      = "Xxx:Upgrade",
    -- Server → Client（结果通知）
    S2C_ACTION_RESULT = "Xxx:ActionResult",
    S2C_UPGRADE_RESULT = "Xxx:UpgradeResult",
}

return XxxConsts

------------------------------------------------------------------------
-- shared/xxx/XxxConsts.lua
-- 子系统常量与数值配表（纯数据，零依赖）
--
-- 事件命名规范：
--   EVENT_{方向}_{动作} = "{Prefix}_{方向缩写}{动作}"
--   方向: REQ = 客户端→服务端请求
--         RES = 服务端→客户端响应（对应某个 REQ）
--         PUSH = 服务端主动推送（无对应 REQ）
--
-- 值格式："{Prefix}_{PascalAction}"
--   Prefix = NetworkEvents.RegisterSubsystem 的第一参数
--   所有 EVENT_* 值必须以 "{Prefix}_" 开头（注册时强制校验）
--
-- 非事件常量（枚举、数值）不以 EVENT_ 开头，不会被 NetworkEvents 收集
------------------------------------------------------------------------
local XxxConsts = {}

--- === 网络事件名 ===

-- Client → Server 请求
XxxConsts.EVENT_REQ_DO_ACTION = "Xxx_ReqDoAction"
XxxConsts.EVENT_REQ_UPGRADE   = "Xxx_ReqUpgrade"

-- Server → Client 响应（1:1 对应 REQ）
XxxConsts.EVENT_RES_DO_ACTION = "Xxx_ResDoAction"
XxxConsts.EVENT_RES_UPGRADE   = "Xxx_ResUpgrade"

-- Server → Client 主动推送（无对应 REQ）
XxxConsts.EVENT_PUSH_STATE_CHANGE = "Xxx_PushStateChange"

--- === 状态枚举 ===
XxxConsts.STATE_IDLE   = 1
XxxConsts.STATE_ACTIVE = 2
XxxConsts.STATE_DONE   = 3

--- === 数值配表 ===
XxxConsts.MAX_LEVEL    = 100
XxxConsts.BASE_COST    = 10
XxxConsts.COOLDOWN_SEC = 60

return XxxConsts

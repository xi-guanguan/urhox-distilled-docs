-- ============================================================================
-- PlayerDataManager.lua — 统一数据管理器（PDM 核心，全项目唯一）
-- 路径: server/character/PlayerDataManager.lua
--
-- 职责:
--   1. 唯一 serverCloud 读写入口（所有持久化统一走 PDM）
--   2. 管理 PlayerNode（REPLICATED） + 内存数据 + SetVar + serverCloud
--   3. 从 CharacterSchema 动态构建键注册表，零硬编码
--   4. Provider 注册机制：统一管理 Money/List/Quota 等外部 provider 生命周期
--
-- 数据流:
--   LoadPlayer:  serverCloud → 内存 → PlayerNode:SetVar(REPLICATED) → 引擎同步到客户端
--   SetStat:     内存 + SetVar 即时同步 → dirty 标记 → Tick 定时 BatchCommit
--   SavePlayer:  遍历 dirty → serverCloud BatchCommit
--   RemovePlayer: 即时存盘 → providers.OnRemove → GateManager.ClearAll → Dispose
--
-- 新增子系统接入方式:
--   1. 在 CharacterSchema.Fields 中声明新字段（type/pdmKey/persist）
--   2. PDM 自动注册，无需修改本文件
--   3. 业务层通过 PDM.SetStat/GetStat/SetStruct/GetStruct 读写
-- ============================================================================

local PlayerDataManager = {}

local CharacterSchema = require("shared.schemas.CharacterSchema")
local GateManager      = require("server.character.GateManager")
local KeyUtils         = require("shared.utils.KeyUtils")

local cjson     = cjson  ---@diagnostic disable-line: undefined-global
local getCharKey = KeyUtils.GetCharKey

-- ============================================================================
-- 从 CharacterSchema 动态构建键注册表
-- ============================================================================

--- { pdmKey = cloudKey | false }
PlayerDataManager.SCALAR_KEYS = {}
PlayerDataManager.STRING_KEYS = {}
PlayerDataManager.JSON_KEYS   = {}

do
    for _, def in pairs(CharacterSchema.Fields) do
        local cloudKey = false
        if def.persist and type(def.persist) == "table" and def.persist.via ~= "money" then
            cloudKey = def.persist.cloudKey
        end

        local bucket = def.type == "scalar" and PlayerDataManager.SCALAR_KEYS
            or def.type == "string" and PlayerDataManager.STRING_KEYS
            or def.type == "json"   and PlayerDataManager.JSON_KEYS
            or nil
        if bucket then bucket[def.pdmKey] = cloudKey end
    end
end

-- ============================================================================
-- Provider 注册机制
-- ============================================================================

---@type table<string, { provider: table, deferred: boolean }>
local providers_ = {}

--- 注册外部 provider（如 ServerMoney / ListManager / QuotaProvider）
--- provider 需实现: OnLoad(uid, charId, done), 可选 OnSave(uid), OnRemove(uid)
---@param name string
---@param provider table
---@param opts table|nil  { deferred = true → LoadPlayer 不调用, 需手动 LoadDeferredProviders }
function PlayerDataManager.RegisterProvider(name, provider, opts)
    providers_[name] = {
        provider = provider,
        deferred = opts and opts.deferred or false,
    }
end

-- ============================================================================
-- 货币 / 列表 / 配额 — 委托给对应 provider
-- ============================================================================

function PlayerDataManager.AddMoney(uid, moneyKey, amount, callbacks)
    local e = providers_["money"]
    return e and e.provider.Add and e.provider.Add(uid, moneyKey, amount, callbacks)
end

function PlayerDataManager.RemoveMoney(uid, moneyKey, amount, callbacks)
    local e = providers_["money"]
    return e and e.provider.Remove and e.provider.Remove(uid, moneyKey, amount, callbacks)
end

function PlayerDataManager.GetMoney(uid, moneyKey)
    local e = providers_["money"]
    return e and e.provider.Get and e.provider.Get(uid, moneyKey) or 0
end

function PlayerDataManager.ListAddItem(uid, listName, item, mapKey, callbacks)
    local e = providers_["list"]
    if e and e.provider.AddItem then e.provider.AddItem(uid, listName, item, mapKey, callbacks) end
end

function PlayerDataManager.ListRemoveItem(uid, listName, predicate, callbacks)
    local e = providers_["list"]
    if e and e.provider.RemoveItem then e.provider.RemoveItem(uid, listName, predicate, callbacks) end
end

function PlayerDataManager.ListGetAll(uid, listName)
    local e = providers_["list"]
    return e and e.provider.GetList and e.provider.GetList(uid, listName) or {}
end

-- ...更多代理方法（ListModifyItem / ListBatchAdd / ListBatchRemove / AddQuota / GetQuota）同理

-- ============================================================================
-- 内部状态
-- ============================================================================

local players_       = {} ---@type table<number, PlayerData>
local scene_         = nil
local Server_        = nil
local SAVE_INTERVAL  = 30

-- ============================================================================
-- 初始化
-- ============================================================================

---@param scene userdata REPLICATED Scene
---@param server table   Server 模块（提供 SendToClient）
function PlayerDataManager.Setup(scene, server)
    scene_  = scene
    Server_ = server
end

-- ============================================================================
-- 玩家生命周期
-- ============================================================================

--- 加载玩家：serverCloud BatchGet → 创建 PlayerNode → SetVar → providers.OnLoad
---@param uid number
---@param charId string
---@param connection userdata
---@param onComplete function|nil
function PlayerDataManager.LoadPlayer(uid, charId, connection, onComplete)
    -- 1. 复用/创建 PlayerNode
    -- 2. serverCloud BatchGet 拉取所有注册键
    -- 3. 标量 → scalars + SetVar(REPLICATED)
    -- 4. JSON  → structs + SetVar(REPLICATED, encoded)
    -- 5. 调用非 deferred providers.OnLoad
    -- 6. onComplete(true)
    -- （详见项目实际实现）
end

--- 延迟加载 deferred providers（客户端握手后调用）
---@param uid number
---@param onComplete function|nil
function PlayerDataManager.LoadDeferredProviders(uid, onComplete)
    -- 遍历 deferred providers → 调用 OnLoad → 全部完成后 onComplete
end

--- 移除玩家：即时存盘 → providers.OnRemove → GateManager.ClearAll → Dispose
---@param uid number
---@param skipSave boolean|nil
function PlayerDataManager.RemovePlayer(uid, skipSave)
    -- 1. dirty 则 SavePlayer
    -- 2. 遍历 providers.OnRemove
    -- 3. GateManager.ClearAll(uid)
    -- 4. node:Remove()
    -- 5. players_[uid] = nil
end

-- ============================================================================
-- 数据读写（核心 API）
-- ============================================================================

--- 设置标量值: 更新内存 + SetVar 即时同步 + 标记 dirty
function PlayerDataManager.SetStat(uid, varName, value) end

--- 读取标量值
function PlayerDataManager.GetStat(uid, varName) end

--- 增减标量值（自动 clamp ≥ 0）
function PlayerDataManager.AddStat(uid, varName, delta) end

--- 设置 JSON 结构: 更新内存 + SetVar(encode) + 标记 dirty
function PlayerDataManager.SetStruct(uid, varName, value) end

--- 读取 JSON 结构
function PlayerDataManager.GetStruct(uid, varName) end

--- 获取玩家 Node
function PlayerDataManager.GetNode(uid) end

--- 发送结果事件（委托 Server.SendToClient）
function PlayerDataManager.SendResult(uid, eventName, data) end

-- ============================================================================
-- 存盘 & Tick
-- ============================================================================

--- 即时存盘: 遍历 scalar/json dirty → serverCloud BatchCommit
function PlayerDataManager.SavePlayer(uid) end

--- 定时检查: dirty 且超过 SAVE_INTERVAL → SavePlayer
function PlayerDataManager.Tick() end

return PlayerDataManager

# clientCloud 到 serverCloud 存档迁移指南

> **这是什么**: 从单机架构（clientCloud）迁移到服务端权威架构（serverCloud）时的存档数据迁移方案，含历史 key 格式兼容、双层迁移策略和常见陷阱。  
> **原作者**: 心动  
> **推荐度**: L2（参考学习价值 — 来自实际项目上线后的血泪教训，适合正在做单机→联机迁移的开发者）  
> **适用场景**: 游戏从单机 clientCloud 迁移到服务端 serverCloud 架构

---

## 核心陷阱：两套独立存储

**clientCloud 和 serverCloud 是完全独立的存储空间，key 相同也不互通。**

```
clientCloud (客户端云存储)     serverCloud (服务端云存储)
┌────────────────────┐      ┌────────────────────┐
│ save_data = {...}  │  ✗   │ save_data = (空)   │
│ sv_all = {...}     │ ──→  │ sv_all = (空)      │
└────────────────────┘      └────────────────────┘
       读不到对方的数据！
```

**后果**：直接切换 API 后，玩家登录变成新档，之前几十小时的进度"消失"。

---

## 双层迁移策略

### 层 1：服务端兼容历史 key 格式

`serverLoad()` 按优先级尝试读取所有历史格式：

```lua
function serverLoad(userId, callback)
    local keyFormats = {
        -- 按优先级排列（新 → 旧）
        { type = "single", key = "sv_all" },
        { type = "sharded", keys = {"sv_core", "sv_military", "sv_progress"} },
        { type = "legacy", key = "save_data" },
    }

    TryLoadFormats(userId, keyFormats, 1, function(success, data, format)
        if success then
            -- 如果不是最新格式，迁移后保存为最新格式
            if format ~= "single" then
                serverCloud:Set(userId .. ":sv_all", cjson.encode(data))
            end
            callback(true, data)
        else
            callback(false, nil)  -- 真的没有存档
        end
    end)
end

function TryLoadFormats(userId, formats, index, callback)
    if index > #formats then
        callback(false, nil, nil)
        return
    end

    local fmt = formats[index]

    if fmt.type == "single" then
        serverCloud:Get(userId .. ":" .. fmt.key, function(success, value)
            if success and value and value ~= "" then
                local data = cjson.decode(value)
                -- 注意：sv_all 存在但是空白新档的情况
                if data and HasRealData(data) then
                    callback(true, data, fmt.type)
                    return
                end
            end
            -- 当前格式没数据，尝试下一个
            TryLoadFormats(userId, formats, index + 1, callback)
        end)

    elseif fmt.type == "sharded" then
        -- 批量读取多个分片 key，合并
        serverCloud:BatchGet(
            MapKeys(userId, fmt.keys),
            function(success, results)
                if success and HasAnyData(results) then
                    local merged = MergeShards(results)
                    callback(true, merged, fmt.type)
                else
                    TryLoadFormats(userId, formats, index + 1, callback)
                end
            end
        )
    end
end
```

### 层 2：客户端首次连接时迁移旧数据

客户端首次进入联机模式时，从 clientCloud 读取旧存档，发送给服务端：

```lua
-- Client.lua —— 首次连接时
function TryMigrateFromClientCloud()
    clientCloud:Load(function(success, data)
        if not success or not data then return end

        local parsed = cjson.decode(data)
        if not parsed or not HasRealData(parsed) then return end

        -- 通过远程事件发送给服务端
        local migrateData = VariantMap()
        migrateData["json"] = data
        migrateData["saveSeq"] = tostring(parsed._saveSeq or 0)
        network:GetServerConnection():SendRemoteEvent("MIGRATE_SAVE", true, migrateData)
    end)
end
```

```lua
-- Server.lua —— 处理迁移请求
SubscribeToEvent("MIGRATE_SAVE", function(eventType, eventData)
    local conn = eventData["Connection"]:GetPtr("Connection")
    local json = eventData["json"]:GetString()
    local clientSeq = tonumber(eventData["saveSeq"]:GetString()) or 0

    local playerInfo = GetPlayerByConnection(conn)
    local serverSeq = playerInfo.game._saveSeq or 0

    -- 用序列号比较，客户端存档更新才覆盖
    if clientSeq > serverSeq then
        local migratedData = cjson.decode(json)
        playerInfo.game = migratedData
        playerInfo.saveDirty = true
        print("[迁移] 已用 clientCloud 数据覆盖服务端（seq " .. clientSeq .. " > " .. serverSeq .. "）")
    else
        print("[迁移] 服务端数据更新，跳过迁移")
    end
end)
```

### 序列号（_saveSeq）机制

每次保存时递增，用于判断哪份存档更新：

```lua
function SavePlayerData(playerInfo)
    playerInfo.game._saveSeq = (playerInfo.game._saveSeq or 0) + 1
    playerInfo.game.lastSaveTime = os.time()
    serverCloud:Set(playerInfo.userId .. ":sv_all", cjson.encode(playerInfo.game))
end
```

---

## 历史 key 格式演化

项目迭代过程中存储格式可能多次变更：

| 阶段 | key 格式 | 原因 |
|------|---------|------|
| 最早期 | `save_data`（单 key 全量） | 简单直接 |
| 中期 | `sv_core` / `sv_military` / `sv_progress`（分片） | 单 key 超大小限制 |
| 当前 | `sv_all`（优化后恢复单 key） | 数据优化后不再超限 |

**关键边界**：`sv_all` 存在但内容是空白新档，而旧的分片 key 有真实数据——必须处理这种情况。

---

## 其他踩坑记录

### Manager 层耦合

旧 Manager 内部直接调用 `SaveManager.Save()` 触发持久化：

```lua
-- ❌ 旧写法：Manager 内部触发存档
function BuildingManager.Upgrade(buildingId)
    buildings[buildingId].level = buildings[buildingId].level + 1
    SaveManager.Save()  -- 直接保存 → 迁移到服务端后职责冲突
end

-- ✅ 新写法：Manager 只做计算，不触发存档
function BuildingManager.Upgrade(game, buildingId)
    game.buildings[buildingId].level = game.buildings[buildingId].level + 1
    -- 不调用 Save，由 Server 统一管控 saveDirty
    return true
end
```

迁移涉及对**所有 Manager 文件**（原文提到 13 个）的逐一审查和修改。

### 模块初始化顺序

迁移后模块加载顺序变化，引用可能在初始化前触发：

```lua
-- ❌ 直接引用可能在模块初始化前
UIMain.Build()

-- ✅ 用函数包装，延迟到实际调用时才取引用
getUIMain().Build()
```

### 远程事件序列化限制

VariantMap 的 value 类型有限（String、Int、Bool 等），不能直接传 Lua table。所有复杂数据需要手动 `cjson.encode/decode`：

```lua
-- 全量状态同步（STATE_SYNC）在游戏后期数据量较大时需要关注传输大小
local stateJson = cjson.encode(playerInfo.game)
-- 如果 stateJson 过大，考虑增量同步或分段传输
```

### LSP 误报引擎全局变量

`IsServerMode`、`serverCloud`、`clientCloud`、`SERVER_MAX_PLAYERS` 等是引擎运行时注入的全局变量，LSP 不认识：

```lua
---@diagnostic disable-next-line: undefined-global
if IsServerMode and IsServerMode() then
    -- 服务端逻辑
end
```

---

## 迁移检查清单

- [ ] clientCloud 和 serverCloud 是独立存储，不能直接切换 API
- [ ] 服务端 `serverLoad` 兼容所有历史 key 格式（按优先级逐个尝试）
- [ ] 客户端首次连接时从 clientCloud 读取旧数据发送给服务端
- [ ] 用 `_saveSeq` 序列号判断哪份存档更新，避免新数据被旧数据覆盖
- [ ] 所有 Manager 改为无副作用纯函数，不主动触发存档
- [ ] 处理"新格式 key 存在但内容为空，旧格式有真实数据"的边界
- [ ] 模块初始化顺序检查，避免引用未初始化的模块

# UrhoX 联网游戏开发完整指南

> **这是什么**：从零开始理解并实现 UrhoX 多人联网游戏的完整指南，涵盖权威服务器架构、场景复制、节点同步、远程事件、玩家输入、脉冲按键、兴趣管理、连接管理、云变量排障等全流程。同时包含面向零基础用户的概念讲解和 AI 对话模板。
>
> **原作者**：不得了
> **推荐度**：L2（内容全面详实，覆盖了引擎联网开发的所有核心 API 和概念。技术文档部分直接来源于引擎官方文档，零基础教程部分用通俗比喻讲解多人架构，评论区问答补充了实战排障经验。因为是论坛帖子格式转录，代码示例未经完整项目验证，故定为参考级。）
> **适用场景**：任何需要在 UrhoX/TapTap Maker 中开发联网多人游戏的场景——无论是匹配制、房间制还是常驻服。
>
> **同类对比**：
> - **vs 心动-服务端权威架构三段式模式**：心动方案聚焦架构设计的三个阶段（单机→伪多人→真多人），偏方法论；本文是完整 API 参考 + 实操指南，偏工具书。
> - **vs 糖心哥-服务端架构踩坑百人同服**：糖心哥偏向大规模（百人同服）的性能踩坑经验；本文覆盖面更广但不深入极端场景。
> - **vs 游玩-多人联机房间管理开发指南**：游玩侧重房间管理细节；本文从架构到输入到调试全链路覆盖。
> - **特色**：三篇合一——技术参考 + 零基础教程 + 实战排障，是目前最完整的单篇联网开发参考。
> - **优点**：API 覆盖全面，包含完整代码示例、时序图、对照表；零基础部分降低了入门门槛；排障部分来自真实论坛问答。
> - **缺点**：部分 API（如 GetUserNickname）仅提及未展开；脉冲按键的内部机制描述偏简略。

---

## 目录

1. [概念入门：多人游戏是什么](#1-概念入门)
2. [架构概述](#2-架构概述)
3. [代码结构与运行模式](#3-代码结构与运行模式)
4. [节点创建模式：REPLICATED vs LOCAL](#4-节点创建模式)
5. [节点变量同步（Node Vars）](#5-节点变量同步)
6. [远程事件（Remote Events）](#6-远程事件)
7. [玩家输入同步（Controls）](#7-玩家输入同步)
8. [客户端渲染组件创建](#8-客户端渲染组件创建)
9. [网络节点生命周期](#9-网络节点生命周期)
10. [SmoothedTransform（位置插值）](#10-smoothedtransform)
11. [兴趣管理（Interest Management）](#11-兴趣管理)
12. [连接管理](#12-连接管理)
13. [网络统计与调试](#13-网络统计与调试)
14. [云变量与远程事件排障实战](#14-云变量与远程事件排障实战)
15. [常见问题速查表](#15-常见问题速查表)
16. [给 AI 助手的对话模板](#16-给-ai-助手的对话模板)

---

## 1. 概念入门

### 1.1 联网多人游戏的本质

联网多人游戏 = 多台设备通过网络连接，在同一局游戏中协同。核心问题是**谁说了算**。

**类比**：棋牌室老板模型
- 玩家各自坐在不同位置（客户端，各自的手机）
- 老板在中央记录出牌、算分、判输赢（服务端）
- 所有操作都要经过老板，老板再通知其他人

### 1.2 服务端与客户端的分工

**黄金法则**：服务端 = 裁判（说了算）；客户端 = 传话筒 + 画面工（只负责看和说）。

| 职责 | 服务端 | 客户端 |
|------|--------|--------|
| 伤害判定、碰撞检测 | **必须** | 禁止 |
| 分数、血量、金币 | **必须** | 只读 |
| 胜负判定 | **必须** | 只显示结果 |
| 随机生成道具位置 | **必须**（防作弊） | 只渲染 |
| 玩家操作采集（摇杆/按键） | — | **必须** |
| 渲染画面、播放音效/特效 | 不渲染（headless） | **必须** |

**为什么不能让客户端算伤害？**

> 玩家 A 的手机说"我打中 B 了，扣 100 血"，玩家 B 的手机说"你没打中"——听谁的？
> 所以必须由服务端裁定：算弹道 → 判命中 → 通知双方。

---

## 2. 架构概述

### 2.1 权威服务器架构

```
┌────────────────────────┐
│     服务器 (Headless)    │
│  - 游戏逻辑/碰撞/AI      │
│  - 纯计算，无渲染          │
│  - REPLICATED 创建节点    │
│  - 读 controls 输入       │
└────────────────────────┘
           ↕ 自动同步
┌────────────────────────┐
│        客户端             │
│  - 渲染 + 用户输入         │
│  - 发 controls 到服务端    │
│  - DelayedStart 创建渲染  │
│  - 本地音效/粒子           │
└────────────────────────┘
```

### 2.2 场景复制机制（Scene Replication）

引擎内置场景复制，自动同步：
- REPLICATED 节点的位置、旋转、缩放
- 节点变量（通过 `SetVar` 设置的数据）
- 节点创建和删除事件

**关键**：Scene 是网络同步的必要媒介。即使游戏不需要 3D 场景，也必须创建一个 Scene 对象。

---

## 3. 代码结构与运行模式

### 3.1 推荐代码结构

```
scripts/
├── Main.lua              # 入口文件（判断运行模式）
├── Network/
│   ├── Shared.lua        # 共享代码（配置、事件名、工具函数）
│   ├── Server.lua        # 服务器逻辑
│   └── Client.lua        # 客户端逻辑
└── Modules/              # 可复用模块
```

### 3.2 运行模式判断

框架提供两个全局函数，脚本加载时即可使用：

```lua
if IsServerMode() then
    require("Network.Server")
elseif IsClientMode() then
    require("Network.Client")
end
```

### 3.3 服务器全局变量

服务器端 Lua 启动时，框架自动注入以下全局变量：

| 变量 | 类型 | 说明 |
|------|------|------|
| `SERVER_MAX_PLAYERS` | int | 最大玩家数（来自 settings.json） |
| `SERVER_REGISTERED_PLAYERS` | int | 本局实际玩家数量（开局时确定，不随玩家退出变化） |
| `SERVER_TICK_RATE` | int | 服务器帧率 |
| `SERVER_MODE` | string | 多人模式（如 `"server_authoritative"`） |

> 这些变量**仅服务器端可用**，客户端不存在。值在脚本加载时确定，运行期间不变。

**`SERVER_REGISTERED_PLAYERS` 与 `SERVER_MAX_PLAYERS` 的区别**：

| 场景 | MAX | REGISTERED |
|------|-----|------------|
| 快速匹配 8 人局，6 人 + 2 AI | 8 | 6（实际玩家） |
| 开房间最大 8 人，进了 5 人 | 8 | 5 |
| 满员开局 | 8 | 8 |

```lua
-- 典型用法：根据实际玩家数初始化
for i = 1, SERVER_REGISTERED_PLAYERS do
    -- 为每个真实玩家预分配资源
end

-- 判断是否需要填充 AI
local aiCount = SERVER_MAX_PLAYERS - SERVER_REGISTERED_PLAYERS
if aiCount > 0 then
    -- 创建 AI 玩家
end
```

> 当前在线玩家数需要通过 `network:GetClientConnections()` 实时获取，`SERVER_REGISTERED_PLAYERS` 是开局快照。

### 3.4 常驻服额外变量

| 变量 | 类型 | 说明 |
|------|------|------|
| `PERSISTENT_WORLD_KEY` | string | 当前常驻服的房间标识 |

---

## 4. 节点创建模式

### 4.1 两种模式

| 模式 | 常量 | 行为 |
|------|------|------|
| **REPLICATED** | `REPLICATED` | 同步到所有客户端（**默认值**） |
| **LOCAL** | `LOCAL` | 只存在于当前端，不同步 |

> **极其重要**：`CreateChild()` 和 `CreateComponent()` 的默认模式是 REPLICATED！客户端必须显式指定 LOCAL，否则会与服务器冲突！

```lua
-- 这两行等价
local node = scene:CreateChild("Node")
local node = scene:CreateChild("Node", REPLICATED)  -- 默认就是 REPLICATED

-- 客户端必须这样写
local node = scene:CreateChild("LocalNode", LOCAL)
```

### 4.2 完整对照表

| 对象类型 | 服务端 | 客户端 | 说明 |
|---------|--------|--------|------|
| 游戏实体节点（角色/道具） | REPLICATED | 自动同步（不创建） | 位置自动同步 |
| StaticModel/渲染组件 | 不创建 | LOCAL | 客户端根据节点变量创建 |
| 材质 | 不创建 | LOCAL | 避免材质同步问题 |
| 地面/墙壁（环境） | LOCAL | LOCAL | 各端独立创建 |
| 光照/相机 | 不创建 | LOCAL | 服务器无渲染 |
| 音效 | 不创建 | LOCAL | 通过远程事件通知播放 |

---

## 5. 节点变量同步

### 5.1 基本用法

节点变量是附加在节点上的键值对数据，随 REPLICATED 节点自动同步。

```lua
-- ======= 服务器端：设置节点变量 =======
local node = scene:CreateChild("Entity", REPLICATED)
node:SetVar("EntityType", Variant("enemy"))    -- 字符串
node:SetVar("EntityId", Variant(123))          -- 整数
node:SetVar("Health", Variant(80.0))           -- 更新会自动同步

-- ======= 客户端：读取节点变量 =======
local typeVar = node:GetVar("EntityType")
if typeVar and not typeVar:IsEmpty() then
    local entityType = typeVar:GetString()
end

local id = node:GetVar("EntityId"):GetInt()
local health = node:GetVar("Health"):GetFloat()
```

### 5.2 支持的 Variant 类型

| 类型 | 写入 | 读取 |
|------|------|------|
| 整数 | `Variant(123)` | `GetInt()` |
| 浮点数 | `Variant(1.5)` | `GetFloat()` |
| 布尔值 | `Variant(true)` | `GetBool()` |
| 字符串 | `Variant("text")` | `GetString()` |
| Vector2 | `Variant(Vector2(x,y))` | `GetVector2()` |
| Vector3 | `Variant(Vector3(x,y,z))` | `GetVector3()` |
| Quaternion | `Variant(Quaternion(...))` | `GetQuaternion()` |
| Color | `Variant(Color(r,g,b,a))` | `GetColor()` |

### 5.3 推荐实践

在 `Shared.lua` 中统一定义变量名常量，避免拼写错误：

```lua
-- Shared.lua
Shared.VARS = {
    ENTITY_TYPE = "EntityType",
    ENTITY_ID = "EntityId",
    HEALTH = "Health",
}
```

---

## 6. 远程事件

### 6.1 事件定义

在 `Shared.lua` 中统一定义事件名：

```lua
Shared.EVENTS = {
    CLIENT_READY  = "ClientReady",
    ASSIGN_PLAYER = "AssignPlayer",
    PLAYER_DIED   = "PlayerDied",
    PLAY_SOUND    = "PlaySound",
    GAME_START    = "GameStart",
}
```

### 6.2 事件注册（必须！）

**远程事件必须先注册，才能被对端接收**。这是安全机制，未注册的事件会被 100% 拦截。

```lua
function Start()
    -- 注册本端需要接收的远程事件
    network:RegisterRemoteEvent(Shared.EVENTS.CLIENT_READY)   -- 服务器接收
    network:RegisterRemoteEvent(Shared.EVENTS.ASSIGN_PLAYER)  -- 客户端接收

    -- 然后再订阅事件
    SubscribeToEvent(Shared.EVENTS.ASSIGN_PLAYER, "HandleAssignPlayer")
end
```

### 6.3 发送方向

**客户端 → 服务器**：

```lua
local serverConnection = network:GetServerConnection()

-- 无数据事件
serverConnection:SendRemoteEvent(Shared.EVENTS.CLIENT_READY, true)

-- 带数据事件
local eventData = VariantMap()
eventData["PlayerName"] = Variant("Player1")
eventData["PositionX"] = Variant(100.0)
serverConnection:SendRemoteEvent(Shared.EVENTS.CLIENT_READY, true, eventData)
```

**服务器 → 单个客户端**：

```lua
local eventData = VariantMap()
eventData["PlayerId"] = Variant(playerId)
connection:SendRemoteEvent(Shared.EVENTS.ASSIGN_PLAYER, true, eventData)
```

**服务器 → 所有客户端（广播）**：

```lua
local eventData = VariantMap()
eventData["Message"] = Variant("Game Started!")
network:BroadcastRemoteEvent(Shared.EVENTS.GAME_START, true, eventData)
```

---

## 7. 玩家输入同步

### 7.1 Controls 结构

`connection.controls` 用于客户端→服务端的实时输入同步：

| 字段 | 类型 | 说明 |
|------|------|------|
| `yaw` | float | 水平旋转角度（移动方向） |
| `pitch` | float | 垂直旋转角度 |
| `buttons` | uint | 按钮状态位标志 |

### 7.2 客户端发送输入

```lua
local serverConnection_ = nil
local targetYaw_ = 0.0

function Start()
    serverConnection_ = network:GetServerConnection()
    SubscribeToEvent("Update", "HandleUpdate")
end

function HandleUpdate(eventType, eventData)
    if not serverConnection_ then return end

    if input:GetKeyDown(KEY_A) then targetYaw_ = targetYaw_ + 3.0 end
    if input:GetKeyDown(KEY_D) then targetYaw_ = targetYaw_ - 3.0 end

    serverConnection_.controls.yaw = targetYaw_
end
```

### 7.3 服务器读取输入

```lua
local playerConnections_ = {}

function HandleUpdate(eventType, eventData)
    local dt = eventData["TimeStep"]:GetFloat()

    for connKey, playerInfo in pairs(playerConnections_) do
        local conn = playerInfo.connection
        local yaw = conn.controls.yaw
        local buttons = conn.controls.buttons
        -- 根据输入更新玩家状态...
    end
end
```

### 7.4 脉冲按键可靠传输（PulseButtonMask）

**问题**：`controls.buttons` 通过 unreliable 通道（UDP/KCP）发送。持续按键（如加速）丢一帧无所谓，但脉冲按键（如跳跃）只持续一帧，丢包后服务器永远看不到。

**另一个问题**：服务器帧率较低时，多个客户端帧的输入在同一 tick 到达，最后一个覆盖前面的，也会丢失脉冲按键。

**解决方案**：`SetPulseButtonMask` 指定脉冲位，引擎自动通过 reliable 通道传输。

| 类型 | 通道 | 延迟 | 可靠性 |
|------|------|------|--------|
| pulse（如 JUMP） | MSG_BUTTON_STATE (reliable+ordered) | 多状态排队 +1 tick | 保证送达 |
| 非 pulse（如 BOOST） | MSG_CONTROLS (unreliable) | 零延迟 | 可能丢包 |

**注意事项**：
- `SetPulseButtonMask` **只需在服务端调用一次**，引擎自动同步给客户端
- 只把脉冲按键放入 mask，不要把持续按键放进去
- WASM 平台使用 WebSocket (TCP)，不存在丢包问题，引擎自动跳过 pulse 机制

---

## 8. 客户端渲染组件创建

服务器不做渲染，客户端需要根据同步过来的节点数据自行创建渲染组件。

**时序流程**：

```
服务器                           客户端
──────                           ──────
1. 创建节点 (REPLICATED)
2. SetVar (EntityType 等)
3. 附加 ScriptObject
   ↓ 网络同步
                                 1. 收到数据
                                 2. 创建节点
                                 3. 同步 Vars
                                 4. 加载 ScriptObject
                                 5. DelayedStart()  ← Vars 已就绪
                                 6. 读取 Vars，创建 LOCAL 渲染组件
```

**关键**：使用 `DelayedStart()` 而不是 `Start()`，因为 `Start()` 时节点变量可能还未同步完毕。

---

## 9. 网络节点生命周期

### 9.1 创建节点

```lua
-- 服务器创建 REPLICATED 节点
local node = scene:CreateChild("Entity", REPLICATED)
node.position = spawnPosition
node:SetVar("EntityId", Variant(entityId))
```

### 9.2 移除节点（重要！）

**必须使用 `Dispose()` 而不是 `Remove()`**：

```lua
-- ❌ 错误：Remove() 依赖 GC，删除时机不可控
-- node:Remove()

-- ✅ 正确：Dispose() 立即生效，确保客户端同步
node:Dispose()
```

### 9.3 客户端处理节点移除

```lua
function Start()
    SubscribeToEvent(scene_, "NodeRemoved", "HandleNodeRemoved")
end

function HandleNodeRemoved(eventType, eventData)
    local node = eventData["Node"]:GetPtr("Node")
    local entityId = node:GetVar(Shared.VARS.ENTITY_ID)
    if entityId and not entityId:IsEmpty() then
        localEntityCache_[entityId:GetInt()] = nil
    end
end
```

---

## 10. SmoothedTransform

### 10.1 工作原理

引擎为所有 REPLICATED 节点自动创建 `SmoothedTransform` 组件，在网络数据包之间平滑插值位置，避免卡顿感。

### 10.2 相机跟随注意事项

**不要在相机跟随代码中添加额外的 lerp 平滑**，否则会"平滑套平滑"导致相机抖动：

```lua
-- ❌ 错误：额外 lerp 导致每帧相对位置都在变化
-- local newX = currentPos.x + (targetPos.x - currentPos.x) * smoothSpeed * dt

-- ✅ 正确：直接跟随目标位置
cameraNode_.position = Vector3(targetPos.x, currentPos.y, targetPos.z)
```

---

## 11. 兴趣管理

### 11.1 NetworkPriority 组件

控制哪些对象优先同步给特定客户端：

```lua
local priority = entityNode:CreateComponent("NetworkPriority", REPLICATED)
priority.basePriority = 100.0        -- 基础优先级
priority.distanceFactor = 0.5        -- 距离因子（越近优先级越高）
priority.minPriority = 0.0           -- 最小优先级
priority.alwaysUpdateOwner = true    -- 始终向拥有者更新
```

### 11.2 Observer Position（观察者位置）

客户端需要告知服务器自己的"视点"位置，用于距离计算：

```lua
function HandleUpdate(eventType, eventData)
    if not serverConnection_ then return end
    serverConnection_.position = cameraNode_.worldPosition
    serverConnection_.rotation = cameraNode_.worldRotation
end
```

---

## 12. 连接管理

### 12.1 场景关联时序（极其重要！）

**必须按以下顺序执行**，否则会报 `Can not handle LoadScene message without an assigned scene`：

1. 客户端先设置 `serverConnection.scene = scene_`
2. 客户端发送 `ClientReady` 事件通知服务器
3. 服务器收到 `ClientReady` 后才设置 `connection.scene = scene_`

### 12.2 服务器端连接处理

```lua
local playerConnections_ = {}

function Start()
    Shared.RegisterServerEvents()
    SubscribeToEvent("ClientConnected", "HandleClientConnected")
    SubscribeToEvent("ClientDisconnected", "HandleClientDisconnected")
    SubscribeToEvent(Shared.EVENTS.CLIENT_READY, "HandleClientReady")
end

function HandleClientConnected(eventType, eventData)
    local connection = eventData["Connection"]:GetPtr("Connection")
    local connKey = GetConnectionKey(connection)
    playerConnections_[connKey] = {
        connection = connection,
        playerId = GeneratePlayerId(),
        playerData = nil,
    }
end

function HandleClientReady(eventType, eventData)
    local connection = eventData["Connection"]:GetPtr("Connection")
    local connKey = GetConnectionKey(connection)
    local playerInfo = playerConnections_[connKey]
    if not playerInfo then return end
    -- 收到 ClientReady 后才关联场景
    connection.scene = scene_
end

function HandleClientDisconnected(eventType, eventData)
    local connection = eventData["Connection"]:GetPtr("Connection")
    local connKey = GetConnectionKey(connection)
    local playerInfo = playerConnections_[connKey]
    if playerInfo then
        if playerInfo.playerNode then
            playerInfo.playerNode:Dispose()  -- 用 Dispose 不是 Remove
        end
        playerConnections_[connKey] = nil
    end
end

function GetConnectionKey(connection)
    if connection then
        return tostring(connection:GetAddress()) .. ":" .. tostring(connection:GetPort())
    end
    return nil
end
```

### 12.3 客户端连接处理

**正常模式（默认）**：

```lua
local serverConnection_ = nil

function Start()
    Shared.RegisterClientEvents()
    serverConnection_ = network:GetServerConnection()
    serverConnection_.scene = scene_
    serverConnection_:SendRemoteEvent(Shared.EVENTS.CLIENT_READY, true)

    SubscribeToEvent(Shared.EVENTS.ASSIGN_PLAYER, "HandleAssignPlayer")
    SubscribeToEvent("ServerDisconnected", "HandleServerDisconnected")
end
```

**后台匹配模式（Background Match）**：

```lua
local serverConnection_ = nil

function Start()
    Shared.RegisterClientEvents()
    -- 后台匹配模式下，游戏代码先于连接完成加载
    SubscribeToEvent("ServerReady", "HandleServerReady")
    SubscribeToEvent("ServerDisconnected", "HandleServerDisconnected")
end

function HandleServerReady(eventType, eventData)
    -- 连接完成后才能获取 serverConnection
    serverConnection_ = network:GetServerConnection()
    serverConnection_.scene = scene_
    serverConnection_:SendRemoteEvent(Shared.EVENTS.CLIENT_READY, true)
end
```

### 12.4 常驻服模式（Persistent World）

与普通匹配的关键编码差异：

| 要点 | 普通匹配 | 常驻服 |
|------|---------|--------|
| 玩家加入时机 | 只在开局时处理 | 任何时刻都可能有新玩家加入 |
| 获取在线人数 | `SERVER_REGISTERED_PLAYERS` | `network:GetClientConnections()` 实时查询 |
| 新玩家同步 | 不需要（都在开局前） | 需要遍历现有对象同步给新玩家 |

### 12.5 获取玩家昵称

使用全局函数 `GetUserNickname` 批量查询玩家昵称，服务端和客户端通用。

> 服务端时序要求：`user_id` 在 `ClientIdentity` 事件中才可用。

### 12.6 Ban 机制

```lua
connection:Ban()
```

---

## 13. 网络统计与调试

```lua
function GetClientStats(connection)
    return {
        rtt = connection.roundTripTime,
        bytesIn = connection.bytesInPerSec,
        bytesOut = connection.bytesOutPerSec,
    }
end
```

---

## 14. 云变量与远程事件排障实战

> 以下内容来自论坛实战问答，针对"用远程事件 + 云变量实现存档同步时频繁超时"的排障流程。

### 14.1 问题场景

用户使用"异步"（后台匹配 + 秒开模式）实现类似云存档的功能，通过远程事件让服务端读写 `serverCloud`，客户端设置 3 秒超时，但几乎每次都 TIME OUT。

### 14.2 排障思路（逐环节锁定）

远程事件存档的完整流程：

```
1. 游戏启动 → 连接服务端 → 进入房间 → 显示首页
2. 客户端发消息："我是玩家1，给我存档"
3. 客户端开始计时（3秒超时）
4. 服务端收到 → 查询 serverCloud → 返回存档数据
5. 客户端收到数据（或超时用本地缓存兜底）
```

**需要确认的三个环节**：

| 环节 | 排查方式 |
|------|---------|
| 客户端是否真的和服务端连接成功？ | 客户端打印日志，确认发送时处于连接状态 |
| 客户端发的消息，服务端是否收到？ | 服务端打印日志，记录收到的事件 |
| 服务端发的回应，客户端是否收到？ | 客户端打印日志，排除"收到了但没处理"的情况 |

### 14.3 常见误判

**误判 1：对 serverCloud 做失败重试**

```lua
-- ❌ 不推荐：serverCloud 极少失败，重试会掩盖真正问题
-- 应该直接将失败结果返回客户端，让开发者清楚知道是哪个环节出问题

-- ✅ 推荐：直接告知客户端失败
local ok, data = serverCloud:Get(userId, key)
if not ok then
    -- 通过远程事件告诉客户端"云变量读取失败"
    connection:SendRemoteEvent("CloudReadFailed", true, eventData)
    return
end
```

**误判 2：客户端防空覆盖**

在排查阶段不应该做防御性编程来掩盖问题，应该先定位根因。

### 14.4 serverCloud 的使用限制

| 限制 | 说明 |
|------|------|
| 单个 key 有数据上限 | 不能保存过大的数据 |
| 请求频率限制 | 使用太频繁会被拒绝 |
| 与玩家 ID 绑定 | 查询必须指定玩家 ID，没有公共共享数据 |

### 14.5 关于"异步"的澄清

用户所说的"异步"实际上是以下参数组合的效果：

| 参数 | 效果 |
|------|------|
| **秒开模式** | 人数不满也能开始游戏，不需要大厅页面 |
| **后台匹配** | 不用等服务端连接完成就初始化游戏，连接完成后通过 `ServerReady` 事件通知 |

> 不管这些参数怎么改，客户端使用服务端的方式都是一样的。引擎全权负责连接。

---

## 15. 常见问题速查表

| 问题 | 原因 | 解决方案 |
|------|------|---------|
| `Can not handle LoadScene message` | 时序错误 | 客户端先设 `serverConnection.scene`，再发 `ClientReady`，服务器收到后才设 `connection.scene` |
| 客户端看不到服务器创建的实体 | 时序/模式错误 | 检查初始化时序、ScriptObject 附加、客户端是否误用 REPLICATED |
| 客户端创建的节点与服务器冲突 | 默认模式是 REPLICATED | 客户端所有节点和组件必须用 LOCAL |
| 实体移动时抖动 | 相机额外 lerp | 移除相机跟随中的额外平滑，直接跟随目标位置 |
| 节点删除后客户端还能看到 | 用了 `Remove()` | 改用 `Dispose()` |
| 音效/特效没有播放 | 服务端无渲染 | 服务器通过远程事件通知客户端本地播放 |
| 远程事件数据为空 | 未包装 Variant | 确保用 `Variant()` 包装数据 |
| 远程事件收不到 | 未注册 | 接收方必须调用 `RegisterRemoteEvent` 注册事件 |
| `NodeAdded` 中 `GetVar` 返回空值 | Vars 还未同步完 | 使用 ScriptObject 的 `DelayedStart()` 回调 |
| 新玩家加入时看不到已有玩家 | 常驻服未主动同步 | 遍历当前所有 REPLICATED 节点，或通过远程事件补发状态 |

---

## 16. 给 AI 助手的对话模板

以下模板可直接复制发给 AI 助手，快速启动联网游戏开发：

### 模板 1：启动项目

```
嗒啦啦，我要做一个多人联机的 [游戏类型] 游戏，最多支持 [N] 个玩家同时玩。

请帮我生成完整的联网游戏代码，要求：
1. 使用权威服务器架构，服务端负责所有逻辑
2. 代码结构：
   Main.lua → 入口，判断服务端/客户端模式
   Network/Shared.lua → 共享配置
   Network/Server.lua → 服务端逻辑
   Network/Client.lua → 客户端逻辑

游戏规则：
[用大白话描述你的游戏]
```

### 模板 2：分工指令

```
请帮我设计服务端和客户端的分工：
- 服务端作为权威服务器，负责所有游戏逻辑计算
- 客户端只负责发送玩家输入和渲染画面
- 服务端创建的游戏对象使用 REPLICATED 模式
- 客户端创建相机、灯光等环境元素时使用 LOCAL 模式
```

### 模板 3：排查问题

```
[描述现象，如："客户端看不到服务端创建的金币"]
请检查：
1. 是否遵循正确的初始化时序
2. 是否使用了正确的 REPLICATED/LOCAL 模式
3. 远程事件是否都注册了
4. 节点删除是否使用了 Dispose()
```

---

*素材来源：TapTap 论坛帖子《UrhoX 联网游戏开发指南》《零基础实现简单的多人游戏(服务端)》及评论区问答*
*蒸馏日期：2026-04-24*

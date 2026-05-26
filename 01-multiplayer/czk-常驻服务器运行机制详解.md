# 常驻服务器运行机制详解

## 这是什么

UrhoX 常驻服（persistent_world）模式的完整运行机制文档，覆盖平台侧实例管理、玩家进出流程、服务端事件时序（ClientConnected→ClientIdentity→ClientReady）、实例无状态原则、反序列化 nil 陷阱等核心要点。

- **原作者**: czk
- **推荐度**: L2（参考学习）—— 机制讲解系统完整，但偏原理说明，实战踩坑见长宁的进阶版
- **适用场景**: 使用 persistent_world 模式的多人游戏，理解实例管理/玩家随时进出/数据持久化架构

---

## 常驻服 vs 房间制

| | 房间制（match_info） | 常驻服（persistent_world） |
|---|---|---|
| 开局 | 凑齐 N 人统一开局 | 服务器先启动，随时加入 |
| 中途加入 | ❌ | ✅ |
| 玩家离开 | 可能结束整局 | 游戏继续运行 |
| 生命周期 | 一局即销毁 | 持续运行，空闲超时销毁 |
| 典型场景 | MOBA/吃鸡/棋牌 | 沙盒/社交/IO休闲/挂机 |

---

## 配置

```json
{
  "multiplayer": {
    "enabled": true,
    "max_players": 5,
    "persistent_world": { "enabled": true }
  }
}
```

⚠️ `persistent_world` 和 `background_match` 互斥，同时启用时前者优先。

---

## 实例管理（核心）

### 实例是什么

一个实例 = 一个独立运行的服务器进程，最多容纳 `max_players` 个玩家，有独立内存状态，**不存储任何持久数据**。

### 创建与销毁

```
玩家请求加入 → 平台匹配查找可用实例
  ├─ 有空位 → 加入
  └─ 全满/无实例 → 自动创建新实例
  
最后一人离开 → 空闲计时 → 超时销毁
```

**平台会尽量填满已有实例**（先填满再开新的）。实例数量随在线人数动态增减。

### 实例数量示例（max_players=5）

| 时段 | 在线人数 | 实例数 |
|------|---------|-------|
| 上午 10:00 | 5 | 1 |
| 下午 14:00 | 50 | 10 |
| 凌晨 03:00 | 2 | 1 |
| 凌晨 05:00 | 0 | 全部销毁 |

---

## 玩家进出流程

### 服务端事件时序

```
ClientConnected      ← 仅 TCP 连接，⚠️ 不能获取 user_id
    ↓
ClientIdentity       ← 认证完成，user_id 可用
    ↓                   此时：加载存档、离线结算
ClientReady          ← 客户端准备好，可发送数据
```

### 重连 = 全新连接

玩家断线再进可能进不同实例。服务端不会自动恢复内存状态，必须通过 serverCloud 加载存档还原进度。

---

## 服务端编码要点

### 获取在线人数

```lua
-- ❌ SERVER_REGISTERED_PLAYERS 是启动快照，不更新
-- ✅ 实时查询
local onlineCount = #network:GetClientConnections()
```

### Start() 不能依赖玩家数量

```lua
function Start()
    InitGameWorld()  -- 初始化世界，此时可能没有玩家
    SubscribeToEvent("ClientIdentity", "HandlePlayerJoin")
end
```

### 处理随时加入

```lua
function HandlePlayerJoin(eventType, eventData)
    local conn = eventData["Connection"]:GetPtr("Connection")
    local userId = conn.identity["user_id"]:GetString()
    LoadPlayerData(userId, function(data)
        GameState.init(userId, data)
        local report = SettleOffline(userId, data)
        SendToClient(conn, "InitData", { playerData=data, offlineReport=report })
    end)
end
```

### 反序列化 nil 陷阱 🔴

常驻服中 GameState 数据不会自动清除，跳过 nil 会导致残留数据污染：

```lua
-- ❌ 跳过 nil → 上一个玩家数据残留
function deserialize(data, uid)
    if not data then return end
    GameState.get(uid).myField = data.mf
end

-- ✅ 显式用默认值清空
function deserialize(data, uid)
    local d = data or {}
    local s = GameState.get(uid)
    s.myField = d.mf or 0
    s.myTable = d.mt or {}
end
```

### 存档写入策略

```lua
-- 定时保存（30s 间隔）
if saveTimer >= 30 then SaveAllOnlinePlayers() end

-- 断线时立即保存 + 清理内存
function HandleDisconnect(...)
    SavePlayerData(userId)
    GameState.clear(userId)
end
```

---

## 实例无状态原则

```
实例 = 纯计算节点（CPU + 内存）
serverCloud = 持久存储层（数据库）
```

| 特性 | 意义 |
|------|------|
| 重连可能进不同实例 | 数据从 serverCloud 加载，体验一致 |
| 实例可随时创建/销毁 | 不影响玩家进度 |
| 崩溃恢复简单 | 重连进新实例，自动加载存档 |

### 数据存储位置

| 数据类型 | 存储位置 |
|---------|---------|
| 玩家存档（修为/灵币/背包） | serverCloud Score/子对象 |
| 排行榜 | serverCloud 排行榜 API |
| 市场挂单 | serverCloud List |
| 全局状态（注册人数/世界事件） | serverCloud Score |
| 临时战斗状态（HP/Buff） | 实例内存 GameState |

---

## 检查清单

- [ ] 服务端用 `GetClientConnections()` 获取在线人数
- [ ] `Start()` 不依赖玩家数量
- [ ] 反序列化正确处理 nil（`data or {}`）
- [ ] 断线时立即保存 + 清理 GameState
- [ ] 定时写 serverCloud 防崩溃丢数据
- [ ] 不依赖实例内存做持久化

---

## 常见问题

- **max_players=5 是总人数上限吗？** 不是，是单实例上限。平台按需创建多个实例。
- **跨实例能交互吗？** 不能直接交互，需通过 serverCloud 间接实现。
- **空闲多久销毁？** 引擎自动管理，脚本无法配置。
- **客户端需要特殊处理吗？** 不需要，Lobby 自动处理连接流程。

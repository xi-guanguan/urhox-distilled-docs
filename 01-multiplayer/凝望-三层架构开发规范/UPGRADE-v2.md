# 三层架构 Skill v2 升级指南

> 面向已使用 v1 版本（9 条铁律、5 个模板）的项目，增量升级到 v2。

---

## 变更概览

| 类别 | v1 | v2 | 影响 |
|------|----|----|------|
| 铁律 | 9 条 + 第 10 条（自建事件总线） | 12 条（新增 #10 #11 #12） | 新代码必须遵守 |
| 避雷清单 | 原有条目 | +3 条新 P0/P1/P2 | 新场景必查 |
| 模板数量 | 5 per-subsystem + 3 singleton | 5 per-subsystem + **6** singleton | 新增 3 个 |
| 事件命名 | `XxxConsts.Events = { C2S_*, S2C_* }` | `XxxConsts.EVENT_REQ_* / RES_* / PUSH_*` | 模板变更 |
| XxxClient | 内联 listeners_ 表 | EventBus 实例 + HandleDispatch | 模板重写 |
| PlayerStore | Get + WaitForChange | + Watch / Unwatch / UnwatchAll | 增量追加 |
| 子系统接入 | 2 步（Schema） | 7 步（Schema + 事件注册 + Dispatcher） | 流程扩展 |

---

## 升级步骤

### 第 1 步：新增 3 个中心单例文件

将以下模板复制到项目中：

```
assets/templates/NetworkEvents.lua      → scripts/shared/NetworkEvents.lua
assets/templates/ClientDispatcher.lua   → scripts/client/net/ClientDispatcher.lua
assets/templates/EventBus.lua           → scripts/client/net/EventBus.lua
```

### 第 2 步：改造现有 XxxConsts 事件命名

**旧格式**（v1）：
```lua
XxxConsts.Events = {
    C2S_DO_ACTION     = "Xxx:DoAction",
    S2C_ACTION_RESULT = "Xxx:ActionResult",
}
```

**新格式**（v2）：
```lua
-- 直接挂在模块顶层，EVENT_ 前缀
XxxConsts.EVENT_REQ_DO_ACTION  = "Xxx_ReqDoAction"
XxxConsts.EVENT_RES_DO_ACTION  = "Xxx_ResDoAction"
XxxConsts.EVENT_PUSH_STATE     = "Xxx_PushState"
```

**规则**：
- KEY 格式: `EVENT_{方向}_{动作}`（方向: REQ/RES/PUSH）
- VALUE 格式: `{Prefix}_{PascalAction}`（必须以注册前缀开头）
- 非事件常量（数值/枚举）不以 `EVENT_` 开头，不会被 NetworkEvents 收集

### 第 3 步：在 CharacterSchema 中注册事件

在 `CharacterSchema.lua` 底部子系统注册区域追加：

```lua
-- === 子系统 NetworkEvents 注册 ===
local NetworkEvents = require("shared.NetworkEvents")
local XxxConsts = require("shared.xxx.XxxConsts")
NetworkEvents.RegisterSubsystem("Xxx", XxxConsts)
```

每新增一个子系统，加一行 `NetworkEvents.RegisterSubsystem`。

### 第 4 步：改造现有 XxxClient

**旧模式**（v1）：
```lua
local listeners_ = {}
function XxxClient.On(event, callback)
    listeners_[event] = listeners_[event] or {}
    table.insert(listeners_[event], callback)
end
-- syncClient:OnServerEvent 中 emit
```

**新模式**（v2）：
```lua
local EventBus = require("client.net.EventBus")
XxxClient.Bus = EventBus.New()

function XxxClient.HandleDispatch(eventName, data)
    if eventName == XxxConsts.EVENT_RES_DO_ACTION then
        XxxClient.Bus:Emit("ActionDone", data)
    end
end
```

**关键变更**：
1. 删除内联 `listeners_` 表和 `On/emit` 函数
2. 使用 `EventBus.New()` 创建实例挂到 `XxxClient.Bus`
3. 实现 `HandleDispatch(eventName, data)` 供 ClientDispatcher 路由
4. 在 `client_main.lua` 中注册：`ClientDispatcher.Register("Xxx", XxxClient)`

### 第 5 步：升级 PlayerStore

在现有 PlayerStore 中追加以下功能（参考模板）：

1. **新增内部状态**：
```lua
local persistentWatchers_ = {}
local persistentIdSeq_ = 0
```

2. **新增 API**：
- `PlayerStore.Watch(key, callback, scope)` → 返回 watcherId
- `PlayerStore.Unwatch(watcherId)` → 移除单个
- `PlayerStore.UnwatchAll(scope)` → 批量移除（页面切换用）
- `PlayerStore._GetRaw(key)` → 原始值比对（内部用）
- `PlayerStore._CheckUnsubscribe()` → 自动取消 Update 订阅

3. **修改 HandlePlayerStoreWatcherUpdate**：在一次性 watcher 循环后追加持久 watcher 轮询。

4. **修改 Cleanup()**：清理 `persistentWatchers_`。

### 第 6 步：改造 client_main.lua

在入口文件中追加：

```lua
-- 顶部 require
local ClientDispatcher = require("client.net.ClientDispatcher")

-- Start() 中初始化
ClientDispatcher.Init()

-- NavigateTo 中追加 scope 自动清理
function NavigateTo(pageName)
    if currentPageName_ then
        local scope = currentPageName_:match("([^%.]+)$") or currentPageName_
        ClientDispatcher.ClearScope(scope)
        PlayerStore.UnwatchAll(scope)
    end
    -- ... 原有页面切换逻辑
end
```

### 第 7 步：注册子系统处理器

在 `client_main.lua` Start() 或各子系统初始化时：

```lua
local XxxClient = require("client.xxx.XxxClient")
ClientDispatcher.Register("Xxx", XxxClient, "XxxPage")  -- scope 可选
```

---

## 新增铁律速览

| # | 规则 | 违反后果 |
|---|------|---------|
| 10 | SubscribeToEvent 前 _G 函数必须存在 | "Could not find Lua function" ×N |
| 11 | REPLICATED 只传持久数据 / RemoteEvent 只传瞬时包 | 重连后数据异常 |
| 12 | 事件名必须加子系统前缀 | NetworkEvents 注册 error + 路由失败 |

---

## 新增避雷速览

| 级别 | 症状 | 原因 |
|------|------|------|
| P0 | "Could not find Lua function" ×N | SubscribeToEvent 时 _G[funcName] 未赋值 |
| P1 | 页面切换后 "attempt to index nil" | 幽灵回调操作已销毁 UI，未清理 scope |
| P2 | Watch 回调不触发（引用类型） | json table 内部变化不改变序列化字符串 |

---

## 兼容性说明

- v2 **完全向后兼容** v1 的 Schema 注册机制和 PDM/PlayerStore 数据流
- 旧子系统如果不需要客户端事件分发功能，可以暂不改造
- 新建子系统建议直接用 v2 完整流程（7 步）
- `NetworkEvents.RegisterSubsystem` 只收集 `EVENT_` 开头的字段，不影响旧格式的 `Events = {}` 表

---

## 文件变更清单

```
修改:
  SKILL.md                           (+客户端事件分发章节, 7步接入流程, 12条铁律)
  references/iron-rules.md           (+#10 #11 #12)
  references/gotchas.md              (+3条新避雷 + 症状速查表扩展)
  assets/templates/XxxConsts.lua     (EVENT_REQ/RES/PUSH 命名规范)
  assets/templates/XxxClient.lua     (EventBus + HandleDispatch 模式)
  assets/templates/PlayerStore.lua   (+Watch/Unwatch/UnwatchAll + _GetRaw)

新增:
  assets/templates/NetworkEvents.lua
  assets/templates/ClientDispatcher.lua
  assets/templates/EventBus.lua
  UPGRADE-v2.md                      (本文件)
```

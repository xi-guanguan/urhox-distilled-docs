# 避雷清单（按严重性分级）

> 从实际 Bug 中提炼，每条都对应一个真实事故。

## P0 — 必修（违反 = 数据丢失/服务崩溃）

### 断线时序反转 → 玩家回档
```
❌ UnloadPlayer → SaveAll    （内存已清，写入空数据）
✅ SaveAll → UnloadPlayer    （先保存，再清理）
```

### 写时即存耗尽 serverCloud 配额
```
❌ SetStat 时立即 serverCloud.SetValue()
✅ SetStat → MarkDirty → 心跳/断线时 BatchCommit
```

### 背包删除不完整 → 幽灵条目
```
❌ 只 table.remove(内存)
✅ table.remove(内存) + ListDelete(持久化)  — 两步缺一不可
```

### 重复 LoadPlayer → 首次登录被踢
```
❌ ServerSync.OnCharacterSelected 中调用 PDM.LoadPlayer
✅ 该调用已由 ServerCharacter 完成，禁止重复调用
```
原因：LoadPlayer 会销毁重建 PlayerNode，导致客户端连接断开。

### SubscribeToEvent 前函数未注册 → 9 事件全部无法触发 🆕
```
❌ SubscribeToEvent(event, funcName) 时 _G[funcName] 尚未赋值
   → 引擎在订阅时即解析函数引用，找不到 → "Could not find Lua function"
✅ 先 _G[funcName] = handler，再 SubscribeToEvent(event, funcName)
```
典型场景：ClientDispatcher 动态订阅远程事件。引擎报错 ×N（每个事件一条）。

## P1 — 静默失败（不报错但功能异常）

### 客户端缓存绕过 PDM → 字段名不匹配
```
❌ 本地变量 goldTickets_ 接收 SendToClient 推送
✅ PlayerStore.Get("currency", "goldTickets") 读取
```
教训：v1.3.13 商店模块 4 个字段因本地缓存全部静默失败。

### MarkDirty 延迟 → 发送结果事件前客户端数据未更新
```
❌ PDM.SetStat() → SendToClient(RESULT)    （客户端还没收到新数据）
✅ PDM.SetStat() → PDM.SyncXxx(uid) → SendToClient(RESULT)
```
MarkDirty 是 0.1s 批量延迟，发送结果前必须调 Sync* 即时同步。

### V1 Client.Emit 不存在
```
❌ 三层架构模块 require V1 network.Client 然后调 Client.Emit()
✅ 三层架构模块自建事件总线（参考 SecretRealmClient.lua）
```
V1 Client 代理没有 Emit 方法，只有 V2 Client 才有。

### 结果事件回调中直接读 PlayerStore → 拿到旧值
```
❌ Client.On(RESULT, function() local v = PlayerStore.Get("Gold") end)
   -- REPLICATED 延迟 50-80ms，此时读到旧值
✅ PlayerStore.WaitForChange("Gold", { onChange = function(v) ... end })
   Client.SendToServer(REQUEST, { ... })
```
REPLICATED 变量同步延迟 50-80ms，结果事件先到。用 WaitForChange 轮询等数据到达。
详见 [client-sync-tolerance.md](client-sync-tolerance.md)

### PreBattleGateway 阻断未调 onCancel
```
❌ 阻断时只 return，不调用 opts.onCancel
✅ 阻断时必须调用 opts.onCancel()，否则调用方 GameFlow 卡死
```

### 页面切换后幽灵回调 → UI 操作已销毁的控件 🆕
```
❌ XxxClient 在 EventBus.On 中操作 UI，页面切换后回调仍在
   → "attempt to index a nil value" / UI 残影
✅ EventBus.On 第三参数传 scope，NavigateTo 时自动
   ClientDispatcher.ClearScope(scope) + PlayerStore.UnwatchAll(scope)
```
页面切换时必须清理该页面注册的所有事件监听和 Watch。

## P2 — 逻辑错误（功能行为不正确）

### selfDamage 下限错误
```
❌ math.max(0, damage)   — 自伤可致死（0伤害绕过保护）
✅ math.max(1, damage)   — 保证最少1点伤害
```

### DoT tick 缺少 skillStyle
bleed/burn/poison 的 DoT tick 必须在 layer/buff 上存储 `skillStyle`，tick 时调用 `GetBizarreDotMult(skillStyle)` 应用 dotMultiplier。

### HeartService 字段名
心法匹配使用 `slot.id`（非 `slot.methodId`），字段名错误会导致匹配失败。

### QuotaProvider.Add 返回值
```lua
local result = QuotaProvider.Add(uid, key, amount)
-- result = { ok, new_val, daily_total }
-- ❌ 忽略 ok 字段
-- ✅ 必须检查 result.ok 判断是否超限
```

### AdHandler OnWatchComplete 必须同步回调
```
❌ callback 包在异步流程中 → 回调永不执行 → 秘境卡死
✅ 直接 callback()（同步调用）
```

### PlayerStore.Watch 对引用类型不触发 🆕
```
❌ PlayerStore.Watch("inventory", callback)
   -- Watch 基于 _GetRaw() 轮询原始值（string），json 反序列化后
   -- table 内部字段变化不改变序列化结果 = 不触发
✅ Watch 适合 scalar 字段（HP/Gold/Level 等单值变化）
   引用类型变化（背包增删改）走 RemoteEvent 结果事件通知
```
Watch 内部用 `_GetRaw` 比对字符串级变化，如果服务端 SetStruct 时 JSON 序列化结果相同则不触发。

## P3 — 架构违规（当前可工作但积累技术债）

### 新模块数据链路经过 V2 桥接
```
❌ 三层架构模块 → require v2/client/network/events/xxx → 处理数据
✅ 三层架构模块直接使用 PlayerStore + 自建事件
```

### 在 V2 模块上修字段名
```
❌ 发现 Bug → 在 V2 模块里改字段名适配新模块
✅ 发现 Bug → 消除对 V2 的依赖，用 PDM+PlayerStore 重建链路
```

---

## 症状 → 原因速查

| 症状 | 首先检查 |
|------|---------|
| 客户端数据不刷新 | 是否漏调 Sync*？是否用了本地缓存？ |
| 断线后数据回档 | SaveAll/UnloadPlayer 时序是否反了？ |
| 功能静默失败（不报错） | 字段名是否前后端不匹配？是否绕过了 PDM？ |
| 首次登录被踢 | 是否重复调用了 LoadPlayer？ |
| serverCloud 配额快速耗尽 | 是否写时即存而非 BatchCommit？ |
| 操作成功但 UI 无响应 | 是否 SendToClient 在 Sync 之前发出？ |
| 结果事件回调读到旧数据 | REPLICATED 延迟 50-80ms，用 WaitForChange 轮询 |
| 三层模块调 Emit 报错 | 是否引用了 V1 Client？改用自建事件总线 |
| 客户端加载超时，服务端脚本无报错 | SetVar 超 64KB 静默丢包，检查引擎日志 + 集合数据走分包同步 |
| "Could not find Lua function" ×N | SubscribeToEvent 前 `_G[funcName]` 未赋值（见铁律 #10） |
| 页面切换后 "attempt to index nil" | 页面已销毁但事件回调未清理，检查 scope 自动清理 |
| Watch 回调不触发（引用类型） | Watch 基于 raw string 比对，json table 内部变化可能序列化结果相同 |

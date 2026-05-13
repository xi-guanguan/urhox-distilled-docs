# 云存档双通道持久化 Skill（clientCloud + 本地文件）

> **来源**: 社区分享（微信群）
> **作者**: 店长
> **蒸馏等级**: L2（学习参考）
> **适用场景**: 单机/弱联网游戏需要高可靠存档系统（本地+云端双保险）
> **核心价值**: 双通道架构 + 乐观锁防回档 + Save Guard 防丢失 + 批量读写优化
> **前置知识**: `engine-docs/recipes/client-cloud-score.md`（clientCloud 基础 API）

---

## 一、架构概览

```
┌──────────────────────────────────────────────────┐
│                   GameState                       │
│     (内存中的游戏数据，唯一数据源)                   │
└────────────────┬─────────────────────────────────┘
                 │
        ┌────────┴────────┐
        ▼                 ▼
   本地文件缓存       clientCloud
   (即时写入)         (异步上传)
   File API           BatchSet
```

**双通道策略**：
- **本地文件**：每次保存即时写入，启动时优先读取，保证断网可玩
- **clientCloud**：异步上传到云端，跨设备同步，防卸载丢失

---

## 二、核心模块设计

### 2.1 存档管理器（SaveManager）

```lua
local SaveManager = {}

-- 配置
local SAVE_FILE = "save.json"            -- 本地存档文件名
local AUTO_SAVE_INTERVAL = 30            -- 自动保存间隔（秒）
local CLOUD_KEYS = { "save_data", "save_seq" }  -- 云端键名

-- 内存数据
local gameState = {}    -- 当前游戏状态
local saveSeq = 0       -- 乐观锁序列号
local isDirty = false   -- 是否有未保存的修改
local lastSaveTime = 0  -- 上次保存时间戳
```

### 2.2 数据修改入口（统一标记脏数据）

```lua
function SaveManager.Set(key, value)
    gameState[key] = value
    isDirty = true
end

function SaveManager.Get(key, default)
    local v = gameState[key]
    if v == nil then return default end
    return v
end
```

---

## 三、保存流程

### 3.1 本地保存（同步，即时生效）

```lua
local function SaveLocal()
    saveSeq = saveSeq + 1
    local data = {
        state = gameState,
        seq   = saveSeq,
        ts    = os.time(),
    }
    local json = cjson.encode(data)
    local file = File(SAVE_FILE, FILE_WRITE)
    if file then
        file:Write(json)
        file:Close()
    end
end
```

### 3.2 云端保存（异步，BatchSet 批量写入）

```lua
local function SaveCloud()
    local json = cjson.encode(gameState)
    clientCloud:BatchSet({
        { key = "save_data", value = json },
        { key = "save_seq",  value = tostring(saveSeq) },
    }, function(ok)
        if ok then
            log:Info("云端保存成功 seq=" .. saveSeq)
        else
            log:Warn("云端保存失败，下次重试")
        end
    end)
end
```

### 3.3 统一保存接口

```lua
function SaveManager.Save()
    if not isDirty then return end
    SaveLocal()           -- 先写本地
    SaveCloud()           -- 再传云端
    isDirty = false
    lastSaveTime = os.time()
end
```

---

## 四、加载流程（冲突解决）

### 4.1 启动时加载策略

```lua
function SaveManager.Load(callback)
    -- 1. 读本地存档
    local localData = LoadLocalFile()
    local localSeq  = localData and localData.seq or 0

    -- 2. 读云端存档
    clientCloud:BatchGet(CLOUD_KEYS, function(ok, results)
        if not ok or not results then
            -- 云端不可用，用本地
            if localData then
                gameState = localData.state
                saveSeq = localSeq
            end
            callback(true)
            return
        end

        local cloudData = results["save_data"] and cjson.decode(results["save_data"])
        local cloudSeq  = tonumber(results["save_seq"] or "0")

        -- 3. 乐观锁：谁的 seq 大用谁的
        if cloudSeq > localSeq then
            gameState = cloudData
            saveSeq = cloudSeq
            SaveLocal()  -- 更新本地缓存
        else
            gameState = localData and localData.state or {}
            saveSeq = localSeq
            if localSeq > cloudSeq then
                SaveCloud()  -- 本地更新推到云端
            end
        end
        callback(true)
    end)
end
```

### 4.2 冲突解决规则

| 本地 seq | 云端 seq | 结果 |
|----------|---------|------|
| 5 | 3 | 用本地（本地更新），推送到云端 |
| 3 | 5 | 用云端（云端更新），覆盖本地 |
| 5 | 5 | 一致，直接用本地 |
| 0 | 0 | 新用户，初始化空数据 |

---

## 五、自动保存与 Save Guard

### 5.1 定时自动保存

```lua
function SaveManager.Update(dt)
    if isDirty and (os.time() - lastSaveTime >= AUTO_SAVE_INTERVAL) then
        SaveManager.Save()
    end
end
```

在 `HandleUpdate` 中每帧调用 `SaveManager.Update(dt)`。

### 5.2 Save Guard（生命周期保护）

确保以下时机触发保存：

```lua
-- 切后台时保存
SubscribeToEvent("AppPaused", function()
    SaveManager.Save()
end)

-- 退出前保存（如果引擎支持）
SubscribeToEvent("ExitRequested", function()
    SaveManager.Save()
end)
```

**关键**：`AppPaused` 是移动端最可靠的保存时机，进程可能随时被杀。

---

## 六、BatchGet / BatchSet 使用要点

### 批量读写（推荐）

```lua
-- ✅ 批量读取（一次网络请求）
clientCloud:BatchGet({"key1", "key2", "key3"}, function(ok, results)
    -- results["key1"], results["key2"], results["key3"]
end)

-- ✅ 批量写入（一次网络请求）
clientCloud:BatchSet({
    { key = "key1", value = "val1" },
    { key = "key2", value = "val2" },
}, function(ok) end)
```

### 避免逐个读写

```lua
-- ❌ 错误：多次网络请求，性能差且回调地狱
clientCloud:Get("key1", function(ok1, v1)
    clientCloud:Get("key2", function(ok2, v2)
        clientCloud:Get("key3", function(ok3, v3)
            -- ...
        end)
    end)
end)
```

---

## 七、已知陷阱

### 7.1 seq 膨胀

每次保存 seq+1，长期运行会很大。**不影响功能**，seq 只用于比较大小。如果介意，可在确认云端同步后重置：

```lua
if localSeq == cloudSeq and localSeq > 1000 then
    saveSeq = 1
    SaveLocal()
    SaveCloud()
end
```

### 7.2 回调不可靠

clientCloud 的回调在某些场景（进程被杀、网络超时）不会触发。**必须加超时兜底**：

```lua
local timeout = 5  -- 秒
local responded = false
clientCloud:BatchGet(keys, function(ok, results)
    responded = true
    -- ...正常处理
end)

-- 超时兜底（在 Update 中检查）
local elapsed = 0
local function CheckTimeout(dt)
    elapsed = elapsed + dt
    if elapsed > timeout and not responded then
        -- 超时，使用本地数据
        log:Warn("云端读取超时，使用本地存档")
        -- ...回退到本地
    end
end
```

### 7.3 并发写入保护

避免在短时间内多次触发保存（如快速点击）：

```lua
local saving = false
function SaveManager.Save()
    if saving or not isDirty then return end
    saving = true
    SaveLocal()
    SaveCloud()
    isDirty = false
    -- 延迟解锁（防抖）
    DelayCall(1.0, function() saving = false end)
end
```

---

## 八、接入清单

- [ ] 初始化时调用 `SaveManager.Load(callback)` 加载存档
- [ ] 数据修改统一走 `SaveManager.Set(key, value)`
- [ ] `HandleUpdate` 中调用 `SaveManager.Update(dt)` 驱动自动保存
- [ ] 订阅 `AppPaused` 事件触发保存
- [ ] clientCloud 回调加超时兜底（5 秒）
- [ ] 关键操作（购买、升级）后立即调用 `SaveManager.Save()`

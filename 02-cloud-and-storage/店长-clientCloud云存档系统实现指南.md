# clientCloud 云存档系统实现指南

> **这是什么**: 基于 UrhoX clientCloud API 的单机游戏云存档完整实现方案，涵盖批量读写、加载保护、失败重试、脏标记自动保存、版本迁移等生产级模式。
> **原作者**: 店长
> **推荐度**: L2（参考学习）— 模式成熟完整，可直接套用到任何单机游戏项目。
> **适用场景**: 单机游戏需要云端存档/跨设备同步/排行榜功能时。

---

## 架构总览

```
启动 → BatchGet 批量加载全部 key
       ↓
     GameState（运行时内存状态）
       ↓
     多时机触发 BatchSet 批量保存
       ↓
     云端 clientCloud 持久化
```

三条核心原则：
1. **单次批量读取** — 启动时一次 BatchGet 加载所有字段，避免多次网络往返
2. **分散时机保存** — 结算/购买/领取等关键节点各自触发保存
3. **加载保护** — 未成功加载前拒绝一切保存，防空数据覆盖云端

---

## API 速查

| 类别 | 方法 | 说明 |
|------|------|------|
| 单值 | `Set/Get/SetInt/GetInt/Delete` | 字符串或整数 |
| **批量（推荐）** | `BatchSet/BatchGet` | 合并网络往返 |
| 排行榜 | `GetLeaderboard/GetLeaderboardAroundPlayer` | 需要 SetInt 存储的整数字段 |

### 数据类型选型

| 需求 | 方法 | 示例 |
|------|------|------|
| 需要排行榜排序 | `SetInt`（整数） | 金币、等级、分数 |
| 复杂结构 | `Set`（JSON 字符串） | 背包、配置、装备 |

BatchSet 中可混合使用整数和 JSON 字符串。

---

## 六大核心模式

### 1. 加载（BatchGet）

```lua
clientCloud:BatchGet()
    :Key("saved_gold"):Key("equip_bag")
    :Fetch({
        ok = function(values, iscores)
            -- int 字段从 iscores 读取
            GameState.savedGold = iscores.saved_gold or 0
            -- table 字段从 values 读取并校验类型
            GameState.equipBag = (type(values.equip_bag) == "table") and values.equip_bag or {}
            GameState.cloudLoaded = true
            GameState.cloudLoadSuccess = true
        end,
        error = function(code, reason)
            GameState.cloudLoaded = true  -- cloudLoadSuccess 保持 false → 触发重试
        end
    })
```

防御性处理：`pcall` 检测 `clientCloud` 是否存在，不可用时使用默认值让游戏正常运行。

### 2. 加载保护（防覆盖）

```lua
function CloudManager.Save(gameData, callback)
    if not cloudState.isLoaded then
        print("[CloudManager] 云数据未加载，跳过保存")
        return
    end
    -- 执行保存...
end
```

**问题本质**: 云端加载是异步的。未完成就保存 → 用本地默认值覆盖云端 → 存档丢失。

### 3. 失败重试

- 延迟重试：2 秒间隔，最多 3 次，通过 Update 倒计时驱动
- 超过重试次数 → 显示重试 UI（弹窗 + 重试按钮）

### 4. 脏标记 + 自动保存 + 防并发

```lua
CloudManager.MarkDirty()       -- 任何数据变更时调用
-- AutoSaveCheck 在 HandleUpdate 中检查：
--   isDirty? + 距上次保存 >= 30秒? → Save()
-- Save() 内部：isSaving 防并发，保存期间新变更标记脏位等下次
```

### 5. 版本迁移

存档带版本号，加载时逐级迁移：

| 版本跳跃 | 迁移内容示例 |
|---------|------------|
| v1→v2 | 背包从字符串数组改为 `{id, count}` 对象数组 |
| v2→v3 | 新增成就系统字段 |

装备槽位兼容：`number` → `{id}` → `{id, quality, level, affixes}` 逐级自动补全。

### 6. 多模块分散保存

各模块（商店/邮件/兑换码等）只写入 GameState 字段，统一由一个 `SaveCloudData()` 函数批量提交，避免多模块各自调用 BatchSet 导致竞态。

---

## 保存时机决策表

| 时机 | 方式 | 原因 |
|------|------|------|
| 关卡结算/购买道具/领取奖励 | **立即保存** | 防进度丢失/刷货币/重复领取 |
| 广告播放前 | **立即保存** | 应用可能被系统回收 |
| 游戏退出/切后台 | **立即保存** | 确保最终数据写入 |
| 设置变更/战斗中击杀 | `MarkDirty()` | 等自动保存（30秒）即可 |

---

## 关键陷阱

### JSON 数字键字符串化

clientCloud 内部用 JSON 序列化，数字键变字符串。加载时需手动转换：

```lua
branches[tonumber(k) or k] = v  -- 字符串键转回数字
```

### 动态 Key（日期计数）

```lua
local adTodayKey = "ad_" .. os.date("%Y%m%d")  -- 每日自动隔离
```

### 迁移后必须立即保存

数据迁移完成后必须调用 `SaveCloudData()` 持久化，否则下次加载还会重复迁移。

### 安全 JSON 解析

```lua
local function safeJsonDecode(str, default)
    if not str or str == "" then return default end
    local ok, result = pcall(json.decode, str)
    return ok and result or default
end
```

---

## 完整检查清单

- [ ] 使用 BatchGet/BatchSet 批量操作
- [ ] 需排行的字段用 SetInt，复杂结构用 Set/JSON
- [ ] 加载保护：未加载完成前禁止保存
- [ ] isSaving/isLoading 防并发
- [ ] 失败重试 3 次 + 重试 UI
- [ ] 脏标记 + 30 秒自动保存间隔
- [ ] JSON 解码用 pcall + 默认值
- [ ] 存档带版本号 + 迁移逻辑
- [ ] 每次保存写入时间戳
- [ ] 加载后 tonumber 转回数字键
- [ ] 日期计数用日期后缀动态 key

---

## 存档字段规划模板

| 云端 Key | 方法 | 本地字段 | 说明 |
|----------|------|---------|------|
| `saved_gold` | SetInt | savedGold | 金币（可排行） |
| `high_score` | SetInt | highScore | 最高分（可排行） |
| `equip_bag` | Set | equipBag | 装备背包（JSON） |
| `settings` | Set | settings | 游戏设置（JSON） |
| `ad_YYYYMMDD` | SetInt | dailyAdCount | 每日广告计数（动态key） |

---

*蒸馏自: 店长云存档 skill 导出文档*

# ReactiveUI 响应式状态管理框架

> **来源**: 社区分享（微信群）
> **作者**: 滑滑
> **蒸馏等级**: L1（实用精编）
> **适用场景**: 需要数据驱动 UI 自动刷新的游戏项目（背包、商店、HUD、设置面板等）
> **核心价值**: Store 响应式状态 + bind 自动绑定 + computed 派生计算 + effect 副作用 + 列表渲染
> **前置知识**: `engine-docs/recipes/ui.md`（UrhoX UI 库基础）

---

## 一、核心理念

**数据改了 → UI 自动更新**，不需要手动刷新。

```
Store（数据源）
  │
  ├── bind(key, widget, prop)     → 数据变 → UI 属性自动更新
  ├── computed(deps, fn)          → 依赖变 → 派生值自动重算
  └── effect(deps, fn)            → 依赖变 → 副作用自动触发
```

传统方式 vs ReactiveUI：

```lua
-- ❌ 传统：手动刷新（容易遗漏）
gold = gold + 100
goldLabel.text = "金币: " .. gold    -- 忘了这行 → UI 不更新

-- ✅ ReactiveUI：数据驱动
store:set("gold", store:get("gold") + 100)
-- UI 自动更新，不需要额外代码
```

---

## 二、基础 API

### 2.1 创建 Store

```lua
local ReactiveUI = require("ReactiveUI")

local store = ReactiveUI.new({
    gold = 0,
    hp = 100,
    maxHp = 100,
    playerName = "勇者",
    level = 1,
    items = {},
})
```

### 2.2 读写数据

```lua
store:get("gold")                    -- 读取
store:set("gold", 500)               -- 写入（自动触发绑定更新）
store:set("gold", function(old)      -- 函数式更新
    return old + 100
end)
```

### 2.3 绑定 UI 属性（bind）

```lua
-- 基本绑定：数据变 → 自动设置 widget 属性
store:bind("gold", goldLabel, "text")
-- gold 变化时，自动执行 goldLabel.text = gold 的值

-- 带格式化：
store:bind("gold", goldLabel, "text", function(v)
    return "金币: " .. v
end)

-- 绑定任意属性：
store:bind("hp", hpBar, "value")         -- 进度条
store:bind("visible", panel, "visible")   -- 显示/隐藏
```

### 2.4 派生计算（computed）

```lua
-- 多个依赖 → 自动计算派生值
store:computed({"hp", "maxHp"}, function(hp, maxHp)
    return math.floor(hp / maxHp * 100) .. "%"
end, hpPercentLabel, "text")

-- hp 或 maxHp 任一变化 → 百分比自动重算 → label 自动更新
```

### 2.5 副作用（effect）

```lua
-- 数据变化时触发自定义逻辑（不绑定到特定 widget）
store:effect({"hp"}, function(hp)
    if hp <= 0 then
        ShowGameOver()
    elseif hp < 20 then
        PlayWarningSound()
    end
end)
```

### 2.6 批量更新（batch）

```lua
-- 多个 set 合并为一次更新（避免中间状态触发 UI 刷新）
store:batch(function()
    store:set("hp", 100)
    store:set("maxHp", 150)
    store:set("level", store:get("level") + 1)
end)
-- batch 结束后统一触发一次更新
```

---

## 三、列表渲染（bindList）

适用于背包、商店、排行榜等列表型 UI：

```lua
store:bindList("items", listContainer, function(item, index)
    -- 返回每一项的 UI 元素
    return UI.Panel {
        flexDirection = "row", alignItems = "center",
        height = 48, paddingHorizontal = 8,
        children = {
            UI.Image { src = item.icon, width = 32, height = 32 },
            UI.Label { text = item.name, fontSize = 14, marginLeft = 8 },
            UI.Label { text = "x" .. item.count, fontSize = 12, marginLeft = "auto" },
        },
    }
end)

-- 修改列表 → UI 自动增删
store:set("items", function(list)
    table.insert(list, { name = "药水", icon = "potion.png", count = 3 })
    return list
end)
```

---

## 四、典型使用模式

### HUD 面板

```lua
local store = ReactiveUI.new({ gold = 0, hp = 100, maxHp = 100 })

local hud = UI.Panel {
    width = "100%", height = 46,
    flexDirection = "row", alignItems = "center",
    paddingHorizontal = 12,
    children = {
        UI.Label { id = "goldLabel", fontSize = 15 },
        UI.Label { id = "hpLabel",   fontSize = 15, marginLeft = "auto" },
    },
}

store:bind("gold", hud:find("goldLabel"), "text", function(v) return "金币: " .. v end)
store:computed({"hp", "maxHp"}, function(hp, max)
    return "HP: " .. hp .. "/" .. max
end, hud:find("hpLabel"), "text")
```

### 存档联动

```lua
-- 加载存档 → 批量写入 store → UI 全部自动更新
store:batch(function()
    for k, v in pairs(savedData) do
        store:set(k, v)
    end
end)

-- 保存时直接读 store
local dataToSave = {}
for _, key in ipairs(saveKeys) do
    dataToSave[key] = store:get(key)
end
```

---

## 五、注意事项

1. **Store 是单向数据流**：修改数据必须通过 `store:set()`，禁止直接修改 widget 属性（会被下次 set 覆盖）
2. **避免循环依赖**：A computed 依赖 B，B computed 依赖 A → 死循环
3. **batch 内不要读取刚 set 的值**：batch 内的 get 返回的是旧值
4. **大列表考虑 VirtualList**：`bindList` 适合 <100 项；超大列表用 `UI.VirtualList` + store 组合
5. **清理**：组件销毁时调用 `store:unbindAll()` 避免内存泄漏

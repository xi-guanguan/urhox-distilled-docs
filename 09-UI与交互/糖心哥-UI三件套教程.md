# UI 三件套教程：主菜单 / 设置页 / 背包系统

> **这是什么**：用 UrhoX 内置 UI 库（40+ 控件）搭建三种最常见游戏界面的完整教程，含提示词模板。
>
> **原作者**：糖心哥
> **推荐度**：L2（零基础友好的教学文档，以提示词驱动为主，适合理解 UI 库用法和布局思路）
> **适用场景**：需要快速搭建主菜单、设置页、背包/装备系统时

---

## 零、前置：UI 库初始化

所有 UI 页面共用同一个初始化：

```lua
local UI = require("urhox-libs/UI")

UI.Init({
    fonts = {
        { family = "sans", weights = { normal = "Fonts/MiSans-Regular.ttf" } }
    },
    scale = UI.Scale.DEFAULT,  -- 自动适配手机屏幕，必须设置
})
```

> **铁律 #1**：最后必须调用 `UI.SetRoot(root)`，否则什么都不显示。
> **铁律 #2**：`scale = UI.Scale.DEFAULT` 不设则手机上 UI 大小乱套。

---

## 一、主菜单

### 1.1 心法：居中

```
justifyContent = "center"  -- 垂直居中
alignItems = "center"      -- 水平居中
```

### 1.2 结构

```
全屏容器（垂直居中 + 水平居中）
  └── 卡片面板（背景色 + 圆角 + 内边距）
        ├── Label 标题（大字号）
        ├── Label 副标题（小字号、浅色）
        ├── Button "开始游戏" (variant="primary")
        ├── Button "设置" (variant="secondary")
        └── Button "退出" (variant="danger")
```

### 1.3 核心代码

```lua
local root = UI.Panel {
    width = "100%", height = "100%",
    justifyContent = "center", alignItems = "center",
    children = {
        UI.Panel {
            width = "85%", maxWidth = 360,
            padding = 40, gap = 16, borderRadius = 16,
            backgroundColor = { 0.12, 0.12, 0.15, 0.95 },
            children = {
                UI.Label { text = "星际冒险", fontSize = 28 },
                UI.Label { text = "v1.0", fontSize = 12, color = {0.6,0.6,0.6,1} },
                UI.Button { text = "开始游戏", variant = "primary",
                    onClick = function(self) print("开始游戏") end },
                UI.Button { text = "设置", variant = "secondary",
                    onClick = function(self) OpenSettings() end },
                UI.Button { text = "退出", variant = "danger",
                    onClick = function(self) engine:Exit() end },
            }
        }
    }
}
UI.SetRoot(root)
```

### 1.4 常见扩展

| 需求 | 提示词 |
|------|--------|
| 背景图 | 「加背景图 Textures/menu_bg.png，cover 模式铺满」 |
| 按钮图标 | 「按钮前加 emoji：▶ 开始游戏、⚙ 设置」 |
| 入场动画 | 「标题和按钮淡入，从下往上滑入，间隔 0.1 秒」 |
| 背景音乐 | 「进入主菜单播放 Sounds/menu_bgm.ogg 循环」 |

### 1.5 常见坑

| 坑 | 原因 | 解决 |
|----|------|------|
| 啥也不显示 | 忘了 `UI.SetRoot(root)` | 补上 |
| 手机上字太小/大 | 没设 `UI.Scale.DEFAULT` | 加上 |
| 按钮点不到 | 外层 `pointerEvents = "none"` | 改 `"auto"` |

---

## 二、设置页

### 2.1 心法：表单

"标签 + 控件"反复堆叠，用 Modal 弹窗装起来。

### 2.2 核心控件

| 控件 | 用途 | 示例 |
|------|------|------|
| `UI.Slider` | 连续数值（音量、亮度） | `value=80, onChange=fn` |
| `UI.Toggle` | 开/关选项 | `checked=true, onChange=fn` |
| `UI.Dropdown` | 多选一 | `options={"低","中","高"}` |
| `UI.TextField` | 文本输入（改名） | `placeholder="输入名字"` |
| `UI.Checkbox` | 多选 | `checked=false` |

### 2.3 核心结构

```lua
-- 设置数据（定义在函数外，保持跨次打开的状态）
local settings = {
    musicVolume = 80,
    sfxVolume = 100,
    quality = "medium",
    vibration = true,
}

function OpenSettings()
    UI.Modal {
        title = "游戏设置",
        children = {
            -- 每个设置项：Label + 控件
            UI.Label { text = "音乐音量" },
            UI.Slider { value = settings.musicVolume,
                onChange = function(self, v) settings.musicVolume = v end },

            UI.Label { text = "音效音量" },
            UI.Slider { value = settings.sfxVolume,
                onChange = function(self, v) settings.sfxVolume = v end },

            UI.Label { text = "画质" },
            UI.Dropdown { options = {"低", "中", "高"}, selected = settings.quality,
                onChange = function(self, v) settings.quality = v end },

            -- 震动：横排（flexDirection="row"）
            UI.Panel { flexDirection = "row", alignItems = "center", gap = 12,
                children = {
                    UI.Label { text = "震动反馈" },
                    UI.Toggle { checked = settings.vibration,
                        onChange = function(self, v) settings.vibration = v end },
                }
            },
        },
        buttons = {
            { text = "取消", variant = "secondary", onClick = function() end },
            { text = "保存", variant = "primary", onClick = function()
                print("已保存设置") end },
        }
    }
end
```

### 2.4 常见坑

| 坑 | 原因 | 解决 |
|----|------|------|
| Dropdown 被裁切 | 外层 `overflow="hidden"` | 去掉或改 `"visible"` |
| 关了再开值没保留 | settings 定义在函数内 | 定义在函数外（全局） |
| 设置项挤在一起 | 间距不够 | 加 `gap=20` 或 `UI.Divider` |

---

## 三、背包系统

### 3.1 心法：三层分离

```
DragDropContext（交互层 —— 管拖拽行为）
├── 装备面板
│   ├── ItemSlot [helmet]  ← 只接受头盔
│   ├── ItemSlot [weapon]  ← 只接受武器
│   ├── ItemSlot [armor]   ← 只接受护甲
│   └── ItemSlot [boots]   ← 只接受靴子
└── 背包面板
    └── ItemSlot [1]~[20]  ← 接受任何物品
```

| 层 | 组件 | 职责 |
|----|------|------|
| 数据层 | `InventoryManager` | 物品的增删改查 |
| 视图层 | `ItemSlot` | 单个格子的 UI + 图标显示 |
| 交互层 | `DragDropContext` | 拖拽跟手、放下判定、类型检查 |

### 3.2 关键步骤

**步骤 1：定义物品数据**

```lua
local items = {
    { id = 1, name = "铁头盔", icon = "🪖", type = "helmet", rarity = "common" },
    { id = 2, name = "铁剑",   icon = "⚔️", type = "weapon", rarity = "rare" },
    { id = 3, name = "生命药水", icon = "🧪", type = "consumable", rarity = "common" },
    -- ...
}
```

**步骤 2：创建 InventoryManager**

```lua
local invMgr = UI.InventoryManager {
    bagSize = 20,
    equipSlots = { "helmet", "weapon", "armor", "boots" },
}
-- 填充物品
for i, item in ipairs(items) do
    invMgr:SetItem(i, item)
end
```

**步骤 3：创建 DragDropContext（核心）**

```lua
local dragContext = UI.DragDropContext {
    canDrop = function(dragItem, targetSlot)
        if targetSlot.slotCategory == "inventory" then return true end
        -- 装备格：检查类型匹配
        return dragItem.type == targetSlot.slotType
    end,
    onDragEnd = function(fromSlot, toSlot)
        invMgr:MoveItem(fromSlot.slotId, toSlot.slotId)
        UpdateAllSlots()  -- 刷新视图
    end,
}
```

**步骤 4：创建装备格**

```lua
UI.ItemSlot {
    slotId = "helmet",
    slotCategory = "equipment",
    slotType = "helmet",
    slotTypeIcon = "🪖",  -- 空时显示提示
    size = 72,
    dragContext = dragContext,
}
```

**步骤 5：创建背包格（5×4 网格）**

```lua
for row = 1, 4 do
    for col = 1, 5 do
        local idx = (row - 1) * 5 + col
        UI.ItemSlot {
            slotId = idx,
            slotCategory = "inventory",
            size = 56,
            dragContext = dragContext,
        }
    end
end
```

> **关键**：`dragContext` 必须加到 root 的 children 里，否则拖拽跟手效果不出来。

### 3.3 常见坑

| 坑 | 原因 | 解决 |
|----|------|------|
| 拖不动 | dragContext 没加到 root children | 补上 |
| 装备格不限类型 | canDrop 直接 return true | 加类型检查 |
| 拖完数据没变 | 只动了视图没更新数据 | onDragEnd 里调 `MoveItem()` + `UpdateAllSlots()` |

### 3.4 常见扩展

| 需求 | 提示词 |
|------|--------|
| 长按显示信息 | 「长按物品弹出 Tooltip 显示名称、稀有度、描述」 |
| 数量角标 | 「药水/材料右下角用 Badge 显示数量」 |
| 稀有度边框 | 「根据 rarity 加边框色：common 灰、rare 蓝、epic 紫、legendary 金」 |
| 筛选 | 「背包上方加 Chip 筛选按钮：全部/武器/防具/消耗品」 |
| 出售 | 「背包下方加"出售"区域，拖过去即卖，弹确认框」 |

---

## 四、三合一：状态管理

### 4.1 状态变量

```lua
local gameState = "menu"  -- "menu" | "playing" | "paused"
```

### 4.2 流程

```
主菜单 (menu)
  ├── "开始游戏" → 隐藏菜单，显示游戏 HUD → playing
  ├── "设置"     → 打开设置弹窗（不切状态）
  └── "退出"     → engine:Exit()

游戏中 (playing)
  └── 按 ESC → 弹出暂停菜单 → paused

暂停菜单 (paused)
  ├── "继续"     → 关闭弹窗 → playing
  ├── "设置"     → 打开设置弹窗
  ├── "背包"     → 打开背包界面
  └── "返回主菜单" → 显示主菜单 → menu
```

### 4.3 建议分步实现

1. 先分别做好三个页面，确认各自独立能跑
2. 再用状态变量串联
3. 避免一次性提出太多需求导致混乱

---

## 五、万能 UI 提示词模板

```
帮我做一个【页面类型】，【颜色风格】。
布局：【从上到下/从左到右描述每个区域】。
包含以下控件：
1.【控件1：类型 + 功能】
2.【控件2：类型 + 功能】
3. ...
交互：【点击/拖拽/切换时发生什么】。
```

> 描述越具体（颜色、尺寸、间距、交互），效果越好。
> "暗色、居中、圆角16、间距16" 比 "好看一点" 有用 100 倍。

---

*素材来源：TapTap 开发心得帖（糖心哥）*
*蒸馏日期：2026-05-10*

# NanoVG 地图调校面板三文件架构

| 字段 | 值 |
|------|-----|
| 这是什么 | NanoVG 2D 地图项目的嵌入式调校/编辑面板架构模式总结——覆盖三文件分离（数据/渲染/编辑器）、zone-local 归一化坐标、拖拽交互（带偏移防跳）、折叠分组列表、JSON 覆盖持久化、渲染分层、输入事件消费模式、分派表驱动渲染。可直接作为 prompt 喂给 AI 复刻 |
| 原作者 | 西米（MapCalibrator，纯 NanoVG 实现） |
| 推荐度 | L2（架构模式完整可复用，但 UI 较简陋需自行美化） |
| 适用场景 | NanoVG 2D 地图游戏需要运行时编辑/调校元素位置的场景（地图编辑器、关卡微调、场景摆放） |

---

## 核心架构：三文件分离

| 文件 | 职责 | 禁止事项 |
|------|------|---------|
| `MapData.lua` | 纯数据 + 坐标工具 + 持久化 | 不含任何绘制代码 |
| `MapRenderer.lua` | 只负责渲染，从 MapData 读取数据 | 不持有数据 |
| `MapCalibrator.lua` | 编辑器 UI 叠加层，修改 MapData 数据 | 不直接绘制游戏元素 |

**关键原则**：三者通过 MapData 这个"单一数据源"解耦。渲染器不持有数据，编辑器不直接绘制游戏元素。

---

## 数据表设计

### 统一使用 zone-local 归一化坐标

```lua
-- nx/ny 是相对 zone 的 0~1 归一化值，不是绝对像素
MapData.BUILDINGS = {
    { id = "唯一ID",         -- 持久化用，不可变
      name = "显示名",       -- UI 列表显示
      zone = "zoneName",     -- 所属区域名
      nx = 0.50, ny = 0.30,  -- zone 内归一化坐标
      drawScale = 1.0,       -- 绘制缩放
      buildingType = "xxx",  -- 类型分派键
    },
}

-- 不同类型元素结构同构，类型特有参数放 extra 表
MapData.LANDSCAPES = {
    { id = "唯一ID", name = "显示名", zone = "zoneName",
      nx = 0.30, ny = 0.65, drawScale = 1.0,
      landscapeType = "bamboo",
      extra = { count = 9 },  -- 类型特有参数，避免主表字段爆炸
    },
}
```

**设计要点**：
- `nx/ny` 归一化 → zone 整体移动/缩放不用改每个元素
- `extra` 表存放类型特有参数（竹子数量、花色、桥旋转角等）
- `id` 用中文可读字符串，兼顾调试和持久化

### 坐标转换工具函数

```lua
-- 归一化 → 绝对像素
function MapData.GetXxxPos(item)
    local z = MapData.ZONES[item.zone]
    return z.x + item.nx * z.w, z.y + item.ny * z.h
end

-- 屏幕点 → 地图坐标
function MapData.ScreenToMap(sx, sy, cam, scrW, scrH)
    return (sx - scrW * 0.5) / cam.zoom + cam.x,
           (sy - scrH * 0.5) / cam.zoom + cam.y
end

-- 命中检测（命中半径随缩放自适应）
function MapData.HitTestXxx(sx, sy, cam, scrW, scrH)
    local mx, my = MapData.ScreenToMap(sx, sy, cam, scrW, scrH)
    local hitR = 18 / cam.zoom
    for i, item in ipairs(MapData.XXX) do
        local ix, iy = MapData.GetXxxPos(item)
        local dx, dy = mx - ix, my - iy
        if dx*dx + dy*dy <= hitR*hitR then return i end
    end
    return nil
end
```

---

## JSON 覆盖持久化

**设计思路**：代码内保留默认值，JSON 只存用户修改的覆盖层。

**好处**：
- 代码更新默认值不会被旧存档覆盖
- 新增元素自动使用默认值
- 惰性索引 `_buildingIdIndex[id] → 数组下标` 加速查找

```lua
function MapData.SaveLayout()
    local data = { version = 2, buildings = {...}, landscapes = {...} }
    local file = File("map_layout.json", FILE_WRITE)
    file:WriteString(cjson.encode(data))
    file:Close()
end

function MapData.LoadLayout()
    -- 反序列化后通过 id 索引表快速查找并覆盖
end
```

---

## 编辑器状态设计

```lua
MapCalibrator.active = false           -- F1 切换开关
MapCalibrator.selectedType = nil       -- "building" | "landscape" | nil
MapCalibrator.selectedIdx = nil        -- 选中项在数组中的索引
MapCalibrator.dragging = false         -- 拖拽中
MapCalibrator.dragOffX = 0             -- 拖拽偏移 X
MapCalibrator.dragOffY = 0             -- 拖拽偏移 Y
MapCalibrator.listScrollY = 0          -- 列表滚动位置
MapCalibrator.collapsedZones = {}      -- zone 折叠状态 { [zoneName] = bool }
```

用 `selectedType + selectedIdx` 二元组标识选中项，通过 `getSelectedItem()` 统一获取数据，避免到处 if/else。

---

## 输入事件消费模式

```lua
-- main.lua 中的输入处理
if MapCalibrator.active then
    if MapCalibrator.HandleMouseDown(lx, ly, cam, w, h) then
        return  -- 消费了，不传给相机拖拽
    end
end
-- 未消费 → 正常相机拖拽
```

**返回规则**：

| 位置 | 命中 | 返回值 | 效果 |
|------|------|--------|------|
| UI 区域（工具栏/列表/面板） | 任何 | `true` | 总是消费 |
| 地图区域 | 命中元素 | `true` | 开始拖拽 |
| 地图区域 | 未命中 | `false` | 允许相机拖拽穿透 |

---

## 拖拽实现（带偏移防跳）

```lua
-- MouseDown 时：记录鼠标与元素的偏移
local itemX, itemY = GetPos(item)
local mouseMapX, mouseMapY = ScreenToMap(lx, ly, cam, w, h)
dragOffX = itemX - mouseMapX  -- 差值，不是 0
dragOffY = itemY - mouseMapY

-- MouseMove 时：应用偏移
local mx, my = ScreenToMap(lx, ly, cam, w, h)
mx = mx + dragOffX  -- 加回偏移，元素不会跳到鼠标位置
my = my + dragOffY

-- 反算回 zone-local 归一化坐标（带边界限制）
local newNx = math.max(0.02, math.min(0.98, (mx - z.x) / z.w))
local newNy = math.max(0.02, math.min(0.98, (my - z.y) / z.h))
```

**关键**：记录偏移 → 元素跟手移动，不会在点击瞬间跳到鼠标位置。

---

## 渲染分层

```lua
-- MapRenderer.render() 中：
nvgSave(vg)
-- ...相机变换...
    -- 游戏内容渲染...
    MapCalibrator.RenderHighlight(vg, cam)  -- ① 相机空间：虚线选框
nvgRestore(vg)
MapCalibrator.Render(vg, w, h, cam, fontSans) -- ② 屏幕空间：工具栏/列表/面板
```

| 层 | 空间 | 内容 |
|----|------|------|
| ① 高亮层 | 相机空间（受缩放/平移影响） | 选中元素的虚线选框 |
| ② UI 层 | 屏幕空间（固定位置） | 工具栏、列表、属性面板 |

---

## 折叠分组列表

```lua
for _, zoneName in ipairs(ZONE_ORDER) do
    -- 绘制 zone 标题（带 +/- 指示符 + 元素计数）
    -- 点击标题 → collapsedZones[zoneName] = not collapsedZones[zoneName]
    if not collapsed then
        -- 先渲染该 zone 的建筑（圆点标记 + 家族色）
        -- 再渲染该 zone 的景观（方块标记 + 绿色系）
    end
end
```

**重要**：命中检测逻辑必须与渲染逻辑完全同构（同样的遍历顺序和折叠跳过），否则点击位置与显示位置对不上。

---

## 数据驱动渲染（分派表模式）

用类型字符串 → 绘制函数的映射表，替代 if/elseif 链：

```lua
local LANDSCAPE_DRAW = {
    bamboo = function(vg, x, y, s, extra)
        drawBambooCluster(vg, x, y, s, extra and extra.count or 7)
    end,
    pineTree = function(vg, x, y, s) drawPineTree(vg, x, y, s) end,
    flowerTree = function(vg, x, y, s, extra)
        drawFlowerTree(vg, x, y, s, extra and extra.color)
    end,
}

-- 渲染时一行搞定
function drawLandscapeSprites(vg, zoneName)
    for _, ls in ipairs(MapData.LANDSCAPES) do
        if ls.zone == zoneName then
            local x, y = MapData.GetLandscapePos(ls)
            LANDSCAPE_DRAW[ls.landscapeType](vg, x, y, ls.drawScale, ls.extra)
        end
    end
end
```

---

## 一句话 Prompt 模板

> 请为我的 NanoVG 2D 地图项目添加一个嵌入式调校面板（F1 切换），支持：左侧按区域分组的元素列表（点区域名可折叠/展开）、多种元素类型（建筑+景观）用不同图标/颜色区分、在地图上拖拽调整位置（带偏移防跳）、滚轮调缩放、右侧属性面板显示坐标和缩放值带 +/- 按钮微调、关闭时自动 JSON 持久化、采用三文件架构（MapData/MapRenderer/MapCalibrator）、所有可编辑元素使用 zone-local 归一化坐标(nx/ny 0~1)、渲染层硬编码绘制改为分派表模式、编辑器 UI 在屏幕空间绘制、选中高亮在相机空间绘制、输入事件使用消费模式。

---

## 六大模式总结

| 模式 | 核心思想 |
|------|---------|
| 数据设计 | zone-local 归一化坐标 + extra 表扩展 |
| 坐标系统 | 归一化 ↔ 绝对像素 ↔ 屏幕坐标三级转换 |
| 拖拽交互 | 偏移防跳 + 归一化回写 + 边界限制 |
| 折叠列表 | 渲染与命中检测完全同构 |
| 持久化 | JSON 覆盖层 + 代码默认值，互不冲突 |
| 渲染分层 | 相机空间（高亮）+ 屏幕空间（UI），分派表替代 if/else 链 |

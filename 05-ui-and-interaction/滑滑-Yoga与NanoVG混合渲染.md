# Yoga + NanoVG 混合渲染指南

> 作者：滑滑 | 级别：L2（参考） | 蒸馏自 TapTap 论坛
>
> 适用场景：在 UrhoX UI 系统中使用 NanoVG 自定义绘制控件，实现标准控件无法达到的视觉效果。

---

## 概述

UrhoX UI 系统（`urhox-libs/UI`）基于 Yoga 布局 + NanoVG 渲染。当内置控件不满足需求时，可通过两种方式接入自定义 NanoVG 绘制：

| 方式 | 适用场景 | 复杂度 |
|------|---------|--------|
| **Widget 继承** | 完全自定义控件（新控件类） | 高 |
| **Panel Render 覆写** | 在 Panel 内自由绘制（保留布局能力） | 中 |

---

## 方式一：Widget 继承

创建完全自定义的控件类：

```lua
local Widget = require("urhox-libs/UI/Core/Widget")
local MyWidget = Widget:extend("MyWidget")

function MyWidget:init(props)
    Widget.init(self, props)
    -- 自定义初始化
end

function MyWidget:onRender(vg, x, y, w, h)
    -- vg: NanoVG context
    -- x, y: 控件左上角坐标（Yoga 计算结果）
    -- w, h: 控件尺寸（Yoga 计算结果）
    nvgBeginPath(vg)
    nvgRoundedRect(vg, x, y, w, h, 8)
    nvgFillColor(vg, nvgRGBA(255, 100, 50, 255))
    nvgFill(vg)
end

function MyWidget:onUpdate(dt)
    -- 每帧更新逻辑（动画等）
end
```

## 方式二：Panel Render 覆写

在标准 Panel 上挂载自定义渲染：

```lua
local panel = UI.Panel {
    width = 200, height = 100,
    render = function(self, vg, x, y, w, h)
        -- 自定义绘制内容
        nvgBeginPath(vg)
        nvgCircle(vg, x + w/2, y + h/2, math.min(w, h)/2 - 4)
        nvgFillColor(vg, nvgRGBA(0, 150, 255, 200))
        nvgFill(vg)
    end,
}
```

---

## 坐标系统

| 坐标 | 来源 | 说明 |
|------|------|------|
| `x, y` | Yoga 布局计算 | 控件左上角在屏幕上的绝对位置 |
| `w, h` | Yoga 布局计算 | 控件的逻辑尺寸 |
| NanoVG 原点 | 屏幕左上角 | (0,0) = 左上角 |

**关键**：`onRender` 收到的 x/y 已经是绝对坐标，直接用即可，不需要额外变换。

---

## NanoVG 绘制规范

### 颜色

```lua
nvgRGBA(r, g, b, a)          -- 0-255 范围
nvgRGBAf(r, g, b, a)         -- 0.0-1.0 范围
nvgHSLA(h, s, l, a)          -- h:0-360, s/l:0-255, a:0-255
```

### 渐变

```lua
-- 线性渐变
local paint = nvgLinearGradient(vg, x1, y1, x2, y2, colorStart, colorEnd)
nvgFillPaint(vg, paint)

-- 径向渐变
local paint = nvgRadialGradient(vg, cx, cy, innerR, outerR, colorInner, colorOuter)

-- 盒子渐变（圆角矩形阴影常用）
local paint = nvgBoxGradient(vg, x, y, w, h, radius, feather, colorInner, colorOuter)
```

### 路径

```lua
nvgBeginPath(vg)
nvgMoveTo(vg, x, y)
nvgLineTo(vg, x2, y2)
nvgBezierTo(vg, c1x, c1y, c2x, c2y, ex, ey)
nvgQuadTo(vg, cx, cy, ex, ey)
nvgArcTo(vg, x1, y1, x2, y2, radius)
nvgArc(vg, cx, cy, r, startAngle, endAngle, dir)  -- dir: NVG_CW/NVG_CCW
nvgClosePath(vg)

-- 快捷形状
nvgRect(vg, x, y, w, h)
nvgRoundedRect(vg, x, y, w, h, r)
nvgRoundedRectVarying(vg, x, y, w, h, rTL, rTR, rBR, rBL)
nvgCircle(vg, cx, cy, r)
nvgEllipse(vg, cx, cy, rx, ry)

-- 填充/描边
nvgFill(vg)
nvgStroke(vg)
nvgStrokeWidth(vg, width)
nvgStrokeColor(vg, color)
nvgFillColor(vg, color)
```

### 文本

```lua
-- 字体设置（nvgCreateFont 在 UI.Init 时已完成）
nvgFontFace(vg, "sans")
nvgFontSize(vg, 16)
nvgTextAlign(vg, NVG_ALIGN_CENTER | NVG_ALIGN_MIDDLE)
nvgFillColor(vg, nvgRGBA(255, 255, 255, 255))
nvgText(vg, x, y, "文本内容")
```

### 变换

```lua
nvgSave(vg)          -- 保存状态
nvgTranslate(vg, tx, ty)
nvgRotate(vg, angle) -- 弧度
nvgScale(vg, sx, sy)
nvgRestore(vg)       -- 恢复状态
```

### 裁剪

```lua
nvgScissor(vg, x, y, w, h)       -- 矩形裁剪
nvgIntersectScissor(vg, x, y, w, h)  -- 交集裁剪
nvgResetScissor(vg)
```

---

## Flexbox 布局规则（Yoga 默认值差异）

| 属性 | Yoga 默认 | CSS 默认 | 说明 |
|------|----------|---------|------|
| `flexDirection` | `column` | `row` | Yoga 默认纵向排列 |
| `flexShrink` | `0` | `1` | Yoga 默认不收缩 |
| `position` | `relative` | `static` | - |
| 盒模型 | `border-box` | `content-box` | padding 包含在 width 内 |

**常用布局属性**：
```lua
UI.Panel {
    flexDirection = "row",        -- "row" | "column" | "row-reverse" | "column-reverse"
    justifyContent = "center",    -- 主轴: "flex-start"|"center"|"flex-end"|"space-between"|"space-around"|"space-evenly"
    alignItems = "center",        -- 交叉轴: "flex-start"|"center"|"flex-end"|"stretch"|"baseline"
    flexWrap = "wrap",            -- "nowrap"|"wrap"|"wrap-reverse"
    gap = 8,                      -- 子元素间距
    padding = 16,                 -- 内边距（支持 paddingTop/Right/Bottom/Left）
    width = "100%",               -- 支持数字(px)或百分比字符串
    height = 200,
    flexGrow = 1,                 -- 分配剩余空间
    flexShrink = 1,               -- 允许收缩（默认不收缩！）
}
```

---

## 动画模式

### 模式一：Transition（CSS 风格自动过渡）

```lua
local btn = UI.Panel {
    width = 100, height = 40,
    backgroundColor = "#333",
    transition = { "backgroundColor", "transform", duration = 0.3, easing = "easeOut" },
    onHoverIn = function(self)
        self:setProps({ backgroundColor = "#555", transform = { scale = 1.05 } })
    end,
    onHoverOut = function(self)
        self:setProps({ backgroundColor = "#333", transform = { scale = 1.0 } })
    end,
}
```

### 模式二：手动 gameTime 驱动

```lua
function MyWidget:onUpdate(dt)
    self.elapsed = (self.elapsed or 0) + dt
    local alpha = math.abs(math.sin(self.elapsed * 2)) * 255
    self:setProps({ opacity = alpha / 255 })
end
```

### 模式三：关键帧动画

```lua
local widget = UI.Panel { ... }
widget:animate({
    keyframes = {
        [0]   = { opacity = 0, transform = { translateY = -20 } },
        [100] = { opacity = 1, transform = { translateY = 0 } },
    },
    duration = 0.5,
    easing = "easeOutBack",
})
```

---

## 图标/图片绘制

```lua
-- 在 onRender 中绘制图片
function MyWidget:onRender(vg, x, y, w, h)
    local imgId = nvgCreateImage(vg, "Textures/icon.png", 0)  -- 应缓存！
    local paint = nvgImagePattern(vg, x, y, w, h, 0, imgId, 1.0)
    nvgBeginPath(vg)
    nvgRoundedRect(vg, x, y, w, h, 4)
    nvgFillPaint(vg, paint)
    nvgFill(vg)
end
```

**注意**：`nvgCreateImage` 应在 `init` 中调用一次并缓存句柄，不要每帧调用（显存泄漏）。

---

## 主题颜色接入

```lua
local Theme = require("urhox-libs/UI/Core/Theme")

function MyWidget:onRender(vg, x, y, w, h)
    local colors = Theme.GetColors()
    nvgFillColor(vg, nvgRGBA(
        colors.primary.r, colors.primary.g, colors.primary.b, 255
    ))
end
```

---

## 层级顺序

UI 控件树按**深度优先**顺序渲染：
1. 父节点先渲染（背景）
2. 子节点后渲染（覆盖在父节点上方）
3. 同级节点按数组顺序（后面的在上面）

需要调整层级时使用 `zIndex` 属性。

---

## 常见错误

| 错误 | 原因 | 修复 |
|------|------|------|
| 自定义绘制不显示 | `onRender` 函数名拼错 / 忘记 `nvgBeginPath` | 检查函数名和路径调用 |
| 位置偏移 | 未使用传入的 x/y 参数 | 所有绘制基于 x/y 偏移 |
| 图片每帧创建 | `nvgCreateImage` 放在 render 中 | 移到 init 并缓存句柄 |
| 内容溢出 | 未设置 `nvgScissor` 裁剪 | 渲染前设置裁剪区域 |
| 文字不显示 | 未设置 `nvgFontFace` | 先设字体再绘文字 |
| 动画卡顿 | `setProps` 触发全量重布局 | 仅动画视觉属性（opacity/transform），避免改布局属性 |
| flexShrink 不生效 | Yoga 默认 flexShrink=0 | 显式设置 `flexShrink = 1` |

---

## 最佳实践

1. **布局交给 Yoga，绘制交给 NanoVG**：不要在 NanoVG 中手动计算位置
2. **缓存 NanoVG 资源**：字体、图片句柄只创建一次
3. **Save/Restore 配对**：变换操作前 `nvgSave`，完成后 `nvgRestore`
4. **动画优先用 transition**：仅复杂场景才用 `onUpdate` 手动驱动
5. **性能敏感区域用 `nvgScissor`**：裁剪掉不可见区域的绘制
6. **控件尺寸由 Yoga 决定**：onRender 的 w/h 参数是 Yoga 计算结果，不要硬编码尺寸

# UrhoX Yoga UI 库完整探测指南

> **作者**: 灰语 | **等级**: L2（参考） | **蒸馏日期**: 2026-05-27
>
> UrhoX `urhox-libs/UI` 系统的全面探测手册。覆盖架构、初始化、42控件+7高级组件、布局系统、视觉样式、动画、主题、事件、自定义素材/控件开发、游戏HUD、分辨率适配、能力边界与陷阱。

---

## 1. 架构总览

### 技术栈

```
用户代码 (Lua 5.4)
    ↓
UI 控件树 (Widget/Props/State)
    ↓
Yoga 布局引擎 (Facebook 出品，React Native 同款)
    ↓
NanoVG 矢量渲染 (OpenGL ES 加速)
    ↓
屏幕输出
```

| 层 | 技术 | 说明 |
|---|---|---|
| 布局 | Yoga | Flexbox，默认值与CSS不同！ |
| 渲染 | NanoVG | 矢量图形，硬件加速 |
| 脚本 | Lua 5.4 | 支持位运算 |
| 坐标 | 基准像素 | 逻辑坐标，由 scale 换算到物理像素 |

### 模块结构

```
urhox-libs/UI/
├── init.lua                    # 入口，暴露所有控件为 UI.XXX
├── Core/
│   ├── UI.lua                  # 主管理器（Init/SetRoot/Render/Update）
│   ├── Widget.lua              # 控件基类
│   ├── Theme.lua               # 主题系统
│   ├── Style.lua               # 样式→Yoga属性映射
│   ├── Input.lua               # 输入事件管理
│   ├── InputAdapter.lua        # 平台适配（鼠标/触摸统一化）
│   ├── PointerEvent.lua        # 统一指针事件类
│   ├── Gesture.lua             # 手势识别（tap/swipe/pan/pinch）
│   ├── GestureEvent.lua        # 手势事件类
│   ├── ImageCache.lua          # NanoVG 图片缓存管理
│   ├── Transition.lua          # CSS风格过渡/关键帧动画
│   └── UIInspector/            # 运行时调试检查器
├── Widgets/                    # 42个基础控件
├── Components/                 # 7个高级复合组件
├── GameHUD.lua                 # 游戏HUD封装
└── VirtualControls.lua         # 虚拟摇杆/按钮
```

### 与 Web/React Native 对比

| 特性 | UrhoX UI | Web CSS | React Native |
|---|---|---|---|
| 布局模型 | Yoga Flexbox | CSS Flexbox | Yoga Flexbox |
| flexDirection 默认 | **column** | row | column |
| flexShrink 默认 | **0** | 1 | 0 |
| 盒模型 | border-box | content-box | border-box |
| 渲染 | NanoVG | 浏览器 | Native |
| 动画 | JS风格 transition/keyframe | CSS animation | Animated API |

---

## 2. 初始化与生命周期

### 必须调用的三步

```lua
local UI = require("urhox-libs/UI")

-- 1. 初始化
UI.Init({
    fonts = {
        { family = "sans", weights = { normal = "Fonts/MiSans-Regular.ttf", bold = "Fonts/MiSans-Bold.ttf" } }
    },
    scale = UI.Scale.DEFAULT,   -- 必须使用默认缩放
    -- theme = customTheme,     -- 可选
    -- fontSizeMethod = "pixel",-- "pixel"(pt→px) 或 "char"(直接pt)
    -- autoEvents = true,       -- 自动订阅渲染/输入事件
})

-- 2. 构建控件树
local root = UI.Panel { width = "100%", height = "100%" }

-- 3. 挂载根控件（忘记=什么都不渲染）
UI.SetRoot(root)
```

### `UI.Init` 完整参数

| 参数 | 类型 | 默认 | 说明 |
|---|---|---|---|
| `fonts` | table[] | **必填** | 字体配置，含 family + weights |
| `scale` | number/function | 1 | 缩放系数，推荐 `UI.Scale.DEFAULT` |
| `theme` | table | Material | 自定义主题对象 |
| `fontSizeMethod` | string | "pixel" | 字号转换方式 |
| `autoEvents` | bool/table | true | 自动订阅事件 |

### 生命周期方法

```lua
UI.Init(config)                -- 初始化（Start()中）
UI.SetRoot(root, destroyOld)   -- 挂载根控件
UI.Shutdown()                  -- 清理（场景退出）
-- 手动模式（autoEvents=false时）：
UI.Update(dt)  / UI.Render()  / UI.Layout()
```

---

## 3. Yoga 布局系统完整参数

> **关键差异**：flexDirection 默认 `column`，flexShrink 默认 `0`（与CSS不同！）

### 3.1 尺寸

```lua
width = 200 / "50%" / "auto"
height = 100 / "100%" / "auto"
minWidth / maxWidth / minHeight / maxHeight
aspectRatio = 16/9   -- 设width后height自动算
```

### 3.2 Flex 布局

```lua
flexDirection = "row" / "column"(默认) / "row-reverse" / "column-reverse"
justifyContent = "flex-start" / "center" / "flex-end" / "space-between" / "space-around" / "space-evenly"
alignItems = "stretch"(默认) / "flex-start" / "center" / "flex-end" / "baseline"
alignSelf = "flex-end" / "center"   -- 单个控件覆盖父对齐

flexGrow = 1       -- 填充剩余空间
flexShrink = 1     -- 允许收缩（Yoga默认0！必须显式设）
flexBasis = 0      -- flex起始尺寸
flex = 1           -- 简写: grow=1, shrink=1, basis=0

flexWrap = "no-wrap"(默认) / "wrap" / "wrap-reverse"
```

### 3.3 间距

```lua
gap = 8 / rowGap = 8 / columnGap = 16

-- 外边距（支持number/"N%"/"auto"）
margin = 16 / marginTop/Bottom/Left/Right / marginHorizontal / marginVertical
margin = "auto"   -- 居中

-- 内边距（border-box）
padding = 16 / paddingTop/Bottom/Left/Right / paddingHorizontal / paddingVertical

-- CSS shorthand 数组
padding = { 10 }             -- 四边10
padding = { 10, 20 }        -- 上下10，左右20
padding = { 10, 20, 30, 40 }-- 上右下左
margin = { left = 16 }      -- 命名键
```

### 3.4 定位

```lua
position = "relative"(默认) / "absolute" / "fixed" / "sticky"
top / right / bottom / left
stickyOffset = 0   -- sticky模式距顶偏移

overflow = "visible"(默认) / "hidden"
```

### 3.5 布局辅助

```lua
UI.Row { gap = 8, children = {...} }     -- 水平
UI.Column { gap = 8, children = {...} }  -- 垂直
UI.Spacer()          -- flexGrow=1 的空白
UI.Box(100, 50)      -- 固定尺寸空盒
UI.ButtonGroup { ... }
```

---

## 4. 视觉样式系统完整参数

### 4.1 背景

```lua
backgroundColor = { 240, 240, 240, 255 } / "#F0F0F0"

-- 渐变
backgroundGradient = {
    type = "linear",  -- "linear" / "radial"
    direction = "to-bottom",  -- "to-bottom"/"to-right"/角度数字(0=up,90=right)
    from = { 59, 130, 246, 255 },
    to   = { 147, 51, 234, 255 },
}

-- 图片
backgroundImage = "Images/bg.png"
backgroundFit = "fill" / "contain" / "cover" / "sliced"
backgroundSlice = { top = 10, right = 10, bottom = 10, left = 10 }  -- 九宫格

-- 染色（乘法混合）
imageTint = { 115, 115, 115, 255 }

-- 模糊
backdropBlur = 10
```

### 4.2 边框

```lua
borderWidth = 1 / { 1, 2, 3, 4 } / { top = 2 }
borderColor = { 200, 200, 200, 255 }
borderRadius = 8 / { 8, 16, 8, 16 }  -- {TL, TR, BR, BL}
-- 每角独立: borderRadiusTopLeft / TopRight / BottomRight / BottomLeft
```

### 4.3 阴影

```lua
shadowBlur = 4 / shadowColor / shadowOffsetX / shadowOffsetY

-- CSS box-shadow（支持内外叠加）
boxShadow = {
    { x=0, y=2, blur=8, spread=0, color={0,0,0,40} },
    { x=0, y=1, blur=3, spread=0, color={0,0,0,20}, inset=true },
}
```

### 4.4 变换

```lua
scale = 1.5 / rotate = 45 / translateX = 10 / translateY = 20
transformOrigin = "center" / "top-left" / "bottom-right" / {x, y}
```

### 4.5 透明度与混合

```lua
opacity = 0.5
visibility = "hidden" / "visible"
blendMode = "normal" / "lighter" / "copy" / "xor" / ...
```

### 4.6 裁剪路径

```lua
clipPath = "circle" / { type="circle", radius=50 }
clipPath = "ellipse" / { type="ellipse", rx=80, ry=40 }
```

### 4.7 层级与事件穿透

```lua
zIndex = 10
pointerEvents = "auto"(默认) / "none" / "box-none" / "box-only"
```

---

## 5. 动画与过渡系统

### 5.1 属性过渡

```lua
transition = "all 0.3s easeOut"
transition = "opacity 0.2s easeInOut"
transition = "backgroundColor 0.8s easeInOut, scale 0.3s easeOutBack"
-- 表格式
transition = { properties = {"opacity","scale"}, duration = 0.3, easing = "easeOut" }
```

**可过渡属性**：opacity, scale, rotate, translateX/Y, borderRadius, borderWidth, shadowBlur/OffsetX/Y, backgroundColor, borderColor, shadowColor, fontColor, value(ProgressBar)

**触发**：`widget:SetStyle({ opacity = 0.5 })` 自动插值

### 5.2 缓动函数

| 类型 | 值 |
|---|---|
| 线性 | `linear` |
| 标准 | `easeIn`, `easeOut`, `easeInOut` |
| 三次方 | `easeInCubic`, `easeOutCubic`, `easeInOutCubic` |
| 指数 | `easeInExpo`, `easeOutExpo` |
| 回弹 | `easeInBack`, `easeOutBack`, `easeInOutBack` |
| 弹簧 | `spring` |

### 5.3 关键帧动画

```lua
widget:Animate({
    keyframes = {
        [0]   = { opacity = 0, translateY = 20 },
        [0.5] = { opacity = 1, translateY = 5 },
        [1]   = { opacity = 1, translateY = 0 },
    },
    duration = 0.5,
    easing = "easeOut",
    loop = true,           -- true=无限, 数字=循环次数
    direction = "normal",  -- "normal"/"reverse"/"alternate"
    fillMode = "none",     -- "none"/"forwards"/"backwards"/"both"
    onComplete = function() end,
})
widget:StopAnimation()
widget:HasActiveTransitions()
widget:GetRenderProp(propName)   -- 获取当前动画值
```

**fillMode**：none=结束回原值, forwards=保持最后帧, backwards=开始前用第一帧, both=两者

---

## 6. 全部 42 个控件速查

### 6.1 布局容器（6个）

| 控件 | 用途 | 关键参数 |
|---|---|---|
| Panel | 通用容器 | 所有布局+样式 |
| Label | 文本 | text, fontSize, fontColor, textAlign, whiteSpace, maxLines |
| Divider | 分隔线 | orientation, variant, thickness, label |
| SafeAreaView | 刘海适配 | 同Panel |
| ScrollView | 滚动容器 | scrollX/Y, bounces, scrollSnapType, showScrollbar |
| SimpleGrid | 等宽网格 | columns, gap, minColumnWidth（响应式） |

### 6.2 输入控件（8个）

| 控件 | 用途 | 关键参数 |
|---|---|---|
| Button | 按钮 | text, variant, onClick, disabled |
| TextField | 单行输入 | value, placeholder, password, onChange, onSubmit |
| Checkbox | 复选框 | checked, label, onChange |
| Toggle | 开关 | checked, onChange |
| Slider | 滑块 | value, min, max, step, onChange, onChangeEnd |
| Stepper | 数字加减 | value, min, max, step, onChange |
| Rating | 星级评分 | value, max, allowHalf, onChange |
| FileUpload | 文件上传 | accept, multiple, onSelect |

### 6.3 选择控件（7个）

| 控件 | 用途 | 关键参数 |
|---|---|---|
| Dropdown | 下拉选择 | options, value, placeholder, onChange |
| DatePicker | 日期 | value, format, onChange |
| TimePicker | 时间（滚轮） | hour, minute, second, use24Hour, onChange |
| ColorPicker | 颜色 | value, showAlpha, onChange |
| Calendar | 日历 | selectedDate, onSelect |
| Menu | 上下文菜单 | items（label/onClick/variant/divider） |
| Tree | 树形结构 | data（id/label/children），onSelect |

### 6.4 展示控件（10个）

| 控件 | 用途 | 关键参数 |
|---|---|---|
| Card | 卡片 | variant, elevation, hoverable, coverImage, onClick |
| Badge | 徽标 | content, variant, dot, pulse, max |
| Chip | 标签 | label, variant, color, deletable, selectable |
| Avatar | 头像 | src, name, size, shape, status |
| Alert | 警告框 | title, message, severity, closable |
| Tooltip | 悬停提示 | content, position, delay |
| Skeleton | 加载占位 | variant, animation, lines |
| RichText | 富文本 | text（支持 **bold** *italic*） |
| ProgressBar | 进度条 | value, variant, fillGradient, indeterminate |
| Spine | 骨骼动画（预览版） | src, animation, loop, width, height |

### 6.5 导航控件（3个）

| 控件 | 用途 | 关键参数 |
|---|---|---|
| Tabs | 标签页 | tabs, activeTab, variant, onChange |
| Breadcrumb | 面包屑 | items, separator |
| Pagination | 分页 | currentPage, totalPages, onChange |

### 6.6 容器控件（4个）

| 控件 | 用途 | 关键参数 |
|---|---|---|
| Accordion | 折叠面板 | items, variant, allowMultiple, onChange |
| Carousel | 轮播 | items, autoPlay, interval, showDots |
| Timeline | 时间线 | items（title/description/status） |
| Table | 数据表格 | columns, data, onRowClick |

另有 `UI.List`（简单列表）。

### 6.7 浮层控件（4个）

| 控件 | 用途 | 关键参数 |
|---|---|---|
| Modal | 模态对话框 | title, size, closeOnOverlay, onClose |
| Drawer | 侧边抽屉 | position(left/right/top/bottom), size |
| Popover | 浮动面板 | placement, trigger, content, showArrow |
| Toast | 临时通知 | `UI.Toast.Show(msg, opts)` |

---

## 7. 高级组件（7个）

### VirtualList — 万级数据列表

```lua
UI.VirtualList {
    data = hugeDataArray,     -- 10000+ 条
    itemHeight = 60,          -- 固定行高（必须）
    createItem = function() return UI.Panel { height = 60 } end,
    bindItem = function(widget, item, index) ... end,
    onItemClick = function(item, index) end,
}
```

### ChatWindow — 聊天界面

```lua
UI.ChatWindow {
    messages = { { sender="Alice", text="你好", time="10:00" } },
    onSend = function(self, text)
        self:AddMessage({ sender="Me", text=text, isSelf=true })
    end,
}
```

### DragDropContext + ItemSlot — 拖拽系统

```lua
local ctx = UI.DragDropContext {
    onDrop = function(item, targetSlot, sourceSlot) end,
}
UI.ItemSlot { item = itemData, context = ctx }
```

### InventoryManager / SkillTree

```lua
UI.InventoryManager { slots=20, items=tbl, columns=5, onItemUse=fn }
UI.SkillTree { skills=data, onSkillUnlock=fn }
```

---

## 8. 主题系统

### 默认主题（Material风格）

```lua
UI.Theme.defaultTheme = {
    colors = {
        primary={59,130,246,255}, secondary={100,116,139,255},
        success={34,197,94,255}, error={239,68,68,255},
        warning={245,158,11,255}, info={14,165,233,255},
        text={17,24,39,255}, textSecondary={107,114,128,255},
        background={249,250,251,255}, surface={255,255,255,255},
        border={229,231,235,255}, disabled={243,244,246,255},
    },
    spacing = { xs=4, sm=8, md=16, lg=24, xl=32, xxl=48 },
    radius = { none=0, sm=4, md=8, lg=12, xl=16 },
}
```

### Theme API

```lua
UI.Theme.Color("primary")           -- {r,g,b,a} 表
UI.Theme.NvgColor("primary")        -- NVGcolor
UI.Theme.Spacing("md")  / UI.Theme.Radius("md")
UI.Theme.FontSizeOf("body")         -- 11pt
-- 全部: display(24) headline(18) title(15) subtitle(14)
--       bodyLarge(12) body(11) bodySmall(10) small(9) caption(8) tiny(8)
UI.Theme.FontFace("sans", "bold")   -- "sans-bold"
UI.Theme.ComponentStyle("Button")   -- 组件默认样式
```

### 自定义主题

```lua
local myTheme = UI.Theme.ExtendTheme(UI.Theme.defaultTheme, {
    colors = { primary = {220,38,38,255} },
    radius = { md = 2 },
})
UI.Init({ fonts={...}, theme=myTheme, scale=UI.Scale.DEFAULT })
```

---

## 9. 事件系统

### 9.1 指针事件（鼠标+触摸统一）

```lua
UI.Panel {
    -- (event, widget) 签名
    onPointerEnter/Leave/Down/Up/Move/Cancel = function(event, widget) end,
    -- (widget, event) 签名（注意相反！）
    onClick = function(widget, event) end,
}
```

**PointerEvent 属性**：type, x, y, pointerId, pointerType("mouse"/"touch"), button(0左/1中/2右), buttons, isPrimary, pressure

**方法**：`StopPropagation()`, `PreventDefault()`, `IsTouch()`, `IsMouse()`, `IsPrimaryButton()`

### 9.2 手势事件

```lua
onTap / onDoubleTap / onLongPressStart / onLongPressEnd
onSwipe / onSwipeLeft / onSwipeRight / onSwipeUp / onSwipeDown
onPanStart / onPanMove / onPanEnd
onPinchStart / onPinchMove / onPinchEnd
```

**GestureEvent 属性**：type, x, y, target, direction, velocity, deltaX/Y, totalDeltaX/Y, scale

### 9.3 命令式事件

```lua
widget:OnEvent("pointerenter", function(event, w) end)
widget:OffEvent("click", handler)  -- 移除
```

### 9.4 游戏输入协调

```lua
if UI.IsPointerOverUI() then return end  -- 防误触

-- 全局输入监听
local id = UI.Input.On("PointerDown", function(event) end)
UI.Input.Off("PointerDown", id)
```

---

## 10. 深度自定义：使用自己的素材

### 10.1 图片路径规则

`assets/` 是资源根，引用时从下一级开始：
```lua
backgroundImage = "Textures/button.png"  -- ✅ assets/Textures/button.png
```

### 10.2 四种显示模式

| backgroundFit | 效果 | 场景 |
|---|---|---|
| "fill" | 拉伸（可能变形） | 纯色纹理 |
| "contain" | 保比例缩小看全 | ICON |
| "cover" | 保比例裁剪填满 | 头像/封面 |
| **"sliced"** | **九宫格**（不变形） | **游戏按钮/面板** |

### 10.3 九宫格（Nine-Slice）

```lua
UI.Panel {
    backgroundImage = "Textures/btn_gold_frame.png",
    backgroundFit = "sliced",
    backgroundSlice = { 20, 20, 20, 20 },  -- {上, 右, 下, 左} 像素
}
```

**推荐图片尺寸**：按钮 128x64（切割20~30px），面板 128x128（切割24~32px）

### 10.4 imageTint（乘法混合）

同一张灰度模板图通过 tint 生成多色按钮：
```lua
imageTint = { 255, 200, 60, 255 }   -- 金色
imageTint = { 80, 160, 255, 255 }   -- 蓝色
imageTint = { 120, 120, 120, 200 }  -- 禁用态
```

### 10.5 自定义字体

```lua
UI.Init({ fonts = {
    { family = "sans", weights = { normal = "Fonts/MiSans-Regular.ttf" } },
    { family = "game", weights = { normal = "Fonts/GamePixel.ttf" } },
} })
UI.Label { fontFamily = "game", fontWeight = "bold", fontSize = 32 }
```

### 10.6 图标+文字混排

```lua
UI.Panel {
    flexDirection = "row", alignItems = "center", gap = 8,
    children = {
        UI.Panel { width=24, height=24, backgroundImage="Textures/icon_coin.png", backgroundFit="contain" },
        UI.Label { text = "999", fontColor={255,220,50,255} },
    }
}
```

---

## 11. 制作游戏级按钮：6步演进

### Step 1: 默认按钮
```lua
UI.Button { text = "开始", variant = "primary", onClick = fn }
```

### Step 2: 颜色定制
```lua
UI.Button {
    text = "开始", width = 200, height = 56,
    backgroundColor = {180,120,30,255},
    hoverBackgroundColor = {210,155,60,255},
    pressedBackgroundColor = {140,90,15,255},
    textColor = {255,240,180,255},
    borderRadius = 4, borderWidth = 2, borderColor = {255,210,100,255},
    transition = "backgroundColor 0.15s easeOut",
}
```

### Step 3: 九宫格素材图
```lua
UI.Button {
    text = "开始", width = 220, height = 64,
    backgroundImage = "Textures/btn_gold_normal.png",
    backgroundFit = "sliced", backgroundSlice = {20,20,20,20},
    hoverBackgroundImage = "Textures/btn_gold_hover.png",
    pressedBackgroundImage = "Textures/btn_gold_press.png",
    disabledBackgroundImage = "Textures/btn_gold_disabled.png",
}
```

### Step 4: glowShadow 光晕
```lua
UI.Button {
    ...,
    glowShadow = {
        alpha = { default=80, hover=160 },
        blur  = { default=10, hover=18 },
        pressed = { color={255,80,40,180}, blur=6 },
    },
}
```

### Step 5: 按压缩放动画
```lua
UI.Button {
    ...,
    transition = { properties="scale,opacity", duration=0.1, easing="easeOut" },
    onPointerDown = function(e, self) self:SetStyle({scale=0.95}) end,
    onPointerUp   = function(e, self) self:SetStyle({scale=1.0}) end,
}
```

### Step 6: 完全自定义渲染（继承Widget）

```lua
local GameButton = UI.Widget:Extend("GameButton")

function GameButton:Init(props)
    props.width = props.width or 160
    props.height = props.height or 60
    self.state = { hovered=false, pressed=false, pressAnim=0 }
    UI.Widget.Init(self, props)
    self.props.backgroundImage = props.image or "Textures/btn_game.png"
end

function GameButton:Render(nvg)
    local l = self:GetAbsoluteLayout()
    -- 自定义NanoVG绘制（缩放、九宫格、文字描边等）
end

function GameButton:Update(dt)
    local target = self.state.pressed and 1 or 0
    self.state.pressAnim = self.state.pressAnim + (target - self.state.pressAnim) * (1 - math.exp(-dt*20))
end

function GameButton:OnPointerEnter() self.state.hovered = true end
function GameButton:OnPointerLeave() self.state.hovered = false; self.state.pressed = false end
function GameButton:OnPointerDown(e) if e:IsPrimaryAction() then self.state.pressed = true end end
function GameButton:OnPointerUp(e) if e:IsPrimaryAction() then self.state.pressed = false end end
function GameButton:OnClick(e) if self.props.onClick then self.props.onClick(self, e) end end
function GameButton:IsStateful() return true end

UI.GameButton = GameButton
```

### 按钮设计规范

| 要点 | 标准 |
|---|---|
| 最小触控区域 | 48x48逻辑像素 |
| 按下反馈时间 | 80~120ms |
| 悬停亮度增加 | +10%~15% |
| 按下缩放 | 95%~97% |
| 禁用态透明度 | 40%~50% |
| 文字对比度 | ≥ 4.5:1 |

---

## 12. 自定义控件开发

### Widget 基类可重写方法

```lua
MyWidget:Init(props)            -- 初始化
MyWidget:Render(nvg)            -- 渲染
MyWidget:Update(dt)             -- 每帧更新
MyWidget:OnClick/OnPointerDown/Up/Move/Enter/Leave(event)
MyWidget:OnWheel(dx, dy) / OnKeyDown(key) / OnTextInput(text)
MyWidget:OnFocus() / OnBlur() / OnDestroy()
```

### Widget 基类工具方法

```lua
widget:GetLayout() / :GetAbsoluteLayout()    -- {x,y,w,h}
widget:RenderFullBackground(nvg)             -- 渲染背景+边框+阴影
widget:AddChild(child) / :RemoveChild(child) / :ClearChildren()
widget:FindById("id")                        -- 递归查找
widget:SetStyle({ ... })                     -- 样式更新（触发布局重算）
```

---

## 13. 游戏专用 UI（GameHUD & VirtualControls）

### GameHUD

```lua
require "urhox-libs.UI.GameHUD"
GameHUD.Initialize()
GameHUD.SetControls(character_.controls)

-- 按需创建：
GameHUD.Create()                              -- 仅摇杆
GameHUD.Create({ enableJump=true })           -- +跳跃
GameHUD.Create({ enableJump=true, enableRun=true })  -- +跑步
GameHUD.Create({ enableJump=true, enableRun=true, enableShooter=true,
    onShoot=fn, onReload=fn })                -- TPS射击
GameHUD.EnableTouchLook({ camera = cameraNode })  -- 触摸视角
```

**摇杆输入读取**：
```lua
local hud = GameHUD.GetHUD()
if hud and hud.joystick then
    moveDir.x = hud.joystick.x   -- 左负右正
    moveDir.z = -hud.joystick.y  -- 屏幕Y反转→3D Z
end
```

### VirtualControls（底层）

```lua
require "urhox-libs.UI.VirtualControls"
local joystick = VirtualControls.CreateJoystick({ keyBinding="WASD", deadZone=0.15 })
local jumpBtn = VirtualControls.CreateButton({ label="跳", keyBinding=KEY_SPACE, cooldown=0.5 })
VirtualControls.SetControls(character.controls)
```

---

## 14. 分辨率适配

| 预设 | 场景 |
|---|---|
| `UI.Scale.DEFAULT` | **绝大多数项目**（DPR+小屏密度自适应） |
| `UI.Scale.DPR` | 精确CSS像素对齐 |
| `UI.Scale.DESIGN_RESOLUTION(w,h)` | 有明确设计稿 |

```lua
-- 自定义缩放
UI.Init({ scale = function()
    local dpr = graphics:GetDPR()
    local logW = graphics.width / dpr
    return dpr * math.min(1.0, logW / 375)
end })
```

---

## 15. 能力边界

### 开箱即用
42控件, Material主题, Flexbox, 鼠标/触摸/键盘统一, transition动画, 浮层管理

### 可通过参数配置
任意颜色/渐变, 独立圆角/边框, boxShadow, 九宫格图片, 变换, 过渡/关键帧动画

### 自定义控件层
继承Widget完全控制NanoVG渲染, 自定义事件/动画

### 当前限制

| 限制 | 绕过 |
|---|---|
| 无CSS Grid | SimpleGrid + Panel嵌套 |
| 无真高斯模糊 | backdropBlur近似 |
| 无SVG | NanoVG路径绘制 |
| cursor待修复 | 暂无法改鼠标样式 |
| Spine预览版 | API可能变更 |

---

## 16. 常见陷阱与解法

| # | 症状 | 解法 |
|---|---|---|
| 1 | 什么都不渲染 | 忘了 `UI.SetRoot(root)` |
| 2 | 子元素溢出 | flexShrink默认0，显式设 `flexShrink=1` |
| 3 | ScrollView不滚动 | 同时设 `flexGrow=1` **和** `flexBasis=0` |
| 4 | ScrollView高度0 | 父用 `height` 不要用 `maxHeight` |
| 5 | 百分比尺寸无效 | 父容器必须有明确宽度 |
| 6 | 方向错误 | flexDirection默认column，水平需写"row" |
| 7 | 事件参数搞反 | onClick=(widget,event), onPointerXxx=(event,widget) |
| 8 | 浮层销毁崩溃 | 先Close()再Destroy() |
| 9 | padding外溢 | border-box：width包含padding |

---

## 17. 最佳实践

### 布局
- 用 `gap` 而非每个子元素 margin
- 用 `flexGrow` 填充剩余空间，避免硬编码
- 移动端包裹 `SafeAreaView`

### 性能
- 100+项列表用 VirtualList
- 过渡优先 opacity/scale/translate（不触发布局重算）
- 减少深层嵌套

### 游戏UI
- HUD 用 `position="fixed"` 分层
- 防误触：`UI.IsPointerOverUI()`
- 背包格子用 SimpleGrid
- 伤害飘字用 Animate + fillMode="forwards" + onComplete销毁

### 调试
- Panel 加半透明背景色可视化布局
- `widget:GetAbsoluteLayout()` 打印位置
- ScrollView 不滚动 → 先看 l.h 是否为0

---

## 附录：控件完整索引

| # | 控件 | 分类 | 核心参数 |
|---|---|---|---|
| 1-6 | Panel/Label/Divider/SafeAreaView/ScrollView/SimpleGrid | 布局 | — |
| 7-14 | Button/TextField/Checkbox/Toggle/Slider/Stepper/Rating/FileUpload | 输入 | — |
| 15-21 | Dropdown/DatePicker/TimePicker/ColorPicker/Calendar/Menu/Tree | 选择 | — |
| 22-31 | Card/Badge/Chip/Avatar/Alert/Tooltip/Skeleton/RichText/ProgressBar/Spine | 展示 | — |
| 32-34 | Tabs/Breadcrumb/Pagination | 导航 | — |
| 35-39 | Accordion/Carousel/Timeline/Table/List | 容器/数据 | — |
| 40-43 | Modal/Drawer/Popover/Toast | 浮层 | — |

**高级组件**：VirtualList, ChatWindow, DragDropContext, ItemSlot, ItemTooltip, InventoryManager, SkillTree

---

*蒸馏自: UrhoX Yoga UI 库完整探测指南 v1.0 | 基于 UrhoX UI Library v1.2.0*

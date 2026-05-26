# UI 设计概念图生成与蒸馏工作流

> **作者**: 滑滑 | **等级**: L2（参考/学习级） | **分类**: 10-AI工作流与Skill
> **编号**: #131 | **日期**: 2026-05-12

---

## 一句话总结

用 AI 生图从「视觉风格 + 功能描述 + 画幅比例」出发生成 UI 概念图，用户确认后蒸馏为 Lua 声明式布局文件 + 线框图 Markdown，实现"设计→代码"的半自动化管线。

---

## 适用场景

| 场景 | 说明 |
|------|------|
| 设计新 UI 页面 | 用户说"设计一个XX页面"，AI 生成概念图后蒸馏为布局数据 |
| UI 设计稿转结构化数据 | 已有视觉参考 → 提取元素坐标 → 输出 Lua 布局文件 |
| 线框图文档化 | 概念图 → ASCII 线框 + 元素清单 + 层级树 |

---

## 工作流（四阶段）

### Phase 1: 收集输入

三项**必填**参数（缺哪项问哪项，不要猜）：

| 参数 | 说明 | 示例 |
|------|------|------|
| `visual_style` | 视觉风格 | "赛博朋克霓虹"、"卡通扁平"、"暗黑写实" |
| `ui_function` | UI 功能/页面名称 | "背包页面"、"战斗准备界面"、"商店" |
| `aspect_ratio` | 画幅比例 | "9:16"（竖屏）、"16:9"（横屏） |

可选参数（用户未提供时用默认值）：

| 参数 | 默认值 |
|------|--------|
| `orientation` | 由 aspect_ratio 推断 |
| `canvas_size` | 竖屏 1080×2400，横屏 2400×1080 |
| `extra_notes` | 无 |

### Phase 2: 生成概念图

1. 构造 prompt：视觉风格 + UI 功能元素 + "UI design mockup, game interface"
2. 调用 `generate_image`（或有参考图时 `edit_image`），`thinking_level: "high"`
3. **必须等用户确认**：满意 → Phase 3，不满意 → 修改后重新生成

> **关键规则**：绝不跳过用户确认步骤。

### Phase 3: 蒸馏为 Lua 布局

1. 读取概念图，识别所有可见 UI 元素
2. 估算每个元素的相对位置（rel_x/rel_y: 0.0~1.0）和相对尺寸
3. 映射到设计分辨率画布绝对坐标：`x = round(rel_x * canvas_w)`
4. 填充 Lua 布局模板

### Phase 4: 输出文件

输出到 `docs/data/ui/`：
- **Lua 布局文件**: `{PageName}Layout.lua`（PascalCase）
- **线框图 Markdown**: `{PageName}Layout_wireframe.md`

---

## 蒸馏规则

| 规则 | 说明 |
|------|------|
| 坐标系 | 设计分辨率画布绝对像素值（默认 1080×2400） |
| 元素命名 | camelCase 语义命名（`title`, `charStatus`, `gridPanel`） |
| 字体/图标 | 引用 UIConsts 常量（`FONT.xl`, `ICON.sm`），不写死数字 |
| 组件标注 | `component = "Text"/"FrostedPanel"/"GradientButton"/...` |
| 颜色 | **不写在布局中**，由 Theme 统一管理 |
| 嵌套 | 容器内子元素放入 `children = { ... }` |
| children 坐标 | 画布绝对坐标，**不是**相对父元素 |

---

## UIConsts 常量速查

```lua
FONT = { xxs=22, xs=26, sm=31, base=36, lg=43, xl=58 }
ICON = { xs=48, sm=72, base=100, lg=128, xl=192 }
DESIGN_W = 1080
DESIGN_H = 2400
```

---

## 组件类型速查

| component | 说明 | 典型属性 |
|-----------|------|---------|
| `"Text"` | 文本标签 | x, y, fontSize, align, text |
| `"FrostedPanel"` | 毛玻璃面板 | x, y, w, h, cornerRadius, padding |
| `"GradientButton"` | 渐变按钮 | x, y, w, h, fontSize, cornerRadius, text |
| `"ItemSlot"` | 物品槽位 | x, y, size |
| `"ProgressBar"` | 进度条 | x, y, w, h |
| `"Modal"` | 弹窗容器 | x, y, w, h, cornerRadius |
| （无 component） | 自定义绘制 | 仅 x, y, w, h 等定位属性 |

---

## Lua 布局文件骨架

```lua
local U = require("client.v1.layouts.UIConsts")
local FONT = U.FONT
local ICON = U.ICON

return {
    designSize = { w = U.DESIGN_W, h = U.DESIGN_H },

    elements = {
        pageTitle = {
            component = "Text",
            x = 540, y = 60,
            fontSize = FONT.xl,
            align = "center",
            text = "页面标题",
        },

        mainPanel = {
            component = "FrostedPanel",
            x = 60, y = 300,
            w = 960, h = 400,
            cornerRadius = 24,
            padding = 30,

            children = {
                label = {
                    component = "Text",
                    x = 90, y = 330,         -- 画布绝对坐标
                    fontSize = FONT.sm,
                    text = "子标签",
                },
            },
        },

        actionBtn = {
            component = "GradientButton",
            x = 140, y = 2050,
            w = 800, h = 130,
            fontSize = FONT.lg,
            cornerRadius = 65,
            text = "确认",
        },
    },
}
```

---

## 线框图 Markdown 骨架

线框图包含四部分：

1. **ASCII 布局图** — 用文本框示意元素分布和层级
2. **元素清单表格** — ID / 组件 / 位置 / 尺寸 / 说明
3. **层级树** — 树状结构展示父子关系
4. **交互备注** — 点击、滑动、动画等行为说明

---

## 注意事项

- 概念图是 AI 生成的，坐标为**估算值**（±10~20px），用户可在 Lua 文件中精调
- 同一层级的元素按从上到下、从左到右排序
- 若用户提供了参考图，在 `generate_image`/`edit_image` 时传入 `reference_images`
- Lua 文件保存到 `docs/data/ui/`，后续通过 hardlink 链接到 `scripts/client/v1/layouts/`

---

## 同类对比

| 对比项 | 本文档（UI设计概念图生成） | UI三件套教程（糖心哥） | ReactiveUI（滑滑） |
|--------|--------------------------|----------------------|-------------------|
| 侧重点 | AI 生图 → 蒸馏为布局数据 | UI 组件使用教程 | 响应式 UI 框架 |
| 产出物 | Lua 布局文件 + 线框图 | 可运行的 UI 代码 | 可运行的 UI 代码 |
| 适用阶段 | 设计阶段（概念→结构） | 开发阶段（编码） | 开发阶段（编码） |
| 依赖工具 | AI 图片生成 + 视觉分析 | urhox-libs/UI | urhox-libs/UI |

**建议阅读顺序**：本文档（设计阶段出布局） → ReactiveUI（开发阶段实现） → UI三件套（组件细节）

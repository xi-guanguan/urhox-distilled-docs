# 移动端 UI 设计规范

> **这是什么**: 基于 UrhoX UI 库的移动端竖屏游戏 UI 设计规范，覆盖分辨率适配（DESIGN_RESOLUTION 390×844）、尺寸标准、安全区域、布局体系和色彩主题。
>
> **原作者**: 一棵草
>
> **推荐度**: L2（项目专属规范，基于"去修仙吧崽崽"竖屏 UI 游戏定制，通用原则可借鉴）
>
> **适用场景**: 竖屏手机 UI 驱动型游戏（信息流/背包/图鉴），使用 UI.Scale.DESIGN_RESOLUTION 模式

---

## 核心选择: 固定设计分辨率 390×844

- 对应 iPhone 14 逻辑尺寸，当前最主流竖屏比例
- 使用 `UI.Scale.DESIGN_RESOLUTION(390, 844)` — SHOW_ALL 策略
- 内容不裁切，比例不匹配时出现纯色边条

```lua
UI.Init({
    fonts = { { family = "sans", weights = { normal = "Fonts/MiSans-Regular.ttf" } } },
    scale = UI.Scale.DESIGN_RESOLUTION(390, 844),
})

local root = UI.Panel {
    width = "100%", height = "100%",
    backgroundColor = { 30, 30, 40, 255 },  -- 边条填充色
    justifyContent = "center", alignItems = "center",
    children = {
        UI.SafeAreaView {
            width = 390, height = 844,
            children = { --[[ 所有游戏 UI ]] }
        }
    }
}
UI.SetRoot(root)
```

## 尺寸标准

**最小触摸目标**:

| 元素 | 最小 bp | 推荐 bp |
|------|:---:|:---:|
| 按钮 | 44×44 | 48×48 |
| 图标按钮 | 40×40 | 44×44 |
| 列表项 | 高44 | 高48-56 |

**字号标准**:

| 语义 | 字号 bp | 用途 |
|------|:---:|------|
| display | 24 | 大标题 |
| headline | 18 | 页面标题 |
| title | 15 | 区块标题 |
| **body** | **11** | **默认正文（不应低于此值）** |
| caption | 8 | 图注（最小可用） |

**间距体系**: xs=4 / sm=8 / md=16 / lg=24 / xl=32 / xxl=48

## Yoga Flexbox 注意点

| 属性 | CSS 默认 | Yoga 默认 | 注意 |
|------|:---:|:---:|------|
| flexDirection | row | **column** | 默认纵排 |
| flexShrink | 1 | **0** | 子元素默认不收缩，可能溢出 |
| Box Model | content-box | **border-box** | padding 含在 width 内 |

**ScrollView 必须**: `flexGrow=1, flexBasis=0, flexShrink=1`，否则内容不滚动。

## 安全区域

- 必须用 `SafeAreaView` 包裹内容，避免刘海/挖孔/底部手势条遮挡
- 关键 UI 在安全区域内，背景可延伸到安全区域外
- `UI.GetSafeAreaInsets()` 获取四方向安全距离

## 5 Tab 典型布局

```lua
UI.SafeAreaView {
    width = 390, height = 844,
    children = {
        UI.Panel { flexGrow=1, flexShrink=1, flexBasis=0,
            children = { --[[ 当前Tab页内容 ]] }
        },
        UI.Panel { width="100%", height=56,
            flexDirection="row", justifyContent="space-around", alignItems="center",
            children = { --[[ 底部Tab栏 ]] }
        },
    }
}
```

## 适配检查清单

- [ ] `DESIGN_RESOLUTION(390, 844)` 初始化
- [ ] 根容器设 `backgroundColor` 作边条色
- [ ] 内容包裹在 `SafeAreaView` 中
- [ ] 可点击元素 ≥ 44×44 bp
- [ ] 正文字号 ≥ 11bp
- [ ] ScrollView 设了 `flexShrink=1` + `flexBasis=0`
- [ ] 测试多种宽高比: 16:9 / 18:9 / 19.5:9 / 4:3(iPad)

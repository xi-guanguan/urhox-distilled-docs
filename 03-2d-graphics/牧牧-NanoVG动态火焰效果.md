# NanoVG 动态火焰效果 — 径向渐变叠加法

> **这是什么**: 用 NanoVG 径向渐变圆叠加实现动态火焰，无纹理/无内存分配
> **原作者**: 牧牧
> **推荐度**: ★★★★★ 精华帖，完整实现 + 原理拆解 + 调参指南
> **适用场景**: 火炉、篝火、蜡烛、技能特效等 2D 火焰效果

---

## 函数签名

```lua
--- 在指定区域绘制动态火焰
--- @param vg    NanoVG context
--- @param cx    火焰中心 x
--- @param cy    火焰中心 y
--- @param w     区域宽度（用于计算火焰尺寸比例）
--- @param h     区域高度
--- @param t     当前时间（秒，持续递增，驱动动画）
local function drawFireEffect(vg, cx, cy, w, h, t)
```

---

## 第一层：全局闪烁因子

3 个不同频率的 sin 波叠加，避免单一频率的机械感：

```lua
local R = math.max(w, h) * 0.6  -- 基准半径
local f1 = math.sin(t * 3.2)
local f2 = math.sin(t * 1.7 + 0.5)
local f3 = math.sin(t * 5.1 + 1.2)
local flicker = 0.65 + 0.22 * f1 * f2 + 0.13 * f3
-- flicker 在 ~0.3 到 ~1.0 之间波动
```

**关键**：`f1 * f2` 的乘积产生拍频效果，比简单相加更像真实火焰闪烁。

---

## 第二层：环境热辐射光晕

火焰周围柔和的暖色光晕，用大椭圆径向渐变：

```lua
local envP = nvgRadialGradient(vg,
    cx, cy, R * 0.05, R * 2.0,
    nvgRGBAf(1.0, 0.4, 0.08, 0.18 * flicker),  -- 中心：暖橙，半透明
    nvgRGBAf(0.6, 0.1, 0.0, 0.0)               -- 边缘：全透明
)
nvgBeginPath(vg)
nvgEllipse(vg, cx, cy, R * 2.0, R * 2.5)  -- 竖向略长
nvgFillPaint(vg, envP)
nvgFill(vg)
```

再加一个小范围的热芯光晕，让火焰根部更通透：

```lua
local coreGlowP = nvgRadialGradient(vg,
    cx, cy + R * 0.2, R * 0.02, R * 0.7,
    nvgRGBAf(1.0, 0.7, 0.2, 0.3 * flicker),
    nvgRGBAf(1.0, 0.3, 0.0, 0.0)
)
nvgBeginPath(vg)
nvgCircle(vg, cx, cy + R * 0.2, R * 0.7)
nvgFillPaint(vg, coreGlowP)
nvgFill(vg)
```

---

## 第三层：火焰主体（核心）

140 个径向渐变圆的叠加。

### 3.1 伪随机分布：黄金比例 Hash

不用 `math.random()`（每帧结果不同会抖），用黄金比例 Hash 为每个粒子生成固定参数：

```lua
local h1 = (i * 0.6180339887) % 1.0          -- 第一组随机值
local h2 = ((i * 7 + 13) * 0.6180339887) % 1.0  -- 第二组（不同种子）
local h3 = ((i * 17 + 31) * 0.6180339887) % 1.0 -- 第三组
```

`0.6180339887` 是黄金比例的小数部分 `(√5-1)/2`。乘以不同整数系数再取模，得到多组均匀分布但互不相关的伪随机序列。

### 3.2 生命周期动画

每个粒子有 `p` 值（0=底部刚生成，1=顶部消亡），时间驱动循环：

```lua
local speed  = 0.4 + h1 * 0.7    -- 每个粒子速度不同
local period = 2.0 + h2 * 2.0    -- 每个粒子周期不同
local p = ((t * speed + h3 * period) % period) / period
```

`speed` 和 `period` 都带随机变化，140 个粒子运动周期互不相同，避免"齐步走"。

### 3.3 火焰轮廓：底宽顶窄

指数衰减的包络线控制外形：

```lua
-- y 位置：从底部线性上升
local py = baseY - p * FIRE_H
-- x 方向允许范围随高度衰减（指数 1.2 → 略快于线性）
local envelopeW = FIRE_HALF_W * (1.0 - p) ^ 1.2
-- 在包络线内随机偏移 + 时间驱动的摆动
local xOff = (h1 - 0.5) * 2.0 * envelopeW
local sway  = math.sin(t * (2.5 + h2 * 2.5) + i * 0.7) * envelopeW * 0.4
local sway2 = math.sin(t * (4.0 + h1 * 3.0) + i * 1.3) * envelopeW * 0.15
local px = cx + xOff + sway + sway2
```

双层 sway（主摆动 + 高频微颤）让晃动更有层次。

### 3.4 粒子大小

底部大（叠加后产生高亮核心），顶部小（火星飘散感）：

```lua
local sizeBase = R * (0.22 + h2 * 0.16)  -- 基础大小带随机
local size = sizeBase * (1.0 - p * 0.65)  -- 随高度缩小
    * (0.85 + 0.15 * math.sin(t * 5.0 + i))  -- 微弱大小脉动
```

### 3.5 五段色带

火焰颜色随高度（`p` 值）分 5 段渐变：

```lua
if p < 0.12 then
    -- 核心：近白色      白(255,247,204)
    r, g, b = 1.0, 0.97, 0.8
    a = 0.35 * flicker
elseif p < 0.3 then
    -- 内焰：亮黄        黄(255,217,77)
    r, g, b = 1.0, 0.85, 0.3
    a = 0.30 * flicker
elseif p < 0.55 then
    -- 中焰：橙色        橙(255,140,15)
    r, g, b = 1.0, 0.55, 0.06
    a = 0.25 * flicker
elseif p < 0.78 then
    -- 外焰：暗橙→红     红橙(242,77,8)
    r, g, b = 0.95, 0.3, 0.03
    a = 0.18 * flicker
else
    -- 烟尾：暗红         暗红(179,31,3)
    r, g, b = 0.7, 0.12, 0.01
    a = 0.10 * (1.0 - (p - 0.78) / 0.22) * flicker
end
```

每段 alpha 不同 —— 核心最高(0.35)叠加后趋近不透明，烟尾最低(0.10)快速消失。

### 3.6 绘制：径向渐变圆

```lua
local paint = nvgRadialGradient(vg,
    px, py,           -- 圆心
    size * 0.05,      -- 内圆半径（几乎为 0，亮色集中在中心点）
    size,             -- 外圆半径
    nvgRGBAf(r, g, b, a),              -- 中心色：亮，半透明
    nvgRGBAf(r*0.5, g*0.25, 0.0, 0.0) -- 边缘色：暗，全透明
)
nvgBeginPath(vg)
nvgCircle(vg, px, py, size)
nvgFillPaint(vg, paint)
nvgFill(vg)
```

**为什么内圆 `size * 0.05` 而不是 0？** 留一点内圆面积让中心有实色区域，叠加后核心更饱满。

**为什么边缘色不是 `(0,0,0,0)` 而是 `(r*0.5, g*0.25, 0)`？** 纯黑透明在半透明叠加时会产生灰色过渡带，用偏暖暗色过渡更自然。

---

## 第四层：飘散火星

40 个极小的渐变圆，速度快、alpha 衰减快：

```lua
local SPARKS = 40
for i = 1, SPARKS do
    -- 伪随机 + 生命周期（同上）
    -- 从火焰中上部射出，快速上升
    local sy = (baseY - FIRE_H * 0.35) - p * FIRE_H * 1.0
    -- 横向漂移随高度增大
    local drift = math.sin(t * (3.5 + h2 * 2.5) + i * 1.3) * R * 0.5 * p
    local sx = cx + (h1 - 0.5) * R * 0.4 + drift
    -- 很小的尺寸 + 快速消失的 alpha
    local sparkSize = R * (0.04 + h2 * 0.025) * (1.0 - p * 0.4)
    local sa = (0.7 + h1 * 0.3) * (1.0 - p)^2 * flicker
    -- 径向渐变绘制
    local sp = nvgRadialGradient(vg, sx, sy, 0, sparkSize,
        nvgRGBAf(1.0, 0.75, 0.12, sa),
        nvgRGBAf(1.0, 0.2, 0, 0)
    )
    nvgBeginPath(vg)
    nvgCircle(vg, sx, sy, sparkSize)
    nvgFillPaint(vg, sp)
    nvgFill(vg)
end
```

火星 alpha 用 `(1-p)^2` 衰减（平方），比线性更快 —— 刚射出时亮，很快就消失。

---

## 调参指南

| 参数 | 作用 | 调大 | 调小 |
|------|------|------|------|
| `COUNT` | 粒子总数 | 更浓密、核心更亮 | 稀疏、若隐若现 |
| `FIRE_H` | 火焰高度 | 火柱更高 | 矮火 |
| `FIRE_HALF_W` | 底部半宽 | 根部更宽（篝火感） | 窄火柱（蜡烛感） |
| `sizeBase` | 粒子基础半径 | 每个光球更大更柔和 | 颗粒感更强 |
| 各段 `a` 值 | 透明度 | 更亮更实 | 更虚更透 |
| `speed` | 上升速度 | 更猛烈的涌动 | 更缓慢的燃烧 |
| `sway` 幅度 | 横向摆动 | 更狂暴 | 更稳定 |
| 轮廓指数 `^1.2` | 收窄速度 | 更尖的火焰 | 更圆的火焰 |
| `SPARKS` | 火星数量 | 更多飘散余火 | 更干净的火焰 |
| `flicker` 基准 | 全局亮度下限 | 闪烁幅度更小 | 闪烁更剧烈 |

### 预设风格

**蜡烛火焰**（小而稳定）：
```lua
COUNT = 40, FIRE_H = R * 1.5, FIRE_HALF_W = R * 0.25
sway 幅度 * 0.15, SPARKS = 5
```

**篝火**（宽而猛烈）：
```lua
COUNT = 140, FIRE_H = R * 3.0, FIRE_HALF_W = R * 0.7
sway 幅度 * 0.4, SPARKS = 40
```

**地狱烈焰**（极端）：
```lua
COUNT = 250, FIRE_H = R * 4.0, FIRE_HALF_W = R * 0.9
所有 a 值 * 1.5, speed 范围 0.6~1.5, SPARKS = 80
```

---

## 踩过的坑

### 1. 纯色填充 vs 径向渐变

```lua
-- ❌ 纯色圆 → 像彩色弹珠
nvgFillColor(vg, nvgRGBAf(1, 0.5, 0, 0.3))

-- ✅ 径向渐变圆 → 有光晕的发光体
nvgFillPaint(vg, nvgRadialGradient(vg, x, y, 0, r, bright, transparent))
```

最关键的一步。没有径向渐变，再多粒子也只是一堆色块。

### 2. math.random() vs 黄金比例 Hash

```lua
-- ❌ 每帧随机 → 火焰像在抖
local x = cx + math.random() * w

-- ✅ 确定性伪随机 → 每帧位置平滑变化
local h = (i * 0.6180339887) % 1.0
-- 动画由 sin(t * speed + phase) 驱动，而非随机
```

粒子的"随机性"应该是**空间分布的随机**，不是**时间上的随机**。

### 3. 单频闪烁 vs 多频叠加

```lua
-- ❌ 单频 → 像呼吸灯
local flicker = 0.5 + 0.5 * math.sin(t * 2.0)

-- ✅ 多频乘积 → 不规则的自然闪烁
local flicker = 0.65
    + 0.22 * math.sin(t * 3.2) * math.sin(t * 1.7 + 0.5)
    + 0.13 * math.sin(t * 5.1 + 1.2)
```

### 4. 火苗形状粒子的失败

贝塞尔曲线画火苗形状的粒子（底宽顶尖），效果很不自然 —— 每个火苗都有明确的轮廓边界，像一堆叶子不是火。

**核心思路**：不要让单个粒子看起来像火苗，让大量模糊光球的叠加效果看起来像火焰。单个粒子应该看不清楚（径向渐变到透明），只有群体叠加才产生视觉。

---

## 性能

- 140 粒子 + 40 火星 = 每帧 ~180 次 `nvgRadialGradient` + `nvgCircle` + `nvgFill`
- NanoVG 底层走 GPU，这个量级基本无压力
- 没有纹理、没有创建/销毁对象、没有内存分配，全是数学计算 + 绘图调用

---

> **来源**: TapTap 开发者论坛 — 牧牧《NanoVG 动态火焰效果 — 径向渐变叠加法》(精华)
> **日期**: 2026-05-02
> **蒸馏等级**: L1（实用直接型）

> **这是什么**: 将 Remotion（React 视频框架）的动画设计理念转译为 NanoVG + Lua 等价写法，加上音频可视化、光斑效果、路径动画、图表动画等进阶视觉技巧
> **原作者**: 节拍前夜（项目自研）
> **推荐度**: L2（学习参考价值）— Remotion 动画模式的 Lua 转译 + 可复用视觉效果代码
> **适用场景**: NanoVG 2D 游戏的复杂动画编排、序列动画、转场效果、数据可视化

---

# Remotion 动画转译与进阶视觉技巧

## 一、Remotion → NanoVG/Lua 核心对照

| Remotion 概念 | Lua 等价物 | 说明 |
|--------------|------------|------|
| `useCurrentFrame()` | `HandleUpdate` 中的 `elapsed` 累计时间 | 帧驱动 vs 时间驱动 |
| `interpolate(frame, [a,b], [c,d])` | `interpolate(value, inMin, inMax, outMin, outMax, easing)` | 值映射 |
| `spring({ frame, fps, config })` | `springAnimation(elapsed, config)` | 物理弹簧 |
| `<Sequence from={x}>` | `if elapsed > delay then ...` | 延迟出现 |
| `<Series>` | 按 elapsed 阶段判断 | 依次播放 |
| `Easing.inOut(Easing.quad)` | `easeInOutQuad(t)` | 缓动函数 |
| `extrapolateRight: "clamp"` | `math.min(1, t)` | 钳位 |

---

## 二、核心动画模式转译

### 模式 1：基础插值 (interpolate)

```lua
function interpolate(value, inMin, inMax, outMin, outMax, easingFn)
    local t = (value - inMin) / (inMax - inMin)
    t = math.max(0, math.min(1, t))  -- clamp
    if easingFn then t = easingFn(t) end
    return outMin + (outMax - outMin) * t
end

-- 使用：0~0.5秒内从透明到不透明
local opacity = interpolate(elapsed, 0, 0.5, 0, 1, easeOutQuad)
```

### 模式 2：序列编排 (Sequence)

复杂动画 = 多个简单动画按时间排列：

```
0.0s  0.3s  0.5s  0.8s  1.0s  1.5s
|--飞入--|--缩放--|--闪光--|--文字--|--粒子--|
```

```lua
function createSequence(steps)
    return { steps = steps }
    -- steps 格式: { {delay, duration, animFn}, ... }
end

function updateSequence(seq, elapsed)
    for _, step in ipairs(seq.steps) do
        local localT = elapsed - step.delay
        if localT >= 0 and localT <= step.duration then
            local progress = math.min(1, localT / step.duration)
            step.animFn(progress)
        elseif localT > step.duration then
            step.animFn(1)  -- 保持终态
        end
    end
end

-- 使用示例
local cardEntrance = createSequence({
    { delay = 0.0, duration = 0.3, animFn = function(t)
        cardAlpha = easeOutQuad(t)
    end },
    { delay = 0.2, duration = 0.4, animFn = function(t)
        cardScale = interpolate(springAnimation(t * 2, SPRING_BOUNCY),
                                0, 1, 0.5, 1.0)
    end },
    { delay = 0.5, duration = 0.2, animFn = function(t)
        glowAlpha = easeOutQuad(t) * 0.6
    end },
})
```

### 模式 3：转场 (Transitions)

```lua
-- 淡入淡出
function transitionFade(t)
    return { alphaA = 1 - t, alphaB = t }
end

-- 滑动
function transitionSlide(t, direction, width)
    if direction == "from-right" then
        return { offsetA = -t * width, offsetB = (1-t) * width }
    elseif direction == "from-left" then
        return { offsetA = t * width, offsetB = -(1-t) * width }
    end
end

-- 缩放
function transitionZoom(t)
    return {
        scaleA = 1 + t * 0.3,  alphaA = 1 - t,
        scaleB = 0.7 + t * 0.3, alphaB = t,
    }
end
```

### 模式 4：交错延迟 (Stagger)

```lua
local STAGGER_DELAY = 0.06  -- 每项延迟60ms

for i, item in ipairs(items) do
    local itemDelay = (i - 1) * STAGGER_DELAY
    local itemElapsed = math.max(0, elapsed - itemDelay)
    local t = math.min(1, itemElapsed / 0.3)
    local alpha = easeOutQuad(t)
    local offsetX = (1 - easeOutQuad(t)) * 40
    nvgGlobalAlpha(vg, alpha)
    drawItem(vg, item, baseX + offsetX, baseY + (i-1) * itemH)
end
nvgGlobalAlpha(vg, 1)
```

### 模式 5：进出动画配对 (Enter/Exit)

```lua
function enterExitAnimation(elapsed, totalDuration, enterDur, exitDur)
    local enterT = math.min(1, elapsed / enterDur)
    local enter = springAnimation(enterT * 2, SPRING_SNAPPY)
    local exitStart = totalDuration - exitDur
    local exitT = math.max(0, (elapsed - exitStart) / exitDur)
    exitT = math.min(1, exitT)
    local exit = easeInQuad(exitT)
    return enter * (1 - exit)
end
```

---

## 三、Remotion 的关键教训

1. **不要用定时器做动画** — 所有动画在 `HandleUpdate` / `NanoVGRender` 中基于 `elapsed` 计算，保证确定性
2. **秒为单位，帧为精度** — 设计时按秒思考（0.3秒飞入），运行时用 `dt` 累加
3. **Clamp 永远要加** — `math.min(1, math.max(0, t))` 要成为肌肉记忆

---

## 四、进阶视觉技巧

### 音频可视化 — 低频脉动 (Bass-Reactive)

```lua
-- 如果能接入音频 FFT 数据
local bassIntensity = getBassLevel()  -- 0~1
local scale = 1 + bassIntensity * 0.3  -- 节拍时放大 30%
local glowAlpha = math.min(0.6, bassIntensity * 0.8)
```

**对数缩放**（让低频不压过高频）：
```lua
local function logScale(value)
    local minDb, maxDb = -100, -30
    local db = 20 * math.log10(math.max(value, 1e-10))
    return (db - minDb) / (maxDb - minDb)
end
```

### 光斑泄漏效果 (Light Leak)

半透明渐变光斑覆盖画面，用于场景转换闪光：

```lua
local function drawLightLeak(vg, cx, cy, radius, hue, alpha)
    local paint = nvgRadialGradient(vg, cx, cy, 0, radius,
        nvgHSLA(hue/360, 0.8, 0.6, alpha * 255),
        nvgHSLA(hue/360, 0.8, 0.6, 0))
    nvgBeginPath(vg)
    nvgCircle(vg, cx, cy, radius)
    nvgFillPaint(vg, paint)
    nvgFill(vg)
end
-- 应用：技艺确认闪光、界面转场、胜利屏幕闪光
```

### 路径逐步绘制动画

```lua
local function drawPathProgress(vg, points, progress)
    if #points < 2 or progress <= 0 then return end
    local totalSegments = #points - 1
    local segsToDraw = progress * totalSegments
    nvgBeginPath(vg)
    nvgMoveTo(vg, points[1].x, points[1].y)
    for i = 1, math.min(math.floor(segsToDraw), totalSegments) do
        nvgLineTo(vg, points[i + 1].x, points[i + 1].y)
    end
    local partialSeg = segsToDraw - math.floor(segsToDraw)
    if partialSeg > 0 and math.floor(segsToDraw) < totalSegments then
        local idx = math.floor(segsToDraw) + 1
        local x = lerp(points[idx].x, points[idx + 1].x, partialSeg)
        local y = lerp(points[idx].y, points[idx + 1].y, partialSeg)
        nvgLineTo(vg, x, y)
    end
    nvgStroke(vg)
end
```

### 路径跟随标记

```lua
local function getPointOnPath(points, progress)
    local totalLen = 0
    local segLens = {}
    for i = 1, #points - 1 do
        local dx = points[i+1].x - points[i].x
        local dy = points[i+1].y - points[i].y
        segLens[i] = math.sqrt(dx*dx + dy*dy)
        totalLen = totalLen + segLens[i]
    end
    local targetLen = progress * totalLen
    local accumulated = 0
    for i = 1, #segLens do
        if accumulated + segLens[i] >= targetLen then
            local t = (targetLen - accumulated) / segLens[i]
            return {
                x = lerp(points[i].x, points[i+1].x, t),
                y = lerp(points[i].y, points[i+1].y, t),
                angle = math.atan(points[i+1].y - points[i].y,
                                  points[i+1].x - points[i].x)
            }
        end
        accumulated = accumulated + segLens[i]
    end
    return { x = points[#points].x, y = points[#points].y, angle = 0 }
end
```

### 交错柱状图动画

```lua
local STAGGER_DELAY = 0.08
local function drawBarChart(vg, data, elapsed, x, y, w, h)
    local barW = w / #data
    for i, item in ipairs(data) do
        local delay = (i - 1) * STAGGER_DELAY
        local t = math.max(0, elapsed - delay)
        local barH = easeOutBack(math.min(t / 0.4, 1)) * item.value * h
        nvgBeginPath(vg)
        nvgRect(vg, x + (i-1) * barW + 2, y + h - barH, barW - 4, barH)
        nvgFillColor(vg, item.color)
        nvgFill(vg)
    end
end
```

### 饼图/扇形进度

```lua
local function drawPieProgress(vg, cx, cy, r, progress, color)
    local startAngle = -math.pi / 2
    local endAngle = startAngle + progress * math.pi * 2
    nvgBeginPath(vg)
    nvgMoveTo(vg, cx, cy)
    nvgArc(vg, cx, cy, r, startAngle, endAngle, NVG_CW)
    nvgClosePath(vg)
    nvgFillColor(vg, color)
    nvgFill(vg)
end
```

---

## 五、UI 美学原则（避免 AI Slop）

| 反模式 | 描述 | 正确做法 |
|--------|------|---------|
| 渐变滥用 | 到处彩虹渐变 | 克制使用，1-2 个重点 |
| 圆角过大 | 所有元素胶囊形 | 根据元素大小选 4-12px |
| 阴影泛滥 | 每个元素都有阴影 | 仅浮层/弹出层使用 |
| 色彩过多 | 5+ 种颜色混搭 | 主色 + 辅色 + 中性色 |
| 间距不一致 | 随意填充 | 4/8 倍数体系 |

**色彩体系模板**：

```lua
local THEME = {
    primary     = { 66/255, 133/255, 244/255 },
    primaryDark = { 48/255, 98/255, 180/255 },
    secondary   = { 234/255, 67/255, 53/255 },
    surface     = { 255/255, 255/255, 255/255 },
    background  = { 245/255, 245/255, 245/255 },
    textPrimary = { 32/255, 33/255, 36/255 },
    textSecondary = { 95/255, 99/255, 104/255 },
    divider     = { 218/255, 220/255, 224/255 },
}
```

**动效黄金法则**：
1. 持续时间 150-300ms 最佳（<100ms 太突兀，>500ms 拖沓）
2. 进入用 easeOut，退出用 easeIn，持续用 easeInOut
3. 大元素慢，小元素快；背景先动，前景后动
4. 每个动画都要有功能目的

---

## 六、AnimUtils 工具模块模板

```lua
local AnimUtils = {}

function AnimUtils.interpolate(value, inMin, inMax, outMin, outMax, easingFn)
    local t = (value - inMin) / (inMax - inMin)
    t = math.max(0, math.min(1, t))
    if easingFn then t = easingFn(t) end
    return outMin + (outMax - outMin) * t
end

AnimUtils.tweens = {}

function AnimUtils.tween(id, duration, easingFn, onUpdate, onComplete)
    AnimUtils.tweens[id] = {
        elapsed = 0, duration = duration,
        easing = easingFn or easeOutQuad,
        onUpdate = onUpdate, onComplete = onComplete, done = false,
    }
end

function AnimUtils.updateTweens(dt)
    for id, tw in pairs(AnimUtils.tweens) do
        if not tw.done then
            tw.elapsed = tw.elapsed + dt
            local t = math.min(1, tw.elapsed / tw.duration)
            tw.onUpdate(tw.easing(t))
            if t >= 1 then
                tw.done = true
                if tw.onComplete then tw.onComplete() end
            end
        end
    end
end

function AnimUtils.cancelTween(id) AnimUtils.tweens[id] = nil end

return AnimUtils
```

---

## 参考来源

- [Remotion Skills — animations/timing/sequencing/transitions](https://www.remotion.dev/docs/ai/skills)
- [Remotion audio-visualization](https://www.remotion.dev/docs/the-fundamentals)
- [Frontend Design Best Practices — AI Slop 反模式](https://www.remotion.dev/docs/ai/skills)

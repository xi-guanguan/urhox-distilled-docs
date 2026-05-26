> **这是什么**: Game Juice 六大核心动画技法 + 18 种缓动函数完整 Lua 实现 + 弹簧动画系统 + 辅助工具函数库，面向 NanoVG 纯代码 2D 游戏动画
> **原作者**: 节拍前夜（项目自研）
> **推荐度**: L2（学习参考价值）— 系统完整的动画方法论和可复用代码库
> **适用场景**: NanoVG 2D 游戏动画开发、UI 动效设计、打击感/反馈感提升

---

# GameJuice 动画六大技法与缓动函数库

## 核心理念：什么是 Game Juice？

**Juice = 把能跑的游戏，变成好玩的游戏。**

不是功能，是**感觉**。同一个攻击动作：
- 无 Juice：角色挥手 → 敌人扣血
- 有 Juice：角色挥手（拉伸预备）→ 命中闪白 → 屏幕微震 → 粒子飞溅 → 数字弹出 → 敌人后退

**关键原则**：Juice 必须服务于核心玩法，不是随机加特效。

---

## 一、六大核心动画技法

### 1. 缓动函数（Easing）— 一切动画的灵魂

**绝对不要用线性插值做任何动画！线性 = 机器人。**

| 缓动类型 | 效果 | 典型用途 |
|---------|------|---------|
| **EaseOut** | 快启动，慢停下 | UI 弹出、卡牌飞入、菜单出现 |
| **EaseIn** | 慢启动，快结束 | 物体飞走、消失动画 |
| **EaseInOut** | 平滑加减速 | 界面切换、摄像机移动 |
| **BackOut** | 稍微过头再回弹 | 按钮出现、元素弹入 |
| **ElasticOut** | 弹性震荡 | 攻击命中、抽卡结果 |
| **BounceOut** | 弹跳 | 物品掉落、得分落定 |

**选择速查表**：

```
"弹出一个菜单/按钮"          → easeOutQuad 或 easeOutBack
"卡牌飞到目标位置"            → easeInOutCubic
"命中后数字弹出"              → easeOutBack + scale
"元素消失/飞走"              → easeInQuad
"列表项逐个出现"              → easeOutQuad + stagger
"弹性跳动效果"               → easeOutElastic 或 springAnimation
"物品掉落弹跳"               → easeOutBounce
"平滑的来回移动(呼吸/摇摆)"   → math.sin(time * speed)
"强调/高亮闪烁"              → easeOutExpo
"摄像机平移"                 → easeInOutQuad
```

### 2. Squash & Stretch（挤压拉伸）— 赋予重量感

动画十二法则中最重要的一条。任何碰撞/弹跳都应有形变：

```
飞行中:    scaleX=0.9,  scaleY=1.1   (沿运动方向拉伸)
碰撞瞬间:  scaleX=1.3,  scaleY=0.7   (垂直压扁)
弹起:      scaleX=0.85, scaleY=1.15  (反向拉伸)
恢复:      scaleX=1.0,  scaleY=1.0   (弹性回位)
```

NanoVG 实现：
```lua
nvgSave(vg)
nvgTranslate(vg, x, y)
nvgScale(vg, scaleX, scaleY)
nvgTranslate(vg, -pivotX, -pivotY) -- 相对锚点缩放
-- 绘制内容...
nvgRestore(vg)
```

### 3. 微动画（Micro-Animations）— 让一切活起来

**规则：画面上永远不要有完全静止的东西。**

| 微动画 | 实现 | 时长 |
|-------|------|------|
| Hit Flash（受击闪白） | 受击瞬间整体着色为白色 2-3 帧 | 50-100ms |
| Idle 呼吸 | 周期性 scale 0.98~1.02 | 2-3秒一循环 |
| 按钮反馈 | 按下 scale→0.92，松开 spring 回 1.0 | 150ms |
| 悬停高亮 | 鼠标悬停时边框/发光亮度渐变 | 200ms |
| 数字跳动 | 数值变化时数字先放大再缩回 | 300ms |
| 入场交错 | 列表元素逐个从右滑入（stagger delay） | 每项 50ms 延迟 |

### 4. 粒子效果 — NanoVG 纯代码实现

粒子的本质：**大量小物体 + 随机初始状态 + 物理衰减**。

```lua
-- 粒子数据结构
Particle = {
    x, y,           -- 位置
    vx, vy,         -- 速度
    life, maxLife,   -- 生命周期
    size, color, rotation
}

-- 每帧更新
function updateParticle(p, dt)
    p.x = p.x + p.vx * dt
    p.y = p.y + p.vy * dt
    p.vy = p.vy + gravity * dt     -- 重力
    p.life = p.life - dt
    p.vx = p.vx * 0.98             -- 空气阻力
    local t = p.life / p.maxLife   -- 剩余生命比例 1→0
    p.size = p.size * t            -- 逐渐缩小
    p.alpha = t                    -- 逐渐透明
end
```

**常用粒子模式**：

| 场景 | 发射方式 | 形状 | 颜色 |
|------|---------|------|------|
| 攻击命中 | 爆发 8-15个 | 小圆/菱形 | 白→黄→橙 |
| 技能释放 | 持续+爆发 | 星形/圆 | 技能主色调 |
| 得分获取 | 向上喷射 | 小星星 | 金色 |
| 治疗/恢复 | 上升气泡 | 圆 | 绿色/白色 |

### 5. 发光（Glow）效果 — 多层渐变模拟

NanoVG 没有原生 Glow/Bloom，用**多层径向渐变叠加**模拟：

```lua
function drawGlow(vg, cx, cy, radius, r, g, b)
    -- 外层光晕（大、淡）
    local outerPaint = nvgRadialGradient(vg, cx, cy, 0, radius * 3,
        nvgRGBA(r, g, b, 30), nvgRGBA(r, g, b, 0))
    nvgBeginPath(vg)
    nvgCircle(vg, cx, cy, radius * 3)
    nvgFillPaint(vg, outerPaint)
    nvgFill(vg)
    -- 中层（中等）
    local midPaint = nvgRadialGradient(vg, cx, cy, 0, radius * 1.5,
        nvgRGBA(r, g, b, 80), nvgRGBA(r, g, b, 0))
    nvgBeginPath(vg)
    nvgCircle(vg, cx, cy, radius * 1.5)
    nvgFillPaint(vg, midPaint)
    nvgFill(vg)
    -- 核心亮点（小、亮）
    local corePaint = nvgRadialGradient(vg, cx, cy, 0, radius * 0.5,
        nvgRGBA(255, 255, 255, 200), nvgRGBA(r, g, b, 100))
    nvgBeginPath(vg)
    nvgCircle(vg, cx, cy, radius * 0.5)
    nvgFillPaint(vg, corePaint)
    nvgFill(vg)
end
```

### 6. 屏幕震动（Screen Shake）— 打击感神器

```lua
local shake = { intensity = 0, duration = 0, elapsed = 0 }

function triggerShake(intensity, duration)
    shake.intensity = intensity
    shake.duration = duration
    shake.elapsed = 0
end

function updateShake(dt)
    if shake.elapsed >= shake.duration then return 0, 0 end
    shake.elapsed = shake.elapsed + dt
    local t = 1 - shake.elapsed / shake.duration
    local offsetX = (math.random() * 2 - 1) * shake.intensity * t
    local offsetY = (math.random() * 2 - 1) * shake.intensity * t
    return offsetX, offsetY
end

-- 渲染时应用
function HandleNanoVGRender(eventType, eventData)
    local sx, sy = updateShake(dt)
    nvgBeginFrame(vg, w, h, 1.0)
    nvgTranslate(vg, sx, sy)  -- 整体偏移
    -- 正常绘制...
    nvgEndFrame(vg)
end
```

**震动参数推荐**：

| 场景 | intensity | duration |
|------|-----------|----------|
| 轻击命中 | 2-3 px | 0.05s |
| 重击命中 | 5-8 px | 0.15s |
| 爆炸 | 8-12 px | 0.25s |
| Boss 登场 | 3-5 px | 0.5s |

---

## 二、缓动函数完整库（18种）

所有函数输入 `t`（0~1），输出 0~1。可直接复制到 Lua 项目使用。

### EaseOut 系列（最常用）

```lua
function easeOutQuad(t)  return 1 - (1 - t) * (1 - t) end
function easeOutCubic(t) return 1 - (1 - t) ^ 3 end
function easeOutQuart(t) return 1 - (1 - t) ^ 4 end
function easeOutExpo(t)  return t == 1 and 1 or 1 - 2 ^ (-10 * t) end
```

### EaseIn 系列（用于退出/消失）

```lua
function easeInQuad(t)  return t * t end
function easeInCubic(t) return t * t * t end
function easeInExpo(t)  return t == 0 and 0 or 2 ^ (10 * t - 10) end
```

### EaseInOut 系列（用于来回运动/转场）

```lua
function easeInOutQuad(t)
    return t < 0.5 and 2 * t * t or 1 - (-2 * t + 2) ^ 2 / 2
end
function easeInOutCubic(t)
    return t < 0.5 and 4 * t * t * t or 1 - (-2 * t + 2) ^ 3 / 2
end
function easeInOutExpo(t)
    if t == 0 then return 0 end
    if t == 1 then return 1 end
    return t < 0.5 and 2 ^ (20 * t - 10) / 2 or (2 - 2 ^ (-20 * t + 10)) / 2
end
```

### 特殊缓动

```lua
-- Back — 过冲回弹（按钮弹入效果极佳）
function easeOutBack(t)
    local c1 = 1.70158; local c3 = c1 + 1
    return 1 + c3 * (t - 1) ^ 3 + c1 * (t - 1) ^ 2
end
function easeInBack(t)
    local c1 = 1.70158; local c3 = c1 + 1
    return c3 * t * t * t - c1 * t * t
end

-- Elastic — 弹性震荡（抽卡/命中强调）
function easeOutElastic(t)
    if t == 0 or t == 1 then return t end
    return 2 ^ (-10 * t) * math.sin((t * 10 - 0.75) * (2 * math.pi) / 3) + 1
end
function easeInElastic(t)
    if t == 0 or t == 1 then return t end
    return -(2 ^ (10 * t - 10)) * math.sin((t * 10 - 10.75) * (2 * math.pi) / 3)
end

-- Bounce — 弹跳落地
function easeOutBounce(t)
    local n1, d1 = 7.5625, 2.75
    if t < 1 / d1 then return n1 * t * t
    elseif t < 2 / d1 then t = t - 1.5 / d1; return n1 * t * t + 0.75
    elseif t < 2.5 / d1 then t = t - 2.25 / d1; return n1 * t * t + 0.9375
    else t = t - 2.625 / d1; return n1 * t * t + 0.984375 end
end
function easeInBounce(t) return 1 - easeOutBounce(1 - t) end
```

---

## 三、Spring 弹簧动画系统

```lua
--- 物理弹簧模拟，返回 0→1（可能过冲到 >1 再回落）
function springAnimation(elapsed, config)
    config = config or {}
    local damping   = config.damping or 10
    local stiffness = config.stiffness or 100
    local mass      = config.mass or 1
    local omega = math.sqrt(stiffness / mass)
    local zeta  = damping / (2 * math.sqrt(stiffness * mass))
    if zeta >= 1 then
        local decay = math.exp(-omega * zeta * elapsed)
        return 1 - decay * (1 + omega * zeta * elapsed)
    else
        local omegaD = omega * math.sqrt(1 - zeta * zeta)
        local decay = math.exp(-omega * zeta * elapsed)
        return 1 - decay * (math.cos(omegaD * elapsed)
               + (zeta * omega / omegaD) * math.sin(omegaD * elapsed))
    end
end

-- 预设配置
SPRING_SMOOTH = { damping = 200 }                      -- 平滑无弹跳（微妙揭示）
SPRING_SNAPPY = { damping = 20, stiffness = 200 }      -- 敏捷微弹（UI 元素）
SPRING_BOUNCY = { damping = 8 }                         -- 弹跳入场（活泼动画）
SPRING_HEAVY  = { damping = 15, stiffness = 80, mass = 2 } -- 沉重缓慢
```

---

## 四、辅助工具函数

```lua
function lerp(a, b, t) return a + (b - a) * t end

function lerpEased(a, b, t, easingFn) return lerp(a, b, easingFn(t)) end

function clamp(value, min, max) return math.max(min, math.min(max, value)) end

function progress(elapsed, delay, duration)
    return clamp((elapsed - delay) / duration, 0, 1)
end

function interpolate(value, inMin, inMax, outMin, outMax, easingFn)
    local t = clamp((value - inMin) / (inMax - inMin), 0, 1)
    if easingFn then t = easingFn(t) end
    return outMin + (outMax - outMin) * t
end

function lerpAngle(a, b, t)
    local diff = ((b - a + 180) % 360) - 180
    return a + diff * t
end

function lerpColor(r1,g1,b1,a1, r2,g2,b2,a2, t)
    return lerp(r1,r2,t), lerp(g1,g2,t), lerp(b1,b2,t), lerp(a1,a2,t)
end
```

---

## 五、动画时长参考标准

| 类型 | 推荐时长 | 说明 |
|------|---------|------|
| Hit Flash | 50-80ms | 越短越利落 |
| 按钮反馈 | 100-150ms | 太长感觉迟钝 |
| 屏幕震动 | 50-200ms | 根据冲击力度 |
| UI 弹出/消失 | 200-350ms | 标准 UI 动画时长 |
| 卡牌飞行 | 400-600ms | 需要看清轨迹 |
| 转场 | 300-500ms | 不能太慢打断节奏 |
| 数字弹出 | 300-500ms | 弹出快、停留略久 |
| 粒子生命 | 300-800ms | 根据大小和用途 |
| idle 呼吸 | 2000-3000ms 周期 | 慢而微妙 |
| 列表 stagger | 50-80ms/项 | 项越多间隔越短 |

---

## 六、动画设计 Checklist

- [ ] 使用了缓动函数（不是线性）？
- [ ] 有进场动画？
- [ ] 有退场动画（如果需要消失）？
- [ ] 关键动作有反馈（闪光/震动/粒子）？
- [ ] 待机状态有微动画（不完全静止）？
- [ ] 动画时长合理（UI 150-300ms，游戏反馈 50-150ms）？
- [ ] 多元素有交错延迟？
- [ ] 不同重要度的动画有层次区分？

---

## 参考来源

- [Game Juice 设计技巧 -- GameDeveloper](https://www.gamedeveloper.com/design/squeezing-more-juice-out-of-your-game-design-)
- [Easing Functions Visual Guide -- easings.net](https://easings.net)
- [Robert Penner Easing 原始公式](https://github.com/EmmanuelOga/easing)
- [tween.lua -- 45 种缓动函数](https://github.com/kikito/tween.lua)
- [flux -- 链式补间动画](https://github.com/rxi/flux)

# 2D 自然光照 DESTINATION_OUT 四步法

| 字段 | 值 |
|------|-----|
| 这是什么 | 纯 NanoVG 实现 2D 动态光照效果的方法——不用着色器，用合成模式（DESTINATION_OUT）"擦除黑暗"而非"叠加光线"。覆盖四步渲染流程、多光源类型、性能优化建议 |
| 原作者 | 夜晔（觅光，2D 平台解谜，多种动态光源） |
| 推荐度 | L2（方案可用且效果好，但渲染成本约 2 倍，需理解合成模式原理） |
| 适用场景 | 2D 游戏中需要火把照明、玩家光环、动态昼夜等光照效果，且不想使用着色器 |

---

## 核心思想

> **不要"添加光"——而是"擦除黑暗"**

传统思路是在暗色场景上叠加光圈，但这会导致光区域的场景颜色失真。正确思路：先画正常场景，再盖一层全屏黑幕，然后用 DESTINATION_OUT 模式在光源位置"擦掉"黑幕，露出底下的原始场景。

---

## 三种关键合成模式

| 模式 | NanoVG 常量 | 效果 | 用途 |
|------|------------|------|------|
| SOURCE_OVER | `NVG_SOURCE_OVER` | 新内容画在旧内容上面（默认） | 正常绘制 |
| DESTINATION_OUT | `NVG_DESTINATION_OUT` | 新内容的形状从旧内容中**扣除** | 光源"擦除"黑幕 |
| DESTINATION_OVER | `NVG_DESTINATION_OVER` | 新内容画在旧内容**下面** | 回填被擦除的场景 |

---

## 四步渲染流程

### 第 1 步：正常绘制场景（SOURCE_OVER）

```lua
nvgGlobalCompositeOperation(vg, NVG_SOURCE_OVER)
-- 绘制地面、平台、道具、角色...
DrawScene(vg)
```

一切正常绘制，此时画面是完整的亮色场景。

### 第 2 步：全屏黑幕遮罩（SOURCE_OVER）

```lua
nvgGlobalCompositeOperation(vg, NVG_SOURCE_OVER)
nvgBeginPath(vg)
nvgRect(vg, 0, 0, screenWidth, screenHeight)
nvgFillColor(vg, nvgRGBA(0, 0, 0, ambientDarkness))  -- ambientDarkness: 200~240
nvgFill(vg)
```

整个画面被黑幕覆盖，模拟黑暗环境。`ambientDarkness` 控制环境亮度（值越大越暗）。

### 第 3 步：光源擦除黑幕（DESTINATION_OUT）

```lua
nvgGlobalCompositeOperation(vg, NVG_DESTINATION_OUT)

for _, light in ipairs(lights) do
    nvgBeginPath(vg)
    nvgCircle(vg, light.x, light.y, light.radius)

    -- 径向渐变：中心亮（擦除强） → 边缘暗（擦除弱）
    local paint = nvgRadialGradient(vg,
        light.x, light.y,
        light.radius * 0.06,   -- 内圈半径：6% 处为全亮核心
        light.radius * 0.92,   -- 外圈半径：92% 处渐变到透明
        nvgRGBA(255, 255, 255, light.intensity),  -- 中心：强擦除
        nvgRGBA(255, 255, 255, 0)                  -- 边缘：不擦除
    )
    nvgFillPaint(vg, paint)
    nvgFill(vg)
end
```

**关键参数**：
- `innerRadius = radius * 0.06`：只有 6% 的中心是最亮的核心
- `outerRadius = radius * 0.92`：92% 处开始完全消失
- 这样产生自然的光衰减效果

### 第 4 步：回填被擦除的场景（DESTINATION_OVER）

```lua
nvgGlobalCompositeOperation(vg, NVG_DESTINATION_OVER)
-- ⚠️ 必须按**逆序**重绘场景！
DrawSceneReversed(vg)
```

> **为什么要逆序？** DESTINATION_OVER 把新内容画在旧内容**下面**。如果正序绘制，先画的元素会被后画的遮挡关系搞乱。逆序绘制才能保持原始的 Z 轴层级。

### 第 5 步（可选）：暖光叠加（SOURCE_OVER）

```lua
nvgGlobalCompositeOperation(vg, NVG_SOURCE_OVER)

for _, light in ipairs(warmLights) do
    nvgBeginPath(vg)
    nvgCircle(vg, light.x, light.y, light.radius * 0.3)
    local paint = nvgRadialGradient(vg,
        light.x, light.y, 0, light.radius * 0.3,
        nvgRGBA(255, 200, 100, 30),  -- 暖色微光
        nvgRGBA(255, 200, 100, 0)
    )
    nvgFillPaint(vg, paint)
    nvgFill(vg)
end
```

在光源中心添加一层淡淡的暖色光晕，增加氛围感。强度要低（alpha 约 20~40），否则会过曝。

---

## 多种光源类型

| 类型 | 颜色 | 半径 | 特效 | 用途 |
|------|------|------|------|------|
| 火把 | 暖橙 `(255, 180, 80)` | 中等 | sin 波闪烁 | 场景固定光源 |
| 玩家 | 冷白 `(200, 220, 255)` | 随 LP 变化 | 血量越低越暗 | 角色随行光 |
| 钥匙 | 金色 `(255, 215, 0)` | 小 | 缓慢呼吸 | 道具高亮 |
| 敌人 | 紫色 `(180, 100, 255)` | 小 | 无 | 危险警示 |
| 萤火虫 | 黄绿 `(180, 255, 100)` | 极小 | 随机漂移 | 氛围装饰 |
| 边缘光 | 冷蓝 `(100, 150, 255)` | 极大/极弱 | 无 | 场景边界提示 |

### 火把闪烁实现

```lua
-- sin 波模拟火焰跳动
local flicker = math.sin(time * 5.0) * 0.15 + 1.0  -- 0.85 ~ 1.15
local currentRadius = baseRadius * flicker
local currentIntensity = math.floor(baseIntensity * flicker)
```

### 玩家光源随血量变化

```lua
local hpRatio = currentHP / maxHP
local playerRadius = baseRadius * (0.3 + 0.7 * hpRatio)  -- 满血=100%, 空血=30%
local playerIntensity = math.floor(200 * hpRatio + 55)     -- 最低 55, 最高 255
```

---

## 光源收集函数

```lua
function CollectAllLights()
    local lights = {}

    -- 火把（场景固定光源）
    for _, torch in ipairs(torches) do
        if IsInViewport(torch) then  -- 视口裁剪
            table.insert(lights, {
                x = torch.screenX, y = torch.screenY,
                radius = torch.radius * flicker,
                intensity = torch.intensity,
                color = {255, 180, 80},
                warm = true,  -- 标记需要暖光叠加
            })
        end
    end

    -- 玩家光源
    table.insert(lights, {
        x = player.screenX, y = player.screenY,
        radius = playerRadius,
        intensity = playerIntensity,
        color = {200, 220, 255},
        warm = false,
    })

    -- 其他光源...
    return lights
end
```

---

## 完整渲染流程（DrawLighting）

```lua
function DrawLighting(vg, screenW, screenH)
    local lights = CollectAllLights()

    -- Step 1: 场景已在此前绘制

    -- Step 2: 黑幕
    nvgGlobalCompositeOperation(vg, NVG_SOURCE_OVER)
    nvgBeginPath(vg)
    nvgRect(vg, 0, 0, screenW, screenH)
    nvgFillColor(vg, nvgRGBA(0, 0, 0, 220))
    nvgFill(vg)

    -- Step 3: 擦除
    nvgGlobalCompositeOperation(vg, NVG_DESTINATION_OUT)
    for _, light in ipairs(lights) do
        nvgBeginPath(vg)
        nvgCircle(vg, light.x, light.y, light.radius)
        local paint = nvgRadialGradient(vg,
            light.x, light.y,
            light.radius * 0.06, light.radius * 0.92,
            nvgRGBA(255, 255, 255, light.intensity),
            nvgRGBA(255, 255, 255, 0)
        )
        nvgFillPaint(vg, paint)
        nvgFill(vg)
    end

    -- Step 4: 逆序回填场景
    nvgGlobalCompositeOperation(vg, NVG_DESTINATION_OVER)
    DrawSceneReversed(vg)

    -- Step 5: 暖光叠加
    nvgGlobalCompositeOperation(vg, NVG_SOURCE_OVER)
    for _, light in ipairs(lights) do
        if light.warm then
            nvgBeginPath(vg)
            nvgCircle(vg, light.x, light.y, light.radius * 0.3)
            local paint = nvgRadialGradient(vg,
                light.x, light.y, 0, light.radius * 0.3,
                nvgRGBA(light.color[1], light.color[2], light.color[3], 30),
                nvgRGBA(light.color[1], light.color[2], light.color[3], 0)
            )
            nvgFillPaint(vg, paint)
            nvgFill(vg)
        end
    end

    -- 恢复默认合成模式
    nvgGlobalCompositeOperation(vg, NVG_SOURCE_OVER)
end
```

---

## 性能优化

| 策略 | 说明 |
|------|------|
| 视口裁剪 | 只处理屏幕内的光源（`IsInViewport` 检查） |
| 光源上限 | 10~15 个光源流畅，超过需要按距离优先级裁剪 |
| 渲染成本 | 约为无光照的 **2 倍**（场景画两遍 + 黑幕 + 擦除） |
| 减少重绘 | Step 4 回填时可只画被光源覆盖区域的场景元素 |
| 合并光源 | 距离很近的多个小光源可合并为一个大光源 |

---

## 踩坑备忘

| 坑 | 现象 | 解法 |
|----|------|------|
| Step 4 正序绘制 | 场景元素层级混乱 | DESTINATION_OVER 必须**逆序**绘制 |
| 漏恢复合成模式 | 后续 UI 绘制全部异常 | 流程末尾加 `SOURCE_OVER` 恢复 |
| innerRadius 太大 | 光源中心有明显硬边 | 用 `radius * 0.06`，让核心极小 |
| outerRadius = radius | 光照边缘截断明显 | 用 `radius * 0.92`，留 8% 过渡 |
| 暖光 alpha 太高 | 光源处过曝发白 | alpha 控制在 20~40 |
| 忘记视口裁剪 | 大量屏幕外光源拖慢帧率 | CollectAllLights 中过滤 |
| ambientDarkness 太低 | 光照效果不明显 | 推荐 200~240（0=全亮，255=全黑） |

---

## 三个失败方案（避坑参考）

在找到 DESTINATION_OUT 方案前，作者尝试过以下方案均失败：

| 方案 | 问题 |
|------|------|
| 直接叠加半透明光圈 | 光区颜色失真，多光源重叠处过亮 |
| 先画黑幕再用透明度混合 | 无法精确控制光照衰减 |
| 像素级操作 | NanoVG 不支持逐像素操作，性能不可接受 |

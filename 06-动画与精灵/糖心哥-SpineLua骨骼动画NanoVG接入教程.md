# Spine 骨骼动画接入教程——spine-lua + NanoVG 渲染方案

> **这是什么**：在 UrhoX 中通过 spine-lua 官方 Lua runtime + NanoVG 渲染后端接入 Spine 骨骼动画的完整流程，覆盖资源准备、加载、动画播放、切换、渲染全链路。
>
> **原作者**：糖心哥
> **推荐度**：L2（方案完整可行，利用了 Spine 官方维护的 spine-lua runtime，兼容性好。但 spine-lua 为纯 Lua 实现，性能不如原生 C++ runtime；NanoVG 渲染开销较大，角色数量受限。适合角色少、动画质量要求高的场景。）
> **适用场景**：项目中已有 Spine 编辑器导出的动画资源（`.json` + `.atlas` + `.png`），需要在 UrhoX 中播放。
>
> **同类对比**：
> - **vs 大雄-Spine骨骼动画Runtime完整方案**：大雄方案是从零实现的自研 Runtime（CustomGeometry 渲染），支持 IK/FFD/Mesh 附件等高级特性，但仅支持 Spine 2.x/3.x JSON 格式。糖心哥方案使用 Spine 官方 spine-lua 库 + NanoVG 渲染，依赖官方维护的解析逻辑，理论上格式兼容性更好（跟随官方更新），但渲染层需要自行实现 NanoVG 绑定。
> - **特色**：依赖官方 spine-lua，减少自研维护成本；NanoVG 渲染支持矢量缩放无失真。
> - **优点**：官方 runtime 保证格式兼容；支持动画混合（multi-track）、过渡（defaultMix）等高级播放控制；接入步骤清晰。
> - **缺点**：纯 Lua 性能有限（建议 10 角色以内）；NanoVG 渲染 Region 附件需手写仿射变换代码；不支持 `.skel` 二进制格式（spine-lua 限制）。

---

## 1. 架构概览

```
Spine 编辑器导出
  .json（骨骼数据）+ .atlas（图集描述）+ .png（合图纹理）
        ↓
  spine-lua 官方 runtime
    ↓ 解析骨骼 / Atlas / 创建 Skeleton + AnimationState
        ↓
  NanoVG 渲染后端
    ↓ 遍历 drawOrder → 读取 Region/Mesh 附件 → nvgCreateImage + 仿射绘制
        ↓
  UrhoX NanoVGRender 事件
    ↓ 每帧更新 + 渲染
```

## 2. 资源准备

### 2.1 获取 spine-lua

从 Spine 官方 GitHub 仓库获取 Lua runtime：

```
https://github.com/EsotericSoftware/spine-runtimes/tree/4.x/spine-lua
```

将 `spine-lua/` 整个目录放到 `scripts/libs/spine-lua/`。

### 2.2 Spine 编辑器导出设置

- 选择 **JSON 格式**（不要用二进制 `.skel`，spine-lua 默认解析 JSON）
- 导出 Atlas + PNG
- 将 `.json`、`.atlas`、`.png` 放到 `assets/Spine/角色名/` 目录

### 2.3 目录结构

```
scripts/libs/spine-lua/    ← Spine 官方 Lua runtime
assets/Spine/
└── 角色名/
    ├── skeleton.json      ← 骨骼数据
    ├── skeleton.atlas     ← 图集描述
    └── skeleton.png       ← 合图纹理
```

## 3. 加载骨骼数据

```lua
local spine = require "libs.spine-lua.spine"

-- 自定义纹理加载器（对接 UrhoX/NanoVG 资源系统）
local function createTextureLoader()
    return function(path)
        local image = nvgCreateImage(vg, "Spine/角色名/" .. path, 0)
        return { image = image, width = 0, height = 0 }
    end
end

-- 加载骨骼
local atlasData = cache:GetResource("TextFile", "Spine/角色名/skeleton.atlas"):GetText()
local atlas = spine.TextureAtlas.new(atlasData, createTextureLoader())
local jsonData = cache:GetResource("TextFile", "Spine/角色名/skeleton.json"):GetText()
local skeletonData = spine.SkeletonJson.new(
    spine.AtlasAttachmentLoader.new(atlas)
):readSkeletonDataString(jsonData)

-- 创建骨骼实例
local skeleton = spine.Skeleton.new(skeletonData)
skeleton.x = 400
skeleton.y = 500
skeleton.scaleY = -1  -- UrhoX Y轴向上，Spine Y轴向下，需要翻转

-- 创建动画状态（支持混合过渡）
local animStateData = spine.AnimationStateData.new(skeletonData)
animStateData.defaultMix = 0.2  -- 默认动画过渡混合时间（秒）
local animationState = spine.AnimationState.new(animStateData)
animationState:setAnimationByName(0, "idle", true)  -- track 0 播放 idle 循环
```

**关键点**：`skeleton.scaleY = -1` 是必须的，因为 Spine 使用 Y 轴向下的坐标系，UrhoX 使用 Y 轴向上。

## 4. NanoVG 渲染

```lua
function HandleNanoVGRender(eventType, eventData)
    nvgBeginFrame(vg, width, height, 1.0)

    -- 更新动画
    local dt = eventData["TimeStep"]:GetFloat()
    animationState:update(dt)
    animationState:apply(skeleton)
    skeleton:updateWorldTransform()

    -- 遍历绘制顺序渲染
    for _, slot in ipairs(skeleton.drawOrder) do
        local attachment = slot.attachment
        if attachment and attachment.type == spine.AttachmentType.region then
            -- 计算世界坐标顶点
            local vertices = {}
            attachment:computeWorldVertices(slot, vertices)
            -- 用 NanoVG 绘制纹理区域（需实现仿射变换绘制函数）
            drawRegionAttachment(vg, slot, attachment, vertices)
        end
    end

    nvgEndFrame(vg)
end
```

> `drawRegionAttachment` 函数需要根据顶点坐标做仿射变换将纹理区域映射到屏幕位置，代码较长，核心是使用 `nvgTransform` + `nvgImagePattern` 绘制变换后的纹理矩形。

## 5. 动画控制

### 5.1 切换动画（带混合过渡）

```lua
-- 直接切换到 walk（自动应用 defaultMix 过渡）
animationState:setAnimationByName(0, "walk", true)
```

### 5.2 多轨道叠加

```lua
-- track 0: 基础动作（循环）
animationState:setAnimationByName(0, "walk", true)

-- track 1: 一次性动画（如攻击），播完自动回 idle
animationState:setAnimationByName(1, "attack", false)
animationState:addAnimationByName(1, "idle", true, 0)  -- 攻击结束后回 idle
```

### 5.3 自定义混合时间

```lua
-- 指定特定动画对之间的混合时间
animStateData:setMix("walk", "run", 0.3)
animStateData:setMix("run", "idle", 0.5)
```

## 6. 性能注意事项

| 维度 | 建议 |
|------|------|
| 角色数量 | spine-lua 纯 Lua 实现，建议 **10 个以内** |
| 渲染开销 | NanoVG 渲染比原生 Sprite 大，适合角色少但动画质量高的场景 |
| 大量角色 | 如需大量 Spine 角色（RTS 等），建议预渲染为帧序列 Sprite |
| Spine 版本 | spine-lua 版本需与 Spine 编辑器版本匹配（4.x 对 4.x） |

## 7. 方案优劣总结

| 优势 | 劣势 |
|------|------|
| 完全兼容 Spine 编辑器所有特性（网格变形、IK、路径约束等） | 纯 Lua 性能有上限 |
| 不需要修改引擎源码 | NanoVG 渲染层需自行实现 |
| 跨平台一致性好 | 不支持 `.skel` 二进制格式 |
| 官方维护 runtime，格式兼容性有保障 | 调试复杂度较高 |

---

*素材来源：TapTap 制造论坛帖子《Spine 骨骼动画接入教程——从导出到 UrhoX 播放》*
*蒸馏日期：2026-04-26*

# Spine 骨骼动画 Runtime 完整方案

> **这是什么**：在 TapTap Maker / UrhoX 中加载和播放 Spine 2D 骨骼动画的完整 Runtime 实现方案，包含 JSON 解析、骨骼树构建、动画插值、CustomGeometry 渲染、IK 约束、FFD 变形、Mesh 附件等全流程。
>
> **原作者**：大雄
> **推荐度**：L2（完整可运行的 Runtime 库，附带 5 个 Spine 示例资源和演示 Demo，已在 TapTap Maker 平台验证通过。因 Spine 版本兼容覆盖面有限（2.x/3.x JSON），且部分特性如逐顶点颜色尚未实现，故定为参考级。）
> **适用场景**：需要在 UrhoX/TapTap Maker 中使用 Spine 骨骼动画的项目，如角色动画、UI 动效、怪物动画等。
>
> **同类对比**：
> - **vs 无争-龙骨动画Runtime**：大雄方案专注 Spine 格式（.json），无争方案专注龙骨格式（DragonBones）。两者渲染层都基于 CustomGeometry，但骨骼数据结构和动画格式不同，不可互换。
> - **特色**：提供了完整的库文件 + 演示 Demo + 5 套 Spine 示例资源，开箱即用。
> - **优点**：支持 Mesh 附件、加权顶点、FFD 变形、IK 约束等高级特性；atlas 解析独立实现，不依赖第三方。
> - **缺点**：仅支持 Spine JSON 格式（不支持 .skel 二进制）；不支持逐顶点颜色；Spine 4.x 格式未验证。

---

## 1. 核心架构概览

```
Spine JSON + Atlas JSON + PNG 纹理
        ↓
   SpineRuntime.Load()          ← 解析数据、建立骨骼树
        ↓
   SpineRuntime.CreateInstance() ← 创建场景实例（Node 树 + CustomGeometry）
        ↓
   SpineRuntime.SetAnimation()   ← 设置播放动画
        ↓
   SpineRuntime.Update(dt)       ← 每帧更新：插值 → 骨骼变换 → 几何重建
```

**渲染原理**：每个 Slot 对应一个 CustomGeometry 节点，挂载在骨骼节点树下。Region 附件用 4 顶点矩形，Mesh 附件用三角形列表。材质统一使用 `DiffAlpha.xml`（透明混合）。

**坐标转换**：Spine 使用像素坐标，UrhoX 使用米。库内定义 `PIXEL_SIZE = 0.01`，即 1 Spine 像素 = 0.01 UrhoX 单位。

---

## 2. 资源准备

### 2.1 所需文件

每个 Spine 角色需要 **3 个文件**：

| 文件 | 格式 | 说明 |
|------|------|------|
| 骨骼数据 | `.json` | Spine 编辑器导出的 JSON 格式（**不支持 .skel 二进制**） |
| 图集描述 | `.json`（包装） | Atlas 文本内容包装在 JSON 中（见下文） |
| 纹理图片 | `.png` | 合图纹理（atlas 引用的图片） |

### 2.2 Atlas 必须包装为 JSON

**关键约束**：TapTap Maker 构建系统不会打包 `.atlas` / `.txt` 后缀的文件，因此必须将 atlas 文本包装进 JSON。

**原始 atlas 文本**（如 `spineboy.atlas`）：
```
spineboy.png
size: 1024,512
format: RGBA8888
filter: Linear,Linear
repeat: none
head
  rotate: false
  xy: 2, 2
  size: 84, 70
  orig: 84, 70
  offset: 0, 0
  index: -1
...
```

**包装为 JSON**（保存为 `spineboy-atlas-data.json`）：
```json
{
  "atlas": "spineboy.png\nsize: 1024,512\nformat: RGBA8888\nfilter: Linear,Linear\nrepeat: none\nhead\n  rotate: false\n  xy: 2, 2\n  size: 84, 70\n  orig: 84, 70\n  offset: 0, 0\n  index: -1\n..."
}
```

**包装方法**：将 atlas 全文作为一个字符串，放入 JSON 的 `atlas` 字段。换行符转为 `\n`。

> 可以用文本编辑器手动处理，也可以写脚本自动转换。

### 2.3 目录结构示例

```
assets/Spine/
├── spineboy/
│   ├── spineboy.json            ← 骨骼数据
│   ├── spineboy-atlas-data.json ← atlas 包装为 JSON
│   └── spineboy.png             ← 合图纹理
├── dragon/
│   ├── dragon.json
│   ├── dragon-atlas-data.json
│   └── dragon.png
```

---

## 3. 基本用法

### 3.1 引入库

```lua
local SpineRuntime = require("SpineRuntime")  -- 或项目实际路径
```

### 3.2 加载数据

```lua
-- 参数：骨骼 JSON 路径、atlas JSON 路径
local spineData = SpineRuntime.Load(
    "Spine/spineboy/spineboy.json",
    "Spine/spineboy/spineboy-atlas-data.json"
)
```

`Load()` 会解析骨骼层级、皮肤、动画时间轴、atlas 区域等数据，返回一个数据对象（可复用，多实例共享同一份数据）。

### 3.3 创建实例

```lua
-- 参数：场景 scene、数据对象、纹理路径、rootNode 位置、缩放
local instance = SpineRuntime.CreateInstance(
    scene_,
    spineData,
    "Spine/spineboy/spineboy.png",
    Vector3(0, -2, 0),    -- 位置
    0.5                    -- 缩放（相对于 PIXEL_SIZE=0.01 的倍率）
)
```

`CreateInstance()` 会在 scene 中创建完整的节点树：
- 一个 rootNode，包含所有骨骼子节点
- 每个 slot 对应一个 CustomGeometry 节点
- 材质使用 `DiffAlpha.xml`，自动关闭背面剔除（`CULL_NONE`）

### 3.4 播放动画

```lua
-- 设置动画（名称、是否循环）
SpineRuntime.SetAnimation(instance, "walk", true)

-- 在 Update 中每帧调用
function HandleUpdate(eventType, eventData)
    local dt = eventData["TimeStep"]:GetFloat()
    SpineRuntime.Update(instance, dt)
end
```

### 3.5 切换动画

```lua
-- 直接切换
SpineRuntime.SetAnimation(instance, "jump", false)

-- 切换后回到循环动画（需自行管理）
-- 可以在非循环动画播完后切回
if instance.animTime >= instance.animDuration and not instance.animLoop then
    SpineRuntime.SetAnimation(instance, "walk", true)
end
```

### 3.6 移动/变换

```lua
-- 移动整个角色
instance.rootNode.position = Vector3(x, y, 0)

-- 缩放
instance.rootNode:SetScale(newScale)

-- 翻转（通过负缩放）
instance.rootNode:SetScale(Vector3(-1, 1, 1) * scale)
```

---

## 4. 场景配置要求

### 4.1 正交相机

Spine 动画通常在正交投影下显示效果最佳：

```lua
local cameraNode = scene_:CreateChild("Camera")
local camera = cameraNode:CreateComponent("Camera")
camera.orthographic = true
camera.orthoSize = 5.0  -- 视野高度（米）
cameraNode.position = Vector3(0, 0, -10)
```

### 4.2 Zone 灯光

确保场景有 Zone 提供环境光，否则模型可能全黑：

```lua
local zoneNode = scene_:CreateChild("Zone")
local zone = zoneNode:CreateComponent("Zone")
zone.ambientColor = Color(1, 1, 1)  -- 全亮环境光
zone.boundingBox = BoundingBox(Vector3(-100, -100, -100), Vector3(100, 100, 100))
```

---

## 5. 技术细节

### 5.1 骨骼世界变换

骨骼采用亲和变换矩阵（2x2 + 平移），从 root 到 leaf 逐级累乘：

```
世界变换 = 父骨骼世界变换 × 本地变换(平移 + 旋转 + 缩放 + shear)
```

变换参数：
- `x, y`：相对父骨骼的平移（Spine 像素）
- `rotation`：旋转角度
- `scaleX, scaleY`：缩放
- `shearX, shearY`：剪切（用于倾斜效果）

### 5.2 动画插值

支持的时间轴类型：

| 时间轴 | 插值方式 | 说明 |
|--------|---------|------|
| `rotate` | 线性（最短路径） | 骨骼旋转 |
| `translate` | 线性/步进 | 骨骼平移 |
| `scale` | 线性/步进 | 骨骼缩放 |
| `attachment` | 步进 | 切换附件（显示/隐藏部件） |
| `color` | （预留） | 逐顶点颜色（当前未实现） |
| `ffd` / `deform` | 线性 | 自由变形（Mesh 顶点偏移） |

**Curve 支持**：目前仅实现线性和 stepped（步进），贝塞尔曲线（`curve: [cx1,cy1,cx2,cy2]`）当前退化为线性。

### 5.3 附件类型

| 类型 | 说明 | 渲染方式 |
|------|------|---------|
| `region` | 矩形图片区域 | 4 顶点 2 三角形 |
| `mesh` / `skinnedmesh` / `weightedmesh` | 网格（含顶点权重） | 三角形列表 |
| `boundingbox` | 碰撞边界 | 不渲染 |
| `linkedmesh` | 链接网格 | 继承源 mesh 数据 |

### 5.4 IK 约束

支持单骨骼和双骨骼 IK：
- **单骨骼 IK**：骨骼直接朝向目标
- **双骨骼 IK**：类似手臂的肘部弯折效果（使用三角函数求解）
- `bendPositive`：控制弯折方向
- `mix`：IK 影响权重（0~1 之间插值）

### 5.5 Spine 版本差异

| 特性 | Spine 2.x | Spine 3.x |
|------|-----------|-----------|
| 皮肤数据格式 | `skins: { skinName: { slotName: { ... } } }` | `skins: [ { name: "default", attachments: { ... } } ]` |
| FFD 字段名 | `ffd` | `deform` |
| Mesh 附件 | `skinnedmesh` / `weightedmesh` | `mesh`（通过 vertices 长度判断是否加权） |

库内部自动检测并兼容两种格式。

---

## 6. 已知问题与解决方案

### 6.1 模型全黑

**原因**：CustomGeometry 默认背面剔除，Spine 某些部件的面法线可能朝反方向。

**解决**：库内已自动设置 `CULL_NONE`。如果仍然出现，检查材质：

```lua
material.cullMode = CULL_NONE
```

### 6.2 动画时长为 0

**原因**：某些导出的 JSON 骨骼动画只有一帧或无关键帧。

**解决**：库内部会取所有时间轴最大 time 值作为 duration。如果仍为 0，可能是 JSON 格式异常，检查导出设置。

### 6.3 Atlas `rotate: true` 的 UV 映射

**原因**：Spine atlas 中 `rotate: true` 表示纹理区域在合图中被旋转了 90 度存储。

**解决**：库内已处理旋转 UV 映射（交换 U/V 坐标并调整偏移），但需注意这是个常见的坑点。

### 6.4 Mesh 边界闪烁

**原因**：网格重建时三角形面法线翻转。

**解决**：库内强制 `CULL_NONE` 并保持双面渲染。

---

## 7. 完整 Demo 模板

```lua
-- main.lua: Spine 动画演示
local SpineRuntime = require("SpineRuntime")

local scene_, camera_
local spineInstances = {}

-- 角色配置表
local characters = {
    {
        name = "spineboy",
        jsonPath = "Spine/spineboy/spineboy.json",
        atlasJsonPath = "Spine/spineboy/spineboy-atlas-data.json",
        texturePath = "Spine/spineboy/spineboy.png",
        position = Vector3(0, -2, 0),
        scale = 0.5,
        defaultAnim = "walk",
    },
}

function Start()
    -- 创建场景
    scene_ = Scene()
    scene_:CreateComponent("Octree")

    -- Zone 灯光
    local zoneNode = scene_:CreateChild("Zone")
    local zone = zoneNode:CreateComponent("Zone")
    zone.ambientColor = Color(1, 1, 1)
    zone.boundingBox = BoundingBox(Vector3(-100,-100,-100), Vector3(100,100,100))

    -- 正交相机
    local cameraNode = scene_:CreateChild("Camera")
    camera_ = cameraNode:CreateComponent("Camera")
    camera_.orthographic = true
    camera_.orthoSize = 6.0
    cameraNode.position = Vector3(0, 0, -10)

    renderer:SetViewport(0, Viewport:new(scene_, camera_))

    -- 加载所有角色
    for _, cfg in ipairs(characters) do
        local data = SpineRuntime.Load(cfg.jsonPath, cfg.atlasJsonPath)
        if data then
            local inst = SpineRuntime.CreateInstance(
                scene_, data, cfg.texturePath,
                cfg.position, cfg.scale
            )
            if inst then
                SpineRuntime.SetAnimation(inst, cfg.defaultAnim, true)
                table.insert(spineInstances, inst)
            end
        end
    end

    SubscribeToEvent("Update", "HandleUpdate")
end

function HandleUpdate(eventType, eventData)
    local dt = eventData["TimeStep"]:GetFloat()
    for _, inst in ipairs(spineInstances) do
        SpineRuntime.Update(inst, dt)
    end
end
```

---

## 8. API 参考

### SpineRuntime.Load(jsonPath, atlasJsonPath)

解析 Spine JSON 和 atlas 数据，返回数据对象。

| 参数 | 类型 | 说明 |
|------|------|------|
| `jsonPath` | string | 骨骼 JSON 文件路径（资源相对路径） |
| `atlasJsonPath` | string | Atlas JSON 文件路径 |
| **返回** | table/nil | 数据对象（解析失败返回 nil） |

### SpineRuntime.CreateInstance(scene, data, texturePath, position, scale)

在场景中创建 Spine 角色实例。

| 参数 | 类型 | 说明 |
|------|------|------|
| `scene` | Scene | 目标场景 |
| `data` | table | `Load()` 返回的数据对象 |
| `texturePath` | string | 纹理图片路径 |
| `position` | Vector3 | rootNode 位置 |
| `scale` | number | 缩放倍率（基于 PIXEL_SIZE=0.01） |
| **返回** | table/nil | 实例对象 |

### SpineRuntime.SetAnimation(instance, animName, loop)

设置当前播放的动画。

| 参数 | 类型 | 说明 |
|------|------|------|
| `instance` | table | 实例对象 |
| `animName` | string | 动画名称 |
| `loop` | boolean | 是否循环播放 |

### SpineRuntime.Update(instance, dt)

每帧更新动画。在 `HandleUpdate` 中调用。

| 参数 | 类型 | 说明 |
|------|------|------|
| `instance` | table | 实例对象 |
| `dt` | number | 帧时间步长 |

### SpineRuntime.GetSlotDebugInfo(instance)

获取所有活跃 slot 的调试信息（世界坐标四边形/AABB），用于 debug 绘制。

| 参数 | 类型 | 说明 |
|------|------|------|
| `instance` | table | 实例对象 |
| **返回** | table | `{ { name, slotIdx, att, isMesh, boneName, verts } }` |

---

## 9. 实例属性参考

`CreateInstance()` 返回的实例对象包含以下常用字段：

| 字段 | 类型 | 说明 |
|------|------|------|
| `rootNode` | Node | 根节点，可设置 position/scale/rotation |
| `animName` | string | 当前动画名称 |
| `animTime` | number | 当前播放时间 |
| `animDuration` | number | 当前动画总时长 |
| `animLoop` | boolean | 是否循环 |
| `data` | table | 共享的数据对象 |
| `boneNodes` | table | 骨骼名→Node 映射 |
| `slots` | table | Slot 名→信息映射 |
| `ffdDeltas` | table | FFD 变形偏移量缓存 |
| `rootScale` | number | 创建时的缩放值 |

---

## 10. 资源获取

完整的 SpineRuntime 库文件、演示 Demo 和 5 套 Spine 示例资源可从以下仓库获取：

**仓库地址**：https://gitee.com/silevtyu/TapTap-Maker-Spine

仓库结构：
```
scripts/
├── main.lua              ← 演示 Demo（5 个角色 + HUD 控制）
└── SpineRuntime.lua       ← 运行时库（~1600 行）
assets/Spine/
├── spineboy/              ← Spine 官方示例角色
├── alien/                 ← 外星人
├── coin/                  ← 旋转硬币
├── 34025/                 ← 恶魔猎手
└── dragon/                ← 龙
```

---

## 11. 快速接入清单

- [ ] 从仓库复制 `SpineRuntime.lua` 到项目 `scripts/` 目录
- [ ] 准备 Spine 资源：`.json`（骨骼）+ `.png`（纹理）+ atlas 文本
- [ ] 将 atlas 文本包装为 JSON（`{ "atlas": "..." }`）
- [ ] 资源放入 `assets/Spine/角色名/` 目录
- [ ] 代码中 `require("SpineRuntime")` 并按第 3 节用法调用
- [ ] 确保场景有正交相机和 Zone 环境光
- [ ] 在 `HandleUpdate` 中每帧调用 `SpineRuntime.Update(inst, dt)`
- [ ] 构建运行，确认动画正常播放

---

*素材来源：TapTap 论坛帖子 + Gitee 仓库 https://gitee.com/silevtyu/TapTap-Maker-Spine*
*蒸馏日期：2026-04-23*

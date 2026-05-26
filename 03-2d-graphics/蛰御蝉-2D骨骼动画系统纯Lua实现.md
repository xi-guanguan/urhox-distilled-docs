# 2D 骨骼动画系统纯 Lua 实现

- **这是什么**: 基于 UrhoX + NanoVG 的 2D 骨骼动画系统，纯 Lua 实现。核心引擎（Skeleton.lua）与角色数据完全分离，同一套引擎可驱动任意骨骼结构和动画数据。附带完整的 16 骨骼人形角色数据、7 个身体动画 + 3 个面部动画，以及详细的参数调整参考表
- **原作者**: 蛰御蝉
- **推荐度**: L2（参考学习——系统完整、文档详尽，当前渲染为纯色圆角矩形，贴图渲染需自行扩展；适合需要自定义 2D 骨骼动画且不想依赖外部工具的项目）
- **适用场景**: 横版格斗/冒险游戏的 2D 角色动画、需要数据驱动的可复用骨骼动画系统

---

## 核心设计原则

1. **引擎通用，数据驱动**：所有角色差异都在数据层，引擎代码不改
2. **三层动画叠加**：身体层 + 上半身叠加层 + 面部层，互不干扰
3. **增量动画模式**：关键帧值叠加到初始姿态，零值 = 不变

---

## 文件结构

```
scripts/
  skeleton_demo.lua       -- Demo 入口（角色数据 + 渲染 + UI）
  animation/
    Skeleton.lua           -- 核心引擎（通用，不含任何角色数据）
```

---

## 三层动画架构

```
┌─────────────────────────────────────────────┐
│  第3层: 面部动画叠加层                        │
│  作用: 眨眼、说话、惊讶等表情                  │
│  模式: scaleX/scaleY 绝对值覆盖，其余增量叠加  │
│  范围: 面部骨骼（眼、嘴）                      │
├─────────────────────────────────────────────┤
│  第2层: 上半身叠加层                          │
│  作用: 行走/奔跑中攻击，拔剑，举盾等           │
│  模式: 增量叠加，覆盖上半身骨骼                │
│  范围: 由 setUpperBodyBones() 指定            │
│  特点: 播完自动停止，下半身保持基础动画         │
├─────────────────────────────────────────────┤
│  第1层: 身体动画（基础层）                     │
│  作用: 待机、行走、奔跑、跳跃等全身动作        │
│  模式: 增量叠加到 setupPose                   │
│  范围: 所有骨骼                               │
└─────────────────────────────────────────────┘
```

**执行顺序**：每帧先重置 → 身体层 → 上半身层覆盖 → 面部层覆盖 → 世界变换

**典型组合**：
- 站立攻击 = 全身播放 attack
- 行走中攻击 = 身体层 walk + 上半身层 attack
- 任何时候眨眼 = 面部层 blink（独立于身体/上半身）

---

## 核心引擎 API

### 创建实例

```lua
local Skeleton = require("animation.Skeleton")
local skel = Skeleton.new(skeletonData, animations)
```

### 关键属性

| 属性 | 说明 |
|------|------|
| `skel.x, skel.y` | 整体位置（屏幕坐标） |
| `skel.globalScale` | 整体缩放（默认 1.0） |
| `skel.flipX` | 水平翻转 |
| `skel.direction` | 朝向 "front" / "back" |
| `skel.speed` | 播放速度倍率 |
| `skel.loop` | 是否循环播放 |

### 关键方法

| 方法 | 说明 |
|------|------|
| `skel:play(animName)` | 播放身体动画 |
| `skel:update(dt)` | 每帧更新（内部自动执行全部流程） |
| `skel:setUpperBodyBones(boneNames)` | 设置上半身骨骼名列表 |
| `skel:playUpperBodyAnim(animName)` | 播放上半身叠加动画 |
| `skel:registerFaceAnimations(faceAnims)` | 注册面部动画 |
| `skel:playFaceAnim(animName)` | 播放面部动画 |
| `skel:setDirection(dir)` | 切换朝向，自动切换附件 |

---

## 数据格式

### 骨骼定义

```lua
{
    name     = "chest",
    parent   = "root",         -- nil = 根骨骼
    x = 0,   y = -10,          -- 相对父关节局部偏移（像素）
    rotation = 0,              -- 弧度
    scaleX = 1, scaleY = 1,
    attachments = {            -- 可视附件（多方向）
        front = { offsetX=0, offsetY=-22, width=60, height=56, radius=4, color={55,65,100,255} },
        back  = { ... }
    }
}
```

**规则**：父骨骼必须在子骨骼之前定义；Y 向下为正（屏幕坐标）。

### 身体动画（增量模式）

```lua
{
    name = "idle",
    duration = 2.4,
    bones = {
        chest = {
            { time = 0.0, y = 0 },
            { time = 1.2, y = -2 },    -- 增量: setupY + (-2)
            { time = 2.4, y = 0 },
        },
    }
}
```

**可控属性**：x/y（位移增量）、rotation（旋转增量，弧度）、scaleX/scaleY（绝对缩放值）。插值方式：线性。

### 面部动画（绝对值模式）

scaleX/scaleY 使用绝对值直接覆盖骨骼缩放，x/y/rotation 仍为增量。

---

## 人形角色骨骼层级（16 骨骼）

```
root（腰部中心）
├── chest（胸部）
│   ├── head → left_eye / right_eye / mouth
│   ├── arm_upper_L → arm_lower_L → hand_L
│   └── arm_upper_R → arm_lower_R → hand_R
├── leg_upper_L → leg_lower_L
└── leg_upper_R → leg_lower_R
```

上半身骨骼集合（叠加层影响范围）：chest, head, arm_upper_L/R, arm_lower_L/R, hand_L/R

---

## 动画参数速查表

### rotation 参考范围

| 级别 | 范围（弧度） | 场景 |
|------|-------------|------|
| 微动 | ±0.03 ~ 0.05 | 呼吸 |
| 小幅 | ±0.3 ~ 0.4 | 行走摆臂 |
| 中幅 | ±0.5 ~ 0.7 | 奔跑摆臂 |
| 大幅 | ±0.7 ~ 1.5 | 攻击挥砍 |
| 整圈 | 6.283 (2π) | 旋转 |

### y 位移参考范围

| 级别 | 范围（像素） | 场景 |
|------|-------------|------|
| 微动 | -1 ~ -3 | 呼吸起伏 |
| 中幅 | -5 | 奔跑颠簸 |
| 蹲下 | 5 ~ 6（正值=下沉） | 蓄力 |
| 腾空 | -25 ~ -30（负值=上升） | 跳跃 |

### duration 参考范围

| 类型 | 时长 |
|------|------|
| 快速动作（攻击） | 0.3 ~ 0.5s |
| 中速动作（跳跃） | 0.6 ~ 0.8s |
| 慢速循环（呼吸） | 2.0 ~ 3.0s |
| 移动循环（行走） | 0.6 ~ 0.9s |
| 移动循环（奔跑） | 0.4 ~ 0.6s |

### 左右交替动画口诀

- L 和 R 同一属性起始值互为反相（L=0.4 则 R=-0.4）
- 半周期位置值互换
- 小腿/前臂弯曲通常同向（都是正值弯曲）

---

## 已实现动画总览

**身体动画 7 个**：idle(2.4s循环)、walk(0.8s循环)、run(0.5s循环)、attack(0.5s单次)、jump(0.7s单次)、spin(0.5s单次)、jump_slash(0.8s单次)

**面部动画 3 个**：blink(0.25s)、talk(0.5s循环)、surprised(0.8s)

**手部状态 2 个**：open(张开)、fist(握拳) —— 附件替换实现

---

## 扩展指南

### 创建不同角色

只需提供不同的骨骼数据和动画数据：

```lua
local warrior = Skeleton.new(WARRIOR_BONES, WARRIOR_ANIMS)
local mage    = Skeleton.new(MAGE_BONES, MAGE_ANIMS)
```

不同角色可共用骨骼结构（只改尺寸/颜色），也可用完全不同的骨骼结构。

### 非人形骨骼示例

- **史莱姆**：root → body，用 scaleX/scaleY 挤压拉伸做果冻弹跳
- **巨龙**：多分支骨骼树（spine → chest → neck/wings/tail + 4 legs）
- **蛇**：链式骨骼（head → spine1~4 → tail），每节 rotation 递增相位差 = 波浪扭动

### 贴图渲染（替换纯色矩形）

当前 `drawBoneRect()` 用纯色圆角矩形。升级为贴图：
1. 每个骨骼准备贴图文件（按部位切图）
2. Start() 中 `nvgCreateImage()` 加载（只调用一次）
3. drawBoneRect() 中判断有贴图 → `nvgImagePattern` 填充，无贴图 → 退回纯色

**建议**：先用 AI 绘画生成全身参考图，再分部位转向切割。正/背面需两套贴图。

---

## Demo 操作快捷键

```
1~7 = 身体动画（待机/行走/奔跑/攻击/跳跃/旋转/跳劈）
Q/W = 手张开/握拳
Z/X/C = 眨眼/说话/惊讶
D = 正/背面切换  F = 水平翻转  J = 关节显隐
```

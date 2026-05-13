# 2D 关键帧动作编辑器开发思路（KEIS）

> **这是什么**: 在 UrhoX 内实现一个可实时预览的 2D 关键帧动作编辑器，支持部件旋转/缩放/平移，JSON 导出后可交给外部大语言模型批量生成动作。  
> **原作者**: Keisukenaaa  
> **推荐度**: L2（参考学习价值 — 提供完整思路和工作流，适合俯视角 2D 游戏的动作系统设计参考）  
> **适用场景**: 俯视角 2D 游戏（武侠、ARPG 等）需要角色通用动作、不依赖大量精灵图的场景

---

## 需求分析

### 核心痛点

- 绘制大量精灵图 → 美术负担大且角色无法通用
- 让 AI 口头描述动作 → 不精确，调试循环慢（描述 → 编译 → 进游戏查看）
- 俯视角 2D 游戏的动作资源市面上极少

### 设计目标

| 目标 | 说明 |
|------|------|
| 角色通用 | 同一套动作数据适用于所有角色 |
| 实时预览 | 编辑器内直接查看动作效果，无需编译 |
| 可导出 | 动作数据序列化为 JSON，支持外部工具链 |
| 低美术门槛 | 部件级拼装，不需要逐帧绘制 |

---

## 骨架设计

### 部件化角色

将角色拆分为独立可动的部件，每个部件可单独进行旋转/缩放/位置调节：

```
角色骨架示例（俯视角武侠）：
├── 头部 (head)
├── 身体 (body)
├── 左手 (leftHand)
├── 右手 (rightHand)
└── 武器 (weapon)
```

**前置条件**：Maker 需要事先确定角色有哪些可运动部件。俯视角游戏通常 4-6 个部件即可。

### 部件属性

每个部件在每一帧拥有以下可编辑属性：

```lua
-- 单个部件的帧数据
{
    rotation = 0,        -- 旋转角度（度）
    scaleX = 1.0,        -- X 缩放
    scaleY = 1.0,        -- Y 缩放
    offsetX = 0,         -- X 偏移
    offsetY = 0,         -- Y 偏移
}
```

---

## 编辑器功能

### 核心交互

- 时间轴 + 关键帧：类似 Roblox 动作编辑器的时间轴面板
- 选中部件后通过**滑块**调节旋转/缩放/位置
- 关键帧之间**自动插值**（线性补间）
- 支持循环播放预览
- 回归默认姿态按钮
- 可选择预设基础动作作为编辑起点

### 辅助功能

| 功能 | 说明 |
|------|------|
| Ctrl+Z 撤回 | 操作历史栈，支持多步撤回 |
| 操作反馈 | 屏幕左上角弹出成功/失败提示（含失败原因） |
| 武器绑定调试 | 独立界面，调整武器在手部的位置（正手/反手握持） |

### 武器绑定

武侠游戏中同一把武器不同招式可能需要不同握持方式：

```lua
-- 武器绑定数据
{
    weaponId = "long_sword",
    gripMode = "forward",     -- forward=正手, reverse=反手
    offsetX = 0,
    offsetY = -5,
    rotation = 0,
}
```

---

## 数据导出（重点）

### 问题：编辑器数据如何应用到游戏中？

UrhoX 编辑器的文本框**无法复制内容**（平台限制），且云变量方式对于频繁迭代过于繁琐。

### 解决方案：JSON 序列化 + 截图导出

**方法 1：AI 拉取**

让 AI 将当前保存的动作数据以 JSON 文本形式显示在界面上，手动记录。消耗一定积分但准确。

**方法 2：截图 → 图转文（推荐）**

1. 将 JSON 数据显示在编辑器界面上
2. 截图
3. 将截图发给 AI → 图转文 → 直接得到 JSON

这种方式更快捷，且几乎不消耗积分。

### 动作数据 JSON 格式

```json
{
    "actionName": "slash_forward",
    "frameCount": 8,
    "fps": 12,
    "loop": false,
    "keyframes": {
        "0": {
            "head":      { "rotation": 0, "scaleX": 1, "scaleY": 1, "offsetX": 0, "offsetY": 0 },
            "body":      { "rotation": 0, "scaleX": 1, "scaleY": 1, "offsetX": 0, "offsetY": 0 },
            "rightHand": { "rotation": -30, "scaleX": 1, "scaleY": 1, "offsetX": 5, "offsetY": -10 },
            "weapon":    { "rotation": -30, "scaleX": 1, "scaleY": 1, "offsetX": 5, "offsetY": -15 }
        },
        "4": {
            "rightHand": { "rotation": 60, "offsetX": 10, "offsetY": 5 },
            "weapon":    { "rotation": 60, "offsetX": 12, "offsetY": 3 }
        }
    }
}
```

---

## 外部 LLM 批量生成动作（进阶）

### 工作流

这是整个方案的最大亮点——编辑器 + JSON 格式 + 外部 LLM 构成闭环：

```
① 在编辑器里手动制作 1-2 个参考动作
  ↓
② 导出 JSON + 让 AI 反向输出动作制作流程文档（md）
  ↓（文档内容：骨骼定义、朝向约定、各部件作用、JSON 格式说明）
  ↓
③ 将流程文档 + 参考 JSON 喂给外部大语言模型
  ↓
④ 口头描述新动作 → LLM 直接生成 JSON
  ↓
⑤ 将 JSON 导入编辑器微调 → 导出最终版
  ↓
⑥ 批量将 JSON 交给 UrhoX AI 制作成游戏动作资产
```

### 关键步骤：生成流程文档

让 UrhoX AI 输出一份 md 文档，描述：

- 角色骨骼结构（哪些部件、层级关系）
- 人物默认朝向
- 各部件的旋转/缩放含义
- JSON 格式规范
- 参考动作示例

这份文档作为外部 LLM 的"动作制作规范"，确保生成的 JSON 与编辑器兼容。

### 效果

> "之后我的动作基本全口述，让大语言模型生成"

首次校准方向后，后续动作可以纯口头描述生成，再到编辑器里微调即可。

---

## 游戏侧动作播放

拿到 JSON 后，在游戏中实现部件动画播放：

```lua
-- 伪代码：关键帧插值播放
function PlayAction(character, actionData)
    local totalFrames = actionData.frameCount
    local fps = actionData.fps
    local elapsed = 0

    return function(dt)
        elapsed = elapsed + dt
        local frame = (elapsed * fps) % totalFrames
        
        -- 找到当前帧前后的关键帧
        local prevKey, nextKey = FindSurroundingKeyframes(actionData.keyframes, frame)
        local t = GetInterpolationFactor(prevKey, nextKey, frame)
        
        -- 对每个部件进行插值
        for partName, prevData in pairs(prevKey.parts) do
            local nextData = nextKey.parts[partName] or prevData
            local node = character.parts[partName]
            
            node.rotation = Lerp(prevData.rotation, nextData.rotation, t)
            node.scale = Vector2(
                Lerp(prevData.scaleX, nextData.scaleX, t),
                Lerp(prevData.scaleY, nextData.scaleY, t)
            )
            node.position = Vector2(
                Lerp(prevData.offsetX, nextData.offsetX, t),
                Lerp(prevData.offsetY, nextData.offsetY, t)
            )
        end
    end
end
```

---

## 适用边界

- **适合**：俯视角 2D 游戏、部件拼装式角色、不追求高精度 IK 的项目
- **不适合**：需要精密骨骼动画的侧视角游戏（横版格斗等）、3D 游戏
- **优势**：零额外美术资源、角色通用、可批量生成
- **局限**：部件级动画精度有限，复杂动作（如翻滚、飞踢）表现力不如逐帧精灵图

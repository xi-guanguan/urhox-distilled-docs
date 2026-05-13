# Codex 游戏素材生成 Skill 实战：agent-sprite-forge

> **这是什么**：一个面向 AI 编程助手的 Skill 仓库，让开发者用一句自然语言就能生成游戏级 2D 精灵序列帧、地图和道具——包含完整的 Prompt 工程、后处理管线和质量控制体系。本文蒸馏其核心方法论，引导嗒啦啦开发者将其适配为自己的 Skill。
>
> **原作者**：小陈的第二大脑（公众号）
> **推荐度**：L2（方法论可借鉴，需适配嗒啦啦内置生图能力）
> **适用场景**：想让 AI 助手批量生成 2D 游戏素材（精灵、动画帧、地图、道具）的开发者
>
> **同类对比**（与本库其他 Skill 文档）：
> - **特色**：唯一一篇聚焦"AI 生图 → 游戏素材"全管线的 Skill 设计
> - **优点**：从 Prompt 模板到后处理脚本到 QC 校验，端到端闭环
> - **缺点**：原始设计面向 OpenAI Codex，需要适配才能用于嗒啦啦

---

## 仓库地址

```
https://github.com/0x0funky/agent-sprite-forge.git
```

> **给你的 AI**：把这个仓库 clone 下来，阅读 `skills/` 目录下的两个 SKILL.md，理解其工作流后按下方指引适配。

---

## 1. 仓库结构速览

```
agent-sprite-forge/
├── skills/
│   ├── generate2dsprite/          # Skill 1: 精灵/动画帧生成
│   │   ├── SKILL.md               # ← 核心：Skill 定义文件
│   │   ├── references/
│   │   │   ├── modes.md           # 资产类型 × 动作 × 网格映射表
│   │   │   └── prompt-rules.md    # Prompt 编写规则手册
│   │   ├── scripts/
│   │   │   └── generate2dsprite.py  # 后处理脚本（去背景/切帧/GIF）
│   │   └── agents/openai.yaml    # Agent 配置
│   │
│   └── generate2dmap/             # Skill 2: 2D 地图生产管线
│       ├── SKILL.md               # ← 核心：Skill 定义文件
│       ├── references/
│       │   ├── map-strategies.md      # 地图管线选择策略
│       │   ├── layered-map-contract.md # 分层地图合约
│       │   └── prop-pack-contract.md   # 道具包合约
│       └── scripts/
│           ├── extract_prop_pack.py       # 道具包切割
│           └── compose_layered_preview.py # 分层预览合成
│
├── README.md
└── requirements.txt               # Python 依赖：Pillow, numpy
```

**阅读顺序建议**：
1. `generate2dsprite/SKILL.md` → 理解精灵生成完整工作流
2. `references/prompt-rules.md` → 掌握 Prompt 编写规则
3. `references/modes.md` → 理解资产类型和网格映射
4. `generate2dmap/SKILL.md` → 理解地图管线
5. `references/layered-map-contract.md` → 分层地图的完整合约

---

## 2. 核心设计思想

### 2.1 Agent-First 架构

```
用户一句话描述（"做个火系法师释放技能的动画"）
  ↓
AI Agent 自主决策
  ├── 资产类型：spell_bundle
  ├── 动作分解：cast + projectile + impact
  ├── 网格布局：2×3 / 1×4 / 2×2
  ├── 艺术风格：pixel_art / clean_hd
  └── Prompt 编写：Agent 自己写，不依赖脚本
  ↓
调用内置生图能力 → 生成原始图
  ↓
Python 脚本做确定性后处理
  ├── 品红色键去除（#FF00FF）
  ├── 网格切帧
  ├── 连通分量分析（去噪/保留主体）
  ├── 对齐 + 缩放
  └── 透明 PNG + GIF 导出
  ↓
QC 校验 → 边缘触碰检测 → 不合格则重生成
```

**关键原则**：脚本不是创意大脑，Agent 才是。脚本只做像素级确定性操作。

### 2.2 品红色键方案

所有生成图统一使用 `#FF00FF`（品红）纯色背景，后处理时做色键去除：

```
阈值去除（threshold=100）→ 边缘 BFS 扩展清理（edge_threshold=150）→ 透明 PNG
```

好处：
- 品红在游戏素材中极少自然出现，误删率低
- 比"透明背景"指令更可靠（AI 生图对"透明"的理解不稳定）
- 支持 soft-matte + despill 处理抗锯齿边缘

### 2.3 参考引导生成

当需要保持角色/风格一致性时：

```
1. 确保参考图在对话上下文中可见（本地文件需先 view_image）
2. Prompt 中明确说明参考角色：保持轮廓/配色/面部特征/服装标记
3. 只改变动作/姿态/特效状态
4. 仍然要求品红背景 + 网格约束
```

---

## 3. 精灵生成：参数推断体系

### 3.1 资产类型（asset_type）

| 类型 | 说明 | 典型用途 |
|------|------|---------|
| `player` | 可控主角 | 四方向行走表、动作表 |
| `npc` | 城镇/野外 NPC | 单帧立绘、行走动画 |
| `creature` | 怪物/Boss/召唤兽 | idle 循环、战斗表 |
| `spell` | 法术序列 | 施法、弹体、爆炸 |
| `projectile` | 飞行物 | 循环飞行动画 |
| `impact` | 命中爆发 | 接触爆炸效果 |
| `prop` | 道具/物件 | 地图道具、拾取物 |

### 3.2 网格布局推断

| 场景 | 推荐网格 | 说明 |
|------|---------|------|
| 小型 idle | 2×2 | 4 帧呼吸/姿态循环 |
| 大型 Boss idle | 3×3 | 9 帧展示级循环 |
| 施法序列 | 2×3 | 6 帧蓄力→释放 |
| 弹体循环 | 1×4 | 4 帧飞行循环 |
| 四方向行走 | 4×4 | 16 帧（4 方向 × 4 步） |
| 命中/爆炸 | 2×2 | 4 帧爆发消散 |

### 3.3 Bundle 预设

| Bundle 类型 | 默认组成 | 用途 |
|------------|---------|------|
| `spell_bundle` | cast + projectile + impact | 完整法术链 |
| `unit_bundle` | idle + combat（+ walk） | 可用单位 |
| `combat_bundle` | idle + attack + hurt | 战斗角色 |
| `line_bundle` | 1-3 个进化形态 | 进化链 |

---

## 4. 地图生成：管线化设计

### 4.1 五轴决策

不是"选一种地图类型"，而是组合五个轴：

| 轴 | 选项 | 说明 |
|----|------|------|
| **视觉模型** | baked_raster / layered_raster / tilemap / parallax | 地图怎么画 |
| **运行时对象** | none / separate_props / y_sorted_props | 道具怎么管理 |
| **碰撞模型** | none / coarse_shapes / precise_shapes / tile_collision | 碰撞怎么算 |
| **美术方向** | clean_hd / pixel_inspired / retro_pixel | 什么画风 |
| **引擎目标** | raw_canvas / Godot_TileMap / Tiled_JSON / ... | 给谁用 |

### 4.2 分层地图工作流（核心创新）

```
1. 生成纯地面底图（无任何立体物件）
   ↓
2. 把底图展示给 AI → 基于底图生成"穿衣参考图"（加上道具的效果图）
   ↓
3. 基于参考图批量生成道具（3×3 道具包 或 逐个生成）
   ↓
4. Python 脚本提取透明道具 + 生成放置 JSON
   ↓
5. 底图 + 透明道具 + 放置数据 → 合成分层预览
   ↓
6. 输出碰撞/区域元数据（阻挡物、行走区、遭遇区、出口）
```

**为什么不直接生成一张完整地图？**
- 立体物件需要碰撞、遮挡排序、交互
- 道具需要复用（同一棵树放多处）
- 分层才能实现"角色走到树后面被遮挡"

### 4.3 道具包批量生成

一次生成 3×3 = 9 个同风格道具：

```
Prompt 要求：
- 每个道具占一格，居中，填充 50-60%
- 品红背景，边缘不能碰格子边界
- 同一调色板、同一视角、同一画风

后处理：
- extract_prop_pack.py 按网格切割
- 连通分量分析去噪
- edge_touch 检测 → 碰边的道具拒绝/重生成
- 输出 prop-pack.json 清单
```

---

## 5. Prompt 编写规则精要

### 5.1 必须包含的约束

每个生图 Prompt 都要明确写出：

```
✅ 背景是 100% 纯色 #FF00FF 品红，无渐变
✅ 无文字、无标签、无 UI、无对话框
✅ 精确的网格数量（如 "exactly 2x2 grid"）
✅ 格子之间无边框、无分隔线
✅ 所有帧同一角色/物件、同一尺寸、同一像素比例
✅ 任何部位不得越过格子边缘
✅ 四周留品红边距
```

### 5.2 风格选择

| 风格 | 关键词 | 适用 |
|------|-------|------|
| `pixel_art` | 经典像素风 | 复古 RPG 角色 |
| `clean_hd` | 手绘 HD 风 | 地图道具（默认） |
| `pixel_inspired` | 像素启发 | 现代像素感但不粗糙 |
| `retro_pixel` | 16-bit 复古 | 仅用户明确要求时 |

### 5.3 视角选择

| 视角 | 用途 |
|------|------|
| `topdown` | 俯视角角色、地图道具 |
| `side` | 横版弹体、冲击波 |
| `3/4` | 战斗精灵、Boss |

---

## 6. 后处理脚本技术要点

### 6.1 generate2dsprite.py

核心能力：
- **品红去除**：阈值 + BFS 边缘扩展，处理抗锯齿渐变
- **网格切帧**：按行列数切割，支持边框裁剪 + 边缘清理
- **连通分量分析**：`component_mode=largest` 只保留最大连通区域（去飞溅碎片）
- **共享缩放**：`shared_scale=true` 确保所有帧同比例
- **对齐**：`center`（默认）/ `bottom`（着地角色）/ `feet`（带脚部锚点）
- **GIF 导出**：透明 GIF，调色板 + 透明色索引处理

### 6.2 extract_prop_pack.py

从品红背景道具包网格中提取单个透明道具：
- 支持 `--reject-edge-touch` 自动拒绝碰边道具
- 输出 `prop-pack.json` 清单（含裁切坐标、连通分量信息、edge_touch 标记）

### 6.3 compose_layered_preview.py

底图 + 放置 JSON → 扁平预览图：
- 支持 center-bottom 锚点
- 按 sortY 排序实现伪 Y-sort
- 支持前景层（always-on-top）

---

## 7. 嗒啦啦适配指引

### 7.1 你可以直接用的

| 组件 | 路径 | 用法 |
|------|------|------|
| Prompt 规则 | `references/prompt-rules.md` | 照搬品红背景 + 网格约束的 Prompt 模板 |
| 资产映射表 | `references/modes.md` | 用户说"做个 boss"→ 推断出 creature + idle + 3×3 |
| 地图策略 | `references/map-strategies.md` | 五轴决策框架直接复用 |
| 后处理脚本 | `scripts/*.py` | `pip install Pillow numpy` 后直接运行 |

### 7.2 需要适配的

| 原始设计 | 嗒啦啦适配 |
|---------|-----------|
| Codex 内置 `image_gen` | 嗒啦啦内置 `generate_image` / `batch_generate_images` |
| Codex `view_image` 查看本地文件 | 嗒啦啦读取本地文件作为 `reference_images` |
| 输出到 `$CODEX_HOME/generated_images/` | 输出到 `assets/` 目录 |
| `openai.yaml` Agent 配置 | 改写为嗒啦啦 Skill 的 `SKILL.md` 格式 |

### 7.3 快速上手三步

**第一步：Clone 仓库**
```bash
git clone https://github.com/0x0funky/agent-sprite-forge.git
```

**第二步：阅读核心文件**
```
必读：
  skills/generate2dsprite/SKILL.md          # 精灵 Skill 定义
  skills/generate2dsprite/references/prompt-rules.md  # Prompt 规则
  skills/generate2dmap/SKILL.md             # 地图 Skill 定义

选读：
  skills/generate2dsprite/references/modes.md         # 映射表
  skills/generate2dmap/references/map-strategies.md   # 策略表
```

**第三步：改写为嗒啦啦 Skill**

把 SKILL.md 中的工作流翻译为嗒啦啦 Skill 格式：
1. 把 `image_gen` 调用替换为 `generate_image`（透明背景可设 `transparent: true`，或沿用品红色键方案）
2. 把 `view_image` 替换为 `reference_images` 参数
3. 后处理脚本放到项目中直接调用
4. 在 SKILL.md 的触发条件中写明："用户要求生成 2D 精灵/动画/地图时触发"

---

## 8. 实际效果参考

仓库 README 展示了多个实际生成案例：

| 案例 | 说明 |
|------|------|
| 悟空龟派气功 | 单句话 → 完整攻击动画 GIF |
| 鸣人螺旋丸 | 中文 Prompt 同样有效 |
| 火系法师三连 | spell_bundle：施法 + 弹体 + 命中 |
| 武士四方向行走 | 4×4 player_sheet → 16 帧 + 4 方向 GIF |
| 赛博朋克横版游戏 | 一句话 → 完整可玩游戏（含精灵和地图） |
| RPG 分层地图 | 底图 → 参考稿 → 道具提取 → 碰撞数据 |
| Godot 可编辑地图 | 直接输出 .tscn 场景文件 |

---

*素材来源：公众号"小陈的第二大脑"文章 + GitHub 仓库 https://github.com/0x0funky/agent-sprite-forge*
*蒸馏日期：2026-04-29*

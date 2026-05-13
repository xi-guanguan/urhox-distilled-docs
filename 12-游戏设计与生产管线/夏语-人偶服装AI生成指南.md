# 人偶服装 AI 生成指南

> **这是什么**: 基于完整人偶 + `edit_image` API 生成透明底服装/部件的操作指南
> **原作者**: 夏语
> **推荐度**: ★★★★ 实测验证，4 张成功案例，含 prompt 模板
> **适用场景**: 换装系统的服装候选图快速生成

---

## 核心方法

将完整人偶图作为 `edit_image` 的输入参考，prompt 描述目标服装，设置 `transparent=true`，直接输出透明底的服装/角色图。

```
完整人偶图（原始立绘）
  ↓ edit_image(transparent=true)
透明底服装/角色图
  ↓ 用户挑选 + 手动微调
最终服装图层
```

**优势**：
- 无需预处理底图（不需要色键填充、不需要裁剪）
- 无需后处理提取（不需要 chroma key、不需要 alpha mask）
- 一次调用即可出结果，适合快速迭代

---

## 调用参数模板

```python
edit_image(
    image        = "人偶模板.png",       # 完整人偶图（带体型参考）
    prompt       = "服装描述...",         # 见下方 prompt 编写指南
    name         = "输出文件名",
    aspect_ratio = "2:3",               # 竖版人物推荐
    target_size  = "1024",              # 或具体尺寸如 "570x903"
    transparent  = True,                # 必须！输出透明底
)
```

| 参数 | 值 | 说明 |
|------|-----|------|
| image | 人偶图路径 | 完整人偶立绘，AI 以此为体型参考 |
| prompt | 英文描述 | 服装风格、颜色、材质、细节 |
| aspect_ratio | `"2:3"` | 竖版全身人物最佳比例 |
| target_size | `"1024"` | 输出尺寸，AI 按此和 aspect_ratio 计算实际分辨率 |
| transparent | `true` | 必须设置，否则输出白色背景 |

### 已知特性

- **尺寸偏差**：`edit_image` 输出尺寸可能与 `target_size` 不完全一致（实测宽度偏差约 +6.3%，如请求 570 返回 606），如需精确尺寸需后期 resize
- **输出内容**：AI 会生成包含头发、脸部、身体的完整角色图（不是纯服装图层），服装穿在角色身上

---

## 实测成功案例

以下 4 张均使用同一人偶输入，共同参数：
- aspect_ratio: `"2:3"`, target_size: `"1024"`, transparent: `true`

### 案例 1：红金旗袍

```
Full body character design of the same anime girl, now wearing a traditional
Chinese qipao/cheongsam dress. The qipao is red with gold floral embroidery
patterns, high collar, side slits showing legs. She maintains the same face,
hairstyle (long dark hair with bangs), and body proportions. Standing pose,
slight smile. The dress fits her figure elegantly. Same art style as the
original character sheet - clean anime illustration style with soft shading.
```

效果：红色旗袍配金色花卉刺绣，高领开叉，保持原角色面容和体型。

### 案例 2：深红旗袍

```
Full body anime character wearing an elegant traditional Chinese
qipao/cheongsam. The qipao is deep red/crimson with delicate gold floral
embroidery along the edges and collar. High mandarin collar, form-fitting
silhouette, side slit on right leg. The character has the same face and long
dark hair with bangs as the reference. Standing in a graceful pose with hands
at sides. Clean anime illustration style, soft cel-shading, detailed fabric
texture on the qipao. Full body visible from head to feet.
```

效果：深红旗袍，领口和边缘精致金色刺绣，贴身剪裁，右侧开叉。

### 案例 3：华丽旗袍

```
Anime girl full body character design wearing a beautiful traditional Chinese
qipao cheongsam dress. The qipao dress is deep red with ornate gold embroidery
patterns, high mandarin collar, fitted waist, side slit showing right leg. She
has the same face, same long dark hair with bangs, same body proportions as the
reference mannequin image. Clean anime art style, soft shading, elegant
standing pose. The outfit replaces the simple clothes from the reference while
keeping the exact same character appearance and proportions. Transparent
background, full body from head to toe visible.
```

效果：华丽金色刺绣，收腰剪裁，prompt 额外强调保持参考图体型比例和透明背景。

### 案例 4：哥特洛丽塔

```
Full body anime character design of a cute girl wearing an elegant Gothic
Lolita dress. Black and white frilly dress with lace details, petticoat,
ribbon bow at chest, knee-length skirt with multiple lace layers. She has long
dark hair with bangs, large expressive eyes, youthful face. Standing pose
facing forward. Clean anime illustration style, detailed outfit design.
CHARACTER ON TRANSPARENT BACKGROUND - no background elements, no ground shadow,
just the character floating on empty transparent space. PNG with alpha channel
transparency.
```

效果：黑白哥特洛丽塔，蕾丝花边、蓬裙衬裙、胸口蝴蝶结。prompt 末尾用大写强调透明背景。

---

## Prompt 编写指南

### 有效结构

```
[全身/角色描述] + [服装类型+颜色+材质+细节] + [保持参考图的体型/脸型/发型] + [画风] + [透明背景强调(可选)]
```

### 关键要素

| 要素 | 作用 | 示例 |
|------|------|------|
| 全身描述 | 确保输出完整角色 | `"Full body character design"`, `"Full body visible from head to feet"` |
| 服装细节 | 精确控制衣服样式 | `"deep red qipao with gold floral embroidery, high mandarin collar, side slit"` |
| 保持参考 | 维持人偶体型一致性 | `"same face, same hair, same body proportions as the reference"` |
| 画风 | 统一画面风格 | `"clean anime illustration style, soft cel-shading"` |
| 透明背景 | 增强透明效果（可选） | `"CHARACTER ON TRANSPARENT BACKGROUND"` |

> `transparent=true` 参数本身就确保透明底，prompt 中加透明背景描述是额外保险。

### 精度分级

| 阶段 | 精度要求 | 说明 |
|------|---------|------|
| 探索阶段 | 低 — 简述风格即可 | 快速试验多种方向，挑选最佳 |
| 定制阶段 | 中 — 描述风格+材质+主要装饰 | 确保输出符合设计意图 |
| 生产阶段 | 高 — 精确到颜色、材质、装饰位置 | 确保多次生成保持一致性 |

### 中文 vs 英文

实测 4 张成功案例均使用英文 prompt。`edit_image` 对英文理解更稳定，**建议优先使用英文**。

中文模板：
```
全身动漫角色设计，穿着[服装类型]。[颜色+材质+细节描述]。
保持与参考图相同的脸型、发型和身体比例。
干净的动漫插画风格，柔和的赛璐璐着色。
```

---

## 常见服装类型 Prompt 模板

### 旗袍/中式

```
Full body anime character wearing a traditional Chinese qipao/cheongsam.
The qipao is [颜色] with [装饰] embroidery patterns, high mandarin collar,
form-fitting silhouette, side slit on [left/right] leg.
Same face and body proportions as the reference.
Clean anime illustration style, soft shading.
```

可替换项：
- 颜色：`red`, `deep red/crimson`, `jade green`, `navy blue`, `black`
- 装饰：`gold floral`, `silver phoenix`, `cloud pattern`, `plum blossom`

### 校服/制服

```
Full body anime character wearing a [类型] school uniform.
[上衣描述] with [下装描述]. [配件描述].
Same face and hairstyle as the reference.
Clean anime illustration style.
```

类型：`Japanese sailor uniform`, `blazer-style uniform`, `summer uniform`

### 裙装通用

```
Full body anime character wearing a [裙型] dress.
The dress is [颜色], [材质], [领口类型], [袖型], [裙长].
[装饰细节]. Same proportions as the reference.
Clean anime style, detailed outfit design.
```

裙型：`A-line`, `mermaid`, `empire waist`, `fit-and-flare`

---

## 注意事项

1. **输出是完整角色图**：AI 会生成包含头发、脸部、身体的完整角色，不是纯服装图层
2. **位置/比例可能微调**：不同次生成之间可能有偏差，需用户检查
3. **适合批量试错**：无预处理无后处理，一次调用即出结果。建议一次生成 3-5 张，从中挑选
4. **手动微调可行**：生成的图即使不完美，可在画图软件中微调位置、裁切、调色后使用
5. **人偶输入很重要**：人偶图的体型、姿态、风格直接影响生成结果

### 与其他生成方案的关系

| 方案 | 适用场景 | 复杂度 |
|------|---------|--------|
| 直接生成（本文档） | 快速探索、手动微调 | 最低 |
| 约束模板 | 小部件替换（眼、嘴） | 低 |
| 色键抠像 | 精确服装提取 | 高 |
| 裁剪生成 | 保持轮廓上色 | 中 |

```
需要精确轮廓对齐？
  ├─ 是 → 色键抠像 / 裁剪生成
  └─ 否 → 用本文档的方法（最简最快）
```

---

> **来源**: TapTap 开发者论坛 — 夏语《如何生成人偶对应图案的部件或服装》
> **日期**: 2026-05-01
> **蒸馏等级**: L2（参考学习型）

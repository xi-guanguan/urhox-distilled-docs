# 游戏设计风格 AI 绘图百科

> 作者: 涅槃妙心 | 级别: L1-实操 | 编号: #159

---

## 概述

游戏美术风格 AI 图片生成提示词百科全书。覆盖 16 种美术风格 + 10 种角色原型 + 场景环境，每种均含详细 Prompt 模板和多组示例。

---

## 16 种美术风格

| 编号 | 风格 | 关键词 |
|------|------|--------|
| 1 | 像素风 Pixel Art | pixel art, 8-bit/16-bit, limited palette |
| 2 | 赛璐璐 Cel-Shaded | cel-shaded, flat colors, bold outlines |
| 3 | 水彩风 Watercolor | watercolor wash, wet-on-wet, soft bleeding |
| 4 | 概念艺术厚涂 Concept Art Impasto | thick brushstrokes, painterly, concept art |
| 5 | 日式二次元/抽卡风 Anime Gacha | anime style, gacha splash art, dynamic pose |
| 6 | 韩式MMO写实 K-MMO Realistic | realistic rendering, korean MMO style |
| 7 | 美漫风 American Comic | comic book style, halftone dots, dynamic inking |
| 8 | Low-Poly 低多边形 | low-poly, geometric, faceted surfaces |
| 9 | 体素/方块风 Voxel | voxel art, cubic, minecraft-like |
| 10 | 哥特暗黑 Gothic Dark | gothic, dark atmosphere, ornate details |
| 11 | 赛博朋克 Cyberpunk | neon lights, dystopian, high-tech low-life |
| 12 | 蒸汽朋克 Steampunk | brass gears, victorian, steam-powered |
| 13 | 扁平矢量 Flat Vector | flat design, vector illustration, minimal |
| 14 | 3A写实 AAA Photorealistic | photorealistic, ray-tracing, PBR |
| 15 | 剪纸/手工风 Papercut Craft | paper craft, layered cutout, handmade |
| 16 | 中国水墨 Chinese Ink Wash | chinese ink painting, splatter, calligraphy brush |

---

## 风格 Prompt 结构模板

```
[主体描述], [风格关键词], [质量词], [视角/构图], [光照], [色调]
```

### 通用质量词
- `masterpiece, best quality, highly detailed`
- `professional, studio lighting`
- `4K, sharp focus, intricate details`

### 通用负面词
- `blurry, low quality, deformed, watermark, text, signature`

---

## 各风格详细 Prompt 示例

### 1. 像素风 Pixel Art

**角色**:
```
pixel art warrior character, 32x32 sprite, limited 16-color palette,
retro game style, side view, clean pixel edges, nostalgic 8-bit aesthetic
```

**场景**:
```
pixel art fantasy castle, 16-bit era style, tiled background,
sunset sky gradient, detailed pixel dithering, retro RPG town
```

### 2. 赛璐璐 Cel-Shaded

**角色**:
```
cel-shaded anime swordsman, bold black outlines, flat color fills,
3-tone shading (highlight/base/shadow), dynamic action pose,
wind-swept hair, vibrant saturated colors
```

### 3. 水彩风 Watercolor

**角色**:
```
watercolor painting of forest elf, wet-on-wet technique,
soft color bleeding at edges, visible paper texture,
transparent layered washes, delicate botanical details
```

### 4. 概念艺术厚涂

**角色**:
```
concept art of dark knight, thick impasto brushstrokes,
painterly style, dramatic chiaroscuro lighting,
moody atmosphere, muted color palette with accent red
```

### 5. 日式二次元/抽卡风

**角色**:
```
anime gacha splash art, beautiful sorceress,
dynamic floating pose with magic circles,
sparkle effects, detailed costume design,
gradient hair color, large expressive eyes, JP anime style
```

### 6. 韩式MMO写实

**角色**:
```
realistic korean MMO character art, female paladin,
detailed armor with ornate engravings, realistic skin rendering,
dramatic rim lighting, cinematic composition, ultra-detailed
```

### 7. 美漫风 American Comic

**角色**:
```
american comic book superhero, bold dynamic inking,
halftone dot pattern shadows, speech bubble,
Jack Kirby inspired, dramatic foreshortening,
vivid primary colors
```

### 8. Low-Poly

**场景**:
```
low-poly forest scene, geometric triangular surfaces,
soft gradient sky, minimal color palette,
isometric view, peaceful atmosphere, stylized trees
```

### 9. 体素/方块风

**场景**:
```
voxel art medieval castle, cubic building blocks,
magicavoxel style, warm lighting, detailed interiors visible,
isometric perspective, cozy atmosphere
```

### 10. 哥特暗黑

**场景**:
```
gothic dark cathedral interior, ornate stone carvings,
stained glass windows, volumetric light beams,
dark oppressive atmosphere, cobwebs, candle flames
```

### 11. 赛博朋克

**场景**:
```
cyberpunk neon city street at night, rain-slicked roads,
holographic advertisements, towering megastructures,
pink and cyan neon glow, flying vehicles, dystopian
```

### 12. 蒸汽朋克

**角色**:
```
steampunk inventor character, brass goggles, leather apron,
mechanical arm prosthetic with visible gears,
victorian workshop background, warm amber lighting
```

### 13. 扁平矢量

**UI/图标**:
```
flat vector game icon set, minimal geometric shapes,
2-3 color per icon, bold clean silhouettes,
consistent stroke width, modern mobile game style
```

### 14. 3A写实

**场景**:
```
photorealistic fantasy forest, ray-traced global illumination,
PBR materials, moss-covered ancient ruins,
volumetric fog, god rays through canopy, 8K render
```

### 15. 剪纸/手工风

**场景**:
```
paper craft layered diorama, handmade texture visible,
colored construction paper cutouts, shadow box depth,
whimsical children's book illustration style
```

### 16. 中国水墨

**场景**:
```
chinese ink wash painting, mountain landscape,
calligraphy brush strokes, splatter technique,
negative space, minimalist composition,
traditional rice paper texture, monochrome with cinnabar accent
```

---

## 10 种角色原型

| 原型 | 核心特征 | 适配风格 |
|------|---------|---------|
| 战士/骑士 | 重甲, 大剑/盾, 力量感 | 韩式写实, 概念厚涂, 哥特暗黑 |
| 法师/术士 | 法杖, 魔法阵, 飘逸长袍 | 二次元抽卡, 水彩, 概念厚涂 |
| 盗贼/刺客 | 轻甲, 双匕, 隐匿姿态 | 赛博朋克, 美漫, 赛璐璐 |
| 弓箭手/猎人 | 弓弩, 自然元素, 敏捷 | 水彩, Low-Poly, 像素 |
| 治疗/牧师 | 白色长袍, 光环, 神圣符文 | 二次元, 扁平矢量, 水彩 |
| 召唤师 | 魔物/精灵, 契约书, 神秘 | 哥特, 概念厚涂, 中国水墨 |
| 机械师/工程 | 齿轮装置, 工具, 护目镜 | 蒸汽朋克, 体素, 赛博朋克 |
| 龙骑/驯兽 | 骑乘坐骑, 缰绳, 动态 | 韩式写实, 3A, 概念厚涂 |
| 商人/NPC | 背包货物, 友善表情, 城镇 | 像素, 扁平矢量, 赛璐璐 |
| Boss/精英 | 巨大体型, 威压感, 特效 | 所有风格均可 |

---

## 场景环境 Prompt 模板

### 新手村
```
[风格词] starter village, cozy medieval town,
warm sunlight, thatched roof cottages, town square fountain,
villagers walking, peaceful atmosphere, rolling green hills
```

### 地下城
```
[风格词] dungeon corridor, ancient stone walls,
torch-lit, mysterious runes glowing, treasure chest,
spider webs, depth fog, dangerous atmosphere
```

### Boss 房间
```
[风格词] boss arena, vast circular chamber,
ominous throne at center, dramatic sky visible through broken ceiling,
energy particles floating, before-battle tension
```

### 商店/锻造
```
[风格词] fantasy blacksmith shop interior,
glowing forge, weapons on wall display, anvil,
warm orange lighting, steam and sparks, detailed props
```

---

## 实用技巧

1. **风格混搭**: 可组合两种风格如 "pixel art + cyberpunk"
2. **一致性**: 同一项目保持风格词固定，只变换主体
3. **负面提示**: 始终加入负面词排除不需要的元素
4. **分辨率控制**: 在 prompt 末尾加 "4K" "8K" 或 "256x256 sprite"
5. **批量生成**: 固定风格词 + 变换角色/场景主体 = 风格统一的资产集

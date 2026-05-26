# GLB → UrhoX MDL 转换管线指南

> **这是什么**: 使用 `glb2mdl` 工具将 GLB/glTF 模型转换为 UrhoX 专用 MDL 格式的完整流程，含命令行用法、输出结构、Lua 加载代码和常见坑。
> **原作者**: 夜
> **推荐度**: L3（现已有更简洁的方式——直接用嗒啦啦转换即可，本文作为底层原理参考保留）
> **适用场景**: 需要手动控制 GLB → MDL 转换细节，或批量处理模型资产时

---

## 为什么需要转换

UrhoX 不能直接加载 `.glb` / `.gltf` 文件，必须转成引擎专用格式：
- `.mdl` — 模型文件
- `.ani` — 动画文件
- `.xml` / `.txt` — 材质定义

官方提供 `glb2mdl` 命令行工具（位于 UrhoX SDK 的 `tools/` 目录），文档极少，以下为实战总结。

## 工具准备

1. `glb2mdl` — UrhoX SDK `tools/` 目录
2. Blender 3.x+（可选，用于预处理模型）
3. 模型来源推荐：Sketchfab、Ready Player Me、Mixamo

## 基本转换命令

```bash
# 最简用法
glb2mdl input.glb -o output/

# 指定缩放（GLB 和 UrhoX 默认都是米，通常不需要）
glb2mdl input.glb -o output/ --scale 1.0

# 导出动画
glb2mdl input.glb -o output/ --export-animations

# 分离材质贴图
glb2mdl input.glb -o output/ --export-textures
```

## 输出文件结构

```
output/
├── Models/
│   └── character.mdl          # 模型
├── Textures/
│   ├── character_diffuse.png  # 漫反射贴图
│   ├── character_normal.png   # 法线贴图
│   └── character_roughness.png # 粗糙度贴图
├── Materials/
│   └── character.xml          # 材质定义
└── Animations/
    ├── idle.ani               # 动画
    └── walk.ani
```

## 在 UrhoX 中加载

```lua
-- 加载模型
local node = scene_:CreateChild("Character")
local model = node:CreateComponent("AnimatedModel")
model:SetModel(cache:GetResource("Model", "Models/character.mdl"))
model:SetMaterial(cache:GetResource("Material", "Materials/character.xml"))

-- 加载动画
local animCtrl = node:CreateComponent("AnimationController")
animCtrl:PlayExclusive("Animations/idle.ani", 0, true, 0.2)
```

## 常见坑（6 条）

### 1. 模型朝向

GLB 用右手坐标系（Y-up），UrhoX 也是 Y-up 但是左手系。`glb2mdl` 会自动处理坐标系转换，但如果模型在 Blender 里朝向不对，转出来也会不对。**建议在 Blender 里先确认模型面朝 -Y 方向**。

### 2. 动画名称

GLB 里的动画名会被保留，但文件名会被 sanitize。建议在 Blender 里就把动画名改成英文。

### 3. 贴图路径

`glb2mdl` 导出的材质文件里的贴图路径是相对路径。如果移动文件到别的目录，记得更新材质文件里的路径。

### 4. 骨骼数量限制

UrhoX 单个模型最多支持 **64 根骨骼**。超过需要在 Blender 里减少骨骼数量。

### 5. PBR 材质映射

GLB 使用 PBR metallic-roughness 工作流，`glb2mdl` 会自动映射到 UrhoX 的 PBR Technique。但如果原始模型用了 specular-glossiness 工作流，需要先在 Blender 里转换。

### 6. Mixamo 动画特殊处理

从 Mixamo 下载的动画 GLB 需要额外处理：
1. 下载时选择 "Without Skin"（只要动画数据）
2. 确保骨骼名称和角色模型一致
3. 骨骼名不一致时用 Blender 重新映射

```lua
-- Mixamo 动画通常需要调整播放速度
animCtrl:PlayExclusive("Animations/mixamo_run.ani", 0, true, 0.2)
animCtrl:SetSpeed("Animations/mixamo_run.ani", 1.2)  -- 稍微加快
```

## 批量转换脚本

```bash
#!/bin/bash
INPUT_DIR="./raw_models"
OUTPUT_DIR="./assets"

for f in "$INPUT_DIR"/*.glb; do
    name=$(basename "$f" .glb)
    echo "Converting: $name"
    glb2mdl "$f" -o "$OUTPUT_DIR/" --export-animations --export-textures
done
echo "Done! Converted $(ls "$INPUT_DIR"/*.glb | wc -l) models."
```

## ⚠️ L3 说明

本文记录的是底层手动转换流程。目前已有更简洁的方式——**直接使用嗒啦啦（Talala）的转换功能**即可完成 GLB → MDL 的导入，无需手动执行命令行。本文作为底层原理参考保留，适合需要深度定制转换流程的场景。

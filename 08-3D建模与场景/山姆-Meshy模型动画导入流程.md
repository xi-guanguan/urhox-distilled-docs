# Meshy AI 角色模型导入流程

> **这是什么**: 从 Meshy AI 生成的 FBX 角色模型到 UrhoX MDL 格式的完整导入管线，含骨骼替换和批量操作。
> **原作者**: 山姆
> **推荐度**: L2（项目专属流程，但导入思路通用）
> **适用场景**: 需要导入 AI 生成的角色模型并共享同一套骨骼动画时

---

## 核心原则

所有角色模型必须与基准模型（craftsman）共享同一套骨骼绑定和动画。

- 骨骼数量：25 根（24 Mixamo + 1 Armature 幻影根骨骼）
- 坐标系：Y-up，单位 cm（游戏中 unitScale = 0.01 转米）

## 完整流程（4 步）

### Step 1: FBX → GLB（assimp）

```bash
assimp export input.fbx output.glb -f glb2
# assimp 自动处理 Z-up → Y-up 坐标变换
```

### Step 2: GLB → MDL（glb2mdl.py）

```bash
python3 glb2mdl.py output.glb -o out_dir -n ModelName
# 自动添加 Armature 幻影根骨骼（24 → 25）
```

### Step 3: 替换骨骼（replace_skeleton.py）

```bash
python3 replace_skeleton.py craftsman.mdl target.mdl target.mdl
# 将基准骨骼数据写入目标 MDL，保留目标网格
```

**为什么需要**: 每个 Meshy 模型有不同的绑定姿态，不替换会导致腰部扭曲。

### Step 4: 验证

```bash
UrhoXCLI model-info -i target.mdl --bones
# 确认：骨骼数=25，第一根="Armature"，包围盒高度在 Y 轴
```

## 绝对禁止

| 做法 | 后果 |
|------|------|
| 使用 UrhoXCLI import-model | 只产生 24 骨骼，与动画不兼容 |
| 对 assimp 模型用 fix_mdl_orientation.py | 模型躺倒 |
| 跳过骨骼替换 | 绑定姿态不匹配，腰部扭曲 |

## 动画导入

动画同样走 assimp + glb2mdl 管线，输出的 `.ani` 文件通用于全部角色。

## 批量操作

```bash
python3 batch_convert_fbx.py              # 批量转换
for f in assets/Models/Char*.mdl; do       # 批量骨骼替换
    python3 replace_skeleton.py craftsman.mdl "$f" "$f"
done
```

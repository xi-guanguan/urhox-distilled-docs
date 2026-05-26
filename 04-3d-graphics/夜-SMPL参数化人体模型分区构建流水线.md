# SMPL 参数化人体模型分区构建流水线

## 这是什么

基于 SMPL 参数化人体模型的 6 阶段离线+实时流水线，可生成 6 种体型（3 男 3 女）的 6890 顶点人体网格，自动划分 16 个可独立编辑的身体区域，在 UrhoX 中用 CustomGeometry 实时渲染和交互编辑。

- **原作者**: 夜
- **推荐度**: L2（参考学习）—— 流水线完整但依赖离线 Python 环境（nosmpl/ChromaDB），项目自身代码不开源
- **适用场景**: 需要参数化人体模型（换装/体型定制/分区编辑）的 3D 项目

---

## 核心流水线

```
Phase 1: Python venv + pip install nosmpl onnxruntime numpy
Phase 2: nosmpl 自动下载 smpl.onnx (19.7MB, 6890顶点/13776面/24关节)
Phase 3: 自定义 protobuf 解析器提取权重 → v_template/shapedirs/J_regressor/faces
Phase 4: beta 参数 + 骨骼区域性别变形 + Y归零 → 6种体型 .npz
Phase 5: 关节链段投影 + 多数投票 → 16区分区 → ~785KB JSON
Phase 6: UrhoX CustomGeometry 实时渲染 + 轨道相机 + 分区编辑 UI
```

---

## 关键技术点

### 体型生成公式

```python
vertices = v_template + einsum('vcd,d->vc', shapedirs, betas)
# betas: 10维向量, PCA主成分控制体型
# beta[0]: 整体尺寸  beta[1]: 身高/体宽比  beta[2-9]: 细节特征
```

### 骨骼区域性别变形

中性 SMPL 不编码性别差异，通过基于关节位置的定向顶点变形叠加：

| 性别 | 体型特征 | 关键变形 |
|------|---------|---------|
| 男 | 倒三角（肩臀比 2.4~2.8） | 肩+12%外扩, 臀-5%内收, 胸+6%加厚 |
| 女 | 沙漏（肩臀比 2.0~2.3） | 肩-8%内收, 臀+12%外扩, 腰-10%内收, 胸+1.5cm前推 |

使用 smoothstep Hermite 插值实现区域过渡：`1 - t²(3-2t)`

### 16 区分区算法

每个顶点计算到所有关节链段的点到线段距离，归入最近区域。三角面用多数投票决定归属，跨区域顶点复制到目标区域（冗余~10%）。

### 6 种体型库

| ID | 标签 | 身高 | 肩臀比 | 核心 beta |
|----|------|------|--------|----------|
| male_standard | 男-标准 | 1.70m | 2.59 | [0.5, 0.3, 0,...] |
| male_athletic | 男-健壮 | 1.80m | 2.43 | [2.0, -0.5, 0.8, 0.3,...] |
| male_lean | 男-精瘦 | 1.60m | 2.80 | [-1.0, 1.5, -0.5,...] |
| female_standard | 女-标准 | 1.64m | 2.14 | [-0.3, 0.5, 0, -0.3,...] |
| female_slim | 女-纤细 | 1.56m | 2.31 | [-1.5, 1.8, -0.8,...] |
| female_curvy | 女-丰满 | 1.73m | 2.00 | [1.0, -0.8, 0.5, 0.2,...] |

---

## UrhoX 渲染层

### 数据加载

```lua
local file = cache:GetFile("smpl_male_standard_partitioned.json")
local smplData = cjson.decode(file:ReadString())
```

### CustomGeometry 渲染

每分区一个节点，3 种显示模式（实体/分区着色/线框）：

```lua
local geom = node:CreateComponent("CustomGeometry")
geom:BeginGeometry(0, TRIANGLE_LIST)
for _, v in ipairs(region.vertices) do
    geom:DefineVertex(Vector3(v.x, v.y, v.z))
    geom:DefineNormal(Vector3(v.nx, v.ny, v.nz))
    geom:DefineColor(regionColor)
end
geom:Commit()
```

### 项目结构（~5000 行 Lua）

| 文件 | 行数 | 职责 |
|------|------|------|
| main.lua | 1069 | 入口/场景/相机/UI/交互 |
| ModelGenerator.lua | 866 | 加载调度/region映射 |
| MeshRenderer.lua | 518 | CustomGeometry渲染/3模式 |
| BodyMeshBuilder.lua | 1413 | 旧版程序化生成（回退） |
| 其他6文件 | ~1600 | 分区管理/编辑/拆分/数学工具 |

---

## 添加新体型

1. 编辑 `gen_gendered_bodies.py` 的 `BODY_TYPES` 列表添加 `(id, label, betas, gender)`
2. 运行 `gen_gendered_bodies.py` → 生成 `.npz`
3. 运行 `partition_gendered.py` → 生成分区 JSON (~785KB)
4. 更新 `ModelGenerator.lua` 的 `SMPL_MODELS` 列表
5. 构建 — UI 按钮从列表动态生成

---

## 权重提取踩坑

ONNX 模型只暴露 pose 输入，不接受 beta。需要自定义 protobuf 解析器提取 `shapedirs`。关键发现：张量数据在 protobuf **field 9**（非标准 field 4/13），且 `dims` 字段为空，需用已知 shape 手动 reshape。

---

## 扩展方向

- 替换 SMPL 为 SMAL（动物）等参数化模型，流水线架构可复用
- 引入 pose 参数（72 维）+ LBS 蒙皮实现姿态变化
- 使用 SMPL 男/女专用模型替代中性模型+后处理方案

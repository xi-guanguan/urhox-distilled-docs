# 两级 Alpha 采样：用轮廓代替面积提取 2D 图片边界

> **元信息**
> - **原作者**: 夏语
> - **蒸馏等级**: L2（思路有价值，需根据项目纹理尺寸和脚本层性能调整参数）
> - **主题**: 在 Lua 脚本层高效提取大尺寸 PNG 图片的 alpha 轮廓控制点，供网格变形/三角剖分使用
> - **适用场景**: 2D 纸娃娃/图层系统需要运行时分析 alpha 通道生成贴合内容的三角网格；大图片（1024×2048+）逐像素扫描在脚本层不可接受时
> - **同类对比**: 与同目录 `夏语-画格子图AI转地图代码工作流.md` 互补——画格子图解决的是地图编辑工作流，本文解决的是运行时图像分析性能问题；两者都涉及网格/格子划分但目标完全不同

---

## 场景

一个 2D 纸娃娃角色系统，角色被拆分为 10 个 PNG 图层（头发、头部、身体、衣服等），每个图层画布大小统一为 1024×2048，但实际内容只占画布的一部分。运行时需要为每个图层自动生成网格（供 Delaunay 三角剖分 → 网格变形 → GPU 渲染），第一步就是从图片的 alpha 通道中提取：

- **内容边界框（bbox）**——内容区域的最小外接矩形
- **轮廓控制点**——沿 alpha 边界分布的点集，用于后续三角剖分

---

## 为什么不能逐像素扫描

最直觉的方案：遍历每一个像素，检查 alpha > 阈值。

`1024 × 2048 = 2,097,152 次 GetPixel 调用`

在 C/C++ 层这不算什么，但这个项目跑在 Lua 脚本层——每次 GetPixel 都要跨 Lua/C++ 边界。实测在 WebGL 环境下，200 万次调用会冻住画面好几秒。10 个图层 = 2000 万次采样，显然不可接受。

**需要一种采样量与轮廓长度（而非图片面积）成正比的方法。**

---

## 核心思路

大多数像素不在边界上：

- 图片大部分区域要么完全透明（背景），要么完全不透明（内容中央）
- 只有轮廓附近的像素会在透明和不透明之间切换
- 我们需要的控制点也只在轮廓附近

---

## 第一级：四角共享网格采样

将图片划分为 `gridStep × gridStep`（取 50px）的格子网格：

```
1024 / 50 = 21 列（向上取整）
2048 / 50 = 41 行
```

**关键观察**：每个格子有 4 个角，相邻格子共享角点。不需要为每个格子独立采样 4 次，只需在角点网格上做一次遍历：

```
角点网格 = (gridCols + 1) × (gridRows + 1) = 22 × 42 = 924 个采样点
```

对比逐像素的 200 万次，这里只需要 924 次 GetPixel 调用。

```lua
local gridStep = 50
local gridCols = math.ceil(w / gridStep)  -- 21
local gridRows = math.ceil(h / gridStep)  -- 41
local cornerCols = gridCols + 1           -- 22
local cornerRows = gridRows + 1           -- 42

-- 采样所有角点
local cornerMap = {}
for r = 0, cornerRows - 1 do
    cornerMap[r] = {}
    local py = math.min(r * gridStep, h - 1)
    for c = 0, cornerCols - 1 do
        local px = math.min(c * gridStep, w - 1)
        cornerMap[r][c] = image:GetPixel(px, py).a > 0.04
    end
end
```

然后根据每个格子四个角的采样结果，将格子分为三类：

| 四角状态 | 格子类型 | 含义 |
|---------|---------|------|
| 4 个角全部有内容 | interior | 完全在内容区域内部 |
| 1~3 个角有内容 | border | 轮廓穿过此格子 |
| 4 个角全部透明 | 待定 → 需补充采样 | 可能是空的，也可能有孤岛 |

```lua
if count == 4 then
    cellType[key] = "interior"
elseif count >= 1 then
    cellType[key] = "border"
else
    -- 四角全空：补一次中心点采样
    ...
end
```

### 补丁 1：孤岛检测

四角全空的格子不一定真的是空的——如果图片内容恰好在格子正中间、不接触任何角点，四角采样会完全漏掉。

解决方案：对四角全空的格子额外采样一次中心点：

```lua
if count == 0 then
    local cx = c * gridStep + gridStep / 2
    local cy = r * gridStep + gridStep / 2
    if image:GetPixel(cx, cy).a > 0.04 then
        cellType[key] = "border"  -- 孤岛，视为边界
    else
        cellType[key] = "empty"
    end
end
```

代价很低——一个格子只多 1 次采样。

### 补丁 2：interior 降级

四角全有内容的格子被标记为 interior，但如果它的四邻居中有 empty 格子，说明它实际上靠近轮廓边缘——应该降级为 border 以获得精扫：

```lua
for r = 0, gridRows - 1 do
    for c = 0, gridCols - 1 do
        if cellType[key] == "interior" then
            local hasEmptyNeighbor =
                (r == 0) or (r == gridRows - 1)
                or (c == 0) or (c == gridCols - 1)
                or not cellMap[r-1][c] or not cellMap[r+1][c]
                or not cellMap[r][c-1] or not cellMap[r][c+1]
            if hasEmptyNeighbor then
                cellType[key] = "border"
            end
        end
    end
end
```

这一步不增加任何采样，只是重新分类。

**第一级完成后，我们得到了一张格子分类图。核心数据：哪些格子是 border。**

---

## 第二级：边界格子精扫

只对 border 类型的格子做高密度扫描。精扫步长 `fineStep = gridStep / 6 ≈ 8px`，做两件事：

### 行扫描：找每行的左右 alpha 边界

在格子内部，每隔 fineStep 选一行，从左到右逐像素扫描，记录第一个和最后一个 alpha > 阈值的像素位置：

```lua
for ly = 0, cellH - 1, fineStep do
    local py = cellY + ly
    local left, right = nil, nil
    for lx = 0, cellW - 1 do
        if image:GetPixel(cellX + lx, py).a > 0.04 then
            if not left then left = cellX + lx end
            right = cellX + lx
        end
    end
    if left then
        edgePts[#edgePts + 1] = { x = left, y = py }
        edgePts[#edgePts + 1] = { x = right, y = py }
    end
end
```

### 列扫描：找每列的上下 alpha 边界

同理，每隔 fineStep 选一列，从上到下扫描，记录第一个和最后一个非透明像素：

```lua
for lx = 0, cellW - 1, fineStep do
    local px = cellX + lx
    local top, bot = nil, nil
    for ly = 0, cellH - 1 do
        if image:GetPixel(px, cellY + ly).a > 0.04 then
            if not top then top = cellY + ly end
            bot = cellY + ly
        end
    end
    if top then
        edgePts[#edgePts + 1] = { x = px, y = top }
        edgePts[#edgePts + 1] = { x = px, y = bot }
    end
end
```

行扫描和列扫描交叉使用，确保轮廓的水平段和垂直段都被捕获到。每行/列扫描的范围限制在格子内部（50px），所以每次扫描最多 50 个像素。

---

## 采样量分析

以"后发"层为例（bbox 约 1020×1000，占画布面积约 50%）：

**第一级**：
- 角点采样：22 × 42 = 924 次
- 中心补充采样（四角全空的格子）：约 400 次
- 合计约 1,324 次

**第二级**（假设 ~120 个 border 格子）：
- 每个 border 格子精扫量：
  - 行扫描：(50/8) 行 × 50 像素 ≈ 6 × 50 = 300 次
  - 列扫描：(50/8) 列 × 50 像素 ≈ 6 × 50 = 300 次
  - 每格子合计 ≈ 600 次
- 120 个 border 格子 × 600 = 72,000 次

**总计**：

| 方案 | 采样次数 |
|------|---------|
| 第一级 | ~1,300 次 |
| 第二级 | ~72,000 次 |
| **合计** | **~73,300 次** |
| 逐像素扫描 | 2,097,152 次 |
| **节省比例** | **96.5%** |

实际运行日志印证：

```
[AutoMesh] corner-scan: grid=21x41(step=50), corners=924,
  fine=68742, total=70066 samples, 287 points
```

7 万次 vs 200 万次——采样量降低到 3.3%。

---

## 两级之间的关系

两级之间不是简单的"粗扫 + 细扫"，而是**分类 + 定向精扫**：

- 第一级的输出不是"粗略的 bbox"，而是"**哪些格子需要精扫**"（格子分类图）
- 第二级只在 border 格子内工作
- interior 格子不需要精扫（完全在内容内部）
- empty 格子不需要精扫（没有内容）

**精扫的工作量与轮廓长度成正比，与图片面积无关。** 一张 4096×4096 的图片，如果内容轮廓和 1024×2048 的图片差不多长，精扫量几乎一样。增加的只是第一级的角点采样数（从 924 到几千，依然很小）。

---

## 顶点放置策略

精扫完成后，把边界信息转化为控制点集（供 Delaunay 三角剖分使用）。对不同类型的格子使用不同策略：

| 格子类型 | 顶点来源 | 理由 |
|---------|---------|------|
| border | 精扫得到的边缘点 + 格子中心 | 轮廓处需要高密度点 |
| interior | 四角 + 中心（5 个点） | 内部不需要过多细节 |
| empty | 不放点 | 没有内容 |

所有顶点经过去重——距离小于 `gridStep × 0.12 ≈ 6px` 的点合并，避免三角剖分产生退化三角形：

```lua
local dedupDist = math.max(3, math.floor(gridStep * 0.12 + 0.5))
local function addPoint(px, py)
    for _, p in ipairs(points) do
        if math.abs(p.x - px) < dedupDist
           and math.abs(p.y - py) < dedupDist then
            return  -- 太近，跳过
        end
    end
    points[#points + 1] = { x = px, y = py }
end
```

最终输出 200~400 个控制点，密度足够三角剖分产生贴合轮廓的网格。

---

## 设计决策回顾

### 为什么不用 marching squares？

Marching squares 的目的是生成等值线（连续的轮廓路径），而这里需要的是散点集（供 Delaunay 使用）。用 marching squares 先生成路径再在路径上采样，多了一层间接，且路径连接逻辑在复杂轮廓（多个不连通区域）上容易出 bug。直接在精扫阶段输出边界点更简单直接。

### 为什么 gridStep 取 50？

| gridStep | 角点数 | 典型 border 格子数 | 精扫量 | 效果 |
|----------|-------|-------------------|--------|------|
| 20 | 5,000+ | 300+ | 20 万+ | 过密，接近逐像素 |
| **50** | **924** | **~120** | **~7 万** | **轮廓精度足够** |
| 100 | 231 | ~60 | ~6 万 | 角点太稀疏，孤岛漏检风险高 |

50px 是精度和性能的平衡点。

### 为什么不用采样金字塔 / mipmap？

先在低分辨率版本上找到大致区域，再回到原图精扫——思路可行，但依赖图片的缩小版本。在此场景中，图片是作为纹理资源加载的，获取 mipmap 级别需要额外的 API 调用。而格子采样不依赖任何图像预处理，只需要 GetPixel，实现更简单。

### 精扫阶段为什么不继续分级？

边界格子只有 50×50 像素。在这个尺度上再做分级反而增加逻辑复杂度，且节省的采样量有限（从 2500 降到 ~600 已经够了）。直接逐行/逐列扫描代码最简单，且采样结果直接就是边界点坐标。

---

## 总结对比

|  | 逐像素扫描 | 两级采样 |
|--|----------|---------|
| 采样次数 | 200 万 | ~7 万 |
| 与图片面积的关系 | 线性 O(W×H) | 第一级 O(W×H / gridStep²)，第二级 O(轮廓长度 × gridStep) |
| 轮廓精度 | 像素级 | 像素级（精扫阶段恢复） |
| 实现复杂度 | 极低 | 中等（格子分类 + 精扫 + 去重） |
| 适合场景 | C/C++ 层，小图片 | 脚本层，大图片，多图层 |

**核心思想**：先用极少的采样点把图片分成"不需要看"和"需要仔细看"两类区域，然后只仔细看需要看的部分。

这个思路不限于 alpha 采样。任何"大面积数据中只有边界处的细节有意义"的场景都可以用类似的两级策略——比如地形碰撞检测、可见性剔除、LOD 区域划分等。

---

*素材来源：TapTap 制造论坛 开发心得*
*蒸馏日期：2026-04-29*

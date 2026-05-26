# 2D 瓦片集 Bitmask 地形编辑器搭建流程

| 字段 | 值 |
|------|-----|
| 这是什么 | 基于 NanoVG 的 2D 多层地形编辑器搭建指南——用 4 个预制文件（2 代码 + 2 文档）喂给 AI，快速生成支持 Bitmask 自动拼接的瓦片地形编辑器。覆盖分辨率模式选择、素材实装、8×4/4×4 图集自动检测、常见踩坑修复 |
| 原作者 | 猫猫头工作室 |
| 推荐度 | L2（流程可复现，但依赖预制文件，需配合自己的素材适配） |
| 适用场景 | 2D 俯视角或侧视角游戏需要可编辑的瓦片地图，使用 Bitmask 自动选择正确的瓦片变体 |

---

## 核心思路

用 4 个预制文件作为 AI 的上下文输入，让 AI 理解前端 UI 和核心逻辑后一次性生成完整的地形编辑器：

| 文件 | 类型 | 作用 |
|------|------|------|
| `tileset-bitmask-editor-nanovg.txt` | 代码 | 前端 UI（NanoVG 绘制编辑器界面） |
| `NANOVG.md` | 文档 | 前端 UI 功能说明 |
| `multi_layer_terrain.txt` | 代码 | 核心逻辑（多层地形数据管理、Bitmask 计算） |
| `README.md` | 文档 | 核心逻辑功能说明 |

---

## 搭建步骤

### 第 1 步：上传预制文件

将 4 个文件上传到项目文档中，拖入 AI 对话框，告诉 AI：

> 我要制作一个 2D 的地形编辑器。前端 UI 代码和文档、核心逻辑代码和文档你都阅读一下，告诉我你是否理解。

### 第 2 步：回答 AI 的确认问题

AI 会询问几个关键配置，典型回答：

| 问题 | 推荐回答 |
|------|---------|
| 分辨率模式 | B（系统逻辑分辨率）；俯视角游戏选 A |
| 右侧信息面板 | 可以不要，其他严格按文档做 |
| 素材加载 | 上传到素材库后告知层级对应关系 |
| 图集格式 | 会提供图集，bitmask 0~15 对应的 tile 是**列优先**排列 |

### 第 3 步：上传素材并实装

1. 将瓦片图集 PNG 上传到素材库
2. 确认 AI 能读到素材
3. 告诉 AI 层级分配，例如：

> 我要按层级实装地形素材：层 1 使用 Lords_GrassDark，层 2 使用 city_grasstrim，层 3 使用 city_roundtiles

### 第 4 步：测试和修复

完成后进入游戏测试编辑器功能。

---

## Bitmask 自动拼接原理

每个瓦片根据上下左右四个邻居是否同类型，计算一个 4-bit 掩码（0~15），自动从图集中选取对应变体：

```
  上(1)
左(8) [瓦片] 右(2)
  下(4)

bitmask = 上×1 + 右×2 + 下×4 + 左×8
```

- 4×4 图集：16 种变体（bitmask 0~15）
- 8×4 图集：32 种变体（0~15 基础 + 16~31 扩展）

**列优先排列**：bitmask 0~15 在图集中按列从上到下、从左到右排列，不是行优先。

---

## 踩坑修复

### 坑 1：cols/rows 反了（terrain_renderer.lua）

| 项目 | 修复前（错误） | 修复后（正确） |
|------|--------------|--------------|
| 8×4 图集 | cols=4, rows=8 | cols=8, rows=4 |
| 含义 | 误解为 4 列 8 行 | 实际是 8 列 4 行 |

### 坑 2：8×4 和 4×4 图集解析未区分

`LoadLayerTileset` 需要根据图片实际尺寸自动判定图集类型：

```lua
function MultiLayerTerrain:detectAndSetTilesetType(layer, imageWidth, imageHeight)
    if imageWidth == imageHeight then
        self.layers[layer].tilesetType = '4x4'
    else
        self.layers[layer].tilesetType = '8x4'
    end
end
```

完整修复方案：

| 检测逻辑 | 说明 |
|---------|------|
| `nvgImageSize` 获取图片实际尺寸 | 不依赖硬编码 |
| 宽高比 >= 1.9 → 8×4 | 自动判定 |
| 否则 → 4×4 | 自动判定 |
| `tileW = imgW / cols, tileH = imgH / rows` | 自动计算单 tile 尺寸 |
| 检测结果同步回 `multi_terrain` 数据层 | 确保 `resolveFullTile` 对 8×4 正确使用 16~31 变体 |

---

## 多层地形结构

编辑器支持多层叠加，每层独立的瓦片图集：

```
层 3（最上层）—— 地砖/路面
层 2（中间层）—— 草地边缘修饰
层 1（底层）  —— 基础草地
```

层级越高渲染越靠上，编辑时可切换当前编辑层。

---

## 注意事项

| 要点 | 说明 |
|------|------|
| 列优先排列 | bitmask 0~15 在图集中按列排，不是行排 |
| 图集格式 | 需要预先准备好符合 Bitmask 规范的瓦片图集 |
| 自动检测 | 让渲染器根据图片尺寸自动判定 4×4 或 8×4 |
| 预制文件 | 4 个文件是关键，缺少任何一个 AI 都无法完整理解需求 |

---

## 附录：预制文件完整内容

> 以下是 4 个预制文件的完整内容，可直接复制使用，无需额外查找文件。

---

### 附录 A：README.md（核心逻辑功能说明）

```markdown
# 多层位掩码地形编辑器 - 代码文档

## 目录
1. [项目概述](#1-项目概述)
2. [核心概念](#2-核心概念)
3. [系统架构](#3-系统架构)
4. [模块详解](#4-模块详解)
5. [API 参考](#5-api-参考)
6. [数据结构](#6-数据结构)
7. [使用示例](#7-使用示例)

---

## 1. 项目概述

### 1.1 功能简介
这是一个基于 Web 的 Warcraft 3 风格多层位掩码地形编辑器，支持：
- **4层地形叠加**：层号越高越显示在最上层
- **位掩码绘制**：通过点击/拖拽绘制地形，自动处理边缘过渡
- **Tileset 导入**：支持 4×4（16格）和 8×4（32格）两种格式
- **导出功能**：支持 JSON 数据导出和 PNG 图片导出

### 1.2 技术栈
- HTML5 Canvas
- 原生 JavaScript（无框架依赖）
- CSS3

### 1.3 文件结构
tileset-bitmask-editor-multi.html  # 主程序（单文件）
multi_layer_terrain.lua             # Lua 版本（独立模块）

---

## 2. 核心概念

### 2.1 位掩码系统

每个格子使用 4 位掩码表示四个角落的连接状态：

| 位值 | 含义 | 位置 |
|------|------|------|
| 1    | 左上角 | ◖ |
| 2    | 右上角 | ◗ |
| 4    | 左下角 | ◟ |
| 8    | 右下角 | ◠ |

**组合规则**：
- 1 + 4 = 5（左边完整）
- 2 + 8 = 10（右边完整）
- 1 + 2 + 4 + 8 = 15（完整填充）

### 2.2 Tileset 类型

| 类型 | 图片尺寸 | Tile 数量 | 用途 |
|------|----------|-----------|------|
| 4×4  | 正方形   | 16 个     | 简单地形 |
| 8×4  | 2:1 比例 | 32 个     | 复杂地形 |

### 2.3 完整填充规则

当位掩码为 15（四个角全满）时：
- **4×4 tileset**：始终使用 tile 15
- **8×4 tileset**：
  - 地图边缘：使用 tile 0
  - 地图中间：随机使用 tile 16-31

### 2.4 多层渲染

渲染顺序：层1 → 层2 → 层3 → 层4

┌─────────────────────┐
│     层4 (最高)       │  ← 最后渲染，显示在最上层
├─────────────────────┤
│       层3           │
├─────────────────────┤
│       层2           │
├─────────────────────┤
│    层1 (基底)       │  ← 最先渲染
└─────────────────────┘

---

## 3. 系统架构

### 3.1 状态管理

const state = {
    maxLayers: 4,           // 最大层数
    currentLayer: 1,         // 当前编辑层
    layers: {},             // 各层数据对象
    tileWidth: 32,          // 格子宽度
    tileHeight: 32,         // 格子高度
    mapWidth: 20,           // 地图宽度
    mapHeight: 15,          // 地图高度
    currentTool: 'paint',   // 当前工具
    isDrawing: false,       // 是否正在绘制
    lastBrushPos: null      // 上次绘制位置
};

### 3.2 每层数据结构

layer = {
    tileset: null,        // Image 对象
    tiles: [],            // Tile 数组
    tilesetType: '8x4',   // '4x4' 或 '8x4'
    mapData: []           // 二维位掩码数组 [y][x] = bitmask
}

---

## 4. 模块详解

### 4.1 初始化模块 (init)
初始化各层数据 → 初始化地图 → 设置事件监听 → 渲染画布 → 更新 UI

### 4.2 Tileset 解析模块 (parseTileset)
自动检测 tileset 类型（正方形=4×4，其他=8×4），按列优先解析每个 tile 位置。

### 4.3 绘制模块 (paintAtBrush)
点击一个点时，影响周围 4 个格子的角：
- 当前格子(x,y) → 左下角 BL=4
- 右侧(x+1,y) → 右下角 BR=8
- 下方(x,y+1) → 左上角 TL=1
- 右下(x+1,y+1) → 右上角 TR=2

### 4.4 完整填充处理 (resolveFullTile)
4×4 直接用 15；8×4 边缘用 0，中间随机 16-31。

### 4.5 渲染模块 (renderMap)
从低层到高层依次渲染各层 tile，叠加网格线和位掩码数值显示。

---

## 5. API 参考

### 5.1 JavaScript 版本

| 函数 | 描述 |
|------|------|
| init() | 初始化系统 |
| switchLayer(layer) | 切换编辑层 (1-4) |
| loadTileset(file) | 加载 tileset 图片 |
| paintAtBrush(x, y, isErase) | 绘制/擦除 |
| renderMap() | 重新渲染地图 |
| exportMapData() | 导出 JSON 数据 |
| exportMapImage() | 导出 PNG 图片 |
| clearCurrentLayer() | 清空当前层 |
| initMap() | 重置地图数据 |

### 5.2 Lua 版本

| 函数 | 描述 |
|------|------|
| MultiLayerTerrain.new(w, h, layers) | 创建实例 |
| terrain:paint(layer, x, y, isErase) | 绘制/擦除 |
| terrain:getTileIndex(layer, x, y) | 获取 tile 索引 |
| terrain:getRenderTile(x, y) | 获取最终渲染 tile |
| terrain:clearLayer(layer) | 清空指定层 |
| terrain:exportJSON() | 导出 JSON |

---

## 6. 数据结构

### 6.1 导出 JSON 格式

{
  "width": 20,
  "height": 15,
  "tileWidth": 32,
  "tileHeight": 32,
  "layers": {
    "1": { "tilesetType": "8x4", "mapData": [[0, 0, ...], ...] },
    "2": { ... },
    "3": { ... },
    "4": { ... }
  }
}

### 6.2 位掩码含义速查

| 值  | 二进制 | 含义         |
|-----|--------|--------------|
| 0   | 0000   | 空白         |
| 1   | 0001   | 左上         |
| 2   | 0010   | 右上         |
| 3   | 0011   | 上边完整     |
| 4   | 0100   | 左下         |
| 5   | 0101   | 左边完整     |
| 6   | 0110   | 左上+右下    |
| 7   | 0111   | 左+上        |
| 8   | 1000   | 右下         |
| 9   | 1001   | 左上+右下    |
| 10  | 1010   | 右边完整     |
| 11  | 1011   | 上+右边      |
| 12  | 1100   | 下边完整     |
| 13  | 1101   | 左+下边      |
| 14  | 1110   | 右边+下边    |
| 15  | 1111   | 完整填充     |
| 16-31| -     | 变体 tile    |

---

## 7. 使用示例

1. 选择层 → 导入 Tileset → 选择工具 → 绘制地形 → 切换层 → 导出

---

## 8. NanoVG 版本说明

NanoVG 版本使用 WebGL 硬件加速渲染，支持抗锯齿和触摸屏。
渲染器封装为 NanoVGRenderer 对象，提供 init/beginFrame/endFrame/drawImage/fillRect/strokeLine/drawText/rgba 接口。
WebGL 不可用时自动回退到 Canvas 2D。
```

---

### 附录 B：NANOVG.md（NanoVG 前端 UI 代码文档）

```markdown
# NanoVG 多层位掩码地形编辑器 - 代码文档

## 1. 项目概述

### 1.1 简介
基于 NanoVG (WebGL) 的多层位掩码地形编辑器，是 Canvas 2D 版本的硬件加速实现。

### 1.2 核心功能
- 4 层地形叠加渲染（层号越高越显示在上层）
- 位掩码绘制系统（Warcraft 3 风格）
- 支持 4×4（16格）和 8×4（32格）Tileset
- WebGL 硬件加速渲染
- 触摸屏支持

### 1.3 依赖
<script src="https://cdn.jsdelivr.net/npm/nanovg@0.1.3/dist/nanovg.min.js"></script>

---

## 2. 代码结构

单文件（tileset-bitmask-editor-nanovg.html），包含 HTML/CSS/JS。

### 2.2 代码分段
- CSS 样式 (第 7-251 行)：深色主题 + 三栏布局
- HTML 结构 (第 253-355 行)：侧边栏 | 工作区 | 信息面板
- JavaScript (第 360 行开始)

---

## 3. 核心模块详解

### 3.1 NanoVGRenderer 对象
封装 NanoVG 渲染接口：init → beginFrame → drawImage/fillRect/strokeLine/drawText → endFrame。
使用 NVG.create(gl) 初始化，NVG.rgba() 创建颜色。

### 3.2 状态管理
maxLayers=4, currentLayer, layers{}, tileWidth/Height=32, mapWidth=20, mapHeight=15, currentTool, isDrawing, showGrid, showBitmask。

### 3.3 初始化流程
初始化层数据 → resizeCanvas → initMap → NanoVGRenderer.init → setupEventListeners → renderMap → updateLayerUI

### 3.4 Canvas 尺寸调整
CSS 尺寸 = mapWidth * tileWidth；WebGL 尺寸 = CSS * DPR。resize 后需重新创建 NVG 实例。

### 3.5 事件监听
层切换、Tileset 导入（点击/拖拽）、笔刷切换、地图尺寸、清空、导出、画布交互（鼠标+触摸）。

### 3.6 文件处理
loadTileset → FileReader → Image → parseTileset → preprocessTiles（预生成小 canvas）→ renderMap。

### 3.7 绘制逻辑
paintAtBrush 影响 4 格角位；resolveFullTile 处理完整填充；BITMASK = {TL:1, TR:2, BL:4, BR:8}。

### 3.8 NanoVG 渲染
beginFrame → 清空 → 各层 tile → 网格 → 位掩码数值 → endFrame。NanoVG 不可用则回退 Canvas 2D。

### 3.9 鼠标交互
使用 getBoundingClientRect + CSS 尺寸计算 cellX/cellY，支持 mousedown/mousemove/touchstart/touchmove。

---

## 4. 已知问题
- WebGL 兼容性差异：自动回退到 Canvas 2D
- 点击位置计算：需确保 CSS 尺寸与显示一致

## 5. API 速查

| 函数 | 描述 |
|------|------|
| NanoVGRenderer.init(id) | 初始化 NanoVG |
| NanoVGRenderer.beginFrame() | 开始渲染帧 |
| NanoVGRenderer.endFrame() | 结束渲染帧 |
| NanoVGRenderer.drawImage() | 绘制图像 |
| NanoVGRenderer.fillRect() | 绘制矩形 |
| NanoVGRenderer.strokeLine() | 绘制线条 |
| NanoVGRenderer.drawText() | 绘制文字 |
| NanoVGRenderer.rgba() | 创建颜色 |
| init() | 初始化应用 |
| renderMap() | 渲染地图 |
| paintAtBrush(x, y, erase) | 绘制/擦除 |
| loadTileset(file) | 加载 tileset |
| switchLayer(n) | 切换层 |
```

---

### 附录 C：multi_layer_terrain.txt（Lua 多层地形模块完整代码）

```lua
-- War3 多层位掩码地形系统
-- Bitmask: 1=左上, 2=右上, 4=左下, 8=右下
-- 4x4 tileset: 完整填充用15
-- 8x4 tileset: 完整填充边缘用0，中间用16-31随机
-- 多层: 层号高的覆盖层号低的地形

local MultiLayerTerrain = {}
MultiLayerTerrain.__index = MultiLayerTerrain

-- 位掩码常量
local BITMASK = {
    TL = 1,  -- 左上
    TR = 2,  -- 右上
    BL = 4,  -- 左下
    BR = 8   -- 右下
}

-- 创建多层地形系统
function MultiLayerTerrain.new(mapWidth, mapHeight, maxLayers)
    local self = setmetatable({}, MultiLayerTerrain)
    
    self.mapWidth = mapWidth or 20
    self.mapHeight = mapHeight or 15
    self.maxLayers = maxLayers or 4
    self.tileWidth = 32
    self.tileHeight = 32
    
    -- 每层的独立数据
    self.layers = {}
    for layer = 1, self.maxLayers do
        self.layers[layer] = {
            tileset = nil,
            tilesetType = '8x4',
            tilesetImage = nil,
            mapData = {},
            hasTileset = false
        }
        
        for y = 1, self.mapHeight do
            self.layers[layer].mapData[y] = {}
            for x = 1, self.mapWidth do
                self.layers[layer].mapData[y][x] = 0
            end
        end
    end
    
    return self
end

function MultiLayerTerrain:setLayerTilesetType(layer, tilesetType)
    if layer >= 1 and layer <= self.maxLayers then
        self.layers[layer].tilesetType = tilesetType
    end
end

function MultiLayerTerrain:setTileSize(width, height)
    self.tileWidth = width
    self.tileHeight = height
end

function MultiLayerTerrain:detectAndSetTilesetType(layer, imageWidth, imageHeight)
    if layer >= 1 and layer <= self.maxLayers then
        if imageWidth == imageHeight then
            self.layers[layer].tilesetType = '4x4'
        else
            self.layers[layer].tilesetType = '8x4'
        end
        return self.layers[layer].tilesetType
    end
    return nil
end

function MultiLayerTerrain:setLayerTileset(layer, tilesetImage)
    if layer >= 1 and layer <= self.maxLayers then
        self.layers[layer].tileset = tilesetImage
        self.layers[layer].hasTileset = (tilesetImage ~= nil)
    end
end

function MultiLayerTerrain:resolveFullTile(layer, x, y)
    local ix = x - 1
    local iy = y - 1
    
    local tilesetType = self.layers[layer].tilesetType
    
    if tilesetType == '4x4' then
        return 15
    end
    
    local isEdge = (ix == 0 or ix == self.mapWidth - 1 or 
                    iy == 0 or iy == self.mapHeight - 1)
    
    if isEdge then
        return 0
    else
        return 16 + math.random(0, 15)
    end
end

function MultiLayerTerrain:paint(layer, brushX, brushY, isErase)
    if layer < 1 or layer > self.maxLayers then
        return
    end
    
    brushX = brushX or 1
    brushY = brushY or 1
    
    local mapData = self.layers[layer].mapData
    
    if isErase then
        local affectedCells = {
            {x = brushX,     y = brushY,     corner = BITMASK.BL},
            {x = brushX + 1, y = brushY,     corner = BITMASK.BR},
            {x = brushX,     y = brushY + 1, corner = BITMASK.TL},
            {x = brushX + 1, y = brushY + 1, corner = BITMASK.TR}
        }
        
        for _, cell in ipairs(affectedCells) do
            if cell.x >= 1 and cell.x <= self.mapWidth and
               cell.y >= 1 and cell.y <= self.mapHeight then
                mapData[cell.y][cell.x] = mapData[cell.y][cell.x] & ~cell.corner
            end
        end
    else
        local affectedCells = {
            {x = brushX,     y = brushY,     corner = BITMASK.BL},
            {x = brushX + 1, y = brushY,     corner = BITMASK.BR},
            {x = brushX,     y = brushY + 1, corner = BITMASK.TL},
            {x = brushX + 1, y = brushY + 1, corner = BITMASK.TR}
        }
        
        for _, cell in ipairs(affectedCells) do
            if cell.x >= 1 and cell.x <= self.mapWidth and
               cell.y >= 1 and cell.y <= self.mapHeight then
                local before = mapData[cell.y][cell.x]
                local originalBitmask = (before >= 16) and (before - 16) or before
                local after = originalBitmask | cell.corner
                
                if after == 15 then
                    mapData[cell.y][cell.x] = self:resolveFullTile(layer, cell.x, cell.y)
                elseif before >= 16 then
                    mapData[cell.y][cell.x] = 16 + after
                else
                    mapData[cell.y][cell.x] = after
                end
            end
        end
    end
end

function MultiLayerTerrain:getBitmask(layer, x, y)
    if layer < 1 or layer > self.maxLayers then
        return 0
    end
    return self.layers[layer].mapData[y][x]
end

function MultiLayerTerrain:getTileIndex(layer, x, y)
    if layer < 1 or layer > self.maxLayers then
        return -1
    end
    
    local bitmask = self.layers[layer].mapData[y][x]
    
    if bitmask == 0 then
        return -1
    end
    
    if bitmask >= 16 then
        return bitmask
    end
    
    return bitmask
end

function MultiLayerTerrain:getRenderTile(x, y)
    for layer = self.maxLayers, 1, -1 do
        local tileIndex = self:getTileIndex(layer, x, y)
        if tileIndex >= 0 then
            return tileIndex, layer
        end
    end
    return -1, 0
end

function MultiLayerTerrain:getRenderLayer(x, y)
    for layer = self.maxLayers, 1, -1 do
        if self:getTileIndex(layer, x, y) >= 0 then
            return layer
        end
    end
    return 0
end

function MultiLayerTerrain:clearLayer(layer)
    if layer >= 1 and layer <= self.maxLayers then
        for y = 1, self.mapHeight do
            for x = 1, self.mapWidth do
                self.layers[layer].mapData[y][x] = 0
            end
        end
    end
end

function MultiLayerTerrain:clearAll()
    for layer = 1, self.maxLayers do
        self:clearLayer(layer)
    end
end

function MultiLayerTerrain:resize(width, height)
    self.mapWidth = width
    self.mapHeight = height
    
    for layer = 1, self.maxLayers do
        self.layers[layer].mapData = {}
        for y = 1, self.mapHeight do
            self.layers[layer].mapData[y] = {}
            for x = 1, self.mapWidth do
                self.layers[layer].mapData[y][x] = 0
            end
        end
    end
end

function MultiLayerTerrain:randomFillLayer(layer)
    if layer < 1 or layer > self.maxLayers then
        return
    end
    
    math.randomseed(os.time())
    for y = 1, self.mapHeight do
        for x = 1, self.mapWidth do
            if math.random() > 0.6 then
                self.layers[layer].mapData[y][x] = math.random(1, 15)
            end
        end
    end
end

function MultiLayerTerrain:exportJSON()
    local lines = {}
    table.insert(lines, '{')
    table.insert(lines, string.format('  "width": %d,', self.mapWidth))
    table.insert(lines, string.format('  "height": %d,', self.mapHeight))
    table.insert(lines, string.format('  "tileWidth": %d,', self.tileWidth))
    table.insert(lines, string.format('  "tileHeight": %d,', self.tileHeight))
    table.insert(lines, string.format('  "maxLayers": %d,', self.maxLayers))
    
    table.insert(lines, '  "layers": {')
    for layer = 1, self.maxLayers do
        table.insert(lines, string.format('    "layer%d": {', layer))
        table.insert(lines, string.format('      "tilesetType": "%s",', self.layers[layer].tilesetType))
        table.insert(lines, '      "mapData": [')
        
        for y = 1, self.mapHeight do
            local rowStr = {}
            for x = 1, self.mapWidth do
                table.insert(rowStr, tostring(self.layers[layer].mapData[y][x]))
            end
            if y < self.mapHeight then
                table.insert(lines, '        [' .. table.concat(rowStr, ', ') .. '],')
            else
                table.insert(lines, '        [' .. table.concat(rowStr, ', ') .. ']')
            end
        end
        
        if layer < self.maxLayers then
            table.insert(lines, '      }')
        else
            table.insert(lines, '      }')
        end
    end
    table.insert(lines, '  }')
    table.insert(lines, '}')
    
    return table.concat(lines, '\n')
end

function MultiLayerTerrain:printLayer(layer)
    if layer < 1 or layer > self.maxLayers then
        print(string.format("Invalid layer: %d", layer))
        return
    end
    
    print(string.format("Layer %d - Map %dx%d:", layer, self.mapWidth, self.mapHeight))
    for y = 1, self.mapHeight do
        local row = {}
        for x = 1, self.mapWidth do
            table.insert(row, string.format('%2d', self.layers[layer].mapData[y][x]))
        end
        print('  ' .. table.concat(row, ' '))
    end
end

function MultiLayerTerrain:printAllLayers()
    print(string.format("=== Multi-Layer Terrain %dx%d (Max %d layers) ===", 
        self.mapWidth, self.mapHeight, self.maxLayers))
    for layer = 1, self.maxLayers do
        self:printLayer(layer)
    end
end

function MultiLayerTerrain:getLayerInfo(layer)
    if layer >= 1 and layer <= self.maxLayers then
        return {
            tilesetType = self.layers[layer].tilesetType,
            hasTileset = self.layers[layer].hasTileset
        }
    end
    return nil
end

-- 使用示例:
-- local terrain = MultiLayerTerrain.new(20, 15, 4)
-- terrain:detectAndSetTilesetType(1, 256, 256)  -- 4x4
-- terrain:paint(1, 5, 5, false)
-- local tileIndex, layer = terrain:getRenderTile(5, 5)
-- local json = terrain:exportJSON()

return MultiLayerTerrain
```

---

### 附录 D：tileset-bitmask-editor-nanovg.txt（NanoVG 前端 UI 完整代码）

> 这是完整的 HTML 单文件应用，包含 CSS 样式、HTML 结构和 JavaScript 逻辑。

```html
<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>多层位掩码地形编辑器 (NanoVG)</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        
        :root {
            --bg-primary: #1a1a2e;
            --bg-secondary: #16213e;
            --bg-tertiary: #0f3460;
            --accent: #e94560;
            --text-primary: #eaeaea;
            --text-secondary: #a0a0a0;
            --border: #2a2a4a;
        }
        
        body {
            font-family: 'Segoe UI', system-ui, sans-serif;
            background: var(--bg-primary);
            color: var(--text-primary);
            min-height: 100vh;
            display: flex;
            flex-direction: column;
        }
        
        header {
            background: var(--bg-secondary);
            padding: 12px 20px;
            border-bottom: 1px solid var(--border);
            display: flex;
            align-items: center;
            justify-content: space-between;
        }
        
        h1 { font-size: 16px; font-weight: 600; }
        .header-info { font-size: 12px; color: var(--text-secondary); }
        
        main { flex: 1; display: flex; overflow: hidden; }
        
        .sidebar {
            width: 280px;
            background: var(--bg-secondary);
            border-right: 1px solid var(--border);
            display: flex;
            flex-direction: column;
            overflow-y: auto;
        }
        
        .sidebar-section { padding: 14px; border-bottom: 1px solid var(--border); }
        .sidebar-section h3 {
            font-size: 11px; text-transform: uppercase;
            letter-spacing: 1px; color: var(--text-secondary); margin-bottom: 10px;
        }
        
        .layer-tabs { display: flex; gap: 4px; margin-bottom: 12px; }
        .layer-tab {
            flex: 1; padding: 8px 4px; background: var(--bg-tertiary);
            border: 1px solid var(--border); border-radius: 4px;
            cursor: pointer; text-align: center; font-size: 12px; transition: all 0.2s;
        }
        .layer-tab:hover { background: var(--accent); }
        .layer-tab.active { background: var(--accent); border-color: var(--accent); }
        .layer-tab.has-tileset { position: relative; }
        .layer-tab.has-tileset::after {
            content: ''; position: absolute; top: 2px; right: 2px;
            width: 6px; height: 6px; background: #2ecc71; border-radius: 50%;
        }
        
        .tileset-import {
            border: 2px dashed var(--border); border-radius: 6px;
            padding: 12px; text-align: center; cursor: pointer;
            transition: all 0.2s; margin-bottom: 10px;
        }
        .tileset-import:hover { border-color: var(--accent); background: rgba(233, 69, 96, 0.08); }
        .tileset-import.dragover { border-color: var(--accent); background: rgba(233, 69, 96, 0.15); }
        .tileset-import p { font-size: 11px; color: var(--text-secondary); }
        #fileInput { display: none; }
        
        .tileset-preview { max-height: 200px; overflow-y: auto; }
        #tilesetCanvas {
            width: 100%; image-rendering: pixelated;
            border: 1px solid var(--border); border-radius: 4px;
        }
        
        .brush-controls { display: flex; gap: 8px; flex-wrap: wrap; }
        .brush-btn {
            background: var(--bg-tertiary); border: 1px solid var(--border);
            color: var(--text-primary); padding: 6px 12px;
            border-radius: 4px; cursor: pointer; font-size: 12px; transition: all 0.2s;
        }
        .brush-btn:hover { background: var(--accent); border-color: var(--accent); }
        .brush-btn.active { background: var(--accent); border-color: var(--accent); }
        
        .workspace { flex: 1; display: flex; flex-direction: column; overflow: hidden; }
        
        .toolbar {
            background: var(--bg-secondary); padding: 10px 16px;
            border-bottom: 1px solid var(--border);
            display: flex; gap: 12px; align-items: center;
        }
        .toolbar-section {
            display: flex; gap: 8px; align-items: center;
            padding-right: 12px; border-right: 1px solid var(--border);
        }
        .toolbar-section:last-child { border-right: none; }
        .toolbar label { font-size: 11px; color: var(--text-secondary); }
        .toolbar input[type="number"] {
            width: 50px; background: var(--bg-tertiary);
            border: 1px solid var(--border); color: var(--text-primary);
            padding: 4px 6px; border-radius: 3px; font-size: 12px;
        }
        
        .btn {
            background: var(--accent); color: white; border: none;
            padding: 6px 12px; border-radius: 4px; cursor: pointer; font-size: 12px;
        }
        .btn:hover { opacity: 0.9; }
        .btn-secondary { background: var(--bg-tertiary); border: 1px solid var(--border); }
        
        .canvas-container {
            flex: 1; overflow: auto;
            background: repeating-linear-gradient(90deg, #1a1a2e 0px, #1a1a2e 1px, transparent 1px, transparent 64px),
                        repeating-linear-gradient(0deg, #1a1a2e 0px, #1a1a2e 1px, transparent 1px, transparent 64px), #0f0f1a;
            background-size: 64px 64px;
            display: flex; align-items: center; justify-content: center; padding: 24px;
        }
        
        #mapCanvas {
            box-shadow: 0 4px 24px rgba(0,0,0,0.5);
            cursor: crosshair; display: block; background: #0f0f1a;
        }
        
        .info-panel { width: 200px; background: var(--bg-secondary); border-left: 1px solid var(--border); }
        .info-section { padding: 14px; border-bottom: 1px solid var(--border); }
        .info-section h3 {
            font-size: 11px; text-transform: uppercase;
            letter-spacing: 1px; color: var(--text-secondary); margin-bottom: 10px;
        }
        .current-layer-info { font-size: 12px; margin-bottom: 8px; }
        .layer-status {
            display: flex; align-items: center; gap: 8px;
            padding: 6px; background: var(--bg-tertiary);
            border-radius: 4px; margin-bottom: 8px;
        }
        .layer-dot { width: 12px; height: 12px; border-radius: 50%; }
        .layer-1 { background: #3498db; }
        .layer-2 { background: #2ecc71; }
        .layer-3 { background: #f39c12; }
        .layer-4 { background: #e74c3c; }
        .bitmask-legend { display: grid; grid-template-columns: 1fr 1fr; gap: 6px; font-size: 11px; }
        .bitmask-item {
            display: flex; align-items: center; gap: 6px;
            padding: 4px 6px; background: var(--bg-tertiary); border-radius: 3px;
        }
        .corner-box { width: 12px; height: 12px; border-radius: 2px; background: var(--accent); }
        
        .status-bar {
            background: var(--bg-secondary); padding: 8px 16px;
            border-top: 1px solid var(--border);
            display: flex; justify-content: space-between;
            font-size: 11px; color: var(--text-secondary);
        }
    </style>
</head>
<body>
    <header>
        <h1>多层位掩码地形编辑器 (NanoVG)</h1>
        <span class="header-info">层1=基底，层4最高 | 位掩码: 1=左上,2=右上,4=左下,8=右下</span>
    </header>
    
    <main>
        <aside class="sidebar">
            <div class="sidebar-section">
                <h3>选择编辑层</h3>
                <div class="layer-tabs">
                    <div class="layer-tab active" data-layer="1">层1<br><small>基底</small></div>
                    <div class="layer-tab" data-layer="2">层2</div>
                    <div class="layer-tab" data-layer="3">层3</div>
                    <div class="layer-tab" data-layer="4">层4</div>
                </div>
            </div>
            <div class="sidebar-section">
                <h3>层1 Tileset (4x4)</h3>
                <div class="tileset-import" id="dropZone">
                    <p>拖拽或点击导入<br>支持 4x4(16格) 或 8x4(32格)</p>
                </div>
                <input type="file" id="fileInput" accept="image/*">
                <div class="tileset-preview">
                    <canvas id="tilesetCanvas"></canvas>
                </div>
            </div>
            <div class="sidebar-section">
                <h3>笔刷工具</h3>
                <div class="brush-controls">
                    <button class="brush-btn active" data-tool="paint">绘制</button>
                    <button class="brush-btn" data-tool="erase">擦除</button>
                </div>
            </div>
        </aside>
        
        <div class="workspace">
            <div class="toolbar">
                <div class="toolbar-section">
                    <label>地图尺寸</label>
                    <input type="number" id="mapWidth" value="20" min="5" max="50">
                    <span>x</span>
                    <input type="number" id="mapHeight" value="15" min="5" max="50">
                    <button class="btn btn-secondary" id="resizeMap">应用</button>
                </div>
                <div class="toolbar-section">
                    <button class="btn" id="clearMap">清空当前层</button>
                    <button class="btn" id="clearAll">清空全部</button>
                </div>
                <div class="toolbar-section">
                    <button class="btn btn-secondary" id="exportMap">导出</button>
                    <button class="btn btn-secondary" id="exportImage">导出图片</button>
                </div>
                <div class="toolbar-section">
                    <label><input type="checkbox" id="showGrid"> 网格</label>
                    <label><input type="checkbox" id="showBitmask" checked> 位掩码</label>
                </div>
            </div>
            <div class="canvas-container">
                <canvas id="mapCanvas"></canvas>
            </div>
        </div>
        
        <aside class="info-panel">
            <div class="info-section">
                <h3>当前层信息</h3>
                <div class="layer-status">
                    <div class="layer-dot layer-1" id="currentLayerDot"></div>
                    <span id="currentLayerText">层1 (基底)</span>
                </div>
                <div class="current-layer-info">
                    <div>位掩码: <span id="cellBitmask">-</span></div>
                    <div>Tile索引: <span id="cellIndex">-</span></div>
                </div>
            </div>
            <div class="info-section">
                <h3>位掩码规则</h3>
                <div class="bitmask-legend">
                    <div class="bitmask-item"><div class="corner-box"></div><span>1 = 左上</span></div>
                    <div class="bitmask-item"><div class="corner-box"></div><span>2 = 右上</span></div>
                    <div class="bitmask-item"><div class="corner-box"></div><span>4 = 左下</span></div>
                    <div class="bitmask-item"><div class="corner-box"></div><span>8 = 右下</span></div>
                </div>
            </div>
            <div class="info-section">
                <h3>层状态</h3>
                <div id="layerStatusList"></div>
            </div>
        </aside>
    </main>
    
    <div class="status-bar">
        <span id="statusText">选择层并导入Tileset开始编辑</span>
        <span id="layerInfo">当前: 层1</span>
    </div>

    <script src="https://cdn.jsdelivr.net/npm/nanovg@0.1.3/dist/nanovg.min.js"></script>
    
    <script>
        // ===== NanoVG 渲染器 =====
        // （完整 JavaScript 代码见上方 NanoVGRenderer 对象定义、状态管理、
        //   初始化、事件监听、层切换、文件处理、绘制逻辑、
        //   NanoVG 渲染、Canvas 2D 回退、鼠标/触摸交互、导出等全部模块）
        // 完整代码约 1280 行，此处为节省篇幅已在附录 B 的文档中详细说明每个模块。
        // 实际使用时请从原始 tileset-bitmask-editor-nanovg.txt 文件获取完整代码。
    </script>
</body>
</html>
```

> **注意**：附录 D 的 `<script>` 部分因篇幅原因做了摘要。完整的 JavaScript 代码（约 1280 行）包含 NanoVGRenderer 渲染器封装、状态管理、初始化、Canvas DPR 适配、层切换 UI、Tileset 文件拖拽导入与解析、位掩码绘制逻辑（paintAtBrush/resolveFullTile）、NanoVG 渲染管线、Canvas 2D 回退渲染、鼠标与触摸交互、JSON/PNG 导出等完整功能。各模块的详细代码结构和 API 已在附录 B（NANOVG.md）中完整记录。

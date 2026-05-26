---
title: "格子地图 BFS 寻路系统"
这是什么: 格子地图（魔塔类）自动寻路的完整实现方案——从 BFS 算法核心到点击门/NPC 的特殊处理、路径平滑执行、双输入共存，覆盖了格子寻路的全部实战细节。
原作者: 点点
推荐度: L1（实战参考）
适用场景: 格子/瓦片地图游戏的点击自动寻路；魔塔、Roguelike、回合制 RPG 等需要 BFS 寻路的 2D 游戏
---

# 格子地图 BFS 寻路系统

> 基于魔塔（逃离乐园）的实际开发记录。

---

## 一、算法选择

| 算法 | 特点 | 适用场景 |
|------|------|---------|
| **BFS（广度优先）** | 保证最短路径，逻辑最简单 | 格子地图、移动代价统一 |
| A* | 启发函数加速，大地图更快 | 大型地图、移动代价不同 |
| Dijkstra | 支持不同权重最短路径 | 有地形代价（沼泽慢、道路快） |

**结论**：格子地图（≤50×50）、移动代价统一 → **BFS 足够**。最坏 2500 次遍历，无需优化。

---

## 二、地图数据结构

### 2.1 二维数组 + 通行性查找表

```lua
-- 地图：二维数组，行优先，mapData[y][x]
local mapData = {
    { 8, 8, 8, 8, 8 },    -- 全是墙
    { 8, 2, 2, 2, 8 },    -- 墙-路-路-路-墙
    { 8, 2, 8, 2, 8 },    -- 中间有堵墙
    { 8, 2, 2, 2, 8 },
    { 8, 8, 8, 8, 8 },
}

-- 瓦片类型
local TILE = {
    GRASS = 1, PATH = 2, WALL = 8, DOOR = 11, HOUSE = 6,
}

-- 不可通行集合（新增类型只加这里，寻路代码不用改）
local SOLID_TILES = {
    [TILE.WALL] = true, [TILE.DOOR] = true, [TILE.HOUSE] = true,
}

function IsTilePassable(tx, ty)
    if tx < 1 or tx > mapWidth or ty < 1 or ty > mapHeight then
        return false
    end
    return not SOLID_TILES[mapData[ty][tx]]
end
```

### 2.2 坐标转换

格子游戏有两套坐标，**搞混必出 BUG**：

| 类型 | 范围 | 说明 |
|------|------|------|
| 瓦片索引 | 整数，从 **1** 开始 | 第几行第几列，查地图数据用 |
| 玩家坐标 | 浮点数，0.5 为格子中心 | 渲染和平滑移动用 |

```lua
-- 玩家坐标 → 瓦片索引
function PosToTileX(x)
    return math.floor(x) + 1   -- 0.5 → 1, 1.5 → 2
end

-- 瓦片索引 → 格子中心坐标
function TileCenterX(tileIdx)
    return tileIdx - 0.5        -- 1 → 0.5, 2 → 1.5
end
```

> **踩坑**：Lua 数组从 1 开始，`PosToTileX` 如果忘了 `+1`，索引为 0 时查表返回 nil → 崩溃。

---

## 三、BFS 核心实现

```lua
function bfsPath(sx, sy, gx, gy)
    local mapW = GetMapWidth()
    local mapH = GetMapHeight()

    -- 一维 key 避免二维 table 开销
    local function key(x, y) return (y - 1) * mapW + x end

    local visited = {}
    local parent = {}     -- parent[key] = {x, y, parentKey}
    local startK = key(sx, sy)
    visited[startK] = true

    local queue = { { sx, sy } }
    local head = 1        -- 头指针模拟队列（O(1) 出队）
    local goalK = key(gx, gy)
    local dirs = { {0,-1}, {0,1}, {-1,0}, {1,0} }

    while head <= #queue do
        local cur = queue[head]
        head = head + 1
        local cx, cy = cur[1], cur[2]
        local ck = key(cx, cy)

        if ck == goalK then
            -- 回溯路径（终点→起点，需反转）
            local path = {}
            local k = goalK
            while k ~= startK do
                local info = parent[k]
                path[#path + 1] = { tx = info[1], ty = info[2] }
                k = info[3]
            end
            local n = #path
            for i = 1, math.floor(n / 2) do
                path[i], path[n - i + 1] = path[n - i + 1], path[i]
            end
            return path  -- 不含起点，直接遍历即为每一步
        end

        for _, d in ipairs(dirs) do
            local nx, ny = cx + d[1], cy + d[2]
            if nx >= 1 and nx <= mapW and ny >= 1 and ny <= mapH then
                local nk = key(nx, ny)
                if not visited[nk] and IsTilePassable(nx, ny) then
                    visited[nk] = true
                    parent[nk] = { nx, ny, ck }
                    queue[#queue + 1] = { nx, ny }
                end
            end
        end
    end

    return nil  -- 无路可达
end
```

### 实现要点

| 技巧 | 原因 |
|------|------|
| 一维 key `(y-1)*W+x` | 单 table 查找，比二维 `visited[x][y]` 快 |
| `head` 指针模拟队列 | `table.remove(q,1)` 是 O(n)，指针移动是 O(1) |
| 路径不含起点 | 调用方直接遍历就是要走的每一步 |

---

## 四、点击门 / NPC 的特殊处理

门和 NPC 本身不可通行，BFS 找不到路。交互逻辑：**走到旁边 → 面朝目标 → 触发交互**。

```lua
if IsTileDoor(tileX, tileY) then
    -- 已经在旁边 → 直接面朝门触发
    local dist = math.abs(tileX - curTX) + math.abs(tileY - curTY)
    if dist == 1 then
        player.direction = calcFaceDir(curTX, curTY, tileX, tileY)
        doorDetected = true
        return
    end

    -- 找门旁边最近的可通行格
    local adjDirs = { {0,-1}, {0,1}, {-1,0}, {1,0} }
    local bestAdj, bestDist = nil, math.huge
    for _, d in ipairs(adjDirs) do
        local ax, ay = tileX + d[1], tileY + d[2]
        if IsTilePassable(ax, ay) then
            local d2 = math.abs(ax - curTX) + math.abs(ay - curTY)
            if d2 < bestDist then
                bestDist = d2
                bestAdj = { x = ax, y = ay }
            end
        end
    end
    if not bestAdj then return end

    -- 寻路到邻居格，记录到达后朝向
    local path = bfsPath(curTX, curTY, bestAdj.x, bestAdj.y)
    if not path then return end
    movePath = path
    pendingFaceDir = calcFaceDir(bestAdj.x, bestAdj.y, tileX, tileY)
end
```

**到达后转向**：

```lua
if pathIndex > #movePath then
    movePath = nil
    if pendingFaceDir then
        player.direction = pendingFaceDir
        pendingFaceDir = nil
        doorDetected = true   -- 通知主循环触发交互
    end
end
```

---

## 五、路径执行：逐格追踪 + 对齐

```lua
local movePath = nil
local movePathIdx = 0
local moveWaypoint = nil

function UpdateMove(dt)
    if not movePath then return end

    if not moveWaypoint then
        if movePathIdx <= #movePath then
            local wp = movePath[movePathIdx]
            moveWaypoint = {
                x = TileCenterX(wp.tx),
                y = TileCenterY(wp.ty),
            }
            player.direction = calcDirection(player, moveWaypoint)
        else
            movePath = nil  -- 路径走完
            return
        end
    end

    local dx = moveWaypoint.x - player.x
    local dy = moveWaypoint.y - player.y
    local dist = math.sqrt(dx * dx + dy * dy)

    if dist < 0.05 then
        -- 到达 → 强制对齐格子中心
        player.x = moveWaypoint.x
        player.y = moveWaypoint.y
        moveWaypoint = nil
        movePathIdx = movePathIdx + 1
    else
        local step = math.min(speed * dt, dist)
        player.x = player.x + (dx / dist) * step
        player.y = player.y + (dy / dist) * step
    end
end
```

> **为什么每步对齐？** 浮点累积误差走 10 格后可能偏 0.001，`PosToTileX` 算出错误索引 → 碰撞检测出错。每步强制对齐就没这个问题。

---

## 六、双输入共存（键盘 + 触摸）

```lua
-- 键盘按下 → 立即取消寻路
if keyboardDir ~= NONE then
    movePath = nil
    moveWaypoint = nil
end

-- 触摸点击 → 重新计算路径
if touchClicked then
    movePath = bfsPath(...)
    movePathIdx = 1
end
```

**规则**：键盘优先级高于触摸，中途按方向键立即切手动。

**切层冻结**：上楼梯切到新楼层时，如果方向键还按着角色会立刻走一格。设 `inputFrozen` 标记，等松开所有方向键再解冻。

---

## 七、实战清单

| 步骤 | 要点 |
|------|------|
| 1. 地图数据 | 二维数组 + 查找表判断通行性 |
| 2. 坐标转换 | 瓦片索引（整数从 1）与玩家坐标（浮点数）分清 |
| 3. 寻路算法 | 小地图 BFS 足够（最短路径 + 代码简单） |
| 4. 不可通行目标 | 门/NPC → 寻路到旁边最近可通行格 + 记录到达后朝向 |
| 5. 路径执行 | 逐格追踪，每步对齐格子中心，避免浮点漂移 |
| 6. 输入优先级 | 键盘覆盖触摸，切层后冻结输入 |

> 格子寻路本身不难，BFS 几十行写完。真正花时间的是边界情况——点击门怎么办、不可达怎么办、走到一半切输入怎么办。

---

> **素材来源**: TapTap 开发者论坛 · 点点 · 开发日记
> **蒸馏日期**: 2026-05-01
> **蒸馏等级**: L1 — 重新组织结构，保留全部实用代码和踩坑经验

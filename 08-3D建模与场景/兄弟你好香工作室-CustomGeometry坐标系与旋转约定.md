# CustomGeometry 坐标系与旋转约定

> **这是什么**: 使用 CustomGeometry 程序化生成 3D 模型时的坐标系规则和 Quaternion 旋转方向约定，含各轴旋转速查表。  
> **原作者**: 兄弟你好香工作室  
> **推荐度**: L2（参考学习价值 — 方块人体版本，部分写法稍过时，但坐标系与旋转原理通用）  
> **适用场景**: CustomGeometry 程序化建模、骨骼/关节旋转控制、方块人/体素角色制作

---

## 坐标系基础

### Y-up 左手坐标系（与 Unity 相同）

```
        Y (UP)
        │
        │
        │
        └───── X (RIGHT)
       /
      /
     Z (FORWARD)
```

| 轴 | 方向 | 常量 |
|----|------|------|
| +X | 向右 | `Vector3.RIGHT` |
| +Y | 向上 | `Vector3.UP` |
| +Z | 向前（屏幕内） | `Vector3.FORWARD` |

### 面的朝向（面法线）

从 +Z 方向观察，**逆时针**顶点顺序的面朝向观察者（正面）：

```lua
-- 一个朝向 +Z 方向的正方形面
geom:DefineVertex(Vector3(-0.5, -0.5, 0))  -- 左下
geom:DefineVertex(Vector3( 0.5, -0.5, 0))  -- 右下
geom:DefineVertex(Vector3( 0.5,  0.5, 0))  -- 右上
-- 三角形 1: 左下 → 右下 → 右上（逆时针 → 面朝 +Z）
```

---

## Quaternion 旋转规则

### 核心：右手定则（无论坐标系左手右手）

**Quaternion 始终使用右手定则判断旋转方向**：

> 右手大拇指指向旋转轴正方向 → 四指弯曲方向 = **正角度**旋转方向

这与坐标系是左手还是右手**无关**。

---

## 各轴旋转速查表

### 绕 Z 轴旋转（Vector3.FORWARD）

右手大拇指指向 +Z（屏幕内），四指弯曲方向 = 从 +X 向 +Y（逆时针）。

| 角度 | 旋转方向 | 用途示例 |
|------|---------|---------|
| `+90°` | 向右倾倒（朝 +X） | 右臂平举 |
| `-90°` | 向左倾倒（朝 -X） | 左臂平举 |

```lua
-- 手臂绕肩膀旋转
-- ❌ 左臂却指向了右边
SetRot("leftShoulderPivot", Quaternion(90, Vector3.FORWARD))

-- ✅ 左臂指向左边
SetRot("leftShoulderPivot", Quaternion(-90, Vector3.FORWARD))
```

### 绕 X 轴旋转（Vector3.RIGHT）

右手大拇指指向 +X（右方），四指弯曲方向 = 从 +Y 向 +Z。

| 角度 | 旋转方向 | 用途示例 |
|------|---------|---------|
| `+角度` | 向后倾（朝 -Z / 背面） | 仰头、后仰 |
| `-角度` | 向前倾（朝 +Z / 正面） | 低头、前踢 |

```lua
-- 腿部绕髋关节旋转
-- 抬腿向前踢 = 绕 X 轴负角度
SetRot("leftHipPivot", Quaternion(-45, Vector3.RIGHT))

-- 腿向后摆 = 绕 X 轴正角度
SetRot("leftHipPivot", Quaternion(30, Vector3.RIGHT))
```

### 绕 Y 轴旋转（Vector3.UP）

右手大拇指指向 +Y（上方），四指弯曲方向 = 从 +Z 向 +X。

| 角度 | 旋转方向 | 用途示例 |
|------|---------|---------|
| `+角度` | 从正面转向右侧 | 右转头 |
| `-角度` | 从正面转向左侧 | 左转头 |

```lua
-- 头部左右转
SetRot("headPivot", Quaternion(30, Vector3.UP))   -- 右转 30°
SetRot("headPivot", Quaternion(-30, Vector3.UP))  -- 左转 30°
```

---

## 关节弯曲速查

人体关节弯曲方向的快速记忆法：

| 关节 | 旋转轴 | 弯曲角度 | 说明 |
|------|--------|---------|------|
| 肘关节 | `Vector3.RIGHT` | **负角度** | 小臂向身体前方弯曲 |
| 膝关节 | `Vector3.RIGHT` | **正角度** | 小腿向身体后方弯曲 |
| 肩膀抬臂 | `Vector3.FORWARD` | ±90° | +90 右臂抬起，-90 左臂抬起 |
| 髋关节前踢 | `Vector3.RIGHT` | **负角度** | 腿向前抬 |

```lua
-- 肘部弯曲 90°（小臂向前弯）
SetRot("leftElbowPivot", Quaternion(-90, Vector3.RIGHT))

-- 膝盖弯曲 90°（小腿向后弯）
SetRot("leftKneePivot", Quaternion(90, Vector3.RIGHT))
```

---

## 5 个常见陷阱

### 陷阱 1：弄反旋转方向

```lua
-- ❌ 想让左臂平举，结果指向右边
node.rotation = Quaternion(90, Vector3.FORWARD)

-- ✅ 左臂平举 = 绕 Z 轴负角度
node.rotation = Quaternion(-90, Vector3.FORWARD)
```

**解法**：用右手定则先判断正角度方向，再决定正负。

### 陷阱 2：混淆旋转轴

```lua
-- ❌ 想让角色低头，用了 Y 轴（这是左右转头）
node.rotation = Quaternion(-30, Vector3.UP)

-- ✅ 低头 = 绕 X 轴（RIGHT）负角度
node.rotation = Quaternion(-30, Vector3.RIGHT)
```

**记忆法**：
- 左右转 → Y 轴（UP）
- 抬低头 → X 轴（RIGHT）
- 左右倾 → Z 轴（FORWARD）

### 陷阱 3：忘记 Pivot 偏移

旋转是绕节点原点进行的。如果关节不在原点，需要用 Pivot 节点偏移：

```lua
-- 在肩膀位置创建 Pivot 节点
local shoulderPivot = bodyNode:CreateChild("shoulderPivot")
shoulderPivot.position = Vector3(0.3, 0.8, 0)  -- 肩膀位置

-- 手臂挂在 Pivot 下面
local armNode = shoulderPivot:CreateChild("arm")
armNode.position = Vector3(0.3, 0, 0)  -- 相对肩膀的偏移

-- 旋转 Pivot = 手臂绕肩膀旋转
shoulderPivot.rotation = Quaternion(-90, Vector3.FORWARD)
```

### 陷阱 4：多轴旋转顺序错误

Quaternion 乘法不满足交换律，`A * B ≠ B * A`：

```lua
-- 先绕 Y 转 30°，再绕 X 转 -20°
local rot = Quaternion(30, Vector3.UP) * Quaternion(-20, Vector3.RIGHT)

-- 这和下面的结果不同！
local rot2 = Quaternion(-20, Vector3.RIGHT) * Quaternion(30, Vector3.UP)
```

**建议**：复杂姿态尽量拆成独立 Pivot 节点的单轴旋转，避免多轴组合。

### 陷阱 5：面的正反搞错

顶点顺序决定面朝向。从目标方向看去应该是逆时针：

```lua
-- 一个朝上的面（从 +Y 向下看，顶点逆时针）
geom:DefineVertex(Vector3(-0.5, 0,  0.5))  -- 左前
geom:DefineVertex(Vector3( 0.5, 0,  0.5))  -- 右前
geom:DefineVertex(Vector3( 0.5, 0, -0.5))  -- 右后
-- 如果看到黑面 → 顶点顺序反了，交换任意两个顶点即可
```

---

## 自查清单

- [ ] 坐标系确认：Y 向上、X 向右、Z 向前？
- [ ] 旋转方向：用右手定则验证了正角度方向？
- [ ] 旋转轴选择：左右转=Y，抬低头=X，侧倾=Z？
- [ ] Pivot 节点：关节旋转有正确的旋转中心？
- [ ] 面朝向：从目标方向看去是逆时针？

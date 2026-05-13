> **这是什么**: UrhoX/SCE 引擎 API 可用性守卫 — 黑名单（绝对不可用）、灰名单（容易用错）、三步验证流程、替代方案思维、自更新协议
> **原作者**: 节拍前夜（项目自研）
> **推荐度**: L2（学习参考价值）— 编码前自动拦截不可用 API，避免运行时崩溃
> **适用场景**: UrhoX Lua 游戏开发，特别是新接触引擎的开发者避坑

---

# UrhoX 引擎 API 可用性黑灰名单防护

## 核心流程

编写每一行引擎 API 调用前，执行三步检查：

```
1. 黑名单拦截 → 命中？→ 用替代方案
2. 灰名单警惕 → 命中？→ 查文档确认用法
3. 不确定？    → 查 LSP / .emmylua / engine-docs/api/ 验证
```

---

## 一、黑名单（绝对不可用）

### 标准 Lua 沙箱移除

| 被移除 API | 替代方案 |
|-----------|---------|
| `io` 库（io.open/read/write/close） | `File` 类 |
| `loadfile()` / `dofile()` | `require` |
| `os.execute()` / `os.remove()` / `os.rename()` | 无替代（`os.clock`/`os.time`/`os.date` 可用） |
| `debug` 库 | 无替代 |

### 引擎 API 禁用

| 被禁用 API | 替代方案 |
|-----------|---------|
| `graphics:SetMode(...)` | `graphics:GetWidth()` / `GetHeight()` / `GetDPR()` |
| `FileSystem:SystemCommand()` | 无替代（沙箱禁止系统调用） |
| `FileSystem:GetProgramDir()` 等路径 getter | 返回空字符串 |
| `NamedPipe` / `PackageFile` | 无替代 |

### 已废弃系统

| 废弃项 | 替代方案 |
|-------|---------|
| 原生 UI（UIElement/Button/Text/Window） | `urhox-libs/UI`（Yoga+NanoVG，40+控件） |
| `sscores`（旧排行榜） | `clientScore` API |

---

## 二、灰名单（容易用错）

| API / 场景 | 陷阱 | 正确用法 |
|-----------|------|---------|
| `eventData["TimeStep"]` | iOS 容器可能减半 | 用 `time:GetElapsedTime()` 交叉验证 |
| `eventData["Key"]:GetInt()` | tolua++ 绑定方式 | `eventData:GetInt("Key")` 更高效 |
| `nvgCreateFont()` | 每次调用分配显存 | `Start()` 中调一次，句柄复用 |
| NanoVG 绑在 `Update` 事件 | 不渲染任何东西 | 必须用 `NanoVGRender` 事件 |
| `nvgText()` 不显示 | 没创建字体 | 先 `nvgCreateFont` 再 `nvgFontFace` |
| 鼠标按钮 `== 0` | 枚举值不一定是 0 | 用 `MOUSEB_LEFT` / `MOUSEB_RIGHT` |
| 键盘按键用数字 | 跨平台不一致 | 用 `KEY_SPACE` / `KEY_ESCAPE` 等 |
| `array[0]` | Lua 数组从 1 开始 | `array[1]` |
| `camera.orthoSize` | 代表全高度，内部用半高 | 手动计算时乘 0.5 |
| Technique 路径猜测 | 猜错直接白屏 | 只用 `PBRNoTexture.xml` / `PBRNoTextureAlpha.xml` / `NoTextureUnlit.xml` |
| `table.unpack()` 不在末尾 | 只展开第一个元素 | 确保在表构造器最后位置 |
| Box2D 碰撞体放子节点 | 碰撞检测失败 | 碰撞形状必须和 `RigidBody2D` 同节点 |
| `string.format("%d", x)` | Lua 5.4 严格区分 int/float，float 传 `%d` 崩溃 | 用 `%.0f` 或先 `math.floor()` |
| WASM 文件存档 | 刷新即丢失 | 用 `clientScore` 云存档 |
| 服务端文件读写 | 完全屏蔽，返回 nil | 文件操作只放客户端 |

---

## 三、验证流程（不确定时）

```
Step 1: LSP 查询 → textDocument/hover 查类型签名 → nil/unknown → 不存在
Step 2: .emmylua 类型定义 → grep 查找类/方法 → 无结果 → 大概率不存在
Step 3: engine-docs/api/ → 查对应模块文档 → 无记录 → 确定不存在
Step 4: examples/ → 查实际用例 → 有 → 安全；无 → 谨慎
```

---

## 四、替代方案优先级

当 API 不可用时：

1. **官方替代** — 文档明确给出的替代 API
2. **库封装** — `urhox-libs/` 中的封装
3. **组合现有 API** — 用多个可用 API 组合实现
4. **程序化实现** — 手写算法（如 CustomGeometry 替代缺失几何体）
5. **降级方案** — 简化需求，近似效果

---

## 五、自更新协议

本名单是**缓存**，权威数据源是引擎文件：

| 场景 | 动作 |
|------|------|
| 黑名单 API 在 LSP/emmylua 查到了 | 可能已恢复 → 移到灰名单观察 |
| 编码时发现新的不可用 API | 确认后追加黑名单 |
| 发现新的行为陷阱 | 追加灰名单 |

**名单与 LSP 冲突时以 LSP 为准**。

---

## 六、编码检查清单

- [ ] 没用 `io` 库？（→ `File`）
- [ ] 没调 `graphics:SetMode()`？（→ `GetWidth/GetHeight/GetDPR`）
- [ ] 没用原生 UI？（→ `urhox-libs/UI`）
- [ ] 鼠标/键盘用的枚举不是数字？
- [ ] NanoVG 在 `NanoVGRender` 事件中？
- [ ] `nvgCreateFont` 只调一次？
- [ ] 数组索引从 1 开始？
- [ ] Technique 路径是已知存在的？
- [ ] `string.format` 没用 `%d`？（→ `%.0f` 或 `math.floor`）

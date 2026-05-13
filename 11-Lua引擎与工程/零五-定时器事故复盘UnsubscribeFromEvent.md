# 定时器事故复盘：UnsubscribeFromEvent("Update") 连环翻车

> **这是什么**: 一个项目中因 `UnsubscribeFromEvent("Update")` 导致 4 次 P1 级事故的完整复盘，含根因分析和防护规则。
> **原作者**: 零五
> **推荐度**: L1（直接可执行的防护规则，所有项目必读）
> **适用场景**: 使用 UrhoX 事件系统开发时；需要启停动画/定时器时

---

## 事故根因（4 次事故完全一致）

```
某模块调用 UnsubscribeFromEvent("Update")
  └→ 取消了当前对象上 Update 事件的 ALL 订阅
      ├→ HandleUpdate（main.lua）被误杀
      ├→ BGM 循环保障 → BGM 播完就停
      ├→ 体力恢复定时器 → 体力不回
      └→ 自动存档定时器 → 存档丢失
```

**核心问题**: `UnsubscribeFromEvent(eventName)` 是**集束炸弹** —— 取消该事件的所有订阅，不区分回调函数。

**隐蔽性**: 延迟爆炸（需特定操作触发）、症状分散、首次修复会掩盖问题。

## 防护规则

### 规则 1: 禁止 UnsubscribeFromEvent("Update") 🔴

```lua
-- ❌ 绝对禁止
UnsubscribeFromEvent("Update")

-- ✅ 正确：用 flag 控制
animating_ = false  -- 回调内 if not animating_ then return end
```

### 规则 2: 标准动画启停写法

```lua
local animating_ = false

function MyModule.StartAnimation()
    animating_ = true
    SubscribeToEvent("Update", "HandleMyModuleAnim")
end

function MyModule.StopAnimation()
    animating_ = false
    -- 不要调用 UnsubscribeFromEvent!
end

function HandleMyModuleAnim(eventType, eventData)
    if not animating_ then return end
    -- 动画逻辑...
end
```

### 规则 3: HandleUpdate 是生命线

| 职责 | 断掉的后果 |
|------|-----------|
| audioScene_:Update(dt) | 音频停止更新 |
| BGM 循环保障 | BGM 不循环 |
| 体力定时器 | 体力不回复 |
| 自动存档定时器 | 存档丢失 |

### 自查清单

- [ ] 代码中是否有 `UnsubscribeFromEvent("Update")`？→ 删掉，用 flag
- [ ] 回调函数内部是否有 flag 保护？
- [ ] HandleUpdate 中的定时器和保障机制是否正常？

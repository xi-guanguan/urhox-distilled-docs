# Lua 数组 nil 空洞防护

> **这是什么**: Lua 表构造器中条件元素产生 nil 空洞，导致 ipairs/# 截断的防护方案
> **原作者**: 节拍前夜
> **推荐度**: L1（即开即用）
> **适用场景**: 构建 UI children 数组含条件元素；数组元素来自可能返回 nil 的函数；任何需要 ipairs/#/table 操作的序列表

---

## 原理

Lua 数组中出现 `nil` 会产生"空洞"，引发三类问题：

| 影响 | 表现 |
|------|------|
| `#t` | 可能返回空洞前的长度，后续元素被截断 |
| `ipairs(t)` | 遇到 `nil` 立即停止遍历 |
| `table.insert` / `table.remove` | 行为不可预测 |

---

## 危险模式

### 模式 1：条件三元表达式

```lua
local children = {
    headerWidget,                          -- [1] OK
    showScore and scoreWidget or nil,      -- [2] 条件为 false 时 = nil，产生空洞
    footerWidget,                          -- [3] 被截断，ipairs 到不了
}
```

### 模式 2：可能返回 nil 的函数

```lua
local items = {
    createButton("start"),                 -- [1] OK
    maybeCreateBonus(),                    -- [2] 可能返回 nil，产生空洞
    createButton("quit"),                  -- [3] 被截断
}
```

---

## 正确方案

### 方案 A -- table.insert 逐个追加（推荐）

```lua
local children = {}
table.insert(children, headerWidget)
if showScore then
    table.insert(children, scoreWidget)
end
table.insert(children, footerWidget)

-- 函数返回值同理
local bonus = maybeCreateBonus()
if bonus then table.insert(children, bonus) end
```

### 方案 B -- compact() 过滤（适合一行表达式场景）

```lua
local function compact(t)
    local out = {}
    for i = 1, #t do
        if t[i] ~= nil then out[#out + 1] = t[i] end
    end
    return out
end

local children = compact({
    headerWidget,
    showScore and scoreWidget or nil,
    footerWidget,
})
```

---

## 检查清单

编写数组时自查：

- [ ] 数组中有 `X and Y or nil` 模式？ -- 改用 table.insert
- [ ] 数组中有函数调用可能返回 nil？ -- 先接收返回值，判空后 insert
- [ ] 数组会传给 ipairs / # / UI children？ -- 确保无 nil 空洞

# UI.TextField 输入框配置参考

> **这是什么**: UrhoX UI 库 TextField 组件的完整用法参考，含输入框、配套按钮、整行布局和防重复点击。
> **原作者**: 一棵草
> **推荐度**: L1（直接可用的代码参考）
> **适用场景**: 需要文本输入框时（礼包码、聊天、搜索、登录等）

---

## 1. TextField 基础用法

```lua
local input = UI.TextField {
    flexGrow = 1,                             -- 填满剩余空间
    height = 36,
    backgroundColor = { 30, 35, 65, 255 },    -- 深蓝背景
    borderRadius = 8,
    borderWidth = 1,
    borderColor = { 50, 60, 100, 180 },
    fontSize = 14,
    fontColor = { 255, 255, 255, 255 },
    placeholder = "请输入礼包码",
    maxLength = 20,
    onChange = function(self, text) end,       -- 输入变化
    onSubmit = function(self, text) end,       -- 回车提交
}
```

### 常用方法

| 方法 | 说明 |
|------|------|
| `input:GetValue()` | 读取当前输入值（比 onChange 闭包更可靠，移动端兼容） |
| `input:SetValue("")` | 设置/清空输入内容 |

## 2. 整行布局（图标 + 标签 + 输入框 + 按钮）

```lua
UI.Panel {
    width = "100%", flexDirection = "row", alignItems = "center", gap = 8,
    children = {
        UI.Label { text = "🎁", fontSize = 16 },
        UI.Label { text = "礼包码", fontSize = 13, width = 50 },
        input,      -- flexGrow=1 自动撑满
        btn,        -- 固定宽度
    },
}
```

## 3. 防重复点击模式

```lua
local locked = false
local function setEnabled(enabled, text)
    locked = not enabled
    btn:SetStyle({
        backgroundColor = enabled and {59,130,246,255} or {60,70,100,200},
    })
    local lbl = btn.children and btn.children[1]
    if lbl and lbl.SetText then lbl:SetText(text or "兑换") end
end

-- 按钮点击
onClick = function()
    if locked then return end
    setEnabled(false, "处理中…")
    -- 异步完成后:
    setEnabled(true, "兑换")
end
```

## 4. 参数速查

| 参数 | 类型 | 说明 |
|------|------|------|
| `placeholder` | string | 无输入时灰色提示 |
| `maxLength` | number | 最大字符数 |
| `fontSize` | number | 文字大小 |
| `fontColor` | table | RGBA |
| `onChange` | function(self, text) | 输入变化回调 |
| `onSubmit` | function(self, text) | 回车提交回调 |

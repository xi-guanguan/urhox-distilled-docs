# 小程序热更新黑屏 pcall 兜底方案

| 字段 | 值 |
|------|-----|
| 这是什么 | 小程序不杀端热重启 + 版本变更时出现黑屏的兜底修复方案——用 pcall 包裹 require 链，加载失败时用 NanoVG 渲染友好提示代替黑屏。根因未完全确定，但 pcall 兜底可靠有效 |
| 原作者 | 附中（地城弹珠，多模块 require 链） |
| 推荐度 | L3（平台已更新热更新功能，此方案为旧版本的临时修复） |
| 适用场景 | 小程序热重启 + 版本变更导致 require 链失败的黑屏问题 |

---

## 问题现象

| 场景 | 表现 |
|------|------|
| 热重启 + 版本变更 | **黑屏**（必定复现） |
| 杀端冷启动 | 正常 |
| 热重启 + 无版本变更 | 正常 |

### 错误链路

```
main.lua Start()
  └→ require("network.Standalone")              -- 正常
       └→ require("shared.MapEditor")           -- 正常
            └→ require("shared.editor.EditorState")  -- module not found!
```

require 链中的深层子模块加载失败 → `dispatch.Render` 未被设置 → 画面黑屏。

### 已排除的猜测

| 猜测 | 验证结果 |
|------|---------|
| 多层子目录 require 路径导致 | 另一个项目加了同样的多层 require，无法复现 |
| 多层 require 需要在子模块中而非 main.lua 中 | 另一个项目在子模块中调用，也无法复现 |
| 常驻服模式特有问题 | 另一个常驻服项目没有此问题 |

**结论**：具体引擎层面根因尚未确定，可能与项目的模块数量、资源包结构等特定条件相关。

---

## 解决方案：pcall 兜底

在 `Start()` 中用 pcall 包裹整个 require 链，加载失败时捕获异常，用 NanoVG 渲染友好提示：

```lua
local ok, err = pcall(function()
    Module = require("network.Standalone")
end)

if not ok then
    _startupError = "require failed: " .. tostring(err)
    _G.dispatch.Render = _ErrorFallbackRender
    return
end

if Module and Module.Start then
    local ok2, err2 = pcall(Module.Start)
    if not ok2 then
        _startupError = "Start() failed: " .. tostring(err2)
        _G.dispatch.Render = _ErrorFallbackRender
        return
    end
end
```

`_ErrorFallbackRender` 用 NanoVG 在屏幕上显示提示文字：

> 有更新版本内容，请杀端重启客户端

### 效果对比

| 场景 | 无 pcall（之前） | 有 pcall（之后） |
|------|----------------|----------------|
| 热重启 + 版本变更 | 黑屏，用户困惑 | 显示"请杀端重启客户端" |
| 热重启 + 无变更 | 正常 | 正常 |
| 杀端冷启动 | 正常 | 正常 |

pcall 不影响正常流程，仅在异常时兜底。

---

## 注意事项

| 要点 | 说明 |
|------|------|
| 不是根治方案 | pcall 只是兜底，根因仍未确定 |
| 平台已更新 | TapTap 平台已更新热更新功能，新项目可能不再遇到此问题 |
| 跨项目不一致 | 作者另一个项目表现为 `main.lua not found` 而非子模块找不到 |
| 建议保留 pcall | 即使平台已修复，pcall 兜底作为防御性编程仍有价值 |

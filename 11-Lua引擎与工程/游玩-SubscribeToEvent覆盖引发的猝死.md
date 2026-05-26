# 一次 SubscribeToEvent 覆盖引发的"猝死"

> **作者**: 游玩  
> **日期**: 2026-05-11  
> **分类**: 开发心得  
> **级别**: L2（参考）  
> **浏览**: 42  

---

## 问题

一个 UrhoX 游戏，进入对局后 UI 完全正常，但游戏逻辑不推进——没有倒计时，没有状态切换，整个对局像被冻结了。

## 原因

项目里有两处代码都订阅了 Update 事件：

```lua
-- main.lua
function Start()
    SubscribeToEvent("Update", "HandleUpdate")
end

-- 某个业务模块初始化时
function ModuleA.Init()
    local done = false
    SubscribeToEvent("Update", function(eventType, eventData)
        if done then return end
        done = true
        DoVersionCheck()
    end)
end
```

ModuleA 的开发者只是想"下一帧执行一次版本检测"，选了最直觉的方式。

但 **UrhoX 的 `SubscribeToEvent` 对同一个事件只维护一个 handler，后来的调用会静默替换前一个，没有任何警告**。

`ModuleA.Init()` 在游戏初始化流程中被调用后，`main.lua` 的 `HandleUpdate` 就被踢出了订阅列表。引擎每帧调用的变成了那个匿名函数——它第一帧做完版本检测，后续每帧直接 return。

引擎还在跑，UI 还在渲染，但驱动整个游戏逻辑的主循环已经"死"了。

**这个 bug 没有任何报错，没有崩溃，没有警告。**

## 解决

确立一条规则：**只有 main.lua 可以订阅 Update 事件，且只订阅一次。**

项目中建立一个集中式的帧更新调度器 GameLoop，所有模块需要帧更新时通过它注册：

```lua
-- 主循环入口，全项目唯一的 Update 订阅
function HandleUpdate(eventType, eventData)
    local dt = eventData["TimeStep"]:GetFloat()
    GameLoop.Update(dt)
end

-- 任何模块需要帧更新，走 GameLoop 注册
function ModuleA.Init()
    GameLoop.RegisterAlways("ModuleA.VersionCheck", function(dt)
        -- 版本检测逻辑
    end)
end
```

## 关键结论

`SubscribeToEvent("Update", ...)` 不是"添加监听器"，而是"设置唯一监听器"。

把它当成全局唯一资源对待，只在入口处使用一次，其余一律走调度器——问题就不会再出现。

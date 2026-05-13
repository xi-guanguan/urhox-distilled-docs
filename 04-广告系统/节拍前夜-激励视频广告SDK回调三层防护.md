> **这是什么**: 激励视频广告系统的五大风险防护方案 — SDK 回调丢失三层防线、崩溃恢复先写后播、eCPM 每日限额、测试 fallback、状态一致性
> **原作者**: 节拍前夜（项目自研）
> **推荐度**: L2（学习参考价值）— 生产环境踩坑经验提炼的防护守卫
> **适用场景**: 接入激励视频广告的游戏项目，防止黑屏卡死/奖励丢失/eCPM 递减

---

# 激励视频广告 SDK 回调三层防护

## 核心原则

**不要信任 SDK 回调作为唯一判据。** 自己维护广告会话状态机。

---

## 一、SDK 回调丢失 — 三层防线消灭黑屏

SDK 回调可能丢失、延迟、不触发。必须有兜底：

```
第一层: SDK 正常回调 → resolved=true → 正常发放
第二层: InputFocus 焦点恢复 → 宽限期(0.5s)等迟到回调 → 强制结束(视为成功)
第三层: 绝对超时(45s) → 强制结束 → 发放奖励保证不卡死
```

**关键**: 每层都必须清除 `adPaused`/`adLoading`，恢复 BGM。

---

## 二、崩溃恢复 — 先写后播

广告播放前把"应发奖励"写入云端（clientCloud），进程被杀后重启时检查恢复：

| 时机 | 操作 |
|------|------|
| 调用 ShowRewardVideoAd **之前** | 写入待发奖励标记 |
| 恢复函数**开头** | 立即清除标记（先清后发） |
| 标记方式 | `claimed = true`（不用 nil，nil 删除 key 云端无法覆盖） |
| Flush 保证 | 确认云端写入成功后才播放广告 |

---

## 三、广告限额 — 看太多反而亏

eCPM 随观看频率递减。设定每日上限（参考约 20 次），超限后跳过 SDK 直接发奖。

计数必须存服务端，客户端可篡改。

---

## 四、测试 fallback

无 SDK 环境（开发/测试）直接跳过广告执行奖励回调，确保奖励逻辑可测试。

---

## 五、状态一致性

- `adPaused` 在 Update 最前面拦截所有游戏逻辑
- 多个广告入口（Vote/Dash 等）共享同一套 `onAdStart`/`onAdEnd`
- 广告结束后 `adPaused` + `adLoading` + BGM 全部恢复

---

## 六、常见代码缺陷

```lua
-- 缺陷1: 只在 success 分支恢复状态
sdk:ShowRewardVideoAd(function(result)
    if result.success then
        adPaused = false  -- ❌ fail 分支没恢复！
    end
end)

-- 修复: 无条件恢复
sdk:ShowRewardVideoAd(function(result)
    adPaused = false      -- ✅ 先恢复
    adLoading = false
    if result.success then ... end
end)

-- 缺陷2: 没有超时兜底，SDK 不回调就永远黑屏
-- 修复: Update 中检查广告会话时长，超时强制结束

-- 缺陷3: 用 nil 清除云端缓存
cache.reward = nil     -- ❌ key 消失，无法覆盖旧数据
cache.claimed = true   -- ✅ key 保留
```

---

## 七、完整检查清单

### A. 会话追踪
- [ ] 三层防线都实现了？（正常回调 / InputFocus / 绝对超时）
- [ ] 每层都清除了 adPaused/adLoading？
- [ ] 每层都恢复了 BGM？

### B. 崩溃恢复
- [ ] 播放前写入待发奖励标记？
- [ ] 恢复时先清除标记再发奖？
- [ ] 用 `claimed = true` 而非 `nil`？
- [ ] Flush 确认后才播放？

### C. 限额控制
- [ ] 有每日观看上限？
- [ ] 计数存服务端？
- [ ] 超限后直接发奖？

### D. 测试保障
- [ ] 无 SDK 环境有 fallback？
- [ ] 奖励逻辑可独立测试？

### E. 状态一致性
- [ ] adPaused 拦截 Update 最前面？
- [ ] 多入口共享同一套回调？
- [ ] 广告结束后所有状态都恢复？

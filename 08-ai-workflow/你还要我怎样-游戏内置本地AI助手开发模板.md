# 游戏内置本地 AI 助手开发模板

| 字段 | 值 |
|------|-----|
| 这是什么 | 纯本地、不依赖后端/API Key 的游戏内置 AI 问答助手——双文件架构（知识库 + 逻辑 UI）、加权关键词匹配算法、同义词展开、情绪识别、互动玩法（占卜/猜谜）、安全过滤、微信风格聊天气泡 UI、浮动图标拖拽/点击区分 |
| 原作者 | 你还要我怎样 |
| 推荐度 | L2（完整可用模板，知识库规模约 80 条目 / 60K 字符，适合中小游戏；大型游戏需扩展匹配策略） |
| 适用场景 | 单机/联机游戏中嵌入 NPC 助手、FAQ 机器人、新手引导对话系统 |

---

## 核心思路

**不需要大模型**。用 **关键词加权匹配 + 同义词展开 + 情绪检测** 即可覆盖 90% 游戏内问答场景，零网络依赖、零成本、确定性输出。

### 架构总览

```
ai_knowledge.lua          ai_chat.lua              main.lua
┌──────────────┐      ┌────────────────────┐    ┌──────────┐
│ 知识库数据     │ ←── │ 匹配引擎 + UI 交互  │ ←─ │ 3 行集成  │
│ ·GAME_KNOWLEDGE│      │ ·SearchKB()         │    │ require  │
│ ·CHAT_KNOWLEDGE│      │ ·EmotionDetect()    │    │ Init()   │
│ ·EMOTION_*    │      │ ·ChatBubbleUI       │    │ Subscribe│
│ ·RIDDLES      │      │ ·FloatingIcon       │    └──────────┘
│ ·PERSONALITY  │      └────────────────────┘
│ ·BLOCKED_KEYWORDS│
└──────────────┘
```

**文件职责**：
| 文件 | 职责 | 行数参考 |
|------|------|---------|
| `ai_knowledge.lua` | 纯数据，所有知识条目和文案 | ~1500 行 |
| `ai_chat.lua` | 匹配引擎、情绪检测、UI 渲染、交互逻辑 | ~800 行 |
| `main.lua` | 3 行集成：require → Init → SubscribeToEvent | 3 行新增 |

---

## 知识库结构（ai_knowledge.lua）

### 1. 安全过滤词

```lua
BLOCKED_KEYWORDS = {
    "伤害公式", "掉落概率", "内部数据", "后台",
    "源代码", "漏洞", "刷钱",
}
```

命中任何一个 → 直接返回拒绝回答文案，**不进入匹配流程**。

### 2. 游戏知识库（核心）

```lua
GAME_KNOWLEDGE = {
    {
        keys = { "怎么升级", "升级方法", "如何升级", "提升等级" },
        answer = "完成主线任务和每日任务都可以获得经验值...",
        priority = 5,     -- 1~5，越高越优先
    },
    {
        keys = { "装备强化", "强化装备", "怎么强化" },
        answer = "打开背包→选择装备→点击强化按钮...",
        priority = 4,
    },
    -- ... 更多条目
}
```

**字段说明**：
| 字段 | 类型 | 作用 |
|------|------|------|
| `keys` | string[] | 触发关键词列表，支持多种表述 |
| `answer` | string | 回复文案 |
| `priority` | number(1~5) | 同分时高优先级胜出，并参与评分加权（× priority/5） |

### 3. 闲聊知识库

```lua
CHAT_KNOWLEDGE = {
    { keys = {"你好", "嗨", "在吗"}, answer = "你好呀！有什么想问的？" },
    { keys = {"谢谢", "感谢"},       answer = "不客气，随时找我~" },
}
```

结构与 `GAME_KNOWLEDGE` 相同，匹配时**游戏知识库权重 ×1.1**（优先返回游戏相关回答）。

### 4. 同义词映射表

```lua
SYNONYMS = {
    ["咋"] = "怎么",
    ["啥"] = "什么",
    ["牛逼"] = "厉害",
    ["肝"] = "刷",
    ["氪"] = "充值",
    -- 玩家黑话 → 标准词
}
```

匹配前先做一轮**同义词替换**，把玩家口语/黑话规范化。

### 5. 情绪模式

```lua
EMOTION_PATTERNS = {
    happy = { "哈哈", "太好了", "开心", "耶", "棒" },
    sad   = { "难过", "伤心", "唉", "呜呜", "郁闷" },
    angry = { "垃圾", "什么鬼", "气死", "坑", "骗人" },
}

EMOTION_RESPONSES = {
    happy = {
        prefix = { "看你这么开心~", "心情不错嘛！" },
        suffix = { "继续加油哦！", "保持好心情~" },
    },
    sad = {
        prefix = { "别难过啦~", "抱抱你~" },
        suffix = { "会好起来的！", "有什么我能帮忙的吗？" },
    },
    angry = {
        prefix = { "消消气~", "别生气啦~" },
        suffix = { "有问题可以慢慢说~", "我帮你看看怎么解决" },
    },
}
```

### 6. 互动玩法数据

```lua
FORTUNE_RESULTS = {
    { fortune = "大吉", message = "今天运气爆棚！适合抽卡/打Boss！" },
    { fortune = "中吉", message = "平稳的一天，适合日常任务~" },
    { fortune = "小凶", message = "小心点...今天别去危险地图" },
}

RIDDLES = {
    {
        question = "什么东西越洗越脏？",
        answer_key = { "水" },     -- 多关键词匹配
        answer_text = "答案是：水！越洗越脏~",
    },
}
```

### 7. 人格文案

```lua
PERSONALITY = {
    random_openers  = { "嗯...", "让我想想...", "这个嘛..." },
    random_closers  = { "还有别的问题吗？", "需要我帮忙的话随时叫我~" },
    idle_actions    = { "*伸了个懒腰*", "*打了个哈欠*", "*东张西望*" },
    follow_up       = { "对了，你还可以试试...", "顺便说一下..." },
}
```

---

## 匹配引擎（ai_chat.lua）

### 核心算法：SearchKB

```lua
--- 在知识库中搜索最佳匹配
---@param kb table       知识库表（GAME_KNOWLEDGE 或 CHAT_KNOWLEDGE）
---@param text string    用户输入（已做同义词替换）
---@param minScore number 最低分数阈值
---@return table|nil     { answer, score, priority }
function SearchKB(kb, text, minScore)
    local best = nil
    for _, entry in ipairs(kb) do
        local score = 0
        local matchCount = 0
        for _, key in ipairs(entry.keys) do
            if string.find(text, key, 1, true) then
                score = score + #key         -- 关键词越长，得分越高
                matchCount = matchCount + 1
            end
        end
        -- 多关键词命中奖励
        if matchCount >= 2 then
            score = score + matchCount * 3
        end
        -- 优先级加权
        score = score * (entry.priority or 3) / 5
        if score >= minScore and (not best or score > best.score) then
            best = { answer = entry.answer, score = score, priority = entry.priority }
        end
    end
    return best
end
```

**评分规则拆解**：

```
得分 = Σ(命中关键词的字符长度)
     + (matchCount >= 2 ? matchCount × 3 : 0)    -- 多命中奖励
     × priority / 5                                -- 优先级系数
```

| 因素 | 说明 |
|------|------|
| 关键词长度 | "怎么升级" (8 bytes) > "升级" (4 bytes)，长关键词更精准 |
| 多命中奖励 | 同一条目命中 2+ 个关键词，额外加 matchCount×3 |
| 优先级系数 | priority=5 → ×1.0，priority=3 → ×0.6 |

### 完整回复组装流程

```
用户输入
  │
  ├─ 安全过滤（BLOCKED_KEYWORDS）→ 命中 → 返回拒绝
  │
  ├─ 同义词替换（SYNONYMS）
  │
  ├─ 触发词检测
  │   ├─ "占卜" / "算命" / "运势" → 随机返回 FORTUNE_RESULTS
  │   └─ "猜谜" / "出题"          → 进入猜谜模式
  │
  ├─ 情绪检测（EMOTION_PATTERNS）→ 记录情绪类型
  │
  ├─ 知识库匹配
  │   ├─ SearchKB(GAME_KNOWLEDGE, text, 3) × 1.1 权重
  │   └─ SearchKB(CHAT_KNOWLEDGE, text, 2)
  │   └─ 取高分者
  │
  ├─ 重复检测（最近 5 条 topic 去重，≥3 次提醒）
  │
  └─ 组装回复
      = 随机 opener + 情绪 prefix + 知识回答 + 情绪 suffix + 随机 closer/follow_up
```

### 重复检测

```lua
local recentTopics = {}   -- 环形缓冲，最多 5 条
local MAX_RECENT = 5

function TrackTopic(text)
    local stripped = text:gsub("[%s%p]", "")  -- 去空格标点
    table.insert(recentTopics, stripped)
    if #recentTopics > MAX_RECENT then
        table.remove(recentTopics, 1)
    end
    -- 统计重复次数
    local count = 0
    for _, t in ipairs(recentTopics) do
        if t == stripped then count = count + 1 end
    end
    return count >= 3  -- true = 需要提醒
end
```

### 猜谜模式

```lua
-- 进入猜谜
currentRiddle = RIDDLES[math.random(#RIDDLES)]
-- 返回 currentRiddle.question

-- 检查答案
function CheckRiddleAnswer(text)
    for _, key in ipairs(currentRiddle.answer_key) do
        if string.find(text, key, 1, true) then
            currentRiddle = nil
            return currentRiddle.answer_text  -- 回答正确
        end
    end
    return "不对哦，再想想~"
end
```

---

## UI 实现要点

### 浮动图标

```lua
-- 呼吸动画：缩放 0.95 ~ 1.05 循环
local breathScale = 1.0 + math.sin(time * 2) * 0.05

-- 拖拽 vs 点击区分（阈值 3 像素）
local DRAG_THRESHOLD = 3
function OnTouchMove(x, y)
    local dx = x - touchStartX
    local dy = y - touchStartY
    if math.abs(dx) > DRAG_THRESHOLD or math.abs(dy) > DRAG_THRESHOLD then
        isDragging = true
    end
end

function OnTouchEnd()
    if not isDragging then
        ToggleChatPanel()  -- 点击 → 打开/关闭面板
    end
    isDragging = false
end
```

### 聊天气泡（微信风格）

```
┌─────────────────────────────┐
│  [AI头像]  ┌──────────────┐ │
│            │ AI 的回复文本 │ │
│            └──────────────┘ │
│                             │
│  ┌──────────────┐ [玩家头像]│
│  │ 玩家的输入   │           │
│  └──────────────┘           │
│                             │
│  ┌─────────────────────┐    │
│  │ 输入框         [发送]│    │
│  └─────────────────────┘    │
└─────────────────────────────┘
```

**关键细节**：
- AI 消息左对齐 + 左侧头像，玩家消息右对齐 + 右侧头像
- 气泡背景色区分（AI 浅灰、玩家浅蓝）
- 消息列表自动滚动到底部
- 输入框支持回车发送

### main.lua 集成（仅 3 行）

```lua
local AIChat = require("ai_chat")

function Start()
    -- ... 游戏初始化代码 ...
    AIChat.Init()
end

-- 在已有的 Update 事件中追加
SubscribeToEvent("Update", function(_, eventData)
    local dt = eventData["TimeStep"]:GetFloat()
    AIChat.Update(dt)
end)
```

---

## 扩展指南

### 新增知识条目

只需在 `ai_knowledge.lua` 对应表中追加一条：

```lua
-- GAME_KNOWLEDGE 末尾追加
{
    keys = { "新功能关键词1", "关键词2" },
    answer = "回答文本...",
    priority = 3,
},
```

**不需要修改 ai_chat.lua 的任何逻辑。**

### 知识库规模建议

| 规模 | 条目数 | 关键词匹配表现 |
|------|--------|---------------|
| 小型 | 20~50 | 优秀，几乎无误匹配 |
| 中型 | 50~100 | 良好，偶尔需调整优先级 |
| 大型 | 100~300 | 可用，建议增加分类前缀或拆分多个知识库 |
| 超大 | 300+ | 建议改用模糊匹配或接入 LLM |

### 进阶方向

| 方向 | 做法 |
|------|------|
| 上下文记忆 | 记录最近 N 轮对话，匹配时考虑上文 |
| 条件回答 | keys 增加 `condition` 字段（检查玩家等级/进度） |
| 多语言 | 知识库按语言分表，运行时切换 |
| 接入 LLM | 本地匹配失败时 fallback 到 HTTP API 调用 |

---

## 踩坑备忘

| 问题 | 原因 | 解决 |
|------|------|------|
| 同一问题每次回复完全相同 | 没有随机 opener/closer | 加 PERSONALITY 随机文案 |
| 玩家打错字匹配不到 | 没有同义词映射 | 扩充 SYNONYMS 表 |
| 回答太长气泡溢出 | answer 文案太长 | 控制单条 answer 在 100 字以内 |
| 安全词被绕过 | 只做了精确匹配 | 对 BLOCKED_KEYWORDS 也做 string.find |
| 占卜每次结果一样 | 没设随机种子 | `math.randomseed(os.time())` |

# CV 配音专家 Skill（AI 语音设计与台词生成）

> **来源**: 社区分享（微信群）
> **作者**: 灰语
> **蒸馏等级**: L2（学习参考）
> **适用场景**: 使用 ElevenLabs Voice Design 为游戏角色设计配音、生成台词音频
> **核心价值**: 五阶段语音设计流程 + 六维度 Prompt 框架 + Audio Tags 情绪控制 + 游戏导演模式
> **前置知识**: ElevenLabs API（`audition_voices_for_character` / `text_to_dialogue` 工具）

---

## 一、三种工作流

| 模式 | 触发场景 | 流程 |
|------|---------|------|
| **完整设计** | 新角色需要从零设计声音 | 五阶段咨询 → 试听 → 确认 → 生成台词 |
| **台词生成** | 角色已有声音，需要新台词 | 读角色设定 → 编写台词 → 生成音频 |
| **快速模式** | 用户直接给出明确需求 | 跳过咨询，直接按需求执行 |

---

## 二、五阶段语音设计流程

### 阶段 1：角色理解

收集角色基本信息：
- 性别、年龄范围
- 性格特征（温柔/热血/冷酷/搞怪）
- 在游戏中的角色定位（主角/NPC/Boss/旁白）

### 阶段 2：声音方向

确定声音风格：
- 音色方向（低沉/清亮/沙哑/磁性）
- 语速节奏（快/慢/变化多端）
- 情绪基调（沉稳/活泼/神秘/威严）

### 阶段 3：六维度 Prompt 构建

**ElevenLabs Voice Design 的 Prompt 必须包含以下六个维度**：

| 维度 | 说明 | 示例 |
|------|------|------|
| 1. 年龄/性别 | 年龄段+性别 | "young adult male in his 20s" |
| 2. 音色/质感 | 声音质地 | "warm, magnetic, smooth" |
| 3. 语速/节奏 | 说话速度 | "measured pace with dramatic pauses" |
| 4. 情绪/氛围 | 人格气质 | "confident, mysterious, authoritative" |
| 5. 风格 | 表演风格 | "anime style, professional Chinese VA" |
| 6. 音质 | 必须包含 | "studio-quality recording" |

**完整 Prompt 示例**：
```
Young adult male in his 20s, professional Chinese voice actor,
clear and magnetic tone, elegant, confident, crisp articulation,
prince-like quality. Measured pace with slight warmth.
Studio-quality recording.
```

### 阶段 4：试听比选

生成 1-3 个候选声音，用户试听后选择。

### 阶段 5：台词生成

用选定的声音生成游戏台词。

---

## 三、角色原型 Prompt 模板

### A. 华丽公子 / 温暖男主
```
Young adult male in his 20s, professional Chinese voice actor,
clear and magnetic tone, elegant, confident, crisp articulation,
prince-like quality. Studio-quality recording.
```

### B. 动漫萌系 / 吉祥物
```
High-pitched female anime voice, fantasy mascot character,
fairy-like, energetic and bubbly, hyper-enthusiastic,
professional voice acting, chibi style. Studio-quality recording.
```

### C. 高冷御姐 / 女王
```
Young adult female in her late 20s, deep and cool tone, icy,
aloof, authoritative, slow and deliberate pacing, low emotional
variation, mysterious, regal. Studio-quality recording.
```

### D. 智慧老者 / 导师
```
Elderly wise man in his 70s, voice deep and gravelly, speaking
slowly with dramatic pauses, mysterious and calm tone, warm
undertone, storyteller quality. Studio-quality recording.
```

### E. 热血少年 / 冒险者
```
Young adult male, energetic and passionate, fast-paced speaking,
enthusiastic, slight breathiness from excitement, adventurous
spirit, anime protagonist style. Studio-quality recording.
```

---

## 四、Audio Tags 情绪控制

在台词文本中插入英文标签控制语音表现：

### 情绪标签

| 标签 | 效果 |
|------|------|
| `[laughing]` / `[chuckling]` | 笑声 |
| `[sad]` / `[crying]` | 悲伤/哭泣 |
| `[excited]` / `[enthusiastic]` | 兴奋 |
| `[angry]` / `[furious]` | 愤怒 |
| `[nervous]` / `[anxious]` | 紧张 |
| `[whispering]` / `[softly]` | 低语/轻声 |
| `[shouting]` / `[yelling]` | 喊叫 |

### 动作标签

| 标签 | 效果 |
|------|------|
| `[sighs]` | 叹气 |
| `[gasps]` | 倒吸气 |
| `[clears throat]` | 清嗓子 |
| `[pause]` | 停顿 |

### 使用示例

```lua
"[sighs] 唉，真是累了... [softly] 不过，一切都会好起来的。"
"[excited] 哇！这里好漂亮啊！[gasps] 快看，那边有宝藏！"
```

---

## 五、标点符号控制节奏

| 标点 | 效果 |
|------|------|
| `...` | 停顿，思考/犹豫 |
| `——` | 语气转折/中断 |
| `!` | 强调 |
| `?` | 疑问语调上扬 |
| `,` | 短暂停顿 |

**示例**：`"等等... 你说什么?! 这——这不可能!"`

---

## 六、稳定性参数（stability）

| 范围 | 效果 | 适用场景 |
|------|------|---------|
| 0.3-0.5 | 更多情感变化 | 戏剧性台词、战斗呐喊 |
| 0.5-0.7 | 平衡 | 日常对话 |
| 0.7-1.0 | 更稳定一致 | 旁白、正式场合 |

---

## 七、安全过滤与童声替代

ElevenLabs **禁止** 生成儿童声音。替代方案：

| 需求 | 替代 Prompt |
|------|-----------|
| 可爱/吉祥物 | "High-pitched female, fantasy mascot, fairy-like, chibi style" |
| 年轻感 | "Young adult female with soft youthfulness but NOT child-like" |
| 动漫风 | "High-pitched anime voice, energetic and bubbly, fantasy character" |

---

## 八、试听台词要求

- **至少 100 字符**（API 硬性要求）
- **风格匹配**：温柔角色用温柔台词，热血角色用激昂台词
- **完整句子**：展示角色的说话方式和情绪
- **不要用测试语句**：如 "测试一二三"

---

## 九、已知问题

1. **口音保存后减弱**：预览中听到的口音在保存后可能减弱，如口音是关键需求需实测
2. **确认创建消耗 Voice Slot**：预览免费，确认后消耗 1 个名额（Free=3, Starter=10, Creator=30, Pro=160）
3. **试听台词与 Prompt 情绪不匹配**：会导致生成质量差，务必保持一致

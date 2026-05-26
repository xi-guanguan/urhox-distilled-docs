# 声音设计六维度 — Voice Design Prompt 构建指南

> 构建高质量声音 prompt 的核心框架。每个维度必须覆盖，缺一不可。

---

## 六维度模型

### 维度 1: 年龄/性别 (Age & Gender)

**作用**: 决定音色基底。ElevenLabs 根据此生成基础声纹。

| 描述模板 | 适用角色 |
|---------|---------|
| `young adult male in his early 20s` | 少年、学生、冒险者 |
| `young adult male in his late 20s` | 青年剑士、王子、骑士 |
| `middle-aged male in his 40s` | 将军、父亲、导师 |
| `elderly man in his 70s` | 智者、长老、隐士 |
| `young adult female in her early 20s` | 少女、术士、弓箭手 |
| `young adult female in her late 20s` | 女王、姐姐、指挥官 |
| `middle-aged female in her 40s` | 母亲、女巫、教官 |
| `elderly woman in her 60s` | 祖母、先知、长老 |

**禁区**: 绝对禁止使用 child、young girl、kid、little boy、儿童、幼女、萝莉、童声。
**替代方案**: 用 `high-pitched female, fantasy mascot, fairy-like, chibi style` 代替。

---

### 维度 2: 音色/质感 (Tone & Timbre)

**作用**: 声音的"材质"——温暖如木、清冷如冰、沙哑如砂纸。

**词库（按感觉分类）**:

| 感觉类别 | 英文关键词 | 中文描述 |
|---------|----------|---------|
| 温暖厚实 | warm, rich, deep, full-bodied, resonant, velvety | 像壁炉旁的低语 |
| 清亮通透 | clear, bright, crisp, crystalline, bell-like, silvery | 像清晨的山泉 |
| 沙哑粗犷 | husky, raspy, gravelly, rough, gritty, scratchy | 像砂纸打磨木头 |
| 柔软轻盈 | soft, gentle, breathy, airy, feathery, delicate | 像风吹过丝绸 |
| 磁性诱人 | magnetic, smooth, silky, sultry, seductive, alluring | 像深夜电台DJ |
| 尖锐刺耳 | shrill, piercing, sharp, high-pitched, squeaky, nasal | 像金属摩擦 |
| 低沉浑厚 | bass, rumbling, booming, thunderous, baritone | 像远处的雷声 |
| 沧桑疲惫 | weary, tired, worn, weathered, world-weary | 像老兵的叹息 |

**组合建议**: 通常选 2-3 个词组合，避免矛盾（如 `bright` + `deep` 冲突）。

---

### 维度 3: 语速/节奏 (Pacing & Rhythm)

| 英文关键词 | 效果 | 适用角色 |
|----------|------|---------|
| fast-paced, rapid, quick | 语速快，急促 | 热血少年、紧张场景 |
| moderate, steady, even | 中等语速，平稳 | 日常对话、普通NPC |
| slow and deliberate | 慢速，字字清晰 | 智者、领袖、威严角色 |
| measured, carefully paced | 有节制的停顿 | 谋士、心机角色 |
| with dramatic pauses | 戏剧性停顿 | 叙事者、悬疑角色 |
| varied, dynamic rhythm | 节奏变化丰富 | 情绪化角色、疯子 |
| clipped, staccato | 短促有力 | 军人、指挥官 |

---

### 维度 4: 情绪/气质 (Emotion & Vibe)

**作用**: 角色的"人格底色"——不是台词的临时情绪，而是声音的恒定气质。

| 气质类型 | 英文关键词 | 适用角色 |
|---------|----------|---------|
| 自信权威 | confident, authoritative, commanding, assertive | 王、将军、领袖 |
| 温柔亲和 | gentle, kind, nurturing, warm-hearted, caring | 治疗师、母亲、导师 |
| 冷漠疏离 | aloof, detached, cold, distant, indifferent | 刺客、孤狼、冰系角色 |
| 活泼开朗 | energetic, cheerful, bubbly, enthusiastic, lively | 精灵、伙伴、吉祥物 |
| 神秘深邃 | mysterious, enigmatic, mystical, otherworldly | 先知、幽灵、古神 |
| 阴险狡诈 | sinister, cunning, sly, scheming, menacing | 反派、幕后黑手 |
| 忧郁感伤 | melancholic, wistful, sorrowful, pensive | 悲剧角色、诗人 |
| 狂热偏执 | manic, obsessive, frenzied, unhinged, wild | 疯科学家、狂信者 |
| 傲娇别扭 | tsundere, reluctant warmth, tough exterior with hidden softness | 傲娇角色 |
| 慵懒散漫 | lazy, laid-back, drowsy, nonchalant | 闲散侠客、猫系角色 |

---

### 维度 5: 风格/流派 (Style & Genre)

| 英文关键词 | 效果 | 适用场景 |
|----------|------|---------|
| anime style | 日式动画配音风格 | 二次元游戏 |
| professional Chinese voice actor | 专业中文配音演员质感 | 中文游戏、武侠仙侠 |
| movie trailer style | 电影预告片旁白 | 史诗叙事、开场CG |
| audiobook narrator | 有声读物讲述者 | 旁白、叙事 |
| radio announcer | 广播播报员 | 新闻系统、公告 |
| theatrical, stage actor | 舞台剧演员 | 戏剧性场景 |
| naturalistic, conversational | 自然对话感 | 现实题材、日常 |
| over-the-top, exaggerated | 夸张表演 | 搞笑角色、恶搞 |
| prince-like quality | 王子般优雅 | 贵族、华丽角色 |
| warrior-like, battle-hardened | 战士般粗犷 | 战斗角色 |

---

### 维度 6: 录音质量 (Audio Quality)

**必须包含。固定短语二选一**:
```
studio-quality recording
```
或
```
professional audio, clear articulation
```

每个 prompt 结尾必须加上面的短语之一。

---

## Prompt 组装公式

```
[维度1: 年龄性别], [维度2: 音色质感 2-3词], [维度3: 语速节奏], [维度4: 情绪气质 1-2词], [维度5: 风格流派], [维度6: 录音质量].
```

**示例**:
```
Young adult male in his 20s, warm and magnetic tone, steady pacing with occasional dramatic pauses, confident yet gentle, professional Chinese voice actor, prince-like quality. Studio-quality recording.
```

---

## 常见错误

| 错误 | 正确做法 |
|------|---------|
| 只写 "male voice" | 必须指定年龄段 |
| 堆砌 10+ 形容词 | 每个维度 2-3 词足够 |
| 音色词互相矛盾 | 选择一个主方向 |
| 漏掉录音质量维度 | 每个 prompt 结尾必须有 |
| 用中文写 prompt | 必须用英文 |
| 使用 child/kid 等禁词 | 用 high-pitched fantasy mascot 替代 |

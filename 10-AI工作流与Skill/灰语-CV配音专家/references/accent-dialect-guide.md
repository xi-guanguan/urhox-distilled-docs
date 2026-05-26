# 口音与方言控制指南 — Accent & Dialect Control Guide

> 如何让 AI 生成的声音带有特定口音：外国人说中文、中国人说外语、方言腔调普通话。
> 核心武器：voice prompt 描述 + 台词写法配合。

---

## 一、核心原理

口音 = **发音习惯迁移**。母语的发音规则"入侵"目标语言。

控制口音的两个杠杆：
1. **Voice Prompt**（声音层）：在 `character_description` 中描述口音特征
2. **台词写法**（文本层）：用拼写变体、语法错位、语气词强化口音感知

**关键认知**：ElevenLabs 的口音控制不是精确开关，而是概率倾向。同一 prompt 多次生成可能口音浓淡不同。**多生成几次选最佳**。

---

## 二、外国人说中文

### 2.1 日本人说中文（日式中文）

**语音特征**：
- 卷舌音弱化（zh/ch/sh → z/c/s 倾向）
- 声调偏平，四声不够分明
- 节奏偏均匀，缺乏中文的抑扬顿挫
- "r" 发音接近 "l"
- 句尾容易带拖音

**Voice Prompt 关键词**：
```
Japanese-accented Mandarin Chinese, subtle Japanese intonation patterns,
slightly flat tonal delivery, soft and polite speaking manner,
occasional hesitation when switching between languages
```

**台词强化技巧**：
- 加入日语语气词混搭：「あの...就是说...」「嗯...那个...」
- 句尾偶尔带日式语气：「是这样的呢」「好的desu」
- 用犹豫和停顿暗示非母语：「我...想要...那个...怎么说...」
- 助词使用不够地道：「在这里的话，是很好的」

**示例 Prompt**：
```
Young adult female in her early 20s, soft and gentle tone, 
Japanese-accented Mandarin Chinese with occasional Japanese intonation,
slightly flat tones, polite and careful pacing as if choosing words thoughtfully,
naturalistic, conversational. Studio-quality recording.
```

**示例台词**：
```
[softly] あの...你好，我是从东京来的。中文说得...嗯...不太好，
请多多关照呢。这个地方真的好漂亮，和日本的感觉...完全不一样。
```

---

### 2.2 美国人说中文（美式中文）

**语音特征**：
- 声调夸张或错位（一声二声混淆常见）
- "r" 音过重（英语 retroflex 习惯）
- 词与词之间连读不自然
- 语调走势偏英语（句尾上扬表疑问）
- 自信但发音不准

**Voice Prompt 关键词**：
```
American-accented Mandarin Chinese, English intonation patterns bleeding through,
confident delivery with imperfect tones, occasional English word insertions,
natural code-switching between English and Chinese
```

**台词强化技巧**：
- 夹杂英文词：「这个 situation 有点...复杂」
- 句式偏英语语序：「我是很喜欢这个的」
- 语气直接自信：「Hey，没问题，我可以的！」
- 某些词用英文替代：「对对，very good，继续」

**示例 Prompt**：
```
Young adult male in his late 20s, bright and energetic tone,
American-accented Mandarin Chinese, confident but with imperfect tones,
natural English-Chinese code-switching, upbeat and friendly pacing,
naturalistic, conversational. Studio-quality recording.
```

**示例台词**：
```
[excited] Hey\! 你好你好！我来中国已经...两年了？Yeah，两年了。
我的中文还是...嗯...not perfect，但是！比以前好很多了，seriously。
你们的火锅，oh my god，太好吃了，我 literally 每周都要吃。
```

---

### 2.3 欧洲人说中文

#### 法国人说中文

**语音特征**：
- 鼻音浓重
- "h" 音弱化或省略（"好" → "ao"）
- 节奏偏慢，有法语的优雅拖音
- "r" 发小舌音

**Voice Prompt 关键词**：
```
French-accented Mandarin Chinese, nasal resonance, 
elegant and unhurried pacing, soft "h" sounds,
romantic and melodic intonation
```

**示例台词**：
```
[softly] 嗯...你好，我叫 Pierre。中国的文化...怎么说...
非常 magnifique——啊，就是...非常美丽。我特别喜欢...
那个...书法，oui，书法，很有...艺术感。
```

#### 德国人说中文

**语音特征**：
- 辅音清晰有力
- 节奏规整，几乎机械般精确
- 声调偏硬，缺乏弹性
- 语速偏慢但断句清晰

**Voice Prompt 关键词**：
```
German-accented Mandarin Chinese, precise and crisp consonants,
structured and methodical pacing, slightly rigid tonal delivery,
direct and efficient speaking style
```

#### 俄罗斯人说中文

**语音特征**：
- 辅音浓重，带明显颤音
- 元音偏深沉
- 声调偏低沉平直
- 断句硬朗，重音明显

**Voice Prompt 关键词**：
```
Russian-accented Mandarin Chinese, deep and resonant voice,
heavy consonants with slight rolling quality, flat tonal delivery,
direct and no-nonsense speaking manner
```

---

### 2.4 韩国人说中文

**语音特征**：
- 送气音与不送气音混淆（p/b、t/d、k/g 区分弱）
- 声调整体偏高偏平
- 语速偏快
- 句尾习惯性上扬

**Voice Prompt 关键词**：
```
Korean-accented Mandarin Chinese, slightly higher pitch register,
aspirated consonant confusion, fast-paced delivery,
rising intonation at sentence endings
```

**台词强化技巧**：
- 加入韩语语气词：「啊 진짜...真的假的？」
- 句尾上扬：「是这样的吗~？」
- 偶尔混入韩语：「아이고...这个太难了」

---

## 三、中国人说外语

### 3.1 中国人说英语（中式英语）

**语音特征**：
- "th" 发成 "s/z"（think → sink）
- "v" 发成 "w"（very → wery）
- "l/r" 混淆
- 单词重音位置偏移
- 节奏偏均匀，缺乏英语的重轻交替

**Voice Prompt 关键词**：
```
Chinese-accented English, Mandarin tonal influence on English intonation,
"th" sounds softened to "s", even syllable timing rather than stress-timed,
earnest and studious delivery
```

**台词强化技巧**：
- 语法直译：「I tomorrow go to school」
- 时态遗忘：「Yesterday I go shopping」
- 加中文语气词：「This is...怎么说...very good\!」

### 3.2 中国人说日语（中式日语）

**语音特征**：
- 声调习惯带入，重音位置偏移
- 长音短音区分不够
- 促音不够干脆
- 敬语使用偶尔错位

**Voice Prompt 关键词**：
```
Chinese-accented Japanese, Mandarin tonal patterns influencing pitch accent,
slightly imprecise long vowel and geminate consonant distinctions,
polite but occasionally stiff keigo usage
```

---

## 四、方言腔调普通话 🇨🇳

### 4.1 南方口音普通话

#### 广东/粤语区口音

**语音特征**：
- 前后鼻音不分（n/ng：「晴天」→「亲天」）
- 平翘舌不分（zh/z、ch/c、sh/s 混淆）
- 声调系统不同，普通话声调偏"硬"
- "l/n" 混淆
- 语速偏快

**Voice Prompt 关键词**：
```
Southern Chinese Mandarin accent from Guangdong, Cantonese-influenced tones,
no distinction between retroflex and flat tongue sounds,
nasal finals occasionally merged, brisk pacing,
naturalistic, conversational. Studio-quality recording.
```

**台词强化技巧**：
- 偶尔夹粤语词：「这个嘢...就是说...」
- 语气词用粤式：「是咯」「好啦」「得啦」
- 某些发音写谐音暗示：「四（是）不四（是）这样」

#### 四川/西南口音

**语音特征**：
- 平翘舌不分
- 前后鼻音不分
- 声调独特（阳平读降调）
- "f/h" 混淆（「飞机」→「灰机」）
- 语调有明显的川味起伏

**Voice Prompt 关键词**：
```
Southwestern Chinese Mandarin accent from Sichuan, distinctive Sichuanese tonal patterns,
"f" and "h" sound confusion, no retroflex distinction,
lively and expressive intonation with characteristic melodic quality,
naturalistic, conversational. Studio-quality recording.
```

**台词强化技巧**：
- 加入川味语气词：「啥子嘛」「巴适得很」「莫得问题」
- 语气夸张上扬：「你晓得不嘛！」
- 叠词多：「快快快」「慢慢慢」

#### 江浙/吴语区口音

**语音特征**：
- 浊音保留（吴语特征带入普通话）
- 语调偏柔偏软（"嗲"）
- 前后鼻音不分
- "n/l" 混淆
- 节奏偏慢，语气温和

**Voice Prompt 关键词**：
```
Eastern Chinese Mandarin accent from Jiangzhe region, Wu dialect influence,
soft and gentle delivery, slightly nasal quality,
slow and measured pacing with a tender melodic quality,
naturalistic, conversational. Studio-quality recording.
```

#### 闽南/福建口音

**语音特征**：
- 声母系统差异大
- "b/p"、"d/t"、"g/k" 混淆
- 声调与普通话差异显著
- 语速偏慢

**Voice Prompt 关键词**：
```
Southern Fujian-accented Mandarin, Hokkien tonal influence,
occasional initial consonant confusion, distinctive prosody,
warm and straightforward delivery
```

---

### 4.2 北方口音普通话

#### 东北口音

**语音特征**：
- 声调夸张，起伏大
- "二" 化音多
- 语速快，节奏紧凑
- 语气词丰富：「嘎哈」「咋的」「整」
- 直来直去，豪爽感

**Voice Prompt 关键词**：
```
Northeastern Chinese Mandarin accent, Dongbei dialect influence,
exaggerated tonal contours, heavy erhua (r-coloring),
fast-paced and energetic delivery, bold and straightforward manner,
naturalistic, conversational. Studio-quality recording.
```

**台词强化技巧**：
- 大量东北词汇：「贼好」「老厉害了」「整一个」「嘎嘎的」
- 儿化音多加：「那边儿」「一会儿」「好好儿的」
- 语气夸张：「哎呀妈呀！这也太好了吧！」

#### 北京口音

**语音特征**：
- 儿化音极多
- 吞字（「不知道」→「不儿道」→「bùrdào」）
- 语速偏快但有拖腔
- 特有的"京味"语调

**Voice Prompt 关键词**：
```
Beijing Mandarin accent, heavy erhua throughout,
characteristic Beijing drawl with syllable swallowing,
confident and slightly casual delivery, local Beijing flavor,
naturalistic, conversational. Studio-quality recording.
```

**台词强化技巧**：
- 大量儿化：「哥们儿」「胡同儿」「味儿」「范儿」
- 京味词汇：「甭」「您了」「得嘞」「回头见」
- 吞音写法：「那不（是）嘛」「你说（是）不（是）」

#### 天津口音

**语音特征**：
- 声调独特（阴平读类似去声的高降调）
- 自带"相声味"
- 语速中等但节奏感强
- 幽默感天然

**Voice Prompt 关键词**：
```
Tianjin Mandarin accent, distinctive Tianjin tonal patterns,
natural comedic rhythm, characteristic high-falling first tone,
lively and humorous delivery style,
naturalistic, conversational. Studio-quality recording.
```

---

## 五、口音浓度控制

口音不是开关，是旋钮。通过 prompt 关键词控制浓淡：

### 浓度等级词库

| 浓度 | 关键词 | 适用场景 |
|------|--------|---------|
| **淡** | `subtle hint of X accent`, `very slight X influence`, `barely noticeable` | 角色主要说标准语，偶尔露出口音 |
| **中** | `noticeable X accent`, `moderate X influence`, `X-accented` | 日常交流中能明显感知口音 |
| **浓** | `heavy X accent`, `strong X influence`, `thick X accent`, `unmistakable` | 口音是角色标志性特征 |

### 组合示例

```
# 淡：留学多年的日本人，中文很好但偶尔露出日语痕迹
"...with a subtle hint of Japanese accent, mostly fluent Mandarin 
with occasional Japanese intonation patterns..."

# 中：刚来中国一年的美国人
"...noticeable American accent, confident but with imperfect tones,
natural English-Chinese code-switching..."

# 浓：刚开始学中文的法国人
"...heavy French accent, struggling with Mandarin tones,
frequent pauses to search for words, strong nasal quality from French..."
```

---

## 六、已知限制与注意事项

### ⚠️ 口音保存后可能变弱
ElevenLabs 已知问题：preview 中明显的口音在 save（confirm）后可能减弱。
- **应对**：在 prompt 中加强口音关键词，用 `strong`/`heavy`/`thick` 修饰
- **测试**：confirm 后立即生成一段测试台词，确认口音保留程度

### ⚠️ 方言 ≠ 口音
- **方言**：完全不同的语言系统（粤语、吴语、闽南语）
- **口音**：用目标语言（如普通话）说话时带有的母语/方言痕迹
- ElevenLabs 主要能控制的是**口音**，不是让 AI 说纯方言

### ⚠️ 混合口音效果不稳定
同时要求两种以上口音（如「带日语口音的四川普通话」）效果不可预测。
建议只指定一种主要口音来源。

### ⚠️ 台词配合是关键
光靠 prompt 控制口音效果有限。台词中的**语气词、词汇选择、语法结构**对口音感知的贡献往往超过声音本身。两者必须配合。

---

## 七、快速查表

| 我要的效果 | Prompt 核心词 | 台词关键技巧 |
|-----------|-------------|-------------|
| 日本人说中文 | `Japanese-accented Mandarin, flat tones, polite` | 加日语语气词，句尾拖音 |
| 美国人说中文 | `American-accented Mandarin, imperfect tones, confident` | 夹英文词，英语语序 |
| 法国人说中文 | `French-accented Mandarin, nasal, elegant` | 偶尔蹦法语词，拖音优雅 |
| 德国人说中文 | `German-accented Mandarin, precise, rigid tones` | 断句清晰，用词精确 |
| 俄罗斯人说中文 | `Russian-accented Mandarin, deep, heavy consonants` | 语气直接，断句硬朗 |
| 韩国人说中文 | `Korean-accented Mandarin, higher pitch, fast` | 加韩语语气词，句尾上扬 |
| 中国人说英语 | `Chinese-accented English, even timing, soft "th"` | 直译语法，时态遗忘 |
| 东北口音普通话 | `Dongbei accent, exaggerated tones, heavy erhua` | 东北词汇，儿化，夸张语气 |
| 北京口音普通话 | `Beijing accent, heavy erhua, syllable swallowing` | 儿化，吞音，京味词 |
| 四川口音普通话 | `Sichuan accent, f/h confusion, melodic` | 川味语气词，叠词 |
| 广东口音普通话 | `Guangdong accent, no retroflex, brisk` | 粤语词混入，粤式语气词 |
| 江浙口音普通话 | `Jiangzhe accent, Wu influence, soft and gentle` | 语气柔软，语速偏慢 |
| 天津口音普通话 | `Tianjin accent, high-falling first tone, comedic` | 自带相声节奏感 |

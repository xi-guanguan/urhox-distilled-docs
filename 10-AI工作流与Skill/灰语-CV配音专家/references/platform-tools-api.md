# 平台工具与 API 参考 — Platform Tools & API Reference

> 三大 MCP 工具的完整参数说明、调用顺序、注意事项。

---

## 工具总览

| 工具 | 用途 | 消耗 Slot | 前置条件 |
|------|------|----------|---------|
| `audition_voices_for_character` | 生成候选声音供试听 | 否 | 无 |
| `confirm_character_voice` | 确认选择，创建正式声音 | 是（1个） | 必须先 audition |
| `text_to_dialogue` | 用已确认的声音生成台词音频 | 否 | 必须先 confirm |

---

## 工具 1: audition_voices_for_character

**用途**: AI 根据描述生成 1-3 个候选声音供用户试听。

### 参数

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `character_name` | string | 是 | 角色名称 |
| `character_description` | string | 是 | 六维度声音描述（必须英文） |
| `audition_line` | string | 是 | 试音台词（>= 100 字符） |
| `candidate_count` | number | 否 | 候选数量 1-3，默认 3 |

### 关键规则

1. `character_description` 必须用**英文**
2. `character_description` 必须覆盖六维度（年龄性别、音色、语速、情绪、风格、录音质量）
3. `audition_line` 必须 >= 100 字符（API 硬限制）
4. `audition_line` 的情绪风格必须匹配 prompt 的情绪描述
5. 禁止使用 child/kid/young girl 等儿童相关词汇

### 调用示例

```
audition_voices_for_character(
  character_name = "剑圣",
  character_description = "Young adult male in his late 20s, low and cool tone, calm and detached, slow deliberate pacing, minimal emotional variation, blade-sharp delivery. Studio-quality recording.",
  audition_line = "刀出鞘，不见血不归。你若挡我的路，那就别怪我不留情面。这世上没有无缘无故的仇恨，只有不够锋利的剑。",
  candidate_count = 3
)
```

### 返回值
- 返回 1-3 个候选声音的预览音频 URL
- 每个候选有编号（1, 2, 3...）
- 用户试听后选择编号

---

## 工具 2: confirm_character_voice

**用途**: 确认用户选择的候选声音，创建正式 Voice。**消耗 1 个 Voice Slot。**

### 参数

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `character_name` | string | 是 | 角色名称（必须与 audition 时一致） |
| `selected_index` | number | 否 | 用户选择的候选编号（1-3）。省略则用推荐项 |

### 关键规则

1. **必须先完成 audition** 才能 confirm
2. **确认即消耗 Slot**——确认前务必让用户满意
3. 用户说"选 2 号"→ `selected_index = 2`
4. 用户说"继续"或不指定 → 省略 `selected_index`，用推荐项

### Voice Slot 限制

| 订阅等级 | Slot 数量 |
|---------|----------|
| Free | 3 |
| Starter | 10 |
| Creator | 30 |
| Pro | 160 |

---

## 工具 3: text_to_dialogue

**用途**: 用已确认的角色声音生成台词音频。

### 参数

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `inputs` | array | 是 | 台词数组，每项含 `character_name` + `text` |
| `language_code` | string | 否 | 语言代码，默认 `cmn`（普通话） |
| `stability` | number | 否 | 稳定性 0-1，默认 0.5。越低越有情感变化 |
| `output_name` | string | 否 | 输出文件名（无后缀） |

### 关键规则

1. **角色必须已 confirm**——未 confirm 会被拒绝
2. Voice mapping 存储在 `.project/elevenlabs-voice-mapping.json`
3. `text` 中可以插入 Audio Tags 控制情绪
4. 支持批量生成（inputs 数组传多条台词）

### stability 参数指南

| 值 | 效果 | 适用场景 |
|----|------|---------|
| 0.3-0.5 | 更多情感变化 | 戏剧性台词、战斗、告白 |
| 0.5-0.7 | 平衡 | 日常对话 |
| 0.7-1.0 | 稳定一致 | 旁白、正式场合、教程 |

### 台词 Audio Tags 用法

在 `text` 字段中直接插入：
```
"[sad] 他走了……再也不会回来了。[pause] [softly] 但我会记住他。"
```

### 调用示例

```
text_to_dialogue(
  inputs = [
    { character_name = "剑圣", text = "[dramatic tone] 刀已出鞘。[pause] 你准备好了吗？" },
    { character_name = "剑圣", text = "[angry] 别逼我动手！" }
  ],
  stability = 0.4,
  output_name = "剑圣_战斗台词"
)
```

---

## 标准工作流程

```
1. 引导问诊 → 确定角色声音方向
2. 组装六维度 prompt（英文）
3. 准备试音台词（>= 100 字符，匹配角色性格）
4. 调用 audition_voices_for_character → 生成 3 个候选
5. 用户试听 → 选择编号
6. 调用 confirm_character_voice → 创建正式 Voice（消耗 Slot）
7. 编写游戏台词（加 Audio Tags 和标点控制）
8. 调用 text_to_dialogue → 生成台词音频
9. 根据反馈调优（调 stability / 修改 Audio Tags / 重新生成）
```

---

## 语言代码参考

| 代码 | 语言 |
|------|------|
| `cmn` | 中文普通话（默认） |
| `en` | 英语 |
| `ja` | 日语 |
| `ko` | 韩语 |
| `es` | 西班牙语 |
| `fr` | 法语 |
| `de` | 德语 |

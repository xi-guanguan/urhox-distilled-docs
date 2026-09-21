# sprite-gen MCP 四层分工与本地复现

> **这是什么**: 拆开「序列帧 MCP」的真实结构——Agent / 编排引擎 / 图片 MCP / 视频 MCP 四层各干什么、`next` 循环怎么走、本地 Codex 如何用自有图片+视频 MCP 接同一套合同。
> **原作者**: 莎士比亚（搬nana / 本地授权测试开发复现）
> **推荐度**: L1（动手复现必读 — 不混层、不自排步骤、不手写 prompt）
> **适用场景**: 本地已有 generate_image/edit_image 与 create_video_task（或等价），要复现云端 sprite-gen 同一工作流；或要理解「生成序列帧」skill 实际在调什么。
> **配套**: Maker skill `sprite-gen` v1.4.0（`SKILL.md` + `refs/`）。本文钉死分工与顺序，不替代 skill 操作手册。

---

## 一句话

sprite-gen **不是**一个会画画的 MCP。它是一台状态机：自己管进度、门禁、prompt、拆帧、打图集；画画和出视频分别插到图片 MCP、视频 MCP 两个槽里。本地两槽已齐，就能按同一 `next` 循环复现。

---

## 一、四层，不要混

```
Agent  ──循环调 next──►  sprite_gen 编排引擎
                              │
                 kind=agent_task 时点名一个槽
                              │
              ┌───────────────┴───────────────┐
              ▼                               ▼
        图片 MCP                         视频 MCP
   generate_image / edit_image      create_video_task
```

| 层 | 干什么 | 不干什么 |
|----|--------|----------|
| **Agent** | 调 `next`；gate 原样展示并停；按 `do` 调**一个**外部 MCP；产物用 `--payload` 交回 | 自己排步骤、手写 prompt、替用户过审、一口气跑完 |
| **sprite_gen 引擎** | 状态、门禁文案、合成 prompt、预处理、拆帧、打图集、写 `_progress.json` | 自己出图、自己出视频 |
| **图片 MCP** | 候选图：抠图 / ready / 转视角 / 补姿态 | 拆帧、打包、记进度 |
| **视频 MCP** | 图生视频（首帧=ready） | 写 action、抽帧、验收 |

本地已有图片 MCP + 视频 MCP 时：**创意两槽已经齐**。缺的是编排层。本地复现 = 把编排层接到这两槽上，不是另发明一条流水线。

---

## 二、控制动词（只这 7 个）

`sprite_gen` 的 `method` = 动词，`params` = flags。

| 动词 | 作用 | 关键 flags |
|------|------|------------|
| `next` | 启动、提交门禁、交回产物、往下走 | `--sprite-name` `--sprite-type` `--payload` |
| `goto` | 跳回前置阶段或某条动画 | `--stage ready\|viewpoint\|plan\|pose` 或 `--anim-id` |
| `redo` | 重做本步或指定动画 | `--anim-id` 可省 |
| `add` | 追加动画 | `--anims '<json 数组>'` |
| `update` | 改参；先停确认门，`next` 应用 / `redo` 取消 | `--set`；动画级加 `--anim-id`；`--video-model 2.0\|wan` 直接记项目偏好 |
| `describe` | 只读展开配置 | `--sprite-name` |
| `help` | 只读指令集 | 无 |

启动：`next --sprite-name <名> --sprite-type character|generic`  
之后每次都带 `--sprite-name`。恢复会话：`next --sprite-name <名>`（无 payload）。  
本地测试可显式 `--sprite-dir <可写目录>`。

---

## 三、三种 descriptor（Agent 只认这三种）

`next` 每次只返回**一个**动作：

| kind | Agent 做什么 | 是否停用户 |
|------|--------------|------------|
| `gate` | 原样展示 `gate.present`，等真实作答，再按 `gate.accept` 选 `next`/`redo` | **必须停**。「继续」≠ 过审 |
| `agent_task` | 按 `do` 调**一个**外部 MCP；完成后 `next --payload <produce 字段>` | 默认不停。唯一例外：视频返回 `confirmation_required=true` |
| `done` | 结束 | — |

`say` 非空就原样说一句，然后同轮继续 `do`。`say` 不是停顿点。  
确定性步骤（预处理 / 建 prompt / 拆帧 / 导出）夹在两次停顿中间，由引擎自己跑。Agent 不调、不复述。

---

## 四、顺序（character）

用户侧看到的是门禁和成品。`generic` 自动跳过带 `*` 的步。

```
[启动] next --sprite-name --sprite-type
        ↓
① collect_input          gate
   素材图 / 精灵名 / 视角选项(1 keep 2 flip 3 profile 4 cheated 5 custom)
   基础项: target_height=256, content_ratio=0.6, frame_mode=F|K, art_style
   用户确认 → next --payload {source_image, options, adjust_option, custom_prompt?}
        ↓
   引擎 preprocess（抠图判断、ready 画布）
        ↓
② viewpoint_select *     仅 character 且需要转视角
   agent_task: generate_image / edit_image 出候选
   gate: 用户对照评估标准选一张 → next --payload
        ↓
③ plan                   gate  确认动画清单
        ↓
④ pose_detect / pose_select *   仅 character 且有姿态缺口
   agent_task: 逐个补姿态候选图
   gate: 用户选图
        ↓
⑤ 视频模型选择            gate  首次: 2.0 或 wan；写入项目偏好后不再问
        ↓
⑥ anim_loop（cursor 指向当前动画）
   引擎 build_prompt → 写出 anim.prompt.json
        ↓
   agent_task: create_video_task
     model = 该动画 anim.prompt.json 的 video_model 原值（禁止改写）
     首帧/参考 = ready 或引擎指定图
     若 confirmation_required=true → 停、展示预估、用户明确同意后再带 user_confirmed=true
     完成后 next --payload {video_ref, ...}
        ↓
   引擎拆帧（F=按 fps 全帧 / K=关键姿态）+ 预览 webp
        ↓
   gate: 验收该动画（通过 next / 重做 redo --anim-id）
        ↓
   下一条动画，直到清单空
        ↓
   引擎打图集 → {output_dir}/{名}/sprite.json + <anim>/spritesheet.json|.png
        ↓
⑦ done
```

`goto --stage` 可回：`ready` / `viewpoint` / `plan` / `pose`。  
`done` 后：`add` 追加动画（character 回 `pose_detect`，generic 回 `build_prompt`）；`redo --anim-id` 改 action 重做。

---

## 五、顺序（generic）

与 character 同一套 `next` 循环，固定差异：

- `adjust_option` 恒 `keep`，不做侧视 / 转视角 / 姿态缺口。
- 动画清单必须来自用户（id / play_type=`loop`|`once` / action / 可选 user_prompt、duration）。
- pivot 缺省画布中心 `(0.5, 0.5)`；character 用 ready 内容 bbox 底中（脚底）。

---

## 六、本地接线（图片 MCP + 视频 MCP）

本地 Codex 按 **同一 descriptor 合同** 接，不要另写步骤表。

```
本地 Agent
  1. 调本地 sprite_gen 编排器（或等价 next 实现）
  2. 若 kind=gate     → 原样展示，等用户
  3. 若 kind=agent_task
       do 点名图片 → 调本地 generate_image / edit_image
       do 点名视频 → 调本地 create_video_task（或本地等价：首帧+prompt→mp4）
       把产物路径填进 produce 字段，next --payload 交回
  4. 若 kind=done     → 结束
```

**图片槽要覆盖的产物**（引擎会在后续 gate 里拿出给用户选）：

- 非透明输入：`cutout_cand_*.png` → 用户选后落 `cutout.png`
- ready 候选：`ready_cand_*.png` → `ready.png`
- 转视角 / 补姿态候选图（仅 character）

**视频槽要覆盖的产物**：

- `{work_dir}/{名}/_gen_videos/<anim_id>/anim.mp4`
- 交回 `video_ref`（本地用工作区相对路径即可）
- 拆帧、打图集仍归编排层，不归视频 MCP

**prompt 仍由编排层合成**，Agent 禁止手写。本地复现时：要么移植引擎的 prompt 合成，要么先用引擎写出的 `*.prompt.txt` / `anim.prompt.json` 原样喂给本地 MCP。

---

## 七、工作目录

```
{work_dir}/{精灵名}/
  _progress.json          状态机 checkpoint（schema v3）
  _meta.json              精灵级配置
  _user_anims.json        用户动画清单
  _gen_images/            ready / cutout / 候选图 / 对应 prompt
  _gen_videos/<anim_id>/  anim.prompt.json, anim.mp4, 预览 webp

{output_dir}/{精灵名}/
  sprite.json
  <anim_id>/spritesheet.json + .png
```

云端用 `--sprite-name` 当不透明句柄。本地测试用 `--sprite-dir`。  
配置优先级：`_user_anims.json` > `_meta.json` > `config.json`。

---

## 八、本地复现缺什么、不缺什么

| 已有（本地） | 仍要补的编排能力 |
|--------------|------------------|
| 图片 MCP | `next` 状态机 + graph/content 门禁文案 |
| 视频 MCP | 预处理（ready 画布、content_ratio、offset） |
| Skill 协议（本文 + SKILL.md） | prompt 合成（禁止 Agent 手写） |
| | 拆帧（F/K）+ spritesheet 打包 |
| | `_progress.json` reconcile（产物优先恢复会话） |

判断「能不能」：本地两槽能出 PNG 和 MP4，就能把 `agent_task` 跑通。剩下是把引擎内部那几步做成本地可调用模块，**仍然由 `next` 驱动**，不要让 Agent 自己排步骤。

---

## 九、铁律（从 skill 抽出、本地同样适用）

1. 流程只由 `next` 驱动，不得跳步到生成 / 拆帧 / 导出。
2. 所有 prompt 必须由编排层合成，Agent 不得手写。
3. `kind=gate` 必须停下等用户真实作答；「继续 / 你看着办」不等于审核通过。
4. `create_video_task` 返回 `confirmation_required=true` 时，必须把预估原样告知用户，等明确同意后再带 `user_confirmed=true` 重发。
5. 视频 `model` 用该动画 `anim.prompt.json` 的 `video_model` 原值，禁止改写。
6. 对话只呈现成品和 gate 的 `present`；`next` / descriptor / 文件路径等机制名词不进用户对话。

---

## 同类对比

| 文档 | 关系 |
|------|------|
| `南北绿豆-AI视频转游戏序列帧完整工作流` | 手工 5 步流水线（参考图→视频→ffmpeg→抠图→拼表）。本文是 **MCP 状态机合同**，不替代那条手工管线。 |
| `南北绿豆-序列帧动画游戏应用指南` | 运行时怎么播序列帧。本文停在导出 `spritesheet.json`。 |
| `糖心哥-序列帧动画完整指南` | 更偏引擎接入与参数。本文偏生成侧分工。 |
| `一棵草-色幕视频帧提取精灵图生成指南` | 色幕抽帧细节。对应本文「引擎拆帧」那一步的手工版。 |

**建议阅读顺序**: 先读本文搞清四层和 `next` 循环 → 要手工落地抽帧再读南北绿豆/一棵草 → 要播表再读应用指南。

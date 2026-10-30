# Maker 工具手册

以下基于本次可见 MCP schema（运行时包 0.0.38，2026-10-31）。工具名和字段以实际会话为准；更新提示不授权自动升级。没有暴露的工具不得靠猜 API 或直接付费供应商绕过。

## 1. 操作路由

| 需求 | 工具/动作 | 不可漏掉的约束 |
|---|---|---|
| 状态 | `maker://status` / `maker_status_lite` | 本地只读；不等于构建/已绑定/全部远端能力可用 |
| 单张新图 | `generate_image` | `name,prompt,target_size`；一般 `model=default` |
| 多张独立新图 | `batch_generate_images` | 两张以上，同一次请求保留逐项成功/失败 |
| 改已有图/扩展构图 | `edit_image` | `image,name,prompt,target_size`；不是新图工具替代品 |
| 视频 | `create_video_task` | 明确视频请求、费用门槛、模式与参考角色匹配 |
| 视频查询 | `query_video_task` | 有 task_id 才查；pending/running 后至少隔120秒 |
| 音乐/歌曲 | `text_to_music` | 非音效；自定义需 title/style，器乐项在自定义模式生效 |
| 单个/一组音效 | `text_to_sound_effect` / `batch_sound_effects` | 各项 ≤120秒，保留原格式 |
| 声音试听 | `audition_voices_for_character` | 描述具体，台词≥100字符，1–3候选，全部展示 |
| 声音确认 | `confirm_character_voice` | 本人明确选择后调用，占永久 Voice Slot |
| 最终台词 | `text_to_dialogue` | 已有确认映射；角色名与台词，不乱填 voice ID |
| 3D 生命周期 | `create_3d_asset` | start/query/get_options/continue/post_process；reviewed 需人工审核 |
| UrhoX 元数据 | `generate_resource_meta` | 确实供 UrhoX 使用时显式调用；不是其他引擎/宣发文件的前置步骤 |

构建、扫码、反馈和广告不是素材生成工具的隐含前提：不因物料需求自动调用 `maker_build_current_directory`、`generate_test_qrcode` 或 `get_ad_config`。如用户另要求扫码/构建等，按其实际规则处理。调研玩家反馈时优先只读 `get_debug_feedbacks(fetch_and_mark_processed=false)`，不为制作物料默认把反馈标为已处理。

## 2. 图片参数

- 普通新图/编辑默认 `model="default"`。仅用户明确指定后端时用 `nanobanana` / `gpt` / `image3`；不要把旧项目使用过 gpt 当成新项目指定。
- `aspect_ratio` 决定构图形状，`target_size="1920x1080"` 等是必填最终像素；`resolution` 是生成分辨率，不能拿来代替最终像素。
- `reference_images` 支持项目路径/适用 data URL 等，按工具具体 schema；每张本地或 data URL 参考 ≤10MiB。
- 新图最多14张参考；编辑为原图加最多13张额外参考。Image3 总输入最多3张（编辑原图计1张），不要把不同模型限额混用。
- 有 `reference_images` 时优先于旧 `reference_image`。多图注明各图职责，避免样式/身份互相污染。
- `quality` 依具体模型和后端，不承诺所有路由都支持同样等级；保留返回的实际模型信息。
- `transparent=true` 用于确实需要透明底的 Logo/切图；商店 Icon 与完整主视觉通常不能因此交透明底。透明输出要检查实际 alpha，不只看棋盘预览。

可执行参数模板（方括号需替换为已核验值，不原样提交）：
```json
{
  "target_dir": "[唯一Maker项目绝对根]",
  "name": "game_brand_hero_landscape",
  "model": "default",
  "prompt": "[用途、参考职责、主体、画风、构图、留白、允许/禁止变化]",
  "reference_images": ["assets/image/reference/character.png"],
  "aspect_ratio": "16:9",
  "target_size": "1920x1080",
  "resolution": "2K",
  "quality": "high"
}
```

## 3. 视频模式、输入与费用

模式：`text_to_video` / `first_frame` / `first_last_frame` / `multi_modal_reference`。图片角色为 `first_frame` / `last_frame` / `reference_image`，视频为 `reference_video`，音频为 `reference_audio`；不要混淆角色。某模型是否支持某模式、时长、分辨率，按当前 schema/返回说明核对。

当前工具规定的**估价**（不承诺实际账单）：

| model | 估价积分/秒 |
|---|---:|
| `2.0` | 200 |
| `2.5` | 300 |
| `wan` 480p | 42 |
| `wan` 720p | 84 |
| `wan` 1080p | 168 |

- `wan` 省略 resolution 时按1080p估价；省略 duration 或值为 -1 时按所选模型最大时长估价。`default` 的实际路由/计费不明时先核实，不能偷偷按最便宜模型估价。
- **单次估价超过1000积分**：先展示具体估价与“实际费用以生成时计费为准”，等待用户明确确认后才用同一请求 `user_confirmed=true`。≤1000 时不能预先填 true。不拆单规避本人确认门槛；同时披露完整计划总额。
- “普通积分许可自动同意”不能取代明确要求展示费用后的再次本人确认，也不能继承另一个游戏的预算。
- 参考图片 ≤30MiB，视频 ≤50MiB，音频 ≤15MiB；本地项目路径、公网 URL、data URL 的实际支持跟随模式/schema。`generate_audio` 用来声明是否生成伴随音频，不把静音源片当作自带BGM；`return_last_frame` 仅在确需后续衔接且模型支持时开启。
- 返回 pending/task_id 后先做其他工作，至少120秒后查；继续 pending/running，再隔至少120秒。不要每几秒轮询，不因本地请求超时重复 `create_video_task`。
- 原请求超时而 task_id 未知，先查官网任务历史/素材登记等可访问状态，报告执行状态不明；无证据不能认定没扣费。

5秒 wan 720p 的估价为 420 积分，两镜头估价840；这只是算例，不是所有宣传片的套餐价格。长片要分别估生成、可能重试和可选音频，没返回费用的项记“未知”，不要补成0。

## 4. 可选 3D，不把它强塞进纯2D宣发

只有用户的物料确实需要3D资产才进入。角色、生物、NPC、重要物品或明确美术方向采用 reviewed；普通低重要性物件可 direct。balanced 为一般默认，fast 只适合简单低重要性/一次性草稿，精细主体可 high_quality。

```json
{
  "action": "start",
  "target_dir": "[唯一Maker项目绝对根]",
  "payload": {
    "generation_strategy": "reviewed",
    "quality_tier": "balanced",
    "subject_type": "biped",
    "prompt": "[身份、比例、材质、用途与不可变特征]"
  }
}
```

- 文字 reviewed 提供 subject_type：biped（A-pose）、quadruped（中立站姿）、scenery、other。
- 记录 asset_id、task_id、step_id；query 查状态，get_options 查实际步骤选项。
- **所有返回审核预览展示给用户；本人明确批准之后才能 continue**，不自动填 confirm=true，不擅自开始最终模型生成。
- post_process 的 operation 为 rig / texture / retopology / convert。convert 明确格式；rig 先查可绑性。当前不支持 Tripo 动画重定向，不作可交付承诺。
- 使用 `local_delivery` 等返回路径；核对模型、贴图、材质、格式、比例和实际引擎导入需求。模型生成成功不等于已能在游戏里正确运行。

## 5. 本地投递、映射与故障分类

MCP 素材保留在经核验的 Maker 根目录：`assets/image`、`assets/video`、`assets/audio`、`assets/model`，映射以 `.maker/assets/generated-assets.json` 及实际返回为准。只输出不含凭证的路径/ID，不复制 `.maker-mcp/config.json`、登录文件或 Cookie 进交付包。

其他引擎需要引用时保留 Maker 原件，再在用户允许的目标范围复制/转换；不能挪走原件破坏后续编辑映射。纯宣发交付也不靠修改引擎文件“让生成生效”。

| 现象 | 先查 | 不要做 |
|---|---|---|
| 当前目录未绑定 | 目标根与账号/项目，是否存在已批准供应目录 | 自动 init/借另一个游戏扣费/构建 |
| 工具缺失 | 当前会话 tools、注册与具体版本 | 编造工具名、升级其他客户端 |
| 连接失败/超时 | 原始错误、阶段、工具/任务 ID | 立刻把所有失败归为 Maker 宕机 |
| 一批部分失败 | 逐项结果、成功文件与映射 | 整批重复生成导致重复扣费 |
| 生成成功但没文件 | 返回 workspace/local path、映射、实际落点 | 猜文件名、从别的项目拿同名图 |
| 看见图不等于可上传 | 实际尺寸/体积、文字、格式、最终字段 | 拿低清预览或无字母版当最终物料 |

音乐工具可能服务器端等待很久，超时返回task ID时保留ID查任务历史，不把音乐ID交给视频查询工具；没有对应查询能力则说明限制。声音试听是临时文件，永久配音、音效和音乐才按工具返回落到项目，不将试听当最终游戏资产。UrhoX元数据生成只使用官方工具，保留有效meta，不编造UUID，不借此自动构建。

只有明确诊断同一故障后做针对修复；覆盖已有资产、模型切换、付费回退、账号选择等本人停点依当前规则保留。问题报告上传诊断必须先获本次同意。

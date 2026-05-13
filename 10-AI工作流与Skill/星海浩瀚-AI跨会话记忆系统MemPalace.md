# AI 跨会话记忆系统 MemPalace

## 这是什么

基于 ChromaDB 向量数据库的 AI 协作开发"外挂记忆大脑"。解决 AI 助手跨会话失忆、会话内退化、全项目扫描三大问题。通过语义搜索快速恢复项目上下文，token 节省 70%~88%。

- **原作者**: 星海浩瀚
- **推荐度**: L2（参考学习）—— 方案完整可用，但依赖 Python venv + ChromaDB 环境搭建，存在运维门槛
- **适用场景**: 任何需要 AI 跨会话记忆的持续开发项目，项目越大收益越明显

---

## Token 节省效果

| 项目规模 | 无 MemPalace | 有 MemPalace | 节省 |
|---------|-------------|-------------|------|
| 小 ~30 文件 | ~10K/次 | ~3K/次 | 70% |
| 中 ~80 文件 | ~30K/次 | ~5K/次 | 83% |
| 大 ~150 文件 | ~50K/次 | ~6K/次 | 88% |

---

## 安装（一次性）

```bash
python3 -m venv /home/Maker/mempalace-env
source /home/Maker/mempalace-env/bin/activate
pip install mempalace  # v3.0.0 + 60 依赖，含 ChromaDB/ONNX Runtime
```

首次运行自动下载 ONNX 嵌入模型 all-MiniLM-L6-v2（~79MB）。

数据库路径：`/home/Maker/.mempalace/palace/`（持久存储，跨会话）

---

## 两级分类体系

```
wing = 项目标识（如 "my-rpg"）
room = 内容分类
```

| room | 存什么 | 示例 |
|------|--------|------|
| `decisions` | 设计决策/方案选择 | "选了五行相克，1.5x倍率" |
| `progress` | 开发进度/完成状态 | "7模块完成，12测试通过" |
| `bugs` | 踩坑记录 | "group()只接受字符串" |
| `next-steps` | 待办/后续计划 | "下一步：断言压缩" |
| `code-map` | 代码结构索引 | "combat.lua 含 calcDamage，依赖 data.lua" |

`code-map` 是关键分类 — 存储文件摘要/模块关联/数据结构索引，避免全项目扫描。

---

## 完整工作流

### 1. 会话开始：唤醒

```python
col = client.get_collection('mempalace_drawers')
results = col.query(query_texts=['当前进度 决策 待办'], n_results=5)
```

可按 room 过滤：`where={'$or': [{'room': 'progress'}, {'room': 'next-steps'}]}`

### 2. 讨论中：实时保存

触发条件：做出明确决策 / 确定数值参数 / 完成方案讨论 / 发现重要踩坑

```python
col.add(
    ids=['session-8-crit-formula'],
    documents=['暴击公式用(1+暴击伤害%)乘法...代码在combat_formula.lua的calcCrit()'],
    metadatas=[{'wing': '项目名', 'room': 'decisions', 'filed_at': now}]
)
```

### 3. 写代码前：查询

```python
results = col.query(query_texts=['要实现的功能关键词'], n_results=5)
```

语义搜索：查"战斗伤害"能匹配"combat_formula 含 calcDamage"。

### 4. 会话结束：总结

```python
col.add(ids=['session-N-summary'], documents=['本次完成了...决策...踩坑...下次应该...'],
        metadatas=[{'wing': '项目名', 'room': 'progress'}])
```

### 5. 代码变更后：更新 code-map

```python
col.upsert(ids=['codemap-combat'], documents=['combat.lua：战斗核心。calcDamage/calcCrit。依赖data.lua'],
           metadatas=[{'wing': '项目名', 'room': 'code-map'}])
```

`upsert` 自动覆盖同 ID 旧记录。

---

## ID 命名规范

| 类型 | 格式 | 示例 |
|------|------|------|
| 决策 | `session-{N}-{主题}` | session-8-crit-formula |
| 进度 | `session-{N}-progress` | session-12-progress |
| 踩坑 | `session-{N}-bug-{简述}` | session-16-map-bug |
| 代码地图 | `codemap-{文件名}` | codemap-combat-formula |

---

## 记忆内容规范

好的记忆（具体/有上下文/可行动）：
> "暴击公式用 (1+暴击伤害%) 乘法，非固定2x。理由：乘法让暴击装更有意义。代码在 combat_formula.lua 的 calcCrit()"

差的记忆：
> "讨论了暴击系统"

---

## 管理命令

- 查看全部：`col.get()` → 遍历 ids/documents/metadatas
- 按 room 查：`col.get(where={'room': 'decisions'})`
- 删除单条：`col.delete(ids=['要删除的ID'])`
- add vs upsert：新增用 `add`（ID重复报错），更新用 `upsert`（ID重复覆盖）

---

## 注意事项

- 多项目共用同一数据库，通过 `wing` 字段隔离
- 中型项目预计 50-200 条记忆，查询速度不受影响
- venv 丢失只需重装 pip 包，数据库不受影响
- 单次保存 ~200 tokens，单次查询 ~300 tokens

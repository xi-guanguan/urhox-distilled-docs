# 敏捷游戏生产管线: GDD 到 Sprint

> **这是什么**: 将游戏设计文档 (GDD) 转化为可执行的 Agile 开发任务，通过 Epic - Story - Sprint 三级拆分管理游戏开发进度
> **原作者**: 节拍前夜
> **推荐度**: L2（有参考学习价值）
> **适用场景**: GDD 完成后启动正式开发、需要将设计文档转为可执行任务、AI 辅助的游戏迭代开发

---

## 核心流程

```
GDD (docs/gdd.md)
    |
[Phase 1] Epic 拆分
    | 用户确认 Epic 范围
[Phase 2] Story 细化
    | 用户确认 Story 粒度
[Phase 3] Sprint 规划
    |
[执行] Sprint 循环开发
```

前置条件: `docs/gdd.md` 已存在（或等效的游戏设计信息）。

---

## Phase 1: Epic 拆分

**目标**: 将 GDD 中的游戏系统转化为可管理的 Epic。

**输出**: `docs/epics/` 目录，每个 Epic 一个文件。

**拆分规则**:

| 来源 | 映射 |
|------|------|
| GDD Systems Index 中的每个游戏系统 | 1 个 Epic |
| 基础设施（项目搭建、脚手架） | 1 个 Epic |
| 跨系统功能（如"完整游戏流程"） | 1 个 Epic |

---

## Phase 2: Story 细化

**目标**: 将每个 Epic 细化为具体的 User Story。

**输出**: 在每个 Epic 文件中添加 Story 列表。

**拆分规则**:
1. 每个 Story 是一个可独立完成的功能单元
2. 粒度控制在 1-4 小时（以 AI 辅助开发速度为基准）
3. 每个 Story 必须有明确的验收标准
4. 必须包含具体的技术实现提示

---

## Phase 3: Sprint 规划

**目标**: 将 Story 组织为 Sprint。

**输出**: `docs/sprints/` 目录。

**规划规则**:
1. 每个 Sprint 产出可运行的版本
2. Sprint 内 Story 按依赖顺序排列
3. 每个 Sprint 有明确目标和 Demo 要点
4. Sprint 1 必须是可玩的 MVP

---

## 执行阶段: Sprint 循环

```
[Sprint 开始]
    |
选取 Story --> 阅读验收标准 --> 开发 --> 测试 --> 完成
    |
[Sprint 回顾]
    |
更新 Sprint 状态 --> 进入下一个 Sprint
```

---

## 文档结构

```
docs/
├── gdd.md                    # GDD（输入）
├── systems/
│   └── README.md             # 系统索引（输入）
├── epics/
│   ├── README.md             # Epic 总览
│   ├── E01-project-setup.md
│   ├── E02-core-gameplay.md
│   └── ...
└── sprints/
    ├── README.md             # Sprint 总览
    ├── sprint-01.md
    ├── sprint-02.md
    └── ...
```

---

## 工作量估算基准

以 AI (Claude) 辅助开发为基准:

| 任务类型 | 典型时间 | Story 点数 |
|---------|---------|------------|
| 简单 UI 界面 | 10-30 分钟 | 1 |
| 核心机制实现 | 30-60 分钟 | 2 |
| 复杂系统集成 | 1-2 小时 | 3 |
| 完整功能模块 | 2-4 小时 | 5 |
| 大型重构/新系统 | 4+ 小时 | 8 |

---

## 状态追踪

### Story 状态

| 状态 | 含义 |
|------|------|
| Backlog | 待开发 |
| In Progress | 开发中 |
| Testing | 测试中 |
| Done | 已完成 |
| Blocked | 被阻塞 |

### Sprint 状态

| 状态 | 含义 |
|------|------|
| Planned | 已规划 |
| Active | 进行中 |
| Completed | 已完成 |
| Carried Over | 有未完成 Story |

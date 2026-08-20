# Distilled Docs Authority

## 当前权威绑定

- 本地权威镜像：`/Users/kalo/Documents/蒸馏文档`
- GitHub 源仓库：`https://github.com/xi-guanguan/urhox-distilled-docs`
- 权威分支：`master`
- 分类目录：`07-game-design/`

本目录是当前唯一的本地权威根目录。目录中的子目录（例如 `07-game-design/`）仍属于同一个 Git 仓库；目录层级不会自动产生或取消权威性，权威性由本文件记录的“路径 + remote + branch”共同确定。

## 本次归档

四篇数值/难度/关卡/经济手册已从 `one-punch-tang` 学习成果完整复制，仅追加文件末尾的归档登记，不改正文。增量游戏框架以英文 ZIP 原包完整保留，并以旁注标记为 L1：

- `difficulty-and-flow-engineering-handbook.md`
- `economy-system-design-handbook.md`
- `level-design-practical-handbook.md`
- `numerical-design-practical-handbook.md`
- `incremental_game_framework.zip`（旁注：`incremental_game_framework.md`，L1）

## 同步规则

每日巡检只读取本文件、remote、当前分支、工作树，并用 `fetch` 比较本地 `HEAD` 与 `origin/master`。只有远端有新提交、工作树不干净、remote 异常或访问失败时报告；禁止自动 pull、commit、push、reset、clean、删除或覆盖文件。

旧路径 `/Users/kalo/Documents/炼丹/knowledge/urhox-distilled-docs` 已不再是权威根目录，仅作为历史路径保留。

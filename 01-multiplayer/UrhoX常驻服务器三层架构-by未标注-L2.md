# UrhoX 常驻服务器三层架构开发规范

> **这是什么**：一套面向 UrhoX Dedicated Server 项目的三层架构规范，把共享定义、服务端权威逻辑、客户端消费、网络事件和持久化收口到可扩展的固定边界。
>
> **原作者**：未标注
>
> **推荐度**：L2（结构完整且包含模板与避雷清单，但素材未提供作者、适用引擎版本或独立构建验证记录，落地前需与当前项目 API 和数据模型核对）
>
> **适用场景**：新建或改造 UrhoX 常驻服务器多人项目；新增业务子系统、Schema 字段、网络事件、玩家存档或客户端同步逻辑时使用。

---

## 1. 架构目标

将项目固定为三个单向依赖层：

```text
scripts/
├── shared/   # Schema、常量、事件名、纯函数；不调用引擎和业务服务
├── server/   # Handler、Service、PDM、Repository；服务端权威
└── client/   # PlayerStore、Dispatcher、EventBus、UI 消费
```

依赖只能指向 `shared`：

```text
server -> shared
client -> shared
server <-> client 只能通过网络事件通信
```

禁止 `server` 引用 `client`、`client` 引用 `server`，也禁止在 `shared` 中执行引擎 API、网络 IO 或全局状态修改。

---

## 2. 服务端职责分离

每个业务子系统按 `Handler -> Service -> PDM` 流动：

```text
客户端请求
  -> Handler：读取和校验参数、调用 Service、发送响应
  -> Service：执行业务规则，不做网络 IO，不直接写云存档
  -> PDM：读写玩家权威状态、同步 REPLICATED Node、标记待持久化
```

### Handler

- 只处理网络边界、参数校验、错误码和响应。
- 成功写入后先 `SyncPlayer(connection)`，再发送 `RES`。
- 第一个玩家参数传 `connection`，不要只传裸 `uid`。

### Service

- 只放业务规则和事务编排。
- 通过 `PDM.GetStat/SetStat` 访问权威状态。
- 不直接调用 `serverCloud`，不发送网络事件。

### PDM

- 是玩家运行时数据的唯一入口。
- 负责 Schema 驱动的读写、REPLICATED 同步、脏标记、PSA3 编码和断线保存。
- 不承担业务规则和网络请求处理。

---

## 3. Schema 驱动数据定义

字段只在 `shared/schemas/*Schema.lua` 定义：

```lua
XxxSchema.Fields = {
    Level = {
        pdmKey = "XxxLevel",
        type = "int",          -- int | float | bool | string | json
        persist = true,
        category = "xxx",
        lifecycle = "permanent",
    },
}
```

在中心 Schema 注册：

```lua
local XxxSchema = require("shared.schemas.XxxSchema")
CharacterSchema.RegisterSubsystemFields("Xxx", XxxSchema.Fields)
```

注册后的业务键为 `Xxx.Level`。Service 和 PlayerStore 使用业务键，不直接使用 `pdmKey`。

生命周期约束：

| lifecycle | 用途 | persist |
|---|---|---|
| `permanent` | 账号永久数据 | `true` |
| `rebirth_reset` | 当前一世，重生时重置 | `true` |
| `derived` | 可由配置或公式重算 | `false` |
| `external` | 平台身份或特殊快照 | `false`，是否进 blob 由白名单决定 |

不要持久化可从 CSV、公式或平台重新获得的数据，也不要在 PDM 内再维护第二份字段表。

---

## 4. 网络事件与客户端分发

事件名统一放在 `shared/<subsystem>/XxxConsts.lua`：

```lua
XxxConsts.EVENT_REQ_START  = "Xxx_ReqStart"
XxxConsts.EVENT_RES_START  = "Xxx_ResStart"
XxxConsts.EVENT_PUSH_STATE = "Xxx_PushState"
```

在 `shared/NetworkEvents.lua` 注册：

```lua
NetworkEvents.RegisterSubsystem("Xxx", XxxConsts)
```

事件值必须带子系统前缀。不要把事件注册放进 CharacterSchema。

客户端链路：

```text
RemoteEvent
  -> ClientDispatcher：解码和前缀路由
  -> XxxClient.HandleDispatch：业务事件分支
  -> XxxClient.Bus:Emit：通知 UI
  -> 页面销毁时按 scope 清理监听
```

REPLICATED Node 用于持久或展示状态；RemoteEvent 用于请求、结果和瞬时通知。不要让客户端把 RemoteEvent 载荷当成权威存档。

---

## 5. PSA3 单 Blob 持久化

权威路径不是每字段一个 cloud key，而是每玩家、每境界一个 PSA3 blob：

```text
SetStat
  -> 更新内存和 REPLICATED Node
  -> blobDirty = true
  -> 核心初始化 / 30 秒间隔 / 断线时 FlushDirty
  -> PlayerStateBlobCodec.Encode
  -> PlayerStateRepository.SaveBlob
  -> serverCloud:Set(uid, blobKey, blob)
```

境界 key 示例：

- origin：`player_state_psa3`
- 其他境界：`player_state_psa3_<realmId>`

### 加载闸门

1. `LoadPlayer(connection)` 先创建 starter 节点，此时 `blobSaveAllowed=false`。
2. 等待可能存在的 detached save 完成。
3. 读取并解码 blob，或明确确认是空档。
4. 应用数据后才设置 `blobSaveAllowed=true`。
5. 完成核心初始化，再刷盘并发布加载版本。

加载成功前禁止保存，否则 starter 默认值可能覆盖云档。加载失败必须显式失败，不能静默当作新号。

### 断线时序

```text
DisconnectPlayer
  -> FlushDirty("disconnect")
  -> 保留节点进入重连宽限期
  -> 宽限内重连则复用节点
  -> 宽限到期后先处理仓储，再 UnloadPlayer / Dispose
```

先卸载再保存会造成空数据或旧数据回写。保存失败时应建立 detached save 重试，并让下次加载先等待它完成。

### 集合与背包

- 可增长 JSON 不要整表 `SetVar`；单帧约 64KB 超限可能静默丢包。
- 背包由 `InventoryRepository` 维护内存权威记录，压缩快照进入 blob。
- 禁止 `table.remove + ListDelete` 双写。

---

## 6. 客户端同步宽容度

服务端结果事件可能先于 REPLICATED 状态到达：

```text
服务端 SetStat + SyncPlayer + 发送 RES
  -> 客户端先收到 RES
  -> 数十毫秒后 REPLICATED 值才更新
```

客户端不要在 RES 回调中立即读取并假设是新值。应在发请求前注册 `PlayerStore.WaitForChange`，字段变化后刷新 UI，并提供超时兜底。

不适用情况：

- 首次加载：等待 PlayerStore Ready。
- 高频位置更新：直接按帧读取。
- 服务端无请求推送：使用事件分发链路。

页面销毁时必须取消 watcher，并按 scope 清理 EventBus，防止幽灵回调操作已销毁 UI。

---

## 7. 新子系统接入流程

1. 用 `XxxConsts.lua` 定义 `REQ/RES/PUSH` 事件和常量。
2. 用 `XxxSchema.lua` 定义字段、持久性和生命周期。
3. 在 CharacterSchema 注册字段。
4. 在 NetworkEvents 注册事件。
5. 实现 Handler 和 Service；业务写入只走 PDM。
6. 实现 XxxClient、Dispatcher 注册和 EventBus 通知。
7. 做本地诊断与项目规定的构建验证；新增 JSON 集合时检查编码和同步尺寸。

---

## 8. 迁移既有项目

迁移是独立的高风险流程：

1. 只检查目录结构和文件名，判断新项目、已合规项目或中途改造项目。
2. 中途改造必须先生成 `docs/migration-plan.md`，列出文件映射、步骤、复杂度、风险和回滚方法。
3. 用户明确批准后才执行迁移。
4. 执行前备份 `scripts/`。
5. 按模块迁移，每个模块完成后验证；失败立即停止。
6. 全部通过后再清理旧文件，备份保留到迁移确认完成。

不要把迁移方案视为迁移授权，也不要在执行中临时偏离已批准方案。

---

## 9. 高风险避雷清单

- 未加载成功就保存：starter 覆盖云档。
- 断线先卸载再刷盘：玩家回档。
- 每字段写云或写时即存：配额和并发写入风险。
- 绕过 PDM 或在客户端维护权威缓存：状态分叉。
- 发送 RES 前未同步：客户端看不到新状态。
- RES 回调立即读 PlayerStore：读到旧值。
- `SubscribeToEvent` 时函数尚未注册到 `_G`：事件订阅失效。
- 可增长 JSON 整表 SetVar：超限后静默丢包。
- Handler 承担业务逻辑：边界混乱、难以测试。
- Schema 缺少 lifecycle 或放错目录：持久化规则失真。
- 页面监听不清理：幽灵回调和 UI 崩溃。
- `require("cjson")`：该运行时应使用全局 `cjson`。

---

## 10. 落地前核对

- [ ] 当前项目确实使用 UrhoX 常驻服务器和多人模式。
- [ ] 项目引擎版本支持文中涉及的网络、REPLICATED Node 和 serverCloud API。
- [ ] `shared/server/client` 依赖方向无反向引用。
- [ ] PDM 是唯一玩家状态入口。
- [ ] Schema 字段类型、生命周期和持久性一致。
- [ ] 加载闸门阻止默认值覆盖云档。
- [ ] 断线按“先刷盘、后卸载”执行。
- [ ] 客户端处理了 RES 与 REPLICATED 的时序差。
- [ ] 集合数据评估过单帧尺寸和压缩策略。
- [ ] 迁移已获得单独批准并保留可恢复备份。
- [ ] 已完成当前项目要求的本地诊断、构建和真机/多人验证。

---

*素材来源：`three-layer-arch-v3.0.zip`（SKILL.md、5 篇 references 文档、11 个 Lua 模板及升级说明）*

*蒸馏日期：2026-09-20*

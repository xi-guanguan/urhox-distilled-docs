# TapTap CLI 与交付

## 1. 版本和能力发现

官方入口：`https://developer.taptap.cn/v3/cli/`；源码/说明：`https://github.com/taptap/cli`；SDK/小游戏文档入口：`https://developer.taptap.cn/minigameapidoc/`。具体API按当前目标平台导航，不从不对应的SDK复制方法。

2026-10-31实际核对本机已缓存官方 `@taptap/cli@2026.10.29` 的 `--version`、`--help`、`skills list`、`upload-h5-package --help`、`test-qr-code --help`。这说明本手册命令依据，不宣称该版本永远最新，也不自动升级/安装其他客户端Skill。

优先使用当前已安装的准确CLI；PATH缺命令时从实际安装package.json的bin解析入口，不误把“没上PATH”当没安装。不得读取/打印凭证文件。

只读发现示例：
```bash
taptap-cli --version
taptap-cli --help
taptap-cli skills list
taptap-cli auth status
taptap-cli schema app analyze-app-status
taptap-cli upload-h5-package --help
taptap-cli test-qr-code --help
```
这些是当前版本已核对的命令形态，不能保证未来所有参数不变。缺安装且确需使用时，可从官方来源按确认的固定版本获取，例如 `npx --yes --package @taptap/cli@2026.10.29 taptap-cli --version`；不要用未指定版本的latest替代可追溯构建。

当前CLI附带官方业务Skill：先 `skills list`，只读取当前工作需要的包体/资料/测试计划等说明；不要为做一次上传自动运行update --force改动所有全局Skill。

## 2. 身份和授权

先确认当前TapTap用户、developerId、appId与目标游戏。GitHub登录、Maker PAT和TapTap CLI OAuth是不同表面，不能互相代替。

设备授权/二维码/验证码由本人完成，不索取聊天中的token。过期授权要明确旧链接已过期；按用户决定重新发起，不循环刷授权、不强行替人批准。只读身份失败不自动创建新游戏、切服务环境或重置配置。

现有可用账号沿用；只有目标不明/冲突/要求切换时询问。CLI本身提供dry-run/yes不代表用户允许真实写入。

## 3. H5上传

先核对ZIP实际文件、sha256、profile、游戏范围和方向。本次核对的CLI要求输入路径位于当前工作目录内：绝对路径、`..`及解析后越界符号链接会被拒绝。可在有意选定的安全暂存目录复制精确包体，核对复制前后哈希，再从该目录用相对路径执行；不要把用户全盘文件都设为可上传范围。

预演结构示例（变量须由已确认信息填入）：
```bash
taptap-cli upload-h5-package "$ZIP_REL" \
  --dev-id "$DEV_ID" --app-id "$APP_ID" \
  --screen-orientation 1 --dry-run --json
```
本版本方向值0横屏、1竖屏，示例1不适用于所有游戏。dry-run可能读取实时元数据，不写包体不代表绝对离线。

**仅当用户明确要求真实上传且范围已确认**，才执行：
```bash
taptap-cli upload-h5-package "$ZIP_REL" \
  --dev-id "$DEV_ID" --app-id "$APP_ID" \
  --screen-orientation 1 --idempotency-key "$WRITE_INTENT" --yes --json
```
`--yes`只能表达已获得的同意，不替本人作同意。重试同一上传意图沿用稳定幂等key，不能随机换key反复创建版本。不同包/hash是不同意图，应重新核对范围。

任务pending/超时先保留task ID，按当前 `task --help` 查状态/恢复。不同阶段分别记：传输、解析、版本创建、草稿绑定。请求中断不等于远端没成功；查到最终结果前不重复发上传。

## 4. 包体、测试码与资格

解析实际JSON外壳、错误和返回data，区分 `task_id`、version ID与package ID，不把三者混用。上传成功后核对游戏、profile与远端包信息，再交测试入口。

当前自测码命令示例：
```bash
taptap-cli test-qr-code --dev-id "$DEV_ID" --app-id "$APP_ID" \
  --data '{"package_id":123456}' --output test-qr.png --json
```
123456是占位示例，必须换成实际package ID，不是版本ID；输出路径是当前目录内相对路径。不要自动force覆盖已有码。只有本次需要扫码时才调用，不能把码生成当上传/SDK接入必需前置。

扫码能否打开还可能取决于游戏/平台/测试用户资格与包状态。核对已有名单与该平台规则；用户未明确提供账号ID时不猜，不清空其他测试人，不为H5自测盲目创建不相关测试计划。

手机实际显示版本与收据一致后再验SDK。player/review双码明确命名，不能把免广验收包发成普通玩家包。

## 5. 草稿、预检、审核与发布时间

有明确资料回填授权后，先读现有草稿和包体槽位，防止仍绑定旧包、错误profile或“过审即发”。改后回读，按当前 `schema` 获取字段，不猜JSON键。

资料/包体上传、选择主包、预约、预检、最终提审、正式上线/定时上线分别授权与报告。预计发行日期不是定时开放游玩；预约页通过不是游戏已开放。日期写绝对日期和时区，协议/最终提交按平台要求保留本人确认。

预检0阻断/0警告不等于审核通过，二维码成功不等于正式发布。没有完成哪一步就如实写未执行。

## 6. 收据与故障恢复

收据最少有：CLI版本、目标范围、操作意图、输入build/profile/ZIP hash、平台task/version/package、输出/测试码位置、当前状态、实际验证层级、未决项。不写token、Cookie、完整登录配置或个人名单。

分别诊断：PATH/启动器、登录、权限/目标、输入路径/ZIP、编译/资源、远端解析、网络超时与真实SDK。某个表面失败不表示其他会话也失效。使用官方连接与已有授权，不把认证发送公共镜像；只读镜像只能辅助读取公开资料，不能当认证写入端。

本次蒸馏只执行了本地CLI版本/帮助/能力读取，没有登录、上传H5、生成测试码或改发布草稿。核心流程有既有项目收据，跨项目模板与新版CLI组合按执行时规则复核；推荐L2。

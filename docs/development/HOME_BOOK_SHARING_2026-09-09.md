# 首页、账本隔离与共享实施记录（2026-09-09）

本记录供后续窗口接续，记录本轮实现、真实本地联调和验收边界。严禁读取、使用或写入任何 API key。

## 根因与实现

- 原账户、分类、预算、商户规则和收件箱缺少完整账本归属，余额校准固定写默认账本；已新增 bookId、账户期初余额、企业类型及账本查询约束。
- v8→v9 迁移按未删除流水净影响拆分账户，包含转账、校准和已入账未来日期记录；原账户和期初差额保留默认个人账本，其他账本独立账户，保留已删除流水引用。旧预算仅归默认个人账本；分类按账本复制。升级前保存 SQLite 副本。
- v9→v10 新增同步状态、版本、ID 映射、待同步队列与 SQLite 触发器。业务修改和待同步操作原子提交，沿用现有 Repository/DAO。系统安全存储保存登录会话，SQLite 备份不包含会话。
- 首页改用暖米白、实色边框卡片；月账单、今日额度和目标分开；顶部年月独立筛选，路由保留历史月份；书架抽屉从顶部展开，明确创建账本类型。
- 新增 `server/`：Node.js 22 / TypeScript / Fastify 5 / better-sqlite3。注册登录使用密码哈希、可撤销会话；按共享账本成员角色校验；操作幂等、版本冲突、账务变更、余额重算与日志在同一服务端事务内完成。
- 新增 SessionRepository、SharedFamilyService、SharedBookSyncService；个人账本不能启用共享。共享需明确确认范围；只上传对应账本账务数据，不上传通知原文、私有商户记忆或本机附件路径。
- 同设备不同登录用户使用独立共享缓存 ID；本地与远端实体 ID 有稳定持久映射。测试曾发现新流水同步后重复保留两个 ID、重复扣余额，现已修复并加入真实双库测试。
- 支付通知新增固定目标账本和渠道账户映射；缺少账户或权限时保留待处理，浏览时切换账本不改变通知目的地。
- 收尾审计补齐交易 Provider 的当前账本写入约束、目标写入约束和跨账本收件箱引用校验；支付通知使用目标账本范围内的幂等判断，并覆盖固定家庭账本回归测试。
- 书架抽屉收尾改为带悬浮把手、木质层板前沿、书脊、封面内框、高光和投影的立体书本样式；继续保留点击切换、长按管理、关闭按钮和系统返回。
- 将 `/Users/algive/Desktop/icon.png` 复制为项目内统一源 `assets/images/icon.png`，并由它生成 Android 各密度启动图、Adaptive Icon 前景/单色图和 iOS AppIcon，启动图也随之使用同一视觉。

## 实际验证结果与边界

已实际通过：

- `flutter analyze --no-pub`：No issues found。
- `flutter test --no-pub --reporter expanded`：120 个测试全部通过。
- `flutter build apk --release`：`build/app/outputs/flutter-apk/app-release.apk`，72,799,794 bytes，SHA-256 `ea4762b9b8964bb6ebb015e4f1e79a6c9bad53747059e2dae878bf17d924d81c`。
- 服务端 `npm run typecheck && npm test && npm run build`：typecheck、2 个真实 HTTP 测试和 build 全部通过。
- 首页第一轮 320dp / 1.6 字号布局与交互相关 20 个测试。
- 服务端两个真实 HTTP 客户端：登录、邀请、幂等重复提交、并发修改冲突、余额校准、负余额、成员越权、撤销权限和会话失效。
- 两个独立 Flutter SQLite 数据库通过真实本地 Node HTTP 后端联调：共享启用、加入、离线新增、重连、同步回包无重复余额、冲突采用服务端、权限撤销、本地拒绝越权、退出隐藏缓存。
- v1 / v6 / v7 迁移相关 12 个测试；v8 拆分与共享联调相关 3 个测试（迁移测试从最新 schema 降级构造旧库，需移除新触发器）。
- Android 模拟器 `emulator-5554`（Pixel 7）已安装最新 Release APK 并实际打开目标界面：[首页](../../qa/home-book-icon-2026-09-09.png)、[立体书架抽屉](../../qa/bookshelf-book-icon-2026-09-09.png)、[系统桌面图标](../../qa/launcher-book-icon-2026-09-09.png)。这不是物理手机验收。

本轮未做公网部署、支付、短信、附件云存储、企业报税、iOS 真机或 Android 物理机联调；这些属于明确的剩余风险。

## 本地启动方式

在 `server/` 执行 `npm install`、`npm run dev`。默认仅监听 `127.0.0.1:8787`；数据库位于 `server/data/shared-ledger.sqlite`；可通过 `PORT` 和 `LEDGER_DB_PATH` 指定本地端口、数据库。不要添加 API key 配置。测试使用 `npm run typecheck`、`npm test`、`npm run build`。

Android 使用 `adb reverse tcp:8787 tcp:8787`；客户端默认服务地址 `http://127.0.0.1:8787`，可用 `--dart-define=SHARED_API_BASE_URL=...` 指定地址。HTTP 仅允许本机联调地址，其他地址必须 HTTPS。未进行公网部署、支付、短信或附件云存储。

# 当前开发状态

更新时间：2026-09-10

## 项目定位

当前产品是 Flutter 本地优先记账应用。核心账务使用 Drift/SQLite 持久化；个人账本保持本机私有，家庭/企业账本已支持本地 Node.js 共享后端联调。公网部署、会员支付、短信、附件云存储和企业报税仍不在本轮范围。

## 已完成的本地能力

- 首页、流水、目标、我的四个一级导航及核心页面。
- 手动支出、收入、转账；编辑、分类修正和软删除。
- 交易与账户余额在同一数据库事务内联动。
- 账户、分类、预算、资产/负债汇总和余额校准。
- 目标、里程碑、贡献、调整、排序、预测和完成庆祝。
- 收支趋势、分类构成、消费习惯、热力图和本地洞察。
- 商户分类记忆、指纹去重和账单收件箱。
- Android 支付通知解析与幂等自动记账。
- 设备语音识别和本地规则解析。
- CSV 流水导出。
- 可校验的完整 SQLite 本地备份/恢复；恢复采用安全暂存，应用完全重启后切换数据库。
- 个人、家庭、企业账本的账户、分类、预算、流水、目标和通知目标已按 `bookId` 隔离；schema 8→9 会在迁移前保存副本并校准期初余额。
- 首页已改为暖米白实色细边框卡片；月账单支持年月切换，今日额度与目标独立紧凑展示，账本名从顶部书架抽屉切换。
- schema 9→10 新增共享版本、ID 映射、待同步队列和 SQLite 触发器；本地两端可真实注册、邀请、同步、断网记账、冲突处理和撤权。
- Android 本地联调后端位于 `server/`，使用 Node.js 22、Fastify 5、SQLite/better-sqlite3；会话仅保存在系统安全存储。
- 本轮收尾审计修正交易 Provider、目标 Repository、收件箱和支付通知的账本边界；余额校准及目标贡献写入当前真实操作者，固定通知账本不会随浏览账本切换。
- 书架抽屉已增加真实书本层次：顶部把手、木质层板、书脊、封面内框、高光和投影；桌面 `/Users/algive/Desktop/icon.png` 已复制为 `assets/images/icon.png`，并生成 Android/iOS 启动图标。
- 2026-09-10 抽屉切片 1 已统一账本数量规则：Free 10、Pro 20、Family 50；共享他人账本不占创建额度；预览沿创建顺序展示，活动账本在前三本之外时替换第三位。

## 当前未完成或未联调

- OCR 账单识别和独立账单导入入口。
- 云端 ASR/LLM；当前“AI 记账”实际仍以本地规则解析为主。
- 账号体系、会员购买、支付验签、订单服务和权益刷新。
- 公网云部署、对象存储、家庭短信邀请和企业报税。
- 第三方广告 SDK、后台 placement、Rewarded 和 Splash。
- iOS 真机、签名和发布验收。
- 账本抽屉计划中的书架背景拆分、全部账本搜索管理、新建一体化表单和交易详情尚未完成。

## 当前架构风险

1. 流水、分析和去重仍存在全量加载/内存计算，长期大数据量需要分页和 SQL 聚合。
2. Android Release 未配置正式 keystore，当前产物只能作为本地验收包。
3. 共享服务已完成本地真实联调，尚未进行公网部署、TLS 证书、监控和生产备份验收。
4. 提醒设置仍只有未启用的菜单项；支付、短信、附件云存储和企业报税未接入。
5. Release 构建仍收到 `speech_to_text` 使用 Kotlin Gradle Plugin 的未来兼容性 warning；当前构建成功，后续需等待插件迁移到 Built-in Kotlin。
6. 当前账本创建顺序的兼容排序使用 SQLite `rowid` 作为同时间戳的 tie-breaker；后续若需要跨导入/跨设备保持业务创建序号，应在账本模型中增加显式稳定序号并纳入同步协议。

## 实际验证结果

```text
flutter analyze
→ No issues found

flutter test --reporter expanded
→ All tests passed（120 个）

flutter build apk --release
→ Built build/app/outputs/flutter-apk/app-release.apk（72,799,794 bytes）

server: npm run typecheck && npm test && npm run build
→ typecheck、2 个真实 HTTP 测试、TypeScript build 全部通过
```

当前 APK：`build/app/outputs/flutter-apk/app-release.apk`，72,799,794 bytes，SHA-256：
`ea4762b9b8964bb6ebb015e4f1e79a6c9bad53747059e2dae878bf17d924d81c`。

Android 模拟器 `emulator-5554` 已安装 Release APK 并实际打开首页、顶部书架抽屉：
[首页截图](../../qa/home-book-icon-2026-09-09.png) · [立体书架抽屉截图](../../qa/bookshelf-book-icon-2026-09-09.png) · [系统桌面图标截图](../../qa/launcher-book-icon-2026-09-09.png)。这是本地 Pixel 7 模拟器证据，不是物理手机验收。

测试期间有 Drift Widget 测试重复创建内存数据库的 debug warning，但没有测试失败；后续应统一测试数据库生命周期。

完整备份使用 SQLite 文件并校验核心表与 schema 版本；恢复不会在当前页面强制关闭活动数据库，而是先写入待恢复文件，应用下一次启动数据库连接前完成替换。备份不包含独立文件系统中的附件，且没有加密或密码保护。

## 推荐后续顺序

1. 为共享后端补充部署环境的 TLS、数据库备份、监控和限流验收，再决定公网开放范围。
2. 优化流水和分析的查询边界，再扩展筛选能力。
3. 提供支付、短信、附件存储和企业报税的真实服务端协议后分别接入，继续保持个人账本默认不上云。

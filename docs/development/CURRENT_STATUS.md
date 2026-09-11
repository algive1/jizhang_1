# 当前开发状态

更新时间：2026-09-11

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
- 2026-09-10 抽屉切片 2 已完成可搜索的全部账本管理视图、显式管理入口和一体化新建表单；新建默认个人用途，成功后真实持久化并切换，320dp/1.6 字号回归无布局异常。
- 2026-09-10 抽屉切片 2 已通过 `flutter build apk --debug`，产物为 `build/app/outputs/flutter-apk/app-debug.apk`；本机本次未连接 Android 设备，未虚报安装截图验收。
- 2026-09-10 抽屉切片 3 已新增无内置账本的木质书架背景，并将个人/家庭/企业账本改为独立 Flutter 书本层；QA 预缓存清单同步更新，避免截屏在新素材加载前完成。
- 2026-09-10 抽屉切片 3 已完成全量回归：153 个 Flutter tests、analyze 和 Debug APK 构建均通过；本机仍无 Android 设备，未虚报安装验收。
- 2026-09-10 抽屉切片 3 的 Release APK 已成功构建，且 APK 内确认包含 `bookshelf_empty_background_v1.png`；构建仍有既存 `speech_to_text` KGP 兼容性 warning。
- 2026-09-11 抽屉切片 4 已将首页最近交易改为当前账本数据库限量查询（10 条）、本地日期分组和本地时间显示；保留完整流水给预算/分析统计。
- 2026-09-11 抽屉切片 4 已补充 SQL 级未来流水过滤，确保计划流水不会占用最近 10 条名额。
- 2026-09-11 交易详情切片 5 已统一首页、流水、搜索三个入口：点击进入详情，长按保留操作菜单；详情展示金额、类型、发生时间、账户、分类、备注、记录人和同步状态。
- 2026-09-11 交易详情切片 5 已补齐旧 metadata 附件的图片缩略图/全屏缩放、PDF/其他文件系统打开、无处理器提示、文件缺失提示和重新添加入口；编辑、分类修正和软删除复用既有 Service/权限链路。
- 2026-09-11 阶段二附件切片已将 schema 从 10 升到 11：新增独立 `transaction_attachments` 记录、按账本和交易隔离查询、顺序维护及软删除；旧 `metadata.attachments` 会在升级时迁移，其他 metadata 和 malformed 项保留。
- 2026-09-11 阶段二附件切片已接入新建/编辑记账和交易详情；保存会等待附件加载，附件后处理失败会明确提示“流水已入账”，不隐式重复记账。
- 2026-09-11 阶段二附件切片已通过全量 165 个 Flutter tests、analyze、Drift code generation 和 Release APK 构建；本次 `adb devices` 无连接设备，未安装本次 APK，未虚报 UI 验收。

## 当前未完成或未联调

- OCR 账单识别和独立账单导入入口。
- 云端 ASR/LLM；当前“AI 记账”实际仍以本地规则解析为主。
- 账号体系、会员购买、支付验签、订单服务和权益刷新。
- 公网云部署、对象存储、家庭短信邀请和企业报税。
- 第三方广告 SDK、后台 placement、Rewarded 和 Splash。
- iOS 真机、签名和发布验收；当前 `flutter build ios --no-codesign` 被既有 `Application not configured for iOS` 配置问题阻断。
- 账本抽屉计划中的阶段二仅完成独立附件记录和旧 metadata 迁移；版本化数据库＋附件文件备份、押金/结算、模板以及阶段三同步能力尚未完成。

## 当前架构风险

1. 流水、分析和去重仍存在全量加载/内存计算，长期大数据量需要分页和 SQL 聚合。
2. Android Release 未配置正式 keystore，当前产物只能作为本地验收包。
3. 共享服务已完成本地真实联调，尚未进行公网部署、TLS 证书、监控和生产备份验收。
4. 提醒设置仍只有未启用的菜单项；支付、短信、附件云存储和企业报税未接入。
5. Release 构建仍收到 `speech_to_text` 使用 Kotlin Gradle Plugin 的未来兼容性 warning；当前构建成功，后续需等待插件迁移到 Built-in Kotlin。
6. 当前账本创建顺序的兼容排序使用 SQLite `rowid` 作为同时间戳的 tie-breaker；后续若需要跨导入/跨设备保持业务创建序号，应在账本模型中增加显式稳定序号并纳入同步协议。
7. 交易详情的系统文件打开依赖 Android/iOS 系统处理器；iOS 尚未完成可编译项目配置和真机验证。独立附件记录已完成，但附件文件内容尚未纳入备份/同步。

## 实际验证结果

```text
flutter analyze
→ No issues found

flutter test --reporter compact
→ All tests passed（165 个）

flutter build apk --debug
→ Built build/app/outputs/flutter-apk/app-debug.apk

flutter build apk --release
→ Built build/app/outputs/flutter-apk/app-release.apk（77,656,758 bytes）

server: npm run typecheck && npm test && npm run build
→ typecheck、2 个真实 HTTP 测试、TypeScript build 全部通过
```

当前 APK：`build/app/outputs/flutter-apk/app-release.apk`，77,656,758 bytes，SHA-256：
`ea3a57599c3b5d1d52598bb93ce2eae304d89130676d31b77fdce80b54464de1`。

此前交易详情切片的历史 Release APK 曾在 Pixel 7 Android emulator 安装并打开首页、流水列表和交易详情页；本次阶段二 Release APK 未安装：
[首页截图](../../qa/home-book-icon-2026-09-09.png) · [立体书架抽屉截图](../../qa/bookshelf-book-icon-2026-09-09.png) · [系统桌面图标截图](../../qa/launcher-book-icon-2026-09-09.png)。这是本地 Pixel 7 模拟器证据，不是物理手机验收。
以上三个链接仍是历史版本截图；本次详情页的当前截图保存在本机 `/tmp/jizhang-slice5-release-final.png`，并已在模拟器窗口保持打开供人工查看。

测试期间有 Drift Widget 测试重复创建内存数据库的 debug warning，但没有测试失败；后续应统一测试数据库生命周期。Release 构建另有既存 `speech_to_text` KGP 兼容性 warning，但构建成功。

完整备份使用 SQLite 文件并校验核心表与 schema 版本；恢复不会在当前页面强制关闭活动数据库，而是先写入待恢复文件，应用下一次启动数据库连接前完成替换。备份不包含独立文件系统中的附件，且没有加密或密码保护。

## 推荐后续顺序

1. 为共享后端补充部署环境的 TLS、数据库备份、监控和限流验收，再决定公网开放范围。
2. 优化流水和分析的查询边界，再扩展筛选能力。
3. 提供支付、短信、附件存储和企业报税的真实服务端协议后分别接入，继续保持个人账本默认不上云。

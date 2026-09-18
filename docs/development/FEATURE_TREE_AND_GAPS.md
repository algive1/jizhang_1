# 好好记账 · 功能树与缺口分析

生成时间：2026-09-18  
最后复核：2026-09-18（完成 Android 基线收尾，并复核首页编辑/记一笔/自动记账/诊断日志链路）  
范围：Flutter 客户端（iOS + Android）+ `server/` Node.js 共享后端  
用途：上架前的能力盘点、排期依据与验收清单

> 本文档基于当前工作区源码、`docs/development/` 现有记录和实际代码扫描整理，结论均指向具体文件。
> 未在真机/生产环境验证过的能力，一律不标注为“已完成”。
> **凡与旧文档冲突的结论，以本文档的源码复核结果为准。**

## 0. 阅读说明

状态标记：

| 标记 | 含义 |
| --- | --- |
| ✅ | 已实现：有代码，且在本机测试或构建中有验收记录 |
| 🟡 | 部分实现 / 半成品：主链路可用，但存在明确未收尾部分 |
| 🧪 | 代码完成但未生产联调（缺配置、缺证书、缺公网环境、缺真机） |
| ❌ | 未实现：无对应代码 |

---

## 1. 项目现状速览

| 项 | 当前值 |
| --- | --- |
| 客户端 | Flutter（Riverpod 3 + GoRouter 16 + Drift 2.34 + sqlite3） |
| 后端 | `server/`：Node.js 22 + TypeScript + Fastify 5 + better-sqlite3 + Zod |
| 本地数据库 | SQLite schema **v18**，26 张 Drift 表，13 个 DAO |
| Dart 源文件 | 208 个手写文件（另有 `app_database.g.dart` 生成代码） |
| 路由节点 | 35 个 GoRouter 节点，全部走 `ShellRoute → AppScaffold` |
| 测试 | 88 个 Flutter 测试文件；当前全量基线 406 项通过；另有 Android 规则单测和 11 项服务端测试 |
| 产品形态 | **本地优先**记账 App；个人账本默认不上云，家庭/企业账本走自建后端本地联调 |
| 平台 | Android 可出包（`dist/` 内有 debug/release APK）；**iOS 尚未跑通编译** |

**一句话结论**：本地记账主链路（记账、流水、账户、预算、目标、分析、备份）成熟度最高；
账号体系、云同步、自动记账渠道覆盖、会员支付、iOS 上架合规是主要缺口。

---

## 2. 功能树

### A. 平台与工程基础

- ✅ Flutter 单工程双端（`android/` + `ios/`）
- ✅ 暖米白 + 鼠尾草绿主题，Material 3，中文字体（`lib/app/theme/`）
- ✅ 四个一级 Tab（首页/流水/目标/我的）+ 中央快速记账入口
- ✅ 35 个 GoRouter 路由节点（`lib/app/router/app_router.dart`）
- ✅ Android 图标（自适应/圆形/单色/前景）、暖色启动页、启动海报
- ✅ 本地构建脚本（`scripts/build_install_android.sh`、`build_apk_release.sh`）
- 🟡 iOS 工程存在（`ios/Runner`、Podfile、URL Scheme 已配），但 `flutter build ios --no-codesign`
  被 *Application not configured for iOS* 阻断
- ❌ 深色模式适配与回归
- ❌ 多语言 / i18n（当前仅中文；`currency` 字段存在但无多币种 UI）

### B. 账号与身份 ★重点缺口

- 🟡 **注册**：`POST /api/v1/auth/register`（`server/src/app.ts`）已是真实实现；用户名会 trim + lowercase，格式为 `^[a-z0-9_]{3,40}$`，密码长度 10–128；密码用异步 `scrypt` 加盐哈希，插入前在事务内二次查重，成功返回 `201 + 用户信息 + 30 天会话`，重复用户名返回 `409`，注册接口限流 10 次/分钟。
- 🟡 **登录**：`POST /api/v1/auth/login` 已是真实实现；同样规范化用户名，使用 `scrypt` + `timingSafeEqual` 校验，错误统一返回 401，成功返回新的 30 天会话，登录接口限流 15 次/分钟。
- 🟡 **当前用户 / 登出**：`GET /api/v1/auth/me` 校验当前 Bearer 会话；`POST /api/v1/auth/logout` 删除当前 token 的服务端哈希，客户端随后清理本地身份。
- 🟡 **客户端会话持久化**：`lib/features/sharing/data/session_repository.dart` 使用 `flutter_secure_storage` 保存 token、用户、baseUrl 和过期时间；启动恢复会校验 baseUrl 与过期时间，并将同步操作者切换为当前用户，过期会话会被清除。
- 🟡 **权限边界**：除注册/登录外的共享、会员、诊断接口均从 Bearer 会话取得 user id；服务端不接受客户端传入的操作者身份，账本成员权限在服务端重新校验。
- ❌ **独立账号入口**：客户端登录/注册 UI 仍嵌在“共享账本”页内部（`lib/features/family/presentation/family_page.dart:170-209`），不是全 App 的账号中心；当前个人本地账本不要求登录。
- ❌ **找回密码**（`resetPassword` / `forgotPassword` / `verificationCode` / `sms` 全库 0 命中）：没有找回入口、身份验证、reset token 或失效策略。
- ❌ **修改密码 / 绑定联系方式**：没有改密、手机号、邮箱字段和验证流程；当前 `users` 表仍只有 `id, username, password_hash, created_at`。
- ❌ **短信 / 邮件验证码**：后端没有 SMS / 邮件 provider、发送频控、验证码存储和审计链路。
- ❌ **账号注销与数据删除**（`deleteAccount` / `delete_account` / `deactivate` 0 命中）：没有身份二次确认、会话全部撤销、本地数据处理、共享账本交接和服务端删除/保留策略。
- ❌ 第三方登录（微信 / Apple 登录）、多设备会话管理、登录设备列表、单设备强制下线、游客模式与账号升级引导。

### C. 账本体系

- ✅ 三类账本：personal / family / enterprise
- ✅ 多账本 CRUD、归档删除、至少保留一本、默认账本不可删
- ✅ 书架抽屉（真实书本层次：书脊/封面内框/高光/投影）
- ✅ 账本切换作为核心状态边界
  - 账户、分类、预算、流水、目标、商户记忆、收件箱、通知目标全部按 `bookId` 隔离
- ✅ 账本数量配额：Free 10 / Pro 20 / Family 50（`lib/features/books/data/book_repository.dart:18-20`）
- ✅ “使用主账本资产”开关（`asset_source_book_id`）
- ✅ schema 8→9 迁移前自动备份 + 期初余额校准
- 🟡 家庭/企业共享：邀请（7 天码）、接受、成员管理、撤权、归档、操作日志
- 🟡 共享同步基础：SQLite 触发器 + outbox + `operationId` 幂等 + 版本冲突暂停队列
  （`server/src/store.ts` 的 `changes` / `operations` 表）
- ❌ 共享账本的公网部署、TLS、跨网络可用性
- ❌ 押金/结算、账本模板、版本化数据库 + 附件同步

### D. 记账核心

- ✅ 手动记账：支出 / 收入 / 转账 / **债务**（借入 / 借出 / 还款）
- ✅ 金额计算器表达式（`+ − × ÷`，乘除优先，取整到分，拒绝未输完/除零/负数）
- ✅ 一级分类 5 列网格 + 二级子分类横滑条（`Category.parentId`）
- ✅ 账户 / 报销 / 账本 / 附件 / 图片 / 日期 / 定期付 / 更多 收敛为 chip
- ✅ 键盘常驻 + **再记**（保存后留页连续记账）
- ✅ 交易与账户余额在同一数据库事务内联动
- ✅ 编辑、分类修正、软删除
  - 删除撤销余额影响；存在退款/报销/还款/分期时阻止删除
- ✅ 附件：独立 `transaction_attachments` 表、软删除、顺序维护、旧 metadata 自动迁移
- ✅ 图片缩略图/全屏缩放、PDF 系统打开、失败保留重试
- ✅ 语音记账（`speech_to_text` 设备端识别 + 本地规则解析）
- ✅ AI 记账入口（文本/语音 → 确认页逐笔编辑后保存）
- 🟡 语音 / AI 实际仍以**本地规则**为主；`AiParsingGateway` 只有抽象接口，无实现类
  （`lib/features/voice/domain/transaction_parser.dart:220`）
- 🟡 记账页右上角“编辑”入口未实现（本轮确认不做）
- ❌ **OCR 小票 / 账单识别**（`TransactionSource.ocr` 只是枚举，无 SDK、无截图采集）
- ❌ 账单导入（微信/支付宝账单文件；`source=import` 已预留但无入口）
- ❌ 记账模板 / 常用记账快捷方式

### E. 流水管理

- ✅ 全部 / 支出 / 收入筛选，分类筛选，商户 / 分类 / 备注搜索
- ✅ 交易详情页（金额、类型、时间、账户、分类、备注、记录人、同步状态、附件）
- ✅ 日期分组 + 本地时间显示
- ✅ 首页最近流水数据库限量查询（10 条）+ SQL 级未来流水过滤
- ✅ 统一流水关联：报销 `reimbursement`、退款 `refund`
  - 通过 `related_transaction_id` 关联，原流水只累计状态不复制消费
- 🟡 账单收件箱（分类不确定 / 疑似重复 / 缺账户）
- 🟡 性能：流水、分析、去重仍**全量加载 + 内存计算**，缺分页与 SQL 聚合
- ❌ 批量操作（批量分类 / 批量删除）
- ❌ 高级筛选（金额区间、账户、标签、来源、自定义时间）

### F. 账户与资产

- ✅ 账户 CRUD、归档恢复、拖拽排序、余额校准
- ✅ 资产总览：按币种资产 / 负债 / 净资产、资金形式分类
- ✅ 账户详情页、资产负债区、资产变化趋势
- ✅ 资产趋势会员访问控制
- ✅ 账户类型含 `cash / wechat / alipay / debitCard / creditCard / other / liability`
- ✅ 投资买入 / 卖出与账户余额联动（按资产转换处理）
  - `_mirrorTrade` 写入主流水 `assetPurchase`（买入，出资账户减少）与
    `assetSale`（卖出，账户回补）；未填出资账户或账户已不存在时不联动
- ✅ 投资市值计入资产总览净资产
  - `AssetOverview.investmentValue` 计入 `assets` / `netAssets`，
    并归入 `AssetForm.investment`；首页资产卡与资产总览共用同一口径

### G. 分类 / 预算 / 目标

- ✅ 分类：支出 / 收入、一级 / 二级、新增、编辑、排序、隐藏
- ✅ 行业模板：个人 / 家庭 / 企业（`lib/core/database/category_templates.dart`）
- ✅ 预算：月度总预算、分类预算、使用率、日均可用、安全可花
  （`lib/features/budgets/domain/safe_to_spend_service.dart`）
- ✅ 目标：创建、编辑、里程碑、存入 / 取出 / 调整、排序、预测、完成庆祝
- ✅ **新建目标排序为“追加”**：`create` 取当前账本最大 `sortOrder + 1`，
  不会默认 0 抢占首页首位（`lib/features/goals/data/goal_repository.dart` 的 `nextSortOrder`）
- ✅ **旧账本分类模板补齐**：`_upgradeCategoryTemplate` 不再以 `expense-food` 为 marker 提前返回，
  始终执行 `_seedCategories` 补插缺失模板项（含 `expense-payroll`）
  （`lib/core/database/database_seeder.dart`）
- ❌ 预算超额预警通知

### H. 分析与报表

- ✅ 收支分析页：周期 / 币种切换、现金流、分类构成、消费习惯、洞察
- ✅ 收支趋势、分类构成、热力图、本地洞察
- ✅ 消费日历（月历日金额、当日流水）
- ✅ 首页月账单年月选择（支持跨年 / 闰年，禁止未来月份）
- ❌ 自定义报表导出（PDF / 图片分享）
- ❌ 年度报告 / 财务体检
- ❌ 多账本合并分析

### I. 财务扩展

- ✅ 报销管理（待报销 / 已报销汇总、关联回款）
- ✅ 退款（编辑 / 撤销，原子恢复原消费状态与账户余额）
- ✅ 周期账单（周期配置、到期自动记账、暂停 / 结束、提醒）
- ✅ 信用卡分期（计划、详情、每期还款登记、按还款日批量执行）
- 🟡 投资管理 MVP：股票 / 基金 / 债券 / 虚拟币四类
  - 总览 / 持仓 / 详情 / 添加 / 交易记录，schema 17→18 新增 4 张表
- 🟡 投资行情走 `MockMarketDataProvider` + `MemoryQuoteCache`（**未接真实行情**）
  - `RedisQuoteCache` 只有接口占位，无 Redis 客户端实现
- 🟡 投资快照为“当天首次打开懒写入”，无后台定时任务
- 🟡 分红 / 利息只写投资成交记录，未生成主流水（现金到账但账户余额不变）
- ❌ 企业报税 / 发票管理
- ❌ 借贷账单管理

### J. 自动化与智能

- ✅ Android 支付通知监听（`PaymentNotificationListenerService.kt`）
- ✅ **通知监听支持微信、支付宝、云闪付和美团包名**；收款/到账/退款等入账通知会被拒绝
- 🟡 **无障碍页面识别支持四类付款应用**：微信沿用专用规则，支付宝/云闪付/美团使用保守的通用规则；真实 App 版本仍需真机样本补规则
- ❌ 京东 / 拼多多 / 抖音尚未接入，避免在没有稳定页面字段前误记账
- ✅ 悬浮卡片已提供「去确认」入口，跳转 `/profile/autobookkeeping/confirm`
  （`.../autobookkeeping/overlay/AutoBillOverlayService.kt:72`、`:113`）
- ✅ 两条路径统一为**识别 → 本地待确认队列 → 悬浮层/系统通知 → 用户确认后保存**；
  通知路径不再直接 `bookkeeping.save`，无目标账户或解析不确定时保留待处理
- ✅ 商户分类记忆（`merchant_rule_repository.dart`）、指纹去重、账单收件箱
- ✅ Android `AlarmManager` 每日后台 Flutter isolate
  - 处理周期账单 + 分期到期，使用稳定 ID 幂等
- ❌ iOS 后台调度（仅“回前台补齐”策略）
- ❌ 本地 OCR 兜底
- ❌ AI fallback gateway（无 endpoint / 模型 / 额度 / strict schema 落地）

### K. 会员与商业化

- ✅ 会员 catalog：月 / 季 / 年三档 + 8 项权益 + FAQ
  - `server/src/membership_catalog.ts`，由 `assets/config/membership_catalog.json` 驱动
- ✅ 权益项：自动记账、账本数、统计、云同步、资产、导出、主题、客服、分类、去广告
- ✅ 订单：创建 / 查询 / 我的订单 / 当前会员状态
- 🧪 微信 + 支付宝 APP 下单（RSA 签名 + 回调验签 + AES-GCM 解密），`server/src/payment.ts`
- ✅ 服务端订单 → 会员购买自动记账（`orderId` 幂等，稳定哈希生成流水 ID）
- ✅ 会员管理后台 API：`PUT /api/v1/admin/membership/catalog`
  - 需要 `MEMBERSHIP_ADMIN_TOKEN`（≥32 位）
- 🧪 真实商户号 / 证书 / 公网 HTTPS 回调未配置 → **真实扣款未联调**
- ❌ **Apple IAP 完全未接入** → iOS 上架硬阻断
  （Apple 3.1.1：虚拟会员必须走 IAP，不能用微信/支付宝）
- ❌ 自动续费 / 到期降级 / 退款权益回收链路未验收
- ❌ 会员管理没有图形后台（只有 API + token）
- ❌ 优惠券 / 兑换码 / 邀请返利
- ❌ 广告：`lib/features/ads/domain/ad_provider.dart` 是 `UnconfiguredAdProvider` 全 stub
  - `PlacementPolicy` 策略层已写，但无 SDK、无后台 placement、无 Rewarded / Splash

### L. 数据 / 安全 / 备份

- ✅ CSV 流水导出（不含已删除）
- ✅ 完整 SQLite 备份 + 校验 + 恢复（安全暂存，重启后切换数据库）
- ✅ 金额隐私掩码（`lib/core/widgets/privacy_amount.dart`，多页复用）
- 🟡 备份**不含附件文件**、**不加密**、无密码保护
- 🟡 恢复需重启应用
- ❌ 附件云存储 / 附件同步
- ❌ 应用锁 / 生物识别
- ❌ 本地数据库加密
- ❌ 数据删除权（配合账号注销）

### M. 通知与消息

- ✅ 支付通知记账页（通知权限状态、开关、待处理队列）
- ✅ 周期账单到期通知（`RecurringBillNotificationScheduler`）
- ✅ 交易通知目标卡（`notification_target_card.dart`）
- ❌ **后端更新通知 / 强制更新 / 版本检查**
  （`appVersion` / `forceUpdate` / `checkUpdate` / `announcement` / `remoteConfig` 全库 0 命中）
- ❌ 公告 / 站内信 / 消息中心
- ❌ 推送通道（无 FCM / APNs / 极光 / 厂商推送 SDK）
- 🟡 “提醒设置”菜单项实际指向支付通知页（`profile_page.dart:312`），语义错误且未真正启用

### N. 设置与帮助

- ✅ 我的页入口：会员、家庭、数据、通知、资产、分类、预算、周期账单、分期、自动记账、投资
- ✅ 设置 BottomSheet：信用卡分期 / 提醒设置 / 自动记账 / 数据与安全
- 🟡 使用手册 = 静态弹窗文案
- 🟡 反馈建议 = 静态弹窗（“当前版本尚未接入在线反馈提交”）
- 🟡 关于页 = 静态文案（版本号硬编码）
- ❌ 在线客服 / 工单
- ❌ 用户协议 / 隐私政策页面
  （`privacy` 关键词命中全部是金额掩码，非隐私政策）

### O. 后端与运维

- ✅ Fastify 服务、Zod 严格校验、统一错误处理
- ✅ 限流：全局 300/min，注册 10/min，登录 15/min
- ✅ 幂等 `operations` 表、`changes` 游标、版本冲突检测、操作日志
- ✅ 共享协议 schema 校验（`server/src/contract.ts`）
- ✅ 3 个后端测试（`assistant_policy` / `payment` / `sharing`）
- 🟡 仅本地 `127.0.0.1:8787`，未部署
- ❌ TLS / 域名 / 反向代理
- ❌ 生产数据库备份 / 监控 / 告警
- ❌ 删除墓碑 / 审计日志留存策略
- ❌ 管理后台

### P. 上架与发布

- ✅ Android release APK 可构建（`dist/jizhang_app-1.0.0+1-release.apk`；2026-09-18 已安装到实体设备）
- 🟡 当前 release 使用 debug key 签名
- ❌ **正式 keystore / `android/key.properties`**
- ❌ iOS 签名 / Bundle ID / Development Team（pbxproj 内为 `com.algive.jizhangApp`）
- ❌ iOS Privacy Manifest（`PrivacyInfo.xcprivacy`）
- ❌ 应用商店素材（截图、描述、关键词、隐私标签）
- 🟡 诊断日志 / 埋点（已有本地脱敏环形队列和服务端批量幂等上传；无 Crashlytics / Sentry / Firebase）
- ❌ 应用商店隐私合规清单（数据收集声明）
- ❌ 国内商店合规材料（软著、备案等）

---

## 3. 缺口分析

### 3.1 P0 上架阻断项（不做就提交不了）

| # | 缺口 | 现状证据 | 影响 |
| --- | --- | --- | --- |
| 1 | **账号注销** | `deleteAccount` / `delete_account` / `deactivate` 全库 0 命中 | Apple 5.1.1(v)：有账号创建就必须提供账号删除，**必被驳回** |
| 2 | **隐私政策 + 用户协议** | 无页面、无首次同意弹窗、无 `consent` 逻辑 | Apple / Google / 国内商店均强制 |
| 3 | **Apple IAP** | `payment.ts` 只有 wechat / alipay；无 StoreKit | iOS 卖虚拟会员必须走 IAP，用微信支付宝**必被驳回** |
| 4 | **iOS 跑通编译** | `flutter build ios` 被 *Application not configured for iOS* 阻断 | iOS 无法出包 |
| 5 | **正式 keystore** | README 明确“上架前必须配置 `android/key.properties`” | 现有产物无法提审 |
| 6 | **后端公网部署 + HTTPS** | 仅 `127.0.0.1:8787`，无域名/TLS | 云端同步、支付回调、版本通知全部无法工作 |

### 3.2 P1 明确要求但缺失或仅为半成品

#### （1）注册登录 —— 已有可用基础，但仍是“共享账本的附属功能”

- 已完成：服务端真实注册、登录、当前用户、登出；密码不明文存储，token 服务端只保存 SHA-256 哈希；共享接口从会话取得 user id，并在账本成员权限层再次校验。
- 已完成：客户端 `SessionRepository` 的安全存储、baseUrl/过期时间校验、当前同步操作者切换；服务端共享测试覆盖注册、错误登录、登出后 `/auth/me` 返回 401。
- 当前入口：`/profile/family` 页面内的用户名/密码表单，可在“登录”和“创建新账号”之间切换；注册成功后立即建立会话并继续同步共享账本。
- 仍缺：全 App 独立账号中心、账号资料页、手机号/邮箱注册、验证码、游客模式、登录态全局引导、多设备会话管理。
- 架构判断：`SessionRepository` 放在 `lib/features/sharing/` 下与当前功能边界一致，但如果后续个人账本也支持云备份/同步，应先把它提升到 `lib/core/auth/` 或独立 `features/auth/`，避免再复制登录状态管理。

#### （2）找回密码 —— 完全没有

`resetPassword` / `forgotPassword` / `verificationCode` / `sms` 全库 0 命中。需补齐的整条链路：

1. `users` 表增加 `phone` / `email` 字段（当前只有 `username`）
2. 验证码表 / reset token 表（当前没有）
3. SMS 或邮件服务商接入（后端无任何相关依赖）
4. 客户端“忘记密码 → 验证 → 重置”三个页面
5. 频控与防刷（现有仅全局 rate-limit）

#### （3）云端数据同步 —— 只覆盖“共享账本”，个人账本不上云

- 现状：个人账本**本地优先、默认不上云**（`docs/development/PRODUCT_LOGIC.md` 明确的产品决策）；
  只有 family / enterprise 账本走自建后端
- 缺：个人账本跨设备同步、换机迁移、附件同步、云端备份
- 缺：对象存储（无 OSS / S3 / COS 接入）
- 缺：完整的多设备双向增量同步 UI（有冲突队列基础，无完整冲突解决页）
- ⚠️ 另注：共享后端是**单机 SQLite**，多实例部署 / 并发写 / 水平扩展均无设计

#### （4）自动记账渠道覆盖 —— 远低于预期

| 渠道 | 通知监听 | 无障碍页面识别 | 解析器 |
| --- | --- | --- | --- |
| 微信 `com.tencent.mm` | ✅ | ✅ | ✅ `WeChatPaymentParser` |
| 支付宝 `com.eg.android.AlipayGphone` | ✅ | 🟡 保守通用规则，待真机样本校准 | 🟡 `PaymentAppParser` |
| 云闪付 `com.unionpay` | ✅ | 🟡 保守通用规则，待真机样本校准 | 🟡 `PaymentAppParser` |
| **美团**（含外卖包名） | ✅ | 🟡 保守通用规则，待真机样本校准 | 🟡 `PaymentAppParser` |
| **京东** | ❌ | ❌ | ❌ |
| **拼多多** | ❌ | ❌ | ❌ |
| **抖音** | ❌ | ❌ | ❌ |

证据：

- `PaymentNotificationListenerService.kt` 当前接收微信、支付宝、云闪付和两个美团包名；入账类关键词先过滤
- `PaymentSceneDetector.kt` 对微信使用专用解析器，其余支持包名进入 `PaymentAppParser.kt`
- 通知和无障碍两条路径共用 `AutoBookkeepingPendingStore`；保存前必须经过确认页

`docs/development/2026-09-14-cross-platform-autobookkeeping-assessment.md` 仍然有效：
平台需要真机样本才能建规则。当前第一版已完成“无障碍/通知 → 本地保守解析 → 悬浮层或系统通知 → 确认页”，
但支付宝、云闪付、美团的不同版本仍需真机样本补充规则；本轮已在实体设备安装 APK，但尚未采集各支付 App 的有效样本。

**必须一起解决的一致性问题：**

1. 通知路径已改为待确认，不再直接自动保存；队列去重使用订单号或“包名 + 金额 + 商户 + 分钟”指纹
2. **iOS 根本不存在这套方案**（系统不开放跨 App 无障碍 / 通知读取），iOS 端必须另做方案

#### （5）会员开通与管理 —— 骨架完整，缺四块

- 已有：catalog（月/季/年）、权益、订单、微信/支付宝签名与回调验签、订单幂等回写流水、admin catalog API
- 缺 ①：真实商户配置 + 公网 HTTPS 回调 → 真实扣款未验收
- 缺 ②：**Apple IAP**（见 P0）
- 缺 ③：到期 / 续费 / 自动续费 / 退款回收 / 权益降级全链路未验证
- 缺 ④：**会员管理没有图形后台**，只有需要 `MEMBERSHIP_ADMIN_TOKEN` 的 API

#### （6）后端更新通知 —— 完全没有

需要从零建设：

- 版本检查接口（如 `/api/v1/app/version`）+ 强制 / 可选更新策略
- 公告 / 站内信 / 消息中心
- **推送通道**：Android FCM 或厂商推送、iOS APNs（当前无任何推送 SDK）
- 客户端更新弹窗、公告页、消息红点

### 3.3 P2 该有但现在没有的（产品完整性）

| # | 缺口 | 说明 |
| --- | --- | --- |
| 1 | 第三方崩溃平台 | 已有本地脱敏诊断环形队列和服务端上传接口；Crashlytics / Sentry / Firebase 尚未接入 |
| 2 | 在线客服 / 反馈工单 | 现为静态弹窗，无提交入口 |
| 3 | OCR 识别 | 小票 / 账单拍照记账；枚举已留、实现为零 |
| 4 | 账单导入 | 微信/支付宝 CSV 导入；`source=import` 已留、入口为零 |
| 5 | 个人账本云备份 | 现仅本地文件备份，不含附件、不加密 |
| 6 | 应用锁 / 生物识别 / 数据库加密 | 记账 App 标配 |
| 7 | 分页与 SQL 聚合 | `CURRENT_STATUS.md` 自列为架构风险 1 |
| 8 | iOS Privacy Manifest + 隐私标签 | Info.plist 已有相机/相册/麦克风说明，但 Store 隐私标签未做 |
| 9 | 附件云存储 + 附件纳入备份 | 附件仅落本地文件系统 |
| 10 | 无障碍 / 动态字号全面回归 | 现有 320dp × 1.6 回归仅覆盖部分页面 |
| 11 | 年度报告 / 财务体检 / 分享图 | 无 |
| 12 | 企业报税 / 发票管理 | 无 |
| 13 | 多币种 UI | `currency` 字段已有，UI 未做 |
| 14 | 管理后台 | 会员、公告、placement、用户、订单、风控均无 |

### 3.4 P3 半成品收尾清单（代码在，但没闭环）

| 项 | 现状 |
| --- | --- |
| 会员页测试 | 本轮会员页已完成入口文案与返回按钮修正；全量 Flutter 回归以当前工作区为准，若再次出现 `pumpAndSettle` 超时需单独处理 |
| 提醒设置 | 菜单项仍指向 `/profile/payment-notifications`，周期账单提醒实际入口另在周期账单页 |
| 记一笔右上角“编辑” | 未实现（本轮确认不做） |
| 投资 | Mock 行情与 Redis 占位仍待补；账户联动与净资产口径已完成。分红/利息未生成主流水，待确认 |
| 广告 | `UnconfiguredAdProvider` 全 stub；无 SDK / 无后台 placement / Rewarded / Splash |
| AI | `AiParsingGateway` 只有抽象接口，无实现类、无额度服务、无 strict schema 落地 |
| `speech_to_text` | Kotlin Gradle Plugin 未来兼容性 warning |
| 共享服务端 | 单机 SQLite；已有诊断事件表和幂等上传接口，但无 TLS / 备份 / 监控 / 多实例 |

---

### 3.5 本轮已完成并待真机验收的 Android 收尾

- ✅ 首页长按编辑流水使用透明 modal barrier，不再把底部导航栏露到「记一笔」页面；同一修正覆盖流水详情和复制流水入口。
- ✅ 备注输入固定为紧凑单行 40dp，不再被动作按钮撑开详情卡片；编辑已有周期流水时会读取关联周期规则，`定期付` 可继续打开并保存周期规则。
- ✅ Android 自动记账统一为“通知/无障碍识别 → 本地待确认队列 → 悬浮层或系统通知 → 用户确认后保存”；已覆盖微信、支付宝、云闪付和美团包名，入账/退款通知、金额歧义和重复指纹会被拦截。
- 🧪 支付宝、云闪付、美团的通用无障碍解析器已完成保守规则和单测，但不同 App 版本、系统权限、浮窗权限、进程被杀后的行为仍需实体 Android 真机样本验收。
- ✅ 已增加本地脱敏诊断环形队列（最多 200 条）、应用/生命周期/记账成功失败/通知处理事件和服务端批量幂等上传接口；第三方 Crashlytics/Sentry 尚未接入。

---

## 4. 建议补齐顺序

### 第 1 阶段：上架必须（决定能不能提交）

1. 账号体系独立化：先抽出独立登录/注册入口，再补账号资料、改密、手机号/邮箱验证、**找回密码** 和 **账号注销**
   - Slice 1：把现有 `SessionRepository` 提升到账号层，补登录态全局入口和错误/过期引导
   - Slice 2：服务端 `users` 表扩字段，新增验证码 / reset token 表、SMS / 邮件 provider、频控和审计
   - Slice 3：实现注销前确认、撤销全部会话、本地数据处理、共享账本交接和服务端删除/保留策略
2. 隐私政策、用户协议、首次启动同意弹窗、个人信息收集清单
3. **Apple IAP** 接入（iOS 会员唯一合规路径）
4. iOS 编译跑通 + 签名 + Privacy Manifest
5. Android 正式 keystore
6. 后端公网部署：TLS + 域名 + 数据库备份 + 监控

### 第 2 阶段：核心承诺兑现

7. 自动记账补齐
   - 当前已完成微信、支付宝、云闪付、美团的保守识别与统一待确认队列
   - 下一步用真机通知/页面样本补齐各版本规则，并验收悬浮层、系统通知、权限和后台存活
   - 再评估京东 / 拼多多 / 抖音等渠道，不在没有样本时猜规则
8. 补 iOS 自动记账替代方案（账单导入 + 邮件 / 文件解析）
9. 云端同步扩展：个人账本可选上云 + 附件对象存储 + 换机迁移
10. 版本更新 / 公告 / 推送（后端更新通知）

### 第 3 阶段：体验与工程

11. 修会员页测试（先重新定位根因）+ 清理 P3 收尾清单
12. 第三方崩溃平台接入（当前已有本地脱敏诊断日志和自建服务端上传）
13. 分页 / SQL 聚合 + 附件纳入备份 + 备份加密
14. OCR / AI Gateway / 账单导入 / 投资真实行情
15. 清理文档不一致（见 5. 决策记录）

---

## 5. 已确认决策（2026-09-17）

| # | 议题 | 结论 | 状态 |
| --- | --- | --- | --- |
| 1 | Free 账本数量上限 | **10 个**（Pro 20 / Family 50）。早期草案的 3 已废弃，以代码 `BookLimitPolicy` 为准 | ✅ 已确认；`PRODUCT_LOGIC.md` 表格已同步修正 |
| 2 | 新建目标排序 | **追加**：取当前账本最大 `sortOrder + 1`，不抢占首页首位 | ✅ 代码已按此实现，无需改动 |
| 3 | 投资买入与账户余额 | **已联动**：按「资产转换」处理（资金账户减少、投资资产增加），**不计入消费支出** | ✅ 2026-09-17 已实施 |
| 4 | 投资资产与净资产 | **已计入**资产总览净资产 | ✅ 2026-09-17 已实施 |
| 5 | 历史审计结论 | 2026-09-10 审计提出的“目标排序”“企业模板补齐”问题**均已修复**，本文档已相应更正 | ✅ 已复核 |
| 6 | 注册登录边界（2026-09-18） | 当前只为共享账本提供用户名/密码注册登录；个人本地账本不强制登录。注册、登录、`/auth/me`、登出与安全会话已实现；找回密码、改密、联系方式绑定、注销、第三方登录和多设备会话暂不宣称完成 | ✅ 已按源码与服务端测试复核 |

> 3、4 两项已一并完成：买入既不算消费，也不会让资金凭空消失。
> 遗留：分红 / 利息尚未生成主流水；存量持仓不回溯补写（只对改动生效后的新成交联动）。

### 5.1 投资与账务联动口径

| 投资动作 | 主流水类型 | 账户余额方向 | 计入消费 | 计入收入 |
| --- | --- | --- | --- | --- |
| 买入 | `assetPurchase` | 出资账户 − | 否 | 否 |
| 卖出 | `assetSale` | 出资账户 + | 否 | 否 |
| 分红 / 利息 | 不生成（遗留） | 不变 | 否 | 否 |

- 流水 id 为 `investment-mirror-<投资成交 id>`，重试不会重复入账。
- 统计口径：首页月支出与消费日历改用 `isConsumptionExpense`（消费支出且非资产转换）。
- 净资产口径：账户余额 + 投资市值，因此买卖前后净资产不变。

---

## 6. 需要特别提醒的三个高风险点

1. **iOS 上架的三个隐藏雷**
   - Apple IAP（虚拟会员必须走 IAP）
   - 账号注销（有注册就必须能注销）
   - Sign in with Apple（只有未来提供第三方登录，如微信登录时，才需要按平台规则同步规划）
   - 这三个都属于“写了功能反而更容易被驳回”的类型，必须在设计阶段就一起规划。

2. **自动记账在 iOS 上无法对等实现**
   - 这是平台限制，不是工程量问题。
   - 建议 iOS 端产品预期与 Android 主动拉开（iOS 走账单导入 + 手动 + 语音/AI），
     否则会做出永远无法交付的承诺。

3. **文档与代码口径必须统一**
   - 历史上已出现 Free 账本数（文档 3 / 代码 10）不一致，本次已修正。
   - 会员权益、额度、账本上限等对外承诺一旦写进商店描述，就受平台和用户约束。

---

## 7. 关键文件索引

| 主题 | 文件 |
| --- | --- |
| 路由与页面节点 | `lib/app/router/app_router.dart` |
| 后端 API（鉴权/共享/邀请） | `server/src/app.ts` |
| 注册登录与会话 | `server/src/app.ts`、`lib/features/sharing/data/session_repository.dart`、`lib/features/family/presentation/family_page.dart` |
| 后端共享协议 schema | `server/src/contract.ts` |
| 后端存储与冲突处理 | `server/src/store.ts` |
| 会员 catalog | `server/src/membership_catalog.ts`、`assets/config/membership_catalog.json` |
| 支付下单与回调验签 | `server/src/payment.ts` |
| 客户端会话 | `lib/features/sharing/data/session_repository.dart` |
| 登录 / 注册 UI | `lib/features/family/presentation/family_page.dart` |
| 账本配额 | `lib/features/books/data/book_repository.dart` |
| 目标排序 | `lib/features/goals/data/goal_repository.dart` |
| 分类模板与补齐 | `lib/core/database/database_seeder.dart`、`lib/core/database/category_templates.dart` |
| 投资持仓与成交 / 账务联动 | `lib/features/investments/data/investment_repository.dart` |
| 净资产口径 | `lib/features/accounts/domain/asset_overview.dart` |
| 资产转换判定 | `lib/core/models/transaction_record.dart` |
| 首页资产卡 | `lib/features/home/presentation/home_asset_card.dart` |
| 支付通知监听（原生） | `android/app/src/main/kotlin/com/algive/jizhang_app/PaymentNotificationListenerService.kt` |
| 无障碍自动记账（原生） | `android/app/src/main/kotlin/com/algive/jizhang_app/autobookkeeping/` |
| 自动记账规则 | `.../autobookkeeping/rules/PaymentRule.kt` |
| 微信解析器 | `.../autobookkeeping/parser/WeChatPaymentParser.kt` |
| 场景识别（微信专用 + 其他付款应用通用规则） | `.../autobookkeeping/detector/PaymentSceneDetector.kt`、`.../autobookkeeping/parser/PaymentAppParser.kt` |
| 悬浮确认入口 | `.../autobookkeeping/overlay/AutoBillOverlayService.kt` |
| 通知解析与待确认队列 | `lib/features/notifications/application/payment_notification_service.dart`、`lib/features/autobookkeeping/auto_bookkeeping_pending.dart` |
| 本地诊断日志与上传 | `lib/core/diagnostics/operation_log.dart`、`server/src/diagnostics.ts` |
| 广告桩实现 | `lib/features/ads/domain/ad_provider.dart` |
| AI 解析接口 | `lib/features/voice/domain/transaction_parser.dart` |
| 当前开发状态 | `docs/development/CURRENT_STATUS.md` |
| 产品逻辑 | `docs/development/PRODUCT_LOGIC.md` |
| 多平台自动记账评估 | `docs/development/2026-09-14-cross-platform-autobookkeeping-assessment.md` |
| 本轮 Android 自动记账与诊断日志 | `docs/development/2026-09-18-android-autobookkeeping-diagnostics.md` |
| 架构全景 | `docs/development/ARCHITECTURE.md` |

---

## 8. 维护说明

- 本文件随功能迭代更新，建议在每个里程碑收尾时同步刷新。
- 状态标记以“有代码 + 有测试或构建验收记录”为准，**不以计划或设计稿为准**。
- 未在真机 / 生产环境验证的能力，一律使用 🧪 标记，不得标为 ✅。
- **旧审计文档的“发现”不等于当前状态**：2026-09-10 审计提出的两项问题在本轮复核时已确认修复，
  引用旧文档结论前必须回到源码确认。
- 决策 3、4 的实施细节见 [`2026-09-17-investment-ledger-linkage.md`](2026-09-17-investment-ledger-linkage.md)。

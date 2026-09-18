# Android 自动记账与诊断日志收尾

日期：2026-09-18  
范围：Android 首页编辑入口、记一笔页面、周期账单、通知/无障碍自动记账、诊断日志

## 本轮结论

### 页面问题

- 首页长按编辑流水、流水详情编辑和复制流水使用的底部 modal 已改为透明 barrier，避免 `AppBottomNavigation` 透出到「记一笔」页面。
- 备注行改为固定 40dp 的单行输入，输入框不再被右侧编辑动作撑高，详情卡片保持紧凑。
- 编辑已有周期流水时，读取流水 metadata 中的 `recurring_bill_id`，加载关联的周期规则；点击「定期付」可以打开规则页，保存时同步更新原周期账单和通知。

### 自动记账

统一链路为：

```text
Android 通知 / 无障碍页面
  → 保守解析
  → 本地待确认队列
  → 悬浮层或系统通知/Toast 提示
  → 用户确认
  → QuickBookkeepingService 事务保存
```

- 已接入包名：微信、支付宝、云闪付、美团（含美团外卖包名）。
- 微信继续使用专用解析器；其他应用使用 `PaymentAppParser`，要求明确成功标识、唯一金额和商户信息，不在多金额通知中猜测。
- 收款、到账、转入、入账、退款、退回等入账类通知直接拒绝，不会被当作支出。
- 通知和无障碍路径共用 `AutoBookkeepingPendingStore`；订单号优先，缺少订单号时使用包名、金额、商户和分钟粒度时间组成指纹，避免重复入账。
- 美团不默认猜测付款账户，必须由用户配置目标账户后进入待确认流程。
- 浮窗服务不可用时，原生层退回系统通知和 Toast；通知权限受限时仍保留 Toast。真实系统浮窗/通知表现需要真机验收。

### 诊断日志

- Flutter 侧新增本地脱敏环形队列，最多保留 200 条事件，记录应用启动、生命周期、记账成功/失败、通知处理结果等事件。
- 诊断数据只保留有限 primitive 字段，过滤 token、密码、通知正文、账户、卡号、手机号、路径、堆栈等敏感键；崩溃处理器只上传错误类型和页面，不上传堆栈或原始通知文本。
- 服务端新增 `POST /api/v1/diagnostics/events`，要求已登录用户，支持 1～200 条批量事件，按用户和 `event_id` 幂等，重复事件不会重复入库。
- 「自动记账运行日志」页面可查看本地待上传数量，并在已登录共享服务时手动上传。
- 当前是自建诊断事件链路，尚未接入 Crashlytics、Sentry 或 Firebase，也没有声明已具备公网生产监控能力。

## 涉及文件

- `lib/features/bookkeeping/presentation/quick_add_sheet.dart`
- `lib/features/transactions/presentation/transaction_actions.dart`
- `lib/features/transactions/presentation/transaction_detail_page.dart`
- `lib/features/notifications/application/payment_notification_service.dart`
- `android/app/src/main/kotlin/com/algive/jizhang_app/PaymentNotificationListenerService.kt`
- `android/app/src/main/kotlin/com/algive/jizhang_app/autobookkeeping/`
- `lib/core/diagnostics/operation_log.dart`
- `server/src/diagnostics.ts`

## 验证记录

```text
flutter analyze
→ No issues found

flutter test --reporter compact
→ All tests passed（408 项）

Android：./gradlew :app:testDebugUnitTest :app:lintDebug
→ BUILD SUCCESSFUL；应用模块 lint 无 error

server：npm run typecheck && npm test && npm run build
→ typecheck、11 项测试、TypeScript build 全部通过
```

本机没有连接 Android 实体设备（`adb devices` 无设备），因此尚未验证具体微信/支付宝/云闪付/美团版本的通知文案、无障碍节点、悬浮窗授权、后台进程存活及系统通知展示。下一步应先收集真机样本，再补规则 fixture 和端到端验收。


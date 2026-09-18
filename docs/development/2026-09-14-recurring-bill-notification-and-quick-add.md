# 周期账单系统通知与“记一笔”快捷创建交接

日期：2026-09-14

## 需求结果

已按确认方案完成 Android/iOS 系统通知接入，并将“记一笔”中的“定期付”改为周期规则快捷配置：

- 记一笔点击“定期付”后打开新增周期账单的同款“重复规则”卡片；
- 快捷模式只展示周期、频率、日期、起止方式，以及“自动记账”“扣款提醒”和提醒时间；
- 金额、收支类型、分类、扣款账户、子分类由记一笔页面直接带入，不再重复填写；
- 保存记一笔时仍通过现有 `RecurringBillExecutionService.createWithInitial` 同时写入首笔流水和周期计划；
- 自动记账仍由既有每日调度负责，系统通知只负责提醒，不会重复记账；
- 点击系统通知进入 `/profile/recurring-bills?billId=...`，页面加载完成后自动打开对应周期账单详情；
- 详情页保留“确认本期入账”入口，未到扣款日时显示但禁用，到期后可确认入账。

## 调度链路

```text
创建/编辑/恢复周期账单
  → Flutter 计算下一次提醒时间（扣款日 09:00 - reminderDays）
  → Android AlarmManager / iOS UNUserNotificationCenter
  → 系统通知点击
  → 原生携带 open_route
  → Flutter navigation channel
  → 周期账单列表定位并打开详情
```

Flutter 端的 `RecurringBillNotificationScheduler` 负责统一日期计算和通知参数。前台使用 `jizhang/recurring_notifications`，Android 每日后台任务复用 `jizhang/finance_scheduler`，但使用独立的 `scheduleReminder/cancelReminder` 方法，避免和已有自动记账完成回执混用。

Android 使用 `AlarmManager.setAndAllowWhileIdle` 调度一次性提醒，设备重启后 `FinanceSchedulerReceiver` 会立即触发一次同步；iOS 使用不可重复的 `UNCalendarNotificationTrigger`，应用前台启动/恢复时重新同步下一次提醒。

## 主要修改文件

- `lib/features/recurring/application/recurring_bill_notification_service.dart`：统一提醒时间、路由和前后台 MethodChannel 命令。
- `lib/main.dart`、`lib/app/app.dart`：后台每日调度、应用启动和恢复时同步所有账本的提醒，并清理已结束/归档计划的旧提醒。
- `lib/features/bookkeeping/presentation/quick_add_sheet.dart`：定期付快捷配置及保存后的通知同步。
- `lib/features/recurring/presentation/recurring_bill_create_sheet.dart`：增加 `rulesOnly` 模式，复用原型卡片。
- `lib/features/recurring/presentation/recurring_bills_page.dart`、`lib/app/router/app_router.dart`：通知点击定位详情、详情确认入口及保存/暂停/结束后的提醒同步。
- `android/app/src/main/kotlin/com/algive/jizhang_app/RecurringBillNotificationScheduler.kt`、`RecurringBillNotificationReceiver.kt`：Android 通知调度和点击承接。
- `android/app/src/main/kotlin/com/algive/jizhang_app/MainActivity.kt`、`FinanceSchedulerReceiver.kt`、`AndroidManifest.xml`：原生通道、后台命令、权限和 receiver 注册。
- `ios/Runner/AppDelegate.swift`：通知权限、日历触发器、前台展示和点击路由。
- `test/recurring_bill_notification_test.dart`、`test/quick_add_redesign_test.dart`：提醒时间/取消/后台命令及快捷定期付回归覆盖。

## 验证结果

- `flutter analyze --no-pub`：通过。
- `flutter test --no-pub test/recurring_bill_notification_test.dart`：3 个用例通过。
- `flutter test --no-pub test/quick_add_redesign_test.dart`：15 个用例通过，包含真实内存数据库写入首笔流水和周期计划。
- `flutter test --no-pub test/recurring_bill_create_sheet_test.dart test/quick_add_redesign_test.dart`：已通过。
- `flutter build apk --debug`：通过，生成 `build/app/outputs/flutter-apk/app-debug.apk`。
- `flutter test --no-pub` 全量运行到 308 个用例时，观察到来自首页 320 宽度和会员导航测试的 5 个 UI/测试环境失败，均不涉及本次周期账单改动；周期账单定向测试不受影响。会员页测试随后长时间不结束，因此停止全量进程。
- iOS 构建未能在当前环境执行：Flutter 返回工程未配置 iOS，直接 `xcodebuild` 又因当前机器仅选择 Command Line Tools、没有完整 Xcode 而无法启动。Swift 改动已按现有 Runner 工程结构完成，但尚未做真机/模拟器编译和通知点击联调。

## 已知风险与联调清单

1. Android/iOS 系统通知权限需要用户允许；拒绝后账单和自动记账仍可用，但不会显示系统提醒。
2. 当前未在真实 Android/iOS 设备上验证厂商省电策略、重启广播送达、通知样式和冷启动点击；这需要后续真机联调。
3. Android 使用非精确低功耗闹钟，系统可能有少量延迟；业务规则不会重复创建提醒。
4. 工作区在任务开始前已有大量未提交改动，本次没有清理或回退无关文件。

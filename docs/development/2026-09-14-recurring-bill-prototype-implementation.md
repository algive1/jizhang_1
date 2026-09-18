# 周期账单新增原型实现交接

日期：2026-09-14

## 需求与原型边界

本次以 `/Users/algive/Desktop/未命名 2.html` 作为“新增周期账单”的 UI 原型参考，提取了以下真实交互：

- 账单名称、金额、支出/收入切换；
- 每天/每周/每月/每年周期切换；
- 重复频率、扣款日期、生效日期、结束方式；
- 扣款/入账账户、分类选择；
- 自动记账、扣款提醒开关；
- 周期规则摘要、取消和保存操作。

HTML 中的静态示例值（例如“微信”“食品餐饮”“每月 15 日”）没有直接写入业务数据；页面会从当前账本的真实账户和分类 provider 中选择，并通过现有 repository 校验后落库。

## 问题原因

原有周期账单新增入口是 `AlertDialog` + 基础下拉框，只能填写少量字段，和原型的 bottom sheet、分组卡片、周期摘要及选择行交互不一致。项目已有 `RecurringBill` 模型、Drift schema、Repository 和自动记账 Service，不需要新建表或绕过业务层。

## 修改内容

### 新增原型表单

新增 [recurring_bill_create_sheet.dart](/Users/algive/jizhang_01/lib/features/recurring/presentation/recurring_bill_create_sheet.dart)：

- 使用可滚动 bottom sheet，固定底部“取消 / 保存周期账单”操作栏；
- 按原型拆分“账单信息 / 重复规则 / 记账设置”三个圆角卡片；
- 支持四种原型周期、频率选择、周几/月几/年几日期选择、开始日期和结束方式；
- 支持账户、一级/二级分类选择，并保留 `categoryId + subcategoryId` 的现有数据结构；
- 支持支出/收入切换，切换时清空不匹配的分类，避免把支出分类写入收入账单；
- 保存前校验名称、金额、账户、分类和结束日期；
- 计算 `firstOccurrence()` 作为下一次执行日期，仍由现有 `RecurringBill` 规则处理月底、闰年等边界；
- 自动记账保存为 `autoRecord`，提醒保存为 `reminder/reminderDays`。

### 接入周期账单页面

在 [recurring_bills_page.dart](/Users/algive/jizhang_01/lib/features/recurring/presentation/recurring_bills_page.dart) 的新增按钮中接入新表单：

```text
新增按钮
  → RecurringBillCreateSheet.show
  → 返回 RecurringBill
  → recurringBillRepositoryProvider.create
  → 账本 / 账户 / 分类校验
  → Drift recurring_bills
  → invalidate providers 刷新列表
```

QuickAdd 中的 `scheduleOnly` 入口和原有编辑入口仍使用 `RecurringBillEditor`，没有被新建页面的完整字段覆盖，避免破坏既有快速记账流程。

### 测试

新增 [recurring_bill_create_sheet_test.dart](/Users/algive/jizhang_01/test/recurring_bill_create_sheet_test.dart)，覆盖：

- 320×700 窄屏下打开原型页、输入真实账单、选择真实 seed 账户/分类并保存；
- 支出/收入切换；
- 每月切换到每周；
- 重复频率选择；
- 返回的 `RecurringBill` 金额、类型、周期、账户、分类、提醒和下一次日期。

## 重要逻辑说明

- 支出映射为 `RecurringBillType.other`，收入映射为 `RecurringBillType.income`。原型没有账单子类型选择，因此没有擅自把名称推断成房租、订阅等类型。
- 账户必须来自当前账本可用账户；分类必须来自当前账本且与收支类型匹配。最终校验仍在 `DriftRecurringBillRepository`，页面校验不是安全边界。
- `autoRecord` 为 true 时继续使用现有 App 启动/恢复前台自动记账调度；本次没有重复实现自动记账。
- `reminder` 和 `reminderDays` 已正确保存到周期账单。当前项目没有本地通知插件或提醒调度 Service，因此本次没有虚假声称已经发送系统提醒；若要实现真正的到期前 OS 通知，需要单独增加通知能力和调度链路。
- HTML 原型只展示每天/每周/每月/每年；项目已有的季度、半年和自定义周期仍由 QuickAdd/旧编辑器维护，没有在新增原型中删除数据库能力。

## 验证结果

- `flutter analyze --no-pub`：通过，`No issues found`。
- `flutter test --no-pub test/recurring_bill_create_sheet_test.dart`：通过。
- `flutter test --no-pub test/recurring_bill_create_sheet_test.dart test/recurring_bill_repository_test.dart test/recurring_schedule_regression_test.dart`：通过，11 个用例全部通过。
- `flutter build apk --debug`：通过，生成 `build/app/outputs/flutter-apk/app-debug.apk`。
- 目标周期账单 Repository 回归覆盖仍通过：持久化、自动记账幂等、到期补记、月底日期、闰年、结束次数和 v16→v17 迁移。

## 当前工作区注意事项

工作区在本次任务开始前已经存在大量 tracked modifications 和未跟踪文件。本次实际新增的是原型表单、对应测试和本交接文档；`recurring_bills_page.dart` 中除新增表单接入外的其他大片差异属于任务开始前已有工作，不应在后续整理时误删或回退。

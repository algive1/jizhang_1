# 消费日历、反馈提示与统一日期时间样式实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (\`- [ ]\`) syntax for tracking.

**Goal:** 修复消费日历底部遮挡、让记账反馈避让导航/FAB，并清理旧日期弹窗以统一日期时间选择样式。

**Architecture:** 保留现有 ShellRoute、底部导航和记一笔保存链路。日历只修正内部 Scaffold 的正文边界；反馈提示通过一个小型共享构造器按 \`AppNavGeometry\` 计算浮动位置；日期选择继续复用 \`AppDatePicker\` / \`TimeSelector\`，由 \`AppDatePicker\` 补充旧入口需要的日期范围参数。

**Tech Stack:** Flutter/Dart、Material 3、Riverpod、Flutter widget tests、现有 \`AppNavGeometry\` 与主题 token。

---

### Task 1: 修复消费日历正文被本月概览遮挡

**Files:**
- Modify: \`lib/features/calendar/presentation/consumption_calendar_page.dart:190-215\`
- Test: \`test/consumption_calendar_test.dart\`

- [ ] **Step 1: 写失败回归测试**

在 \`monthly overview stays visible while calendar body scrolls\` 测试中，获取日历正文 \`ListView\` 和“本月概览”文本的矩形，增加正文底部必须位于概览顶部之上的断言：

~~~
final bodyRect = tester.getRect(body);
final overviewRect = tester.getRect(find.text('本月概览'));
expect(bodyRect.bottom, lessThanOrEqualTo(overviewRect.top));
~~~

- [ ] **Step 2: 运行测试确认它因当前布局失败**

运行：

~~~
flutter test test/consumption_calendar_test.dart --plain-name "monthly overview stays visible while calendar body scrolls"
~~~

预期：失败，正文 \`ListView\` 的底部仍延伸到固定概览卡片绘制区域。

- [ ] **Step 3: 实现最小布局修复**

在消费日历内部 \`Scaffold\` 移除 \`extendBody: true\`，保留 \`bottomNavigationBar\` 的本月概览和现有 \`SafeArea\`/滚动配置，不改变统计数据与卡片内容。

- [ ] **Step 4: 运行回归测试确认通过**

运行同一条测试命令，预期该测试通过且 \`tester.takeException()\` 没有异常。

- [ ] **Step 5: 运行消费日历测试文件**

~~~
flutter test test/consumption_calendar_test.dart
~~~

预期：该文件所有测试通过。

### Task 2: 统一记账反馈提示的颜色和层级

**Files:**
- Create: \`lib/core/widgets/app_snack_bar.dart\`
- Modify: \`lib/features/bookkeeping/presentation/quick_add_sheet.dart:2023-2088\`
- Test: \`test/app_snack_bar_test.dart\`
- Test: \`test/widget_test.dart:379-389\`

- [ ] **Step 1: 写共享提示构造器的失败测试**

新增 widget test，使用 \`AppTheme.light()\` 和 393×844 的 \`MediaQuery\`，通过 \`AppSnackBar.show\` 显示消息，并验证浮动行为、非默认黑色背景、主题文字颜色以及底部间距能超过导航/FAB 占用空间：

~~~
testWidgets('app snackbar floats above the global navigation and fab', (tester) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: MediaQuery(
        data: const MediaQueryData(size: Size(393, 844), padding: EdgeInsets.only(bottom: 34)),
        child: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () => AppSnackBar.show(context, '已保存到本地账本'),
              child: const Text('show'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('show'));
  await tester.pump();

  final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
  expect(snackBar.behavior, SnackBarBehavior.floating);
  expect(snackBar.backgroundColor, isNot(Colors.black));
  expect(snackBar.margin!.bottom, greaterThan(100));
});
~~~

- [ ] **Step 2: 运行测试确认它因 helper 不存在而失败**

~~~
flutter test test/app_snack_bar_test.dart
~~~

预期：编译失败，提示找不到 \`AppSnackBar\`。

- [ ] **Step 3: 实现最小共享提示构造器**

在 \`app_snack_bar.dart\` 中实现 \`AppSnackBar.show(BuildContext, String)\` 和 \`AppSnackBar.build(BuildContext, String)\`：

~~~
final bottom = MediaQuery.paddingOf(context).bottom;
final fabClearance =
    AppBottomNavigation.geometry.actionCenterFromBottom(bottom) +
    AppNavGeometry.actionDiameter / 2 +
    8;
return SnackBar(
  behavior: SnackBarBehavior.floating,
  margin: EdgeInsets.fromLTRB(16, 0, 16, fabClearance),
  backgroundColor: context.appSurface,
  content: Text(
    message,
    style: TextStyle(color: context.appPrimaryText, fontWeight: FontWeight.w600),
  ),
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
  elevation: 4,
);
~~~

\`show\` 获取 \`ScaffoldMessenger.maybeOf(context)\`，先隐藏当前提示，再显示新提示；没有 messenger 时静默返回。

- [ ] **Step 4: 运行 helper 测试确认通过**

~~~
flutter test test/app_snack_bar_test.dart
~~~

预期：测试通过。

- [ ] **Step 5: 接入记一笔全部反馈路径**

在 \`quick_add_sheet.dart\` 引入 \`app_snack_bar.dart\`。校验失败的 \`_showMessage\` 直接调用 \`AppSnackBar.show\`；保存成功和部分成功分支在 \`Navigator.pop\` 前构造 \`SnackBar\` 并捕获 messenger，弹层关闭后使用捕获的 messenger 显示，避免引用已销毁的 sheet context：

~~~
final messenger = ScaffoldMessenger.of(context);
final snackBar = AppSnackBar.build(context, message);
Navigator.pop(context);
messenger.showSnackBar(snackBar);
~~~

- [ ] **Step 6: 扩展记一笔保存回归断言**

在已有 \`opens manual bookkeeping entry\` 测试的保存断言后检查 \`SnackBar\` 的 \`behavior\`、背景色和 \`margin.bottom\`，不改变原有消息文案。

- [ ] **Step 7: 运行记一笔相关测试**

~~~
flutter test test/app_snack_bar_test.dart test/widget_test.dart --plain-name "opens manual bookkeeping entry"
flutter test test/quick_add_redesign_test.dart
~~~

预期：相关测试全部通过，保存文案仍可见。

### Task 3: 清理旧日期弹窗并保留日期范围

**Files:**
- Modify: \`lib/core/widgets/app_date_picker.dart\`
- Create: \`test/app_date_picker_test.dart\`
- Modify: \`lib/features/accounts/presentation/receivable_detail_page.dart\`
- Modify: \`lib/features/accounts/presentation/receivable_form_page.dart\`
- Modify: \`lib/features/accounts/presentation/restricted_account_form_page.dart\`
- Modify: \`lib/features/accounts/presentation/restricted_account_detail_page.dart\`
- Modify: \`lib/features/finance_center/presentation/finance_center_page.dart\`
- Modify: \`lib/features/goals/presentation/goal_creation_sheet.dart\`

- [ ] **Step 1: 写日期范围回归测试**

新增 \`test/app_date_picker_test.dart\`，调用 \`AppDatePicker.show\` 时传入范围和越界初始值，打开底部弹层后断言 \`CupertinoDatePicker\` 收到范围且初始值已被限制：

~~~
testWidgets('date picker keeps the supplied range and clamps its initial date', (tester) async {
  final minimum = DateTime(2026, 1, 10);
  final maximum = DateTime(2026, 1, 20);
  await tester.pumpWidget(MaterialApp(
    theme: AppTheme.light(),
    home: Builder(
      builder: (context) => Scaffold(
        body: ElevatedButton(
          onPressed: () => AppDatePicker.show(
            context,
            DateTime(2026, 1, 1),
            minimumDate: minimum,
            maximumDate: maximum,
          ),
          child: const Text('open'),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();

  final picker = tester.widget<CupertinoDatePicker>(find.byType(CupertinoDatePicker));
  expect(picker.minimumDate, minimum);
  expect(picker.maximumDate, maximum);
  expect(picker.initialDateTime, minimum);
});
~~~

- [ ] **Step 2: 运行测试确认它因参数不存在而失败**

~~~
flutter test test/app_date_picker_test.dart
~~~

预期：编译失败，\`AppDatePicker.show\` 尚不接受 \`minimumDate\` / \`maximumDate\`。

- [ ] **Step 3: 扩展 AppDatePicker 的范围参数**

为 \`AppDatePicker.show\` 增加可选 \`DateTime? minimumDate\`、\`DateTime? maximumDate\`；将边界转为 \`DateUtils.dateOnly\`，把 \`initial\` clamp 到边界内，并把边界传入 \`CupertinoDatePicker\`。不改变默认无范围调用的现有行为。

- [ ] **Step 4: 运行日期组件测试确认通过**

~~~
flutter test test/app_date_picker_test.dart
~~~

预期：测试通过。

- [ ] **Step 5: 替换所有业务旧入口**

将 \`lib/\` 中所有业务层 \`showDatePicker\` 替换为 \`AppDatePicker.show\`，保留原来的 \`initialDate\`、\`firstDate\` 和 \`lastDate\` 语义：

~~~
final picked = await AppDatePicker.show(
  context,
  initialDate,
  minimumDate: firstDate,
  maximumDate: lastDate,
);
~~~

覆盖应收详情/表单、受限账户详情/表单、财务中心和目标创建；补齐 \`app_date_picker.dart\` import，移除不再需要的旧 Material 依赖。

- [ ] **Step 6: 静态确认旧入口清零**

~~~
rg -n "showDatePicker|showTimePicker" lib -g '*.dart'
~~~

预期：无业务页面匹配；\`app_date_picker.dart\` 内部只保留统一 Cupertino 组件。

- [ ] **Step 7: 运行日期相关回归测试**

~~~
flutter test test/app_date_picker_test.dart test/consumption_calendar_test.dart test/recurring_bill_create_sheet_test.dart
~~~

预期：全部通过。

### Task 4: 集成验收与独立审查

**Files:**
- Modify: \`.agent/PLAN.md\`
- Modify: \`.agent/ACCEPTANCE.md\`
- Modify: \`.agent/PROGRESS.md\`

- [ ] **Step 1: 更新项目任务文档**

在 \`.agent/PLAN.md\`、\`.agent/ACCEPTANCE.md\`、\`.agent/PROGRESS.md\` 追加本任务的目标、可验证验收项、实际修改文件和测试结果；不删除既有历史记录。

- [ ] **Step 2: 查看独立差异和工作区状态**

~~~
git diff --check
git status --short
git diff --stat
git diff -- lib/features/calendar/presentation/consumption_calendar_page.dart lib/core/widgets/app_snack_bar.dart lib/core/widgets/app_date_picker.dart lib/features/bookkeeping/presentation/quick_add_sheet.dart
~~~

预期：只出现本任务相关实现和测试差异，既有未提交文件未被重置或覆盖。

- [ ] **Step 3: 运行范围 analyze 和测试**

~~~
flutter analyze lib test/app_snack_bar_test.dart test/app_date_picker_test.dart test/consumption_calendar_test.dart test/widget_test.dart
flutter test test/app_snack_bar_test.dart test/app_date_picker_test.dart test/consumption_calendar_test.dart test/quick_add_redesign_test.dart test/widget_test.dart
~~~

预期：analyze 无 error；指定测试退出码为 0。

- [ ] **Step 4: 构建 Debug APK**

~~~
flutter build apk --debug
~~~

预期：退出码为 0，生成 Debug APK；若环境已有与本任务无关的构建失败，记录完整错误并区分阻断范围。

- [ ] **Step 5: 完成最终代码审查**

用 \`git diff\` 对照设计文档逐项检查：日历正文是否避开概览、反馈提示是否同时避开导航和 FAB、所有日期入口是否走统一组件、范围约束是否保留、是否引入无关改动。发现问题先修复并重新运行受影响测试，再报告结果。

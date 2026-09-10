# 预算与支出趋势修复记录

日期：2026-09-10

## 问题原因

预算设置弹窗由页面方法创建 `TextEditingController`，`showDialog` 返回后页面立即释放控制器。取消操作返回值完成时，弹窗关闭动画和焦点树仍可能读取该控制器，导致 `TextEditingController was used after being disposed`，随后 Flutter 在卸载焦点继承树时触发 `_dependents.isEmpty` 红屏。该问题已通过真实路由 widget 测试复现。

## 修改

- `budget_page.dart`：预算页改为 `ConsumerStatefulWidget`，保存异步完成前检查 `mounted`；新增 `_BudgetDialog`，由弹窗自身创建和释放控制器，覆盖取消、返回、保存生命周期；总预算调整会预填当前总预算。
- `home_expense_trend.dart`：移除未开放的“本周预算”入口；周/月/年趋势统一使用现有暖色调色板；折线使用由相邻真实数据点控制的二次曲线，避免插值过冲和负值。
- 趋势分段控件显式传入暖色渐变；曲线改为逐段经过真实点的受限 cubic，单点、全零和异常负值均保持在有效坐标范围。
- 趋势分段控件背景与未选中文本也支持暖色配置，避免残留青蓝色。
- `home_cards.dart`：移除未开放的“本周预算”入口，保留现有月预算回调链路。
- 预算分类添加入口仅在存在可选分类时显示；保存捕获开始时的月份与账本作用域仓库，异常通过 SnackBar 呈现；编辑已归档/隐藏分类时不会向 Dropdown 传入不存在的 initialValue。
- `test/widget_test.dart`：加入真实应用路由下的预算取消、页面返回、保存回归测试。
- `test/home_reference_interaction_test.dart`：更新为验证仅展示真实的本月预算入口。

## 验证

修复前新回归测试确认取消操作产生控制器提前释放错误，并连锁出现 `_dependents.isEmpty`。修复后预算生命周期与归档分类真实编辑测试已通过，`test/home_reference_interaction_test.dart` 已通过（3 tests），`test/home_redesign_visual_test.dart` 已通过（6 tests，含 320dp/1.6 大字布局）。`flutter analyze --no-pub` 无问题。趋势截图已随 `test/home_reference_page_capture_test.dart` 生成于 `docs/qa/home-reference-2026-09-10/home-lower.png`。

## 限制

本任务未实现周预算，因为当前数据模型和业务链路只提供月预算；入口已移除以避免暗示功能可用。归档分类 SQLite widget 测试已实际执行编辑、NaN 拒绝和保存归属断言；未修改账本选择或分类数据。

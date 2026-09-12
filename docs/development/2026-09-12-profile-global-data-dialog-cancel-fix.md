# 个人中心全局数据与弹窗取消异常修复（2026-09-12）

## 问题原因

- 个人中心监听了带 `activeBookId` 的 `transactionsProvider`，照片查询也限制在当前账本，所以切换账本后统计、进度和照片会缩水为当前账本数据。
- 顶部资料卡在没有登录用户时回退显示当前账本名，账本名被误当成用户信息。
- 分类新增弹窗由页面方法临时创建 `TextEditingController`，点击“取消”时 `showDialog` 已返回，但弹窗退场动画尚未结束，控制器已被释放，导致 Flutter 红屏。
- 交易退款/报销编辑和目标页的几个输入弹窗存在同样的控制器生命周期风险。

## 修改内容

- `lib/features/profile/data/profile_stats.dart`
  - `ProfileActivity` 增加 `bookkeepingDays`，按首笔有效流水日期至今天（含首日）计算；未来流水、软删除流水不计入。
  - `profilePhotosProvider` 改为跨全部可见账本查询有效图片附件，仍过滤软删除流水、软删除附件和非图片附件。
- `lib/features/profile/presentation/profile_page.dart`
  - 个人中心改用 `allTransactionsProvider`，月度进度、记账天数和照片数量使用全局数据。
  - 顶部姓名仅使用登录用户名，未登录时显示“本地用户”，不再读取账本名。
  - “连续记账”改为“记账天数”；照片弹窗默认“全部”，最多显示“全部”加 4 个账本按钮，账本按钮显示名称前三个字，可按账本过滤图片。
- `lib/features/profile/presentation/profile_cards.dart`
  - 顶部卡片文案改为“已记账 N 天”。
- `lib/features/categories/presentation/category_management_page.dart`
  - 新增 `_CategoryEditorDialog`，由弹窗自身持有和释放输入控制器。
- `lib/features/transactions/presentation/transaction_actions.dart`
  - 退款/报销金额输入统一使用生命周期安全的 `_AmountInputDialog`。
- `lib/features/goals/presentation/goal_creation_sheet.dart`、`goal_detail_page.dart`
  - 目标节点、贡献金额、目标编辑和阶段节点弹窗改为 Stateful dialog/sheet 管理控制器。
- `test/profile_reference_test.dart`、`test/widget_test.dart`
  - 增加首笔记账天数、未来流水、照片账本筛选、分类新增取消和目标弹窗取消回归覆盖。

## 验证结果

- `flutter analyze`：通过，无问题。
- `flutter test`：通过，253 项全部通过。
- `flutter build apk --debug`：通过，产物为 `build/app/outputs/flutter-apk/app-debug.apk`。
- 已将 Debug APK 安装到在线 Android 设备 `145a0a68` 并成功启动；启动后 logcat 未发现 `E/flutter`、`FATAL EXCEPTION` 或 `RenderFlex overflow`。
- 个人中心视觉测试覆盖 320/360/393/430 宽度和 1.0/1.6 字体缩放，并实际点击照片筛选按钮；未发现 Flutter layout exception。
- 静态审计确认临时输入控制器已清除，剩余 `controller.dispose()` 均位于对应 Stateful widget 的 `dispose` 生命周期内。

## 风险与边界

- 本次照片筛选按钮最多展示 4 个账本，连同“全部”最多 5 个；更多账本仍通过照片弹窗的账本选择范围之外的数据统计，不改变账本管理页。
- 当前已完成 Flutter widget/UI 矩阵、Debug APK 构建、Android 安装和启动验证；尚未对本次版本重新进行 Android 真机的完整人工点击验收。
- 项目仍有既存 `speech_to_text` 使用 Kotlin Gradle Plugin 的兼容性 warning，不影响本次 Debug 构建。

## 新窗口继续工作

1. 先阅读本文件和 `docs/development/2026-09-12-profile-page-upgrade.md`。
2. 个人中心统计入口是 `allTransactionsProvider` 与 `profilePhotosProvider`，不要改回 `transactionsProvider` 或当前账本过滤。
3. 输入弹窗中的 `TextEditingController` 应由 Stateful widget 创建并在其 `dispose` 中释放，避免在 `await showDialog` 返回后立即释放。

# 账本抽屉与记账页交互修复

日期：2026-09-11

## 问题原因

- 账本抽屉使用 `showGeneralDialog`。新建和删除成功后调用父级 `Navigator.pop`，导致整个抽屉被关闭。
- 抽屉内会员入口直接 `push` 新路由，没有先关闭当前 dialog，所以会员页上方仍残留抽屉。
- 记账页和会员页返回按钮使用了不同图标、间距和未显式约束的触控规格，视觉与点击区域不一致。
- 金额原先位于分类之前，点击区域主要覆盖金额文字；空金额虽然有校验，但只依赖底部弹层下的 `SnackBar`，反馈不够明显。

## 修改内容

- `lib/features/books/presentation/book_selector.dart`
  - 新建、删除账本后保持抽屉打开并刷新内容。
  - 会员、支付通知、搜索入口统一先关闭抽屉，再跳转页面。
  - 保留选择账本后关闭抽屉，以及共享账本跳转前关闭抽屉的原有行为。
- `lib/features/bookkeeping/presentation/quick_add_sheet.dart`
  - 将金额区域移动到分类/转账账户之后。
  - 金额改为整块可点击卡片，扩大实际点击范围。
  - 空金额或 0 金额时显示内联错误、红色边框并展开数字键盘。
  - 有效输入后自动清除金额错误状态。
  - 返回按钮统一为 `arrow_back_rounded`，触控区域固定为 48×48。
- `lib/features/membership/presentation/membership_page.dart`
  - 返回按钮与记账页统一图标、大小和 48×48 触控区域。
- `test/book_selector_ui_test.dart`
  - 增加创建、删除后抽屉保持打开的回归测试。
  - 更新新建账本测试预期。
- `test/widget_test.dart`
  - 增加会员跳转关闭抽屉、空金额提示、金额位置/整块点击区域及返回按钮尺寸测试。

## 验证结果

- `flutter analyze`：通过，无 issues。
- `flutter test`：通过，170 个测试全部通过。
- `git diff --check`：通过。
- `flutter build apk --debug`：通过，产物为 `build/app/outputs/flutter-apk/app-debug.apk`。

## 风险与说明

- 尚未连接实体 Android 设备验证不同厂商系统的真实触控体验；已覆盖 320dp、393dp 和大字体 Widget 测试。
- 全量测试中仍会出现现有 Drift 多数据库 warning，但没有测试失败，也不是本次改动引入的业务错误。
- Debug 构建仍提示 `speech_to_text` 依赖未来需要迁移 Built-in Kotlin，这是现有依赖兼容性提示，与本次功能无关。

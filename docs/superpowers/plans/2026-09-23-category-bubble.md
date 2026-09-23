# 二级分类浮层交互修复实施计划

> **For agentic workers:** 依任务计划逐项开发并由指挥层独立验收。用户已明确授权实施。

**Goal:** 从记一笔分类选择中移除“不细分”，恢复手指滑动时二级分类图标的放大跟随与松手选择，保持液态玻璃模糊，并验证记一笔页面转场与系统返回。

**Architecture:** 保留现有弹层 PopupRoute、AppGlassSurface 与分类数据库。将二级网格交互恢复为有状态的指针跟随布局，实际类别各自可点、可读；长列表仍可滚动。QuickAdd fullscreenDialog 路由行为保持既有架构，仅加测试验证转场与返回。

**Tech Stack:** Flutter / Dart、Riverpod、Drift、Flutter widget tests。

---

### Task 1：固定二级分类手势与“不细分”验收行为

**Files:**
- Modify: `test/quick_add_redesign_test.dart`

- [ ] 用真实内存数据库打开餐饮分类弹层，断言不存在“不细分”文本或 parent 类别入口。
- [ ] 长按第一个二级项并移动到下一个：验证焦点图标缩放随手指移动，再松手确认第二项并断言其原 ID 写入。
- [ ] 保留超长自定义分类列表滚动测试，确认滚动没有错误且点击末项成功。
- [ ] 测试只先写断言，并运行到因缺少指针跟随焦点元素而失败。

### Task 2：恢复紧凑裸主题图标的手指跟随动画

**Files:**
- Modify: `lib/features/bookkeeping/presentation/quick_add_sheet.dart`

- [ ] 将 `_SubcategoryPicker` 恢复为有状态指针选择器；只迭代真实 `categories`，不生成 null parent 项。
- [ ] 用当前滚动偏移将指针映射到最近类别；按距离让裸图标随指针放大/轻微位移，取消或松手后清除焦点。
- [ ] 一次点击仍只选择一个类别；滑动列表保持可滚动；长列表中滚动手势不误选。
- [ ] 删除“不细分”独立 footer 与其 callback。一级网格、类别种子和存储结构不改。
- [ ] 保留 `AppGlassSurface`、半透明主题 tint 和液态玻璃主题的 BackdropFilter 模糊。
- [ ] 运行 Task 1 的失败测试，确认通过后运行相关 UI 测试。

### Task 3：检查记一笔转场、系统返回和边缘返回

**Files:**
- Modify: `test/quick_add_redesign_test.dart`（仅需时）
- Verify: `test/ios_swipe_back_parity_test.dart`

- [ ] 点击记一笔按钮，验证 fullscreenDialog 路由动画从未完成态进入并最终稳定显示。
- [ ] 系统返回关闭二级浮层时仍留在记一笔；再次返回以反向转场关闭记一笔。
- [ ] 执行现有 Android/iOS 边缘滑动返回测试，包含普通路由和 fullscreenDialog 的模态边界。
- [ ] 三主题弹层测试中确认液态玻璃主题仍含 `BackdropFilter`，其他主题行为遵循现有材质实现。

### Task 4：交付验收

- [ ] 运行 `flutter test --no-pub test/quick_add_redesign_test.dart test/ios_swipe_back_parity_test.dart test/category_display_consistency_test.dart`。
- [ ] 对改动文件运行 `flutter analyze --no-pub ...`、`git diff --check` 和 `flutter build apk --debug --no-pub`。
- [ ] 安装最新 Debug APK 到已连接的真机，打开记一笔分类浮层并确认浮层/导航动画正常。
- [ ] 更新 QA 图、验收清单、PROGRESS，并由指挥层复核实际 diff/status。

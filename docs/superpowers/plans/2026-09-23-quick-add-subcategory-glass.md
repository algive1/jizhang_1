# 记一笔二级分类浮层实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 让记一笔的二级分类浮层使用导航同款液态玻璃和点击移动选中态、分类布局更紧凑；一级分类“其他”置首，其余按 sortOrder 倒序。

**Architecture:** 在 quick-add 页保留现有弹层 route、遮罩、指针选择器与数据来源。Liquid Glass 主题改用现有 `AppLiquidGlassSurface` 并复用 `AppBottomNavigation.capsuleTint()`；其他主题继续使用不透明的 `AppGlassSurface`。一级排序只调整本地显示比较器，不触碰分类持久化数据。

**Tech Stack:** Flutter、Riverpod、Drift、Flutter widget tests。

---

### Task 1: 固定排序、玻璃材质与紧凑尺寸

**Files:**
- Modify: `test/quick_add_redesign_test.dart`

- [x] 为液态玻璃断言改用 `AppLiquidGlassSurface`，验证导航胶囊 alpha 0.24、圆角 30 和 BackdropFilter。
- [x] 增加网格断言：默认五列、行高 58 dp、浮层宽度不超过 344 dp。
- [x] 增加一级排序用例：“其他”固定首位，其余按 sortOrder 倒序。
- [x] 增加 Liquid Glass 子分类选中胶囊移动与导航背景模糊测试。
- [x] 先运行新增测试，确认材质、尺寸和排序断言暴露当前实现。

### Task 2: 更新二级浮层样式与一级显示顺序

**Files:**
- Modify: `lib/features/bookkeeping/presentation/quick_add_sheet.dart`

- [x] 把显示排序改为“其他”首位，其余类别按 `sortOrder` 降序。
- [x] 将最大浮层宽度设为 344 dp、横向总边距设为 32 dp，外层内边距设为 6 dp、玻璃模糊与导航同为 5 dp、圆角半径设为 30 dp。
- [x] 基础行高按 `43 + media.textScaler.scale(10) * 1.5` 计算；图标改为 24 dp，图标与文字间距改为 2 dp。
- [x] 仅在 Liquid Glass 主题用 `AppLiquidGlassSurface(tint: AppBottomNavigation.capsuleTint())` 和移动选中胶囊；其他主题保留不透明 `AppGlassSurface`。
- [x] 重跑材质/尺寸/排序用例以及滚动、手指跟随、点击选择用例。

### Task 3: 独立验收并安装真机

**Files:**
- Review: `lib/features/bookkeeping/presentation/quick_add_sheet.dart`
- Review: `test/quick_add_redesign_test.dart`

- [x] 检查 `git diff`、`git status`，确认未触碰已有用户改动。
- [x] 运行相关 widget tests、目标文件 `flutter analyze` 和 `git diff --check`。
- [x] 构建 `flutter build apk --debug --no-pub`。
- [ ] 将包含模糊路径修复的最新 Debug APK 安装到 Xiaomi 真机并启动应用，确认安装与主 Activity 状态。（设备当前未连接 ADB）

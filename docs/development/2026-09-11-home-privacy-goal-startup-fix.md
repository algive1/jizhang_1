# 首页金额隐私、目标节点与启动海报修复

## 问题原因

- 首页“小眼睛”原先只传递给预算卡和资产卡，支出趋势、分类支出、最近交易、洞察卡和计算依据仍然直接渲染真实金额。
- 旧数据中默认个人账本可能保存为“个人”，标题格式化只识别“个人账本/我的账本”，所以首页会显示“个人的账本”。
- 目标节点建议比例只有 12.5%、25%、37.5%、62.5%，且首页和目标卡分别截取节点，导致目标进度过于稀疏。
- 启动海报只在数据库 bootstrap 的 loading 状态显示，数据库初始化较快时几乎不可见；原生 Android 12 启动窗口还受系统限制，不能直接呈现完整海报。

## 修改内容

- 首页金额隐藏状态贯穿趋势图、分类金额/比例、最近交易、分类详情、洞察抽屉和安心可花计算依据；隐藏时不再保留可推断精确值的图表曲线或进度比例。
- `formatBookTitle` 通过稳定的 `SeedIds.personalBook` 识别历史默认个人账本；自定义账本仍显示名称前两个字加“的账本”。
- `GoalMilestoneService.suggest` 改为更细的 10%、20%、30%、40%、50%、60%、75%、90%节点，并新增统一的 `visibleAmounts` 算法。首页和目标进度卡最多显示 7 个节点，保留当前值、最终目标及当前附近的已完成/待达成节点，不修改数据库中的既有节点。
- 启动海报改为 `BoxFit.cover`，在高屏手机上按比例裁切侧边而不拉伸 logo 和文字；应用启动门控改为 450ms 的 Flutter 动画时钟，保证首帧海报稳定可见，同时不阻塞后续路由加载。
- Android 低版本启动窗口继续使用海报资源填满背景；Android 12+ 的系统启动窗口继续使用新松鼠图标，这是 Android 系统对 splash window 的显示约束，进入 Flutter 首帧后显示完整海报。

## 关键文件

- `lib/features/home/presentation/home_page.dart`
- `lib/features/home/presentation/home_expense_trend.dart`
- `lib/core/widgets/transaction_tile.dart`
- `lib/core/widgets/money_text.dart`
- `lib/features/goals/domain/goal_milestone_service.dart`
- `lib/features/home/presentation/home_cards.dart`
- `lib/core/widgets/goal_progress_card.dart`
- `lib/core/formatters/book_title_formatter.dart`
- `lib/app/app.dart`
- `lib/core/widgets/startup_poster.dart`
- `assets/images/startup_poster.png`
- `android/app/src/main/res/drawable/launch_background.xml`

## 验证结果

- `flutter test`：193 个测试全部通过。
- `flutter analyze`：通过，无 analyzer issue。
- `flutter build apk --release`：通过。
- APK：`build/app/outputs/flutter-apk/app-release.apk`
- SHA-256：`c3ee78f6f0a6d91a5b2ce607954e5b56787b34a9a5d74829a3e9021841d688f4`
- APK 大小：80,681,778 bytes。
- `apksigner verify`：APK Signature Scheme v2 通过，单签名者。
- APK 内容核验：包含 `assets/flutter_assets/assets/images/startup_poster.png`。
- 当前没有连接 Android 真机或在线模拟器，尚未完成真实设备上的安装、启动海报截图和小眼睛触控回归；这部分仍需在目标手机上确认。

## 后续检查建议

在目标 Android 手机上安装 APK 后，重点确认：启动时海报主体是否因屏幕比例裁切到文字/松鼠；点击首页小眼睛后向下滚动，趋势、分类、最近交易及弹层是否都只显示“金额已隐藏”；切换账本后标题和目标节点是否即时刷新。

# 执行进度

## 后续修正（2026-09-23）
- 用户最新要求：分类界面删除“不细分”；二级浮层保持液态玻璃模糊；恢复图标跟手放大动画；检查手势返回与点击记一笔转场。
- 真机 145a0a68 已安装上一版 Debug APK；最新完成后需要重新构建、安装并打开记一笔页。
- 按 TDD 更新测试：无“不细分”、手势指针焦点缩放并松手选择、长列表滚动、玻璃 BackdropFilter、系统返回/页面转场。
- 已先观察新增动画断言因缺少 focus Transform 正确失败；实现后手势动画、无“不细分”、liquidGlass BackdropFilter 与返回转场测试通过。
- 实现：移除 popover 的“不细分”footer 与对应48dp高度；恢复有状态 pointer tracking、距离缩放/轻移及松手选中；GridView 继续处理长列表滚动，仅没有发生滚动的拖动手势作分类选择。
- 独立审计子代理确认现有 quick-add 使用 fullscreenDialog，Android 左缘回退被模态路由有意禁用；popup 系统返回先退弹层；没有改动导航策略。
- 测试：`flutter test --no-pub test/quick_add_redesign_test.dart` 21项通过；`test/ios_swipe_back_parity_test.dart` 5项通过；`test/category_display_consistency_test.dart` 8项通过。
- 静态分析：quick_add_sheet + quick_add_redesign + ios_swipe_back_parity 三项分析无问题。`git diff --check`通过，只有仓库其他既有文件的换行格式警告。
- 构建：Debug APK build 成功，路径 `build/app/outputs/flutter-apk/app-debug.apk`，279,143,811字节。
- 等待真机：构建时 Android 设备 145a0a68 从 ADB 消失；ADB 与 Windows PresentOnly USB 列表均无该设备。新 APK 尚未安装。请用户重新连接并解锁、授权 USB 调试后继续真机安装和页面手动检查。
- 分类种子、Seeder、账单导入映射、语音解析均未修改；全局主题与路由策略未修改。

## 二级浮层可读性补充（2026-09-23）
- 用户根据真机截图明确要求：浮层打开后页面背景更暗；玻璃浮层更模糊；背景图标和文字不能透出。
- 最新 APK 已安装到 Xiaomi 23116PN5BC（ADB 序列号 145a0a68）。实机截图确认 barrier 可见，但浮层内仍可认出下方一级分类图标/文字；此问题待修。
- 指挥层更新了 PLAN 与 ACCEPTANCE，要求先写可验证的参数断言，再做最小范围视觉实现；局部调整不影响全局玻璃组件默认值。
- 实现已完成，由指挥层独立审阅通过。新增四项断言按 TDD 经 RED/GREEN 验证。
- 指挥层复跑 `flutter test --no-pub test/quick_add_redesign_test.dart`：25项通过；`test/ios_swipe_back_parity_test.dart`：5项通过；`test/category_display_consistency_test.dart`：8项通过；scope analyze 无问题；`git diff --check` 通过（只有 LF/CRLF 提示）。
- Debug APK 最终重建成功：`build/app/outputs/flutter-apk/app-debug.apk`，279,141,801字节，2026-09-23 14:18。
- Liquid Glass 渲染截图已更新为 `docs/qa/category-compact-2026-09-23/liquid_glass.png`，遮罩更深，浮层内底层内容不可辨认，浮层文字/图标清楚。
- ADB 当前无设备；Xiaomi 23116PN5BC 真机安装与现场复核仍待设备重新连接。
- 按用户要求准备提交当前项目改动。排除两个临时探针/渲染测试及 `.agent/baseline-*` 快照，其余已跟踪项目改动、实现文件和 QA 资料已暂存。
- 全仓 `flutter test --no-pub`（排除临时渲染脚本）结束：570通过、41失败。失败涉及更广范围的 `AppBottomNavigation.glassTint` 旧断言、多个 v18/v20 数据迁移断言、profile reference finder 以及若干 `pumpAndSettle` 超时；本任务 quick-add/category/navigation 定向测试仍通过。
- `git diff --cached --check` 通过。远端同步遇到 GitHub 443 连接重置/超时，提交后仍需尝试 push。

## 指挥层验收
- 用户最新纠正：保留一级及二级分类现状，本轮只调整二级分类浮层视觉。
- 两名请求的 Luna 子代理均因账户额度限制无法启动，指挥层直接完成实现与验收。
- `CategoryIcon` 新增可选裸图标呈现，默认样式不变；二级浮层使用28px主题色图形、紧凑网格、8px容器内边距和半透明背景。原分类ID/名称/层级/图标键/排序及选择行为保持。
- 截图：`docs/qa/category-compact-2026-09-23/`（fresh_green、mist_blue、liquid_glass）。
- 相关测试：`flutter test --no-pub test/category_display_consistency_test.dart test/quick_add_redesign_test.dart`，28项通过。
- 改动相关文件静态分析通过；`git diff --check`通过，仅提示若干既有文件行尾格式。
- Debug APK构建成功：`build/app/outputs/flutter-apk/app-debug.apk`，279,141,894字节。Gradle日志有既有插件兼容性提示，未阻断构建。
- 数据保全：category_templates、database_seeder、账单导入分类映射、语音解析文件与本轮开工快照一致。
- 注意：仓库还包含大量本轮前未提交改动，未清理或覆盖。仓库全量 analyze 之前发现不相关的 `test/app_scaffold_navigation_test.dart` 对不存在的 `AppBottomNavigation.glassTint` 引用；本轮改动相关 analyze 已通过。
- 已按开工快照审阅本轮源码差异：CategoryIcon只增加可选裸图标分支；quick_add_sheet只调整浮层密度、透明度、裸主题色图标及“不细分”独立按钮布局。
- QA结果文档已添加至`docs/qa/category-compact-2026-09-23/results.md`；最终验收通过。

## 二级浮层对比度调整执行（2026-09-23）
- 已先在 `test/quick_add_redesign_test.dart` 增加四项独立断言：遮罩 alpha 至少 0.55、普通主题浮层完全不透明、Liquid Glass 模糊 sigma 为 32、玻璃渐变的每个色标 alpha 至少 0.94。
- RED 已逐项确认：修改前遮罩为 0.38、普通主题 tint alpha 为 0.76、玻璃 blurSigma 未设置（null）、玻璃渐变色标未达到覆盖度要求。
- 实现：popover barrier 调为黑色 alpha 0.58；只为该二级浮层传入 Liquid Glass blurSigma 32 与 `glassOpacity: .96`；普通主题浮层 tint 完全不透明。`AppGlassSurface.glassOpacity` 默认为 null，默认渐变渲染保持原值，其他调用不变。
- GREEN：`flutter test --no-pub test/quick_add_redesign_test.dart --plain-name "二级分类"` 通过；完整 `flutter test --no-pub test/quick_add_redesign_test.dart` 25 项通过。
- 静态分析：`flutter analyze lib/core/widgets/app_glass_surface.dart lib/features/bookkeeping/presentation/quick_add_sheet.dart test/quick_add_redesign_test.dart` 无问题。`git diff --check` 通过，仅出现仓库已有的 LF/CRLF 转换提示。Flutter 输出一个既有 alipay iOS default plugin 缺失提示，不影响本轮 Android widget 测试。
- 本执行子任务未构建、安装或手动检查真机；等待指挥层独立审阅差异并继续设备验收。

# 页面转场旧内容穿透进度（2026-09-23）

- 已完成：排查 `AppTheme.light`、`AppThemeTokens.appBackground`、`AppScaffold`、`QuickAddSheet`、GoRouter 与 Cupertino 转场；定位默认 Scaffold 背景透明引起的路由层穿透。
- 已完成：`test/route_background_isolation_test.dart` 的普通 Scaffold 与 fullscreenDialog 在原代码下失败；只改默认底色后通过，但 content-only 页面仍失败；增加共用路由底层后 Android 与 iOS push/侧滑测试均通过。
- 已完成：Debug APK 构建和最后审计。`build/app/outputs/flutter-apk/app-debug.apk` 生成成功。
- 修改文件：本任务的 `.agent/PLAN.md`、`.agent/ACCEPTANCE.md`、`.agent/PROGRESS.md`、`lib/app/theme/app_theme.dart`、`test/route_background_isolation_test.dart`。
- 测试结果：路由隔离、iOS/Android 返回、AppScaffold 玻璃和 quick-add 既有测试共 48 项通过；修改文件范围的 `flutter analyze --no-pub` 无问题；`git diff --check` 退出码 0。
- 扩展测试：quick-add 按钮、助手导航、玻璃导航间隙共 11 项通过。`product_visual_regression_test.dart` 原有的两项热力图断言仍失败，分别比较旧硬编码主色与现主题色、以及在窄屏查找尚未构建的图表；与路由背景改动无关。
- 全仓 `flutter analyze --no-pub` 仅报现存未跟踪 `test/zz_tmp_render_shots_test.dart` 的多余导入 info；本次改动范围分析零问题。
- 设备复核：Xiaomi 23116PN5BC 重新接入后，Debug APK 安装成功。液态玻璃主题首页截图可见悬浮玻璃导航条及背景模糊，记一笔完整页卡片空隙未见旧页文字。连续截图没有捕获到进入动画中途帧，设备随后切至其他前台应用，已停止操作。
- 剩余风险：真机 Impeller 动态折射与过渡中途尚无视频/逐帧视觉证据；widget 像素测试已经覆盖 push 与侧滑中途。
- 指挥层验收：已审查 diff/status、复现测试 RED/GREEN、相关测试与构建输出；五张被视觉测试重写的原有 QA 图片已还原。独立只读审查未发现 Critical/Important 实现缺陷，指出动态真机视觉复核仍待完成。

# 液态玻璃导航栏选中态进度（2026-09-23）

- 用户已同意参考木木记账调整导航浅色玻璃层级；指挥层完成现有实现和本地反编译资料分析。
- 基线：`flutter test --no-pub test/app_scaffold_navigation_test.dart`，14 项通过。
- RED 1：新增液态玻璃普通对比度栏体/pill 回归断言后运行 `flutter test --no-pub test/app_scaffold_navigation_test.dart --plain-name "liquid glass uses a pale capsule and a lightly tinted moving pill"`；断言按预期失败，栏体实际为暗化主题 tint（alpha `.38`），预期浅白 alpha `.24`。
- RED 2：补充 moving glass blur/shadow 默认值断言后同命令失败，shadow 预期 blur `9`、实际 `null`，确认整体替换 appearance 会丢失默认阴影。
- 实现：仅液态玻璃普通对比度模式把栏体改为白色 alpha `.24`；移动层从原默认 `effectiveGlass` 复制，只将主题色设为 alpha `.08`，保留 blur、shadow、形状和折射；静止层继续使用 alpha `.26` 主题色。高对比度、其余三套主题、图标/文字颜色、动画和几何分支保持原有配置。
- GREEN：恢复 moving glass appearance 默认值后，同一聚焦测试通过；`flutter test --no-pub test/app_scaffold_navigation_test.dart` 共 15 项通过，含四主题与高对比度覆盖。
- 静态分析：`flutter analyze --no-pub lib/core/widgets/app_bottom_navigation.dart test/app_scaffold_navigation_test.dart` 无问题。
- 构建：`flutter build apk --debug --no-pub` 成功，生成 `build/app/outputs/flutter-apk/app-debug.apk`；仅有 cryptography_flutter 的 Kotlin Gradle Plugin 迁移提示。
- 差异检查：`git diff --check` 退出码 0。最终本任务源码仅改 `lib/core/widgets/app_bottom_navigation.dart` 与 `test/app_scaffold_navigation_test.dart`；更新本节进度记录。仓库仍有指挥层及先前任务的其他未提交文件，均未改动。
- 已发现问题：手机木木记账为 8.2.7，本地反编译 APK 为 8.2.8；真机切到其他应用，点击动画逐帧画面未可靠捕获。
- 剩余风险：Impeller 真机动态观感需要在用户方便时复核；本轮不自动安装或切换用户前台应用。
- 等待指挥层验收：确认移动/静止层级、颜色分支与最终差异。

### 指挥层视觉复核后修正
- 指挥层复核发现 alpha `.08` 移动色与浅白栏体在 Liquid Glass 页面底色上合成后的对比度只有 `1.0972:1`，低于 `1.15:1` 验收门槛。
- RED：将测试改为以 `BuiltInThemes.liquidGlass.background` 为页面底色，先将白色 alpha `.24` 栏体合成到页面，再将移动 pill 实际颜色合成到栏体并计算 WCAG 对比度。`flutter test --no-pub test/app_scaffold_navigation_test.dart --plain-name "liquid glass uses a pale capsule and a lightly tinted moving pill"` 按预期以 `1.097245:1 < 1.15:1` 失败。
- 实现：移动主题色 alpha 从 `.08` 提到 `.14`；合成计算约 `1.1788:1`（按 8-bit 中间颜色取整约 `1.1776:1`），仍低于 `.20` 的低透明度上限。默认 `effectiveGlass` 外观复制方式不变，blur/shadow/refraction 保持原值。
- GREEN：聚焦测试通过；`flutter test --no-pub test/app_scaffold_navigation_test.dart` 15 项通过。
- 静态分析：`flutter analyze --no-pub lib/core/widgets/app_bottom_navigation.dart test/app_scaffold_navigation_test.dart` 无问题。
- 构建：`flutter build apk --debug --no-pub` 成功，生成 `build/app/outputs/flutter-apk/app-debug.apk`；Gradle 输出既有 cryptography_flutter KGP 迁移提示。
- 差异检查：`git diff --check` 通过；本次视觉复核只更新导航组件、对应测试和本进度章节。
- 指挥层独立验收：审阅 `git status`、源码/测试 diff 与视觉样张；导航及布局测试共 21 项通过，范围 analyze 无问题，Debug APK 构建成功，`git diff --check` 退出码 0。真机切换过程中的 Impeller 动态画面仍未逐帧核验。

# 导航选中态全主题二次调整进度（2026-09-23）

- 用户明确要求：导航选中后的背景再浅一些；Liquid Glass 按住移动胶囊应像其他主题一样保持透明，不叠主题色；改好后安装到真机查看。
- 已定位：静止层共享 `restFillAlpha = .26`；Liquid Glass 移动层单独设置主题色 alpha `.14`，而其他主题的 `glassStyle` 为 null、走默认透明玻璃。
- 计划：先更新测试，要求静止透明度 `.18` 且四主题仍可辨；要求 Liquid Glass `glassStyle` 为 null，并继续验证图标对比度及高对比度分支。
- 当前进度：任务计划和验收标准已补充；待执行 RED、最小实现、复验、构建、真机安装。
- 范围：只改导航组件、对应测试和当前 `.agent` 三个记录文件；其他工作区变更原样保留。
- RED：分别运行选中底色主题回归与 Liquid Glass 透明移动胶囊回归；前者因实际 alpha `.26`、预期 `.18` 失败，后者因实际存在 `LiquidGlassStyle` 覆盖、预期 null 失败。
- 实现：普通主题 settled pill alpha 降至 `.18`；移除 Liquid Glass moving glassStyle 的主题色覆层，恢复默认透明移动玻璃；图标、栏体、高对比度颜色、几何与动画参数保留。
- GREEN：`flutter test --no-pub test/app_scaffold_navigation_test.dart test/liquid_glass_nav_gap_layout_test.dart --reporter expanded` 21 项通过；所有内置主题覆盖 `.18` 静止底色、默认透明移动层和选中/未选中文字对比度。
- 分析与构建：范围 `flutter analyze --no-pub lib/core/widgets/app_bottom_navigation.dart test/app_scaffold_navigation_test.dart` 无问题；`flutter build apk --debug --no-pub` 成功，只有既有 KGP 迁移提示。
- 真机：APK 更新安装到 Xiaomi 23116PN5BC 成功，显式启动后 `MainActivity` 成为前台。现场截图保存至 `E:\jizhang_1\nav_glass_review\after_second_adjustment.png`，确认首页正常渲染。
- 差异检查：`git diff --check` 退出码 0。任务源码范围为导航组件和对应测试；已有 `lib/app/theme/app_theme.dart`、其他 `.agent` 记录和未跟踪文件均保留。

# 选中图标明度微调进度（2026-09-23）

- 用户真机查看后要求选中图标颜色再鲜亮一些；用户确认此前版本已安装，本轮完成后需再次更新安装。
- 已确认实现数据流：`selectedInkFactor = .80` 作用在 `scheme.secondary`，`itemStyle.selectedColor` 同时供选中图标与文字使用。
- 目标：系数提升到 `.85`，其他状态颜色不动，验证四主题选中对比度至少 4.5:1。
- 当前进度：任务计划、验收标准已追加；待加入 RED 断言并完成实现、复验和安装。
- RED：导航 ink 测试新增 `.85` 预期，原代码以实际 `.80` 失败。
- 实现/GREEN：`selectedInkFactor` 改为 `.85`；导航与间隙测试共 21 项通过，其中四个内置主题的选中 ink 对比度、未选中 ink 和选中底色均通过断言。
- 验证：范围 analyze 无问题；Debug APK 构建成功（仅有已有 KGP 迁移提示）；`git diff --check` 退出码 0。
- 真机：APK 成功更新并启动，Xiaomi 23116PN5BC 当前前台为 `MainActivity`。最新截图 `E:\jizhang_1\nav_glass_review\selected_ink_bright.png` 显示洞察页选中图标/文字已提亮。

# 木木参考下的选中态层次修正进度（2026-09-23）

- 用户截图指出当前洞察静止 pill 灰蓝整块感仍重，要求背景更淡、选中图标文字更鲜亮，并参考木木反编译代码。
- 木木参考核对：手机应用版本为 8.2.7，本地 AOT 反编译为 8.2.8。`04-木木APK液态玻璃参数复核.md` 记录浅色静止 pill 为白色 alpha `.10`，静止层 blur 为 `0 / 0`；移动胶囊另走折射样式。`main_bottom_navigation_bar.dart` 中 `_buildTab` 将活动状态和主题/tint 颜色分支传给图标与标签；活动项使用完整主题色，未选中降低 alpha。木木的版本与本项目主题色架构不同，因此复用浅色静止层级和活动色方向，不照搬其具体图标色值。
- 原实现确认：静止 pill 所有普通主题均为 primary alpha `.18`；选中图文共用 `secondary * .85`；移动玻璃 `glassStyle == null`，走库默认透明折射。
- RED：先把测试预期更新为 Liquid Glass 白色 alpha `.10`、其他普通主题 primary alpha `.08`、Liquid Glass 选中色 `Color.lerp(secondary, primary, .5)`、其他主题 `secondary * .90`；验证首轮因旧实际 selected 色及 `.85` 系数断言失败。测试同时按各主题页面底色与栏体/静止 pill alpha 合成真实背景，并验证选中和未选中 ink 均达到 4.5:1。
- 实现：静止层仅 Liquid Glass 使用白色 alpha `.10`，其余普通主题 primary alpha `.08`；Liquid Glass 选中图文用 secondary/primary 50% 混合，其余主题 selectedInkFactor 调为 `.90`。移动玻璃仍不设置 glassStyle；未选中样式、几何、弹簧和高对比度配色保持不变。同步删除“选中 ink 必须暗于未选中”的旧测试假设和过时颜色注释。
- GREEN：`flutter test --no-pub test/app_scaffold_navigation_test.dart test/liquid_glass_nav_gap_layout_test.dart` 共 21 项通过；四主题选中与未选中对比度均至少 4.5:1，选中 ink 比此前 `.85` 配置更亮，移动层仍透明；高对比度颜色/静止填充断言通过。
- 静态分析：`flutter analyze --no-pub lib/core/widgets/app_bottom_navigation.dart test/app_scaffold_navigation_test.dart` 无问题；`git diff --check` 退出码 0。
- 按指挥层要求，本轮未构建 APK、安装或操作手机。静止白色 alpha `.10` 的真机轮廓可辨性待指挥层视觉复核；工作树其他已有改动和未跟踪文件均未动。
- 指挥层验收：独立复跑导航与 gap-layout 21 项全部通过，范围 analyze 无问题，`flutter build apk --debug --no-pub` 成功（仅有原 KGP 迁移提示），`git diff --check` 退出码 0；审阅 `git diff`、`git status`，任务外已有改动未触碰。
- 真机安装 `adb -s 145a0a68 install -r build\\app\\outputs\\flutter-apk\\app-debug.apk` 返回 `Success`，`am start` 成功并截图。最新洞察页截图 `E:\\jizhang_1\\nav_glass_review\\selected_mumu_layer_insights2.png`：静止 pill 已由灰蓝整块变为很浅的白色，边界仍可见，选中洞察图标/文字为更明亮的蓝色。用户随后切换了手机前台应用，不再主动操作手机。

# FAB 与导航栏统一玻璃材质进度（2026-09-23）

- 已核对：FAB 当前使用主题色 alpha `.76` 作为玻璃 tint、纯白加号；四主题导航已经统一使用 `LiquidGlassTabBar`，但胶囊 tint 随主题变化。用户要求圆底和导航玻璃同材质、加号带主题色。
- 基线：`flutter test --no-pub test/quick_add_button_test.dart test/app_scaffold_navigation_test.dart`，19 项通过。
- RED：先将 FAB 断言改为与导航胶囊 tint/选中 ink 相同；运行 `flutter test --no-pub test/quick_add_button_test.dart`，旧 FAB 的 Fresh Green 主色 alpha `.76` 与预期导航 `plateTint` 不符，四主题颜色断言失败，确认失败来自新断言。
- 实现：在 `AppBottomNavigation` 提炼 `capsuleTintFor` 与 `selectedEmphasisFor`，导航和 FAB 共用原有普通模式导航颜色计算；FAB 普通模式圆底与胶囊同色，Liquid Glass 为白色 alpha `.24`，加号为导航选中强调色。高对比度仍走不透明主题色按钮。保留圆形尺寸、refraction、blur、光学边缘、点击与长按；阴影改为中性黑色 alpha `.22`、opacity `.3`，避免继续使用浓主题色阴影。更新 FAB 的旧注释及 refraction 尺寸说明。
- 测试：覆盖四主题的共享底色/前景色、合成主题页面底色后的非文本对比度至少 3:1；并锁定折射、模糊、尺寸、光学边缘、存在且中性的阴影、高对比度图标与点击/长按回调。
- GREEN：`flutter test --no-pub test/quick_add_button_test.dart test/app_scaffold_navigation_test.dart` 共 19 项通过。
- 静态分析：`flutter analyze --no-pub lib/core/widgets/app_bottom_navigation.dart lib/core/widgets/quick_add_button.dart test/quick_add_button_test.dart test/app_scaffold_navigation_test.dart` 无问题；`git diff --check` 退出码 0（仅有工作树已有文件的 LF/CRLF 提示）。
- 验证期间 Flutter 提示 alipay_kit 缺失 iOS 默认实现；widget 环境无 Impeller 时折射使用 lite glass 路径。两条为环境提示，测试通过。
- 按指挥层要求，本轮未 build、install 或操作手机；待指挥层独立审查与视觉验收。只修改任务范围内的导航、FAB、FAB 测试及本节进度记录。
- 指挥层独立验收：审阅导航/FAB/测试 diff 与 git status，任务外既有改动保持不动；独立运行 `flutter test --no-pub test/quick_add_button_test.dart test/app_scaffold_navigation_test.dart test/liquid_glass_nav_gap_layout_test.dart --reporter expanded`，25 项通过；范围 analyze 无问题；Debug APK 构建成功（有现存 KGP 迁移提示）；`git diff --check` 退出码 0。
- 真机安装：`adb -s 145a0a68 install -r build\\app\\outputs\\flutter-apk\\app-debug.apk` 返回 `Success`，即当前构建已安装。随后为了模拟器排查重启 ADB，手机设备目前显示 offline，无法继续启动应用或抓取本轮 FAB 画面；手机 USB 设备在 Windows 仍枚举为 Xiaomi 14 Pro。安装后不再操作用户手机。

# 四主题统一采用液态玻璃导航样式修正（2026-09-23）

- 用户反馈上一版其他主题仍保留有色导航栏底和点击后的主题色选中背景，要求所有主题的导航栏/FAB 视觉样式都采用 Liquid Glass 版本。
- 已复核代码：固体主题导航胶囊仍通过 `plateTint(scheme)`，静止 pill 仍用 `primary` alpha `.08`，而 Liquid Glass 是白色 alpha `.24` 胶囊和白色 alpha `.10` pill；FAB 通过导航 tint helper，当前会继承固体主题 `plateTint`。
- 修正目标：普通对比度下四主题共享白玻璃胶囊 `.24`、静止 pill `.10`、FAB 底 `.24`，不按主题叠加背景色；选中 ink/FAB 加号保留主题强调色；高对比度与移动透明玻璃保持不变。先更新测试做 RED，再实现、复测对比度、构建并尝试更新真机。
- RED：先更新 `test/app_scaffold_navigation_test.dart` 使四主题均要求胶囊白色 alpha `.24`、静止 pill 白色 alpha `.10`，并更新 FAB 统一白底预期；`flutter test --no-pub test/app_scaffold_navigation_test.dart --plain-name "all themes share pale glass layers and keep themed ink"` 按预期失败，Fresh Green 实际胶囊仍为主题 tint alpha `.38`。
- 实现：删除主题色 `plateTint` 及其色相/暗化参数、普通模式 `.08` 主题色 pill 分支和过时注释；导航与 FAB 共用白色 alpha `.24` 胶囊/FAB tint，四主题静止 pill 都用白色 alpha `.10`。所选/未选图文及 FAB 加号仍走既有主题 ink；高对比度分支、移动玻璃默认透明样式、动画与几何保持不变。
- 测试：导航四主题断言验证 capsule `.24` 与 rest pill `.10` 完全一致，并继续验证 selected/unselected 4.5:1；FAB 四主题验证共用 `.24`、主题前景及至少 3:1；高对比度与透明移动玻璃原断言保留。
- GREEN：`flutter test --no-pub test/app_scaffold_navigation_test.dart test/quick_add_button_test.dart test/liquid_glass_nav_gap_layout_test.dart` 共 25 项通过；四主题统一材质、主题色 ink 对比度、高对比度和移动玻璃透明断言均通过。
- 静态分析：`flutter analyze --no-pub lib/core/widgets/app_bottom_navigation.dart lib/core/widgets/quick_add_button.dart test/app_scaffold_navigation_test.dart test/quick_add_button_test.dart test/liquid_glass_nav_gap_layout_test.dart` 无问题；`git diff --check` 退出码 0，仅输出工作树文件的 LF/CRLF 提示。
- 按指挥层要求本轮未 build、install 或操作手机，留待独立复审及设备验收。工作树原有其他文件及未跟踪文件未作修改。
- 指挥层独立验收：导航、FAB、gap-layout 25 项重跑通过；5 个改动范围文件 analyze 无问题；Debug APK 构建成功（Gradle 输出既有 KGP 迁移提示）；审阅任务 diff/status 且未触碰任务外既有改动；`git diff --check` 退出码 0。
- 真机：ADB 当前 serial `145a0a68`（Xiaomi 23116PN5BC）在线时执行 `adb -s 145a0a68 install -r build\\app\\outputs\\flutter-apk\\app-debug.apk` 返回 `Success`；`pm path com.algive.jizhang_app` 返回有效 `/data/app/.../base.apk` 路径。当前手机前台是抖音，因此没有强行切换 Activity；用户可自行切回应用查看。

# 深灰静止胶囊网页预览进度（2026-09-23）

- 用户要求把静止选中胶囊改成深灰色 10%，并生成网页预览。
- RED：先更新四主题颜色断言为 `Color(0xFF333333)` alpha `.10`；指定测试按预期因旧实现仍为白色 `.10` 失败。
- 实现：四主题普通模式的静止胶囊统一改为深灰 `.10`。复算发现 Liquid Glass ink 原 50% 混合对比度为 4.355:1，选中颜色混合权重收至 40%，测试要求仍至少 4.5:1；移动玻璃及栏体/FAB 底色不变。
- 网页：生成 `E:\\jizhang_1\\nav_glass_review\\dark_gray_capsule_preview.html`，包含 Liquid Glass、Fresh Green、Mist Blue、Almond 四主题及导航切换交互。浏览器策略拒绝自动打开本地 `file://` URL，因此将交付本地文件链接供用户直接打开。
- GREEN：导航、FAB、gap-layout 定向测试 25 项通过；范围 analyze 无问题。
- 待完成：Debug APK build、最终 `git diff --check` 与工作区状态核对；本轮不安装、不操作真机。
- GREEN/build：定向测试 25 项通过，5 个目标文件 analyze 无问题，`flutter build apk --debug --no-pub` 成功；只有现存 cryptography_flutter KGP 迁移提示。
- `git diff --check` 通过。独立预览文件大小 13,621 字节；本地浏览器安全策略拒绝代理打开 file URL，已保留预览文件给用户直接查看。未执行 adb/安装或手机前台操作。

# 静止胶囊 3% 真机复核进度（2026-09-23）

- 用户要求静止胶囊改为 3%，并安装到真机查看。
- RED：先更新导航断言为 `#333333` alpha `.03`；测试因实现仍为 `.10` 失败，失败原因符合预期。
- GREEN：导航、FAB、gap-layout 定向测试共 25 项通过；范围 analyze 无问题。选中墨色维持原值，四主题对比度门槛通过。
- 网页预览 `E:\\jizhang_1\\nav_glass_review\\dark_gray_capsule_preview.html` 的胶囊 CSS、标题、说明同步改为 3%。
- 构建：`flutter build apk --debug --no-pub` 成功；输出既有 cryptography_flutter KGP 迁移提示。
- 真机：设备 `145a0a68`（Xiaomi 23116PN5BC）在线；APK `install -r` 返回 `Success`，`monkey -p com.algive.jizhang_app 1` 已发送启动事件。
- 真机复核：`pm path` 返回有效 APK 路径，`pidof` 返回进程 11856，`dumpsys activity` 显示 `com.algive.jizhang_app/.MainActivity` 为 RESUMED。截图保存至 `E:\\jizhang_1\\nav_glass_review\\installed_dark_gray_3_percent.png`。
- 补充设备状态：唤醒后系统显示锁屏通知层（`NotificationShade`），底层仍是应用 MainActivity；没有尝试解锁，用户解锁后可查看。

# 二级分类浮层导航同款玻璃与紧凑布局进度（2026-09-23）

- 用户确认视觉预览方向可用，并要求构建后安装到真机查看。
- 当前代码排序按使用次数降序，频繁分类在最前；液态玻璃浮层目前使用高模糊、近不透明的 `AppGlassSurface`，网格最大宽度接近屏宽，基础行高为 72 dp 左右。
- 已记录设计与验收要求，测试先覆盖 Liquid Glass 导航材质、紧凑尺寸与高频一级分类末尾排序。
- 当前状态：待新增 RED 用例，再修改浮层和排序实现。
- 修改文件：计划修改 `lib/features/bookkeeping/presentation/quick_add_sheet.dart` 与 `test/quick_add_redesign_test.dart`；本进度文档只追加本节。
- 测试结果：待执行。
- 已发现问题/剩余风险：导航同款玻璃比旧浮层更透明，类别会透见模糊底层；需确认二级文字图标仍清晰并保留外层 scrim。
- 等待指挥层验收：否，当前开发进行中。

- 用户最新调整一级排序要求：除“其他”外，所有一级分类按既有 sortOrder 倒序；“其他”固定末尾。此要求替代本节前述“高频分类排最后”的排序方案。
- 实现已完成：一级分类显示按 sortOrder 倒序并将“其他”固定末尾；浮层最大宽度 344 dp，基础行高 58 dp，图标 24 dp；Liquid Glass 主题直接复用导航栏液态玻璃材质与 tint，其他主题维持不透明表面。大字号分类文字设置紧凑行高以避免两行标签溢出。
- 回归：新增排序、材质/尺寸断言。首次全测发现紧凑行高下长子分类名发生垂直溢出；明确设置子分类文字字号 10、高度 1.05 后，长列表与 320 dp / 1.6 倍字号用例通过。
- 验收：`flutter test --no-pub test/quick_add_redesign_test.dart` 共 27 项通过；目标源文件与测试文件范围 `flutter analyze` 无问题；`git diff --check` 退出码 0。
- 全项目 `flutter analyze --no-pub` 仅报告既有未跟踪文件 `test/zz_tmp_render_shots_test.dart:4` 的 `dart:typed_data` unnecessary_import 提示；本任务两个目标文件单独分析通过。
- 构建与真机：Debug APK 构建成功（Gradle 报现存 cryptography_flutter KGP 迁移提示）；APK 已安装到 Xiaomi 23116PN5BC（serial `145a0a68`），`install -r` 返回 `Success`，`pm path` 有效，`pidof` 返回 `19675`，`MainActivity` 为 resumed。
- 指挥层代码与工作树审查通过；保留任务外已有工作区修改，等待用户在真机查看。
- 用户根据实机截图再次修正：一级分类“其他”置首，其余维持 `sortOrder` 倒序；二级液态玻璃明确要求匹配导航栏的点击移动效果与背景模糊。
- 新增 RED 用例确认旧顺序仍把“其他”置末、点选后没有移动玻璃胶囊；实现比较器更新为“其他”首位，并在 Liquid Glass 网格加入跟随触点/滑动移动的 220 ms 玻璃选中胶囊。点选后留出 150 ms 展示动画；滚动时同步胶囊位置。
- 液态玻璃弹层及移动胶囊显式复用导航 tint 和 5 dp blur；高对比度下 blur 为 8 dp。
- 新增排序与移动胶囊用例，`flutter test --no-pub test/quick_add_redesign_test.dart` 共 28 项通过；3 个目标文件 analyze 无问题。
- 最新 Debug APK 构建成功并再次安装至 Xiaomi 23116PN5BC；`install -r` 返回 `Success`，`pm path` 有效，进程 PID `26621`，前台 `MainActivity` 已确认。Gradle 仍仅显示 cryptography_flutter 的 KGP 迁移提示。
- 用户询问背景模糊原因。审查确认：传入 `blurSigma=5` 后仍优先选择 runtime shader，导致 sigma 参数没有生效；现将显式 blur 覆盖改为真正使用 `ImageFilter.blur`，正常/高对比度分别采用导航胶囊的 5/8 dp，同时默认未指定 blur 的 surface 保持原 shader 路径。
- 模糊修复后目标 widget 测试仍为 28 项通过、3 个目标文件 analyze 无问题，Debug APK 构建成功。覆盖安装时 ADB 报 serial `145a0a68` not found；`adb reconnect` 与重启 ADB server 后设备列表仍为空，本次最新 APK 尚未安装。等待设备重新连接后完成安装验收。

- 用户让再次尝试安装后，ADB 发现 Xiaomi 23116PN5BC（serial 145a0a68）；最新版 Debug APK 覆盖安装返回 Success。
- 已启动 com.algive.jizhang_app/.MainActivity；dumpsys activity 确认其为 topResumedActivity，pidof 返回 PID 28857。应用当前已在手机前台，可供用户查看。
- 验收进度：最新 APK 安装与启动已确认；浮层最终视觉仍待用户真机查看反馈。

- 用户澄清仍要压暗弹层外页面来聚焦二级分类；发暗问题在弹窗本体。
- 新增 RED 断言确认旧实现浮层 tint 只有 alpha .24、渐变覆盖度 .13/.20/.30 且含主题色；外点关闭测试经坐标校正后确认遮罩可用。
- 实现：二级外层玻璃使用白 tint、.94 覆盖度、导航 5 dp blur，并关闭主题色 shadow/渐变 tint/彩色下缘；移动胶囊仅关闭主题色修饰，默认透明度、模糊和动画保持不变。其余 AppLiquidGlassSurface 调用方仍走原默认参数。
- 验证：`flutter test --no-pub test/quick_add_redesign_test.dart` 28 项通过；三个目标文件 `flutter analyze --no-pub` 无问题；`flutter build apk --debug --no-pub` 成功；`git diff --check` 通过（仅有 CRLF 风格提示）。
- 最新 APK 已生成于 `build/app/outputs/flutter-apk/app-debug.apk`。安装前后多次运行 `adb devices -l`，并执行 ADB server 启动/重连，列表仍为空；真机安装与前台确认待设备重新出现。

- 用户要求再次尝试后，ADB 已发现 Xiaomi 23116PN5BC（serial `145a0a68`）。
- 最新 `app-debug.apk` 覆盖安装返回 `Success`，启动 `com.algive.jizhang_app/.MainActivity` 成功。
- 真机确认：`pm path` 返回安装路径；`pidof` 返回 PID `5691`；`dumpsys activity` 显示 MainActivity 为 `topResumedActivity`。最新 APK 已在手机前台，供用户查看二级分类弹层亮度。
- 本轮验收完成。
# 2026-09-24 五项改动进度

- 指挥层基线：仓库在 `E:\jizhang_1\repo`，`main` 分支；开工时已有主题、导航、记一笔、若干测试、QA 图片及 `.agent` 文档的未提交改动，均须保留。
- 已定位：会员支付资产常量在 `membership_visuals.dart`；日历月概览在滚动 ListView 末尾；主流水、搜索与首页最近流水已有长按；导入成功只显式 invalidate 两个流水 provider。
- 当前进行：三组独立文件的测试先行开发；等待执行子代理报告及指挥层验收。
- 修改文件、测试结果、发现问题、剩余风险、待验收内容：执行子代理分别追加记录。

## 2026-09-24 首页目标与导入重算子任务进度

- 已核对首页导航：`HomePage` 已按有无目标跳转 `/goals/:id` 或 `/goals`；预算及金额隐藏控件单独处理；首页两个真实流水 `TransactionTile` 已有操作层长按。
- 目标点击缺口：活动目标面板原本把左右 padding 放在 InkWell 外，面板边缘留白无法进入目标页。新增稳定面板边缘命中测试；原实现观察到点击未触发。现将 padding 移入覆盖全宽的 InkWell，语义 label 保留。点击目标路由仍由既有 `HomePage.onGoal` 提供。
- 导入刷新依赖：成功路径在 `saveAll` 后才 invalidates `transactionsProvider` 与 `allTransactionsProvider`；`budgetOverviewProvider`、本地洞察与远端洞察都 watch 当前账本 `transactionsProvider`，底层为 Drift `watchActive(bookId)`，新数据在提交后 stream emission 时被重新读取。全重复行在保存前返回；普通保存异常不刷新。
- 发现部分提交缺口：`QuickBookkeepingService` 可在 `createAll` 已提交后因设置/附件/智能处理失败而抛出 `BookkeepingCommittedException`。原导入 catch 将其显示为失败且不刷新。已新增专门恢复处理器：仅非空已提交记录刷新账本与跨账本流水视图，并提示“已导入，流水已保存，请勿重复导入”，然后关闭导入页；未提交异常保留错误行为。
- 修改文件：`lib/features/home/presentation/home_cards.dart`、`lib/features/bill_import/presentation/bill_import_page.dart`、新增 `lib/features/bill_import/application/bill_import_commit_handler.dart`、`test/home_redesign_visual_test.dart`、新增 `test/bill_import_commit_handler_test.dart`、新增 `test/bill_import_insight_refresh_test.dart`。
- RED/GREEN：目标 padding 用例以稳定 `home-goal-panel` 坐标在旧实现失败，改后通过；提交异常恢复用例在禁用处理器时观察到刷新次数为 0 而预期 1，恢复处理器后通过。
- 测试：`flutter test --no-pub test/bill_import_insight_refresh_test.dart` 通过，使用真实三个月流水与 `FinancialInsightEngine`，导入前个人账本无建议，导入后出现 ¥350–420 的餐饮预算建议；另一账本已有同等历史仍不会污染个人账本。
- 回归：`flutter test --no-pub test/home_redesign_visual_test.dart test/home_amount_visibility_test.dart test/home_recent_transactions_test.dart test/bill_import_commit_handler_test.dart test/quick_bookkeeping_service_test.dart` 全部通过（30 项）；随后提交异常与真实建议两组测试复跑 3 项通过。覆盖首页目标点击、预算/隐藏金额、真实流水更新、保存后处理异常和 bookkeeping 服务。
- 分析：6 个目标文件 `flutter analyze --no-pub` 无问题；`git diff --check` 通过。Flutter 仍输出既有 `alipay_kit_ios` iOS 默认插件提示；与本任务 Android/widget 路径无关。
- 风险/待验收：成功、已提交异常按当前活动账本流水更新；全重复在刷新前短路，普通未提交异常不刷新。已提交异常页面已离开时不使用已 dispose 的 `WidgetRef`，后续页面仍从数据库读取。等待指挥层独立审阅与组合验收。

## 2026-09-24 支付图标子任务进度

- 已完成：抽取共享 `PaymentBrandIcon` 与微信/支付宝资源常量；会员支付卡改用同一组件；账户管理头像、资产账户 glyph、记一笔当前账户 chip / 账户选择器 / 转账账户对改用对应会员 PNG。通用钱包、银行卡等图标语义保留；资产截图不视为支付品牌图标。
- 修改文件：`lib/core/widgets/payment_brand_icon.dart`（新增）、`lib/features/membership/presentation/membership_visuals.dart`、`lib/features/accounts/presentation/account_management_page.dart`、`lib/features/accounts/presentation/asset_dashboard_icons.dart`、`lib/features/bookkeeping/presentation/quick_add_sheet.dart`（仅账户图标局部）、`test/payment_brand_icon_test.dart`（新增）、`test/quick_add_redesign_test.dart`（默认微信账户品牌图标断言）。
- RED/GREEN：共享组件测试初始因文件/API 缺失编译失败；记一笔集成断言在账户图标回退原 Icon 时按预期失败，恢复品牌组件后通过。
- 测试：`flutter test test/payment_brand_icon_test.dart`、`flutter test test/membership_page_ui_test.dart`、记一笔默认展示定向测试通过。范围 `flutter analyze` 无问题；`git diff --check` 通过。
- 问题与风险：Flutter 持续报告 `alipay_kit_ios` 缺失的既有 iOS 默认插件提示；不影响 Android/widget 测试。未运行整套测试或 APK 构建，留待指挥层组合验收。
- 等待指挥层验收。

## 2026-09-24 消费日历与流水长按子任务

- 已完成日历 UI 盘点：月概览原在滚动 ListView 最后，改为 Scaffold `bottomNavigationBar` 内固定卡片，四周保留间距与阴影；SafeArea 保留底部安全区，内容最多占屏高 40%，极端文字缩放时卡片区域可内部滚动，日历和流水仍有 body 滚动区。
- 已给消费日历选中日、账户详情、资产概览近期变动、报销卡片，以及分期详情原始消费行和分期列表原始消费按钮接入现有 `showTransactionActions`。原有单击 `openTransactionDetail` 与报销卡片内“登记回款”按钮保留。
- 窄屏与大字验收先发现日历日期格的固定高度在辅助文字缩放下溢出；将字号增高对应的日期格高度增长系数从 24 调至 36，320×640 / 1.8 倍文字用例现无布局异常，月概览仍固定在屏内且可命中。
- 修改文件：`lib/features/calendar/presentation/consumption_calendar_page.dart`、`lib/features/accounts/presentation/account_detail_page.dart`、`lib/features/accounts/presentation/asset_overview_page.dart`、`lib/features/reimbursements/presentation/reimbursement_page.dart`、`lib/features/installments/presentation/installment_plan_detail_page.dart`、`lib/features/installments/presentation/installment_plans_page.dart`、`test/consumption_calendar_test.dart`。
- RED/GREEN：消费日历月概览固定区域断言先因 Scaffold 无底栏通过失败；日历流水长按先未找到“编辑流水”操作层，连接 handler 后通过。日历长按测试滚动后定位当日真实行，再检查现有操作层。
- 测试：`flutter test --no-pub test/consumption_calendar_test.dart` 6 项通过；`flutter test --no-pub test/asset_overview_interaction_test.dart` 7 项通过；`flutter test --no-pub test/reimbursement_page_test.dart` 1 项通过；`flutter test --no-pub test/installment_plan_repository_test.dart` 4 项通过。7 个相关 Dart 源文件及日历测试 `flutter analyze --no-pub` 无问题。Flutter 输出既有 `alipay_kit_ios` 默认插件警告；资产 UI 测试有 Lite Glass 无 Impeller/祖先视图警告，均未导致失败。
- 投资详情页 `InvestmentTransaction` 属于投资域记录，仓储无编辑/删除 API，普通 `TransactionRecord` 操作层不适用；按指挥层确认，本次不引入只读伪操作或投资 CRUD。
- 剩余风险：账户详情、近期资产变动、报销及分期详情原始消费的长按为轻量回调接线，本轮没有各自新增独立 UI 手势测试；组合验收可继续审阅这些接线。Debug APK 构建、最终全任务 diff/status 由指挥层处理。
- 等待指挥层验收。

## 2026-09-24 跨账本操作作用域返工

- 指挥层审查确认日历/资产近期变动可显示 `allTransactionsProvider` 的其他账本流水，而完整操作层使用当前 `activeBookIdProvider` 下的写入服务；必须先切账本才能呈现写入动作。
- 测试先行新增 `test/transaction_actions_book_scope_test.dart`，覆盖跨账本安全确认层不显示编辑/删除，选择切换后活动账本更新且打开完整现有动作层；同账本仍直接打开完整操作层。
- `showTransactionActions` 现在在共用入口比较流水与当前账本。跨账本时仅提供提示、查看详情、切换并操作；只有 `activeBookIdProvider.notifier.select(transaction.bookId)` 完成后才递归进入原操作层；切换异常时提示失败并停止，不调用写入服务。同账本路径不变。
- 返工修改文件：`lib/features/transactions/presentation/transaction_actions.dart`、新增 `test/transaction_actions_book_scope_test.dart`。
- 当前验证：按指挥层要求暂未启动 Flutter 测试；测试需后续跑 RED/GREEN。已对两文件运行 `dart format`，`git diff --check` 通过。
- 等待指挥层解除 Flutter 测试限制后验证。

## 2026-09-24 指挥层最终组合验收

- 已独立检查本次改动的 `git diff` 与完整 `git status`；任务前已有的主题、导航、记一笔、QA 图片和未跟踪测试/文档保留，只有任务相关局部接线和新增文件进入本次实现。
- 跨账本操作测试已由指挥层运行并通过，切换前无编辑/删除项，切换后进入所属账本的原操作层，同账本入口直接打开原操作层。此前执行子代理记录的“暂未运行”已由本条更新。
- 组合测试第一组 21 项通过：跨账本操作、消费日历、支付品牌图标、导入提交异常与洞察刷新、首页目标面板。
- 扩展回归第二组 95 项通过：主流水/详情、资产、报销、分期、会员、记一笔、首页、批量记账与导入服务等。
- 对本任务涉及的 21 个 Dart 源码/测试文件运行 `flutter analyze --no-pub`，结果为 `No issues found`。全仓 `flutter analyze --no-pub` 唯一提示为开工前已存在的未跟踪 `test/zz_tmp_render_shots_test.dart:4:8` 的 `dart:typed_data` 多余导入；未修改该任务外文件。
- `flutter build apk --debug --no-pub` 成功，产物 `build/app/outputs/flutter-apk/app-debug.apk`（279168717 字节）；`git diff --check` 退出码 0。构建只有既有 `cryptography_flutter` KGP 迁移提示，Flutter 测试仍显示既有 `alipay_kit_ios` 插件配置提示，均不阻断本次 Android 构建与测试。
- 代码审查重点：会员和账户品牌图片统一由 `PaymentBrandIcon` 引用；日历底栏在 Scaffold/ SafeArea 内且大字测试无溢出；普通流水行都接入共用长按层；导入正常提交与已提交后续处理异常都触发流水 provider 失效，从而让目标建议、预算和洞察重新读取已保存流水。未发现阻断级回归，验收通过。

## 2026-09-24 消费日历卡片背景反馈

- 根因：Scaffold 默认将 body 截止在 `bottomNavigationBar` 上沿；固定卡片下方因此显示固定的 Scaffold 背景区域，视觉上像整块页面背景也固定。
- 修正：给消费日历 Scaffold 启用 `extendBody: true`，日历 ListView 现在延伸到卡片背后；底栏包装没有不透明填充，只有 `AppCard` 自身绘制卡片表面，SafeArea 与卡片固定位置不变。
- 验证：目标页面 `flutter analyze --no-pub` 通过，`git diff --check` 通过。未运行测试。
- 修改文件：`lib/features/calendar/presentation/consumption_calendar_page.dart`；本节追加于 `.agent/PLAN.md`、`.agent/ACCEPTANCE.md`、`.agent/PROGRESS.md`。

## 2026-09-24 首页分类流水弹层与多指标趋势

- 当前阶段：已定位分类筛选 ID 键不一致；趋势图已有收入/支出点位模型与绘制器，首页当前仅显示支出线。按默认方案采用三线同图、净资产口径。
- 当前工作树：`main` 上含大量先前未提交改动；本任务只追加任务文档并修改首页分类弹层与趋势图相关 Dart 源码。
- 修改文件、静态分析/构建结果、发现问题与剩余风险：待实现后追加。
- 等待指挥层独立审查。

## 2026-09-24 首页三指标趋势子任务进度

- 已完成：首页趋势组件显示支出、收入、净资产三条线；周/月/年选择与点选状态保留，点选后在图上方显示所选日期三项金额及语义文本。支出采用当前主题主色，收入使用 `AppColors.income`，净资产使用橙色 `AppColors.warning`。
- 数据口径：首页分析流水序列沿用 `StatisticalAnalysisService` 的退款后净支出及入账收入；净资产从首页当前资产币种的账户记录历史重建，叠加投资日快照，当前日使用实时投资市值。月视图按月累计收入、支出，净资产取当月最后一个日点。净资产账户币种依 `AssetOverview.group` 与首页资产卡相同的优先顺序选择。
- 修改文件：`lib/core/models/analysis.dart`（CashflowPoint 可选净资产字段）、`lib/core/widgets/cashflow_trend_chart.dart`（仅新增 opt-in 三序列绘制参数，分析页默认路径保留原颜色和绘制行为）、`lib/features/home/presentation/home_expense_trend.dart`（数据组装、月聚合与首页呈现）。未改首页分类弹层。
- 实际命令：`dart format lib/core/models/analysis.dart lib/core/widgets/cashflow_trend_chart.dart lib/features/home/presentation/home_expense_trend.dart`；`flutter analyze --no-pub lib/core/models/analysis.dart lib/core/widgets/cashflow_trend_chart.dart lib/features/home/presentation/home_expense_trend.dart` 输出 `No issues found! (ran in 3.3s)`；最后修改首页语义文本及币种选择后再次格式化并运行相同范围分析，输出 `No issues found! (ran in 3.6s)`；`git diff --check` 退出码为 0（Git 输出工作区已有 LF/CRLF 转换提示）。按指挥层约束，没有新增或运行测试，也未运行 Debug APK build。
- 未决风险：历史 `InvestmentSnapshot` 模型只存全投资组合总市值，不含币种分拆；当投资持仓包含多币种时，历史日快照无法像当前投资金额一样精确限定到资产卡首选币种。没有修改数据库 schema；请指挥层审查是否接受现有快照模型的此限制。新建账户/投资组合导致快照历史不足时，缺少早于最早快照的日期会按 0 投资值显示。
- 待指挥层审查：核对三线比例与橙色资产色、非 CNY 首选资产组表现、组合多币种快照限制；独立复核 diff/status，并在组合验收时完成要求的 Debug APK build。
- 指挥层审查后的返工：选中金额与指标名称改为“总资产净额”；如果日期早于首条可用投资快照且当前仍有投资市值，该日期的净资产改为 `null`，图上跳过该段，点选文本显示“暂无历史估值”，不会捏造零投资历史。无投资持仓且无历史快照时仍按账户净资产计（投资额为零）。修订后再次运行范围分析，输出 `No issues found! (ran in 3.3s)`；未新增或运行测试。
## 2026-09-24 首页趋势币种审查返工

- 已修正历史投资快照的币种门控：只有当前投资持仓存在且全部属于趋势资产币种时，才将无法按币种拆分的全组合历史快照用于该资产趋势；投资币种混合、币种不匹配、当前无持仓但存在历史快照时，历史净资产点返回不可用；当前日仍使用 `investmentValueByCurrencyProvider[trendCurrency]` 的精确值。确实无当前持仓且无任何快照时才将投资额视为零。
- 总资产净额选中金额及 Semantics 改为显示真实资产币种代码/单位；支持 CNY、USD、EUR、GBP、JPY 对应符号，其他币种显示币种代码。收入和支出仍按 CNY 显示。
- 修改文件：`lib/features/home/presentation/home_expense_trend.dart`。验证：`dart format lib/features/home/presentation/home_expense_trend.dart`；`flutter analyze --no-pub lib/core/models/analysis.dart lib/core/widgets/cashflow_trend_chart.dart lib/features/home/presentation/home_expense_trend.dart` 输出 `No issues found! (ran in 3.5s)`。未新增或运行测试。
## 2026-09-24 首页趋势总资产口径返工

- 按用户澄清，资产线改为“总资产”：历史时点逐个账户调用 `AssetHistory.balanceAt(date, accountId: account.id)`，只累计正余额的整数分，再加该资产币种的投资市值；负余额不抵扣。选中指标及 Semantics 已从“总资产净额”改为“总资产”，保留币种代码/符号。
- 修改文件：`lib/features/home/presentation/home_expense_trend.dart`。验证：`dart format lib/features/home/presentation/home_expense_trend.dart`；`flutter analyze --no-pub lib/core/models/analysis.dart lib/core/widgets/cashflow_trend_chart.dart lib/features/home/presentation/home_expense_trend.dart` 输出 `No issues found! (ran in 3.4s)`；未运行测试或 build。
## 2026-09-24 首页趋势快照币种与字段命名复审返工

- 修正历史投资快照逻辑：旧 `InvestmentSnapshot` 是全账本聚合值且不含币种信息，不再将任何正值历史快照分配给趋势资产币种；只有日期完全匹配且总快照恰为 0 时才可按该日期投资额为 0。其他历史日期在无币种证据时总资产点不可用。当前日期仍使用 `investmentValueByCurrencyProvider[trendCurrency]` 精确值；仅在无当前投资且完全没有历史快照时才将历史投资贡献视作 0。
- 将 `CashflowPoint.netAssets`、`showNetAssets`、`netAssetsColor` 分别改名为 `totalAssets`、`showTotalAssets`、`totalAssetsColor`，与资产不扣负债的口径一致。
- 修改文件：`lib/core/models/analysis.dart`、`lib/core/widgets/cashflow_trend_chart.dart`、`lib/features/home/presentation/home_expense_trend.dart`。`dart format` 后运行目标 `flutter analyze --no-pub` 输出 `No issues found! (ran in 3.3s)`；`git diff --check` 通过。未运行测试或 build。
## 2026-09-24 首页分类弹层支出口径复审修正

- 弹层流水筛选由 `isConsumptionExpense` 改为 `isExpense`，与 `StatisticalAnalysisService` 分类统计候选 `current` 及 `_cashflowCategories(current)` 一致；因此资产支出也会留在其统计分类的弹层中。未改统计业务逻辑。
- `.agent/PLAN.md` 与 `.agent/ACCEPTANCE.md` 已将“消费支出”措辞改为当前 `isExpense` 分类统计支出口径，并明确包括资产支出。
- 修改文件：`lib/features/home/presentation/home_page.dart`、`.agent/PLAN.md`、`.agent/ACCEPTANCE.md`、`.agent/PROGRESS.md`。`flutter analyze --no-pub lib/features/home/presentation/home_page.dart` 输出 `No issues found! (ran in 4.1s)`；`git diff --check` 通过。未运行测试。
## 2026-09-24 首页趋势未来流水门槛复审

- 首页资产趋势现遵循 `AssetHistory.hasFutureRecords` 门槛：检测到未来日期流水后，历史日期的总资产点置为不可用；当前日期改由趋势币种账户的当前正余额逐户汇总并加精确当前投资市值，不调用 `balanceAt(endOfDay)`。没有未来日期流水时，仍通过 `AssetHistory.balanceAt` 重建历史日余额。
- 修改文件：`lib/features/home/presentation/home_expense_trend.dart`。`dart format` 后运行目标 `flutter analyze --no-pub` 输出 `No issues found! (ran in 3.4s)`；`git diff --check` 通过。未运行测试或 build。

## 2026-09-24 指挥层最终验收

- 独立复核分类键与统计分类共用、当前账本/周期/CNY/删除状态过滤、日期和金额双向排序、半屏弹层和可滚动流水；未发现阻断问题。
- 独立复核支出、收入、总资产三线颜色和选中金额，确认总资产按正余额账户加投资市值且不扣负债；旧投资快照缺少币种时不猜测，存在未来日期流水时遵守 `AssetHistory.hasFutureRecords` 停用历史值；未发现阻断问题。
- 五个目标 Dart 文件 `flutter analyze --no-pub` 输出 `No issues found!`；目标文件和任务文档 `git diff --check` 退出码 0；最终 `flutter build apk --debug --no-pub` 成功。构建输出仅含现存 `cryptography_flutter` KGP 迁移提示。
- 未新增或运行测试；本轮保留工作区开工前已有的其他修改与未跟踪文件，没有提交或覆盖它们。
- 验收完成。

### Task 1：投资持仓首页净资产 inclusion 持久化与迁移
- 已完成：`InvestmentHolding` 与 `AddInvestmentRequest` 默认 `includeInHomeNetAssets=false`；`copyWith` 支持更新该值；Drift 列默认 false，仓储写入/读回映射新增字段；schemaVersion 升为 22。v22 迁移在检查列不存在后才添加，覆盖 v18 以下迁移期间新建持仓表的情况。
- 修改文件：`lib/core/database/app_database.dart`、生成文件 `lib/core/database/app_database.g.dart`、`lib/features/investments/domain/investment_holding.dart`、`lib/features/investments/data/investment_repository.dart`、`test/investment_repository_test.dart`、`test/account_management_schema_test.dart`、`.agent/PROGRESS.md`。
- RED：按要求运行 `flutter test --no-pub test/investment_repository_test.dart test/account_management_schema_test.dart`；缺少 request 参数和 holding 字段时报预期编译错误。最初测试中另有一个 portfolio 属性误写（应为 `investmentValue`），修正后未留下该错误。
- Drift 生成：`dart run build_runner build --build-filter=lib/core/database/app_database.g.dart` 完成，生成 Drift 持仓实体、companion 与 DAO 所需代码。
- GREEN：再次运行同一目标测试命令，22 项通过；覆盖默认 false、显式 true 后重读为 true、关闭项仍包含在完整组合及投资市值中，以及启用记录后删列并设置 user_version=21 的迁移夹具；升级后原记录保留、市值不变且 inclusion 为 false。schema 版本断言为 22。
- 检查：`flutter analyze --no-pub` 对本任务 6 个 Dart 源文件/测试输出 `No issues found!`；本任务目标文件 `git diff --check` 退出码 0。输出了 Flutter 已有的 `alipay_kit_ios` 插件声明缺失警告；不影响测试通过。
- 指挥层验收：独立规格审查通过；独立代码质量审查无 Critical/Important，判定可以继续。审查者建议可额外覆盖 `<18` 升级路径；当前迁移的列存在性判断已防止新表路径重复加列，该项作为次要覆盖建议记录。
- 剩余风险：无本任务已知风险；旧插件警告为仓库既有环境提示。本任务未接入表单/provider/UI。

## 2026-09-24 资产总览分布与投资计入首页开关

- 当前阶段：Task 1、Task 2 均通过独立规格和质量审查；开始 Task 3（资产分布/变化卡片、详情与弹层）。

- 当前阶段：已获用户确认布局及默认关闭口径；规格文档已审阅，实施计划已完成，开始拆分测试先行开发。
- 用户口径：新建投资和迁移后的既有持仓默认不计入首页账目净资产；其完整数据仍在投资管理中。
- 已定位：窄屏 `_ChartPair` 阈值为 380dp；分布图只由账户生成 entries；资产详情由透明底色的 modal 路由承载；投资净值 provider 当前按币种汇总全 portfolio。
- 任务计划：`docs/superpowers/specs/2026-09-24-asset-overview-investment-design.md`、`docs/superpowers/plans/2026-09-24-asset-overview-investment.md`。
- 已修改文件：Task 1 已修改数据库/生成模型、投资持仓实体与仓储，以及对应迁移/仓储测试；完整列表见上方记录。接续任务仅做表单与首页 provider。
- 测试结果：持仓仓储与 schema 测试已按 TDD 观察 RED，再 GREEN 通过；详情见下方 Task 1 记录。
- 已发现问题/剩余风险：需验证录入开关与 provider 作用域；资产总览详情弹层黑色条纹仍需在真实 modal 路由中复现并定位。
- 等待指挥层验收：投资持久化/开关任务及资产总览 UI 任务完成后，逐项进行 spec review、quality review 和组合验收。

### Task 3：资产分布/变化卡、详情与 modal footer
- 修改文件：`lib/features/accounts/domain/asset_overview.dart`（共享过滤后的 `distributionEntries` 和零总额安全占比）；`lib/features/accounts/presentation/asset_dashboard_charts.dart`（compact/detail 共用条目与金额/占比；趋势卡和趋势详情独立显示当前计入投资市值）；`lib/features/accounts/presentation/asset_overview_page.dart`（资产总览改读 `includedInvestmentValueByCurrencyProvider`、320/393dp 持续并排、空账户投资组跳过依赖 `accounts.first` 的负债区、modal Surface 延伸至系统底部 inset 且滚动内容保留 SafeArea）；`test/asset_management_test.dart`、`test/asset_overview_layout_test.dart`、`test/asset_overview_interaction_test.dart`。
- TDD RED：分布 compact/detail 测试实际因没有“投资管理”项而失败（0 个匹配）；320dp 和 393dp 布局测试测得图卡上下错开 188dp，430dp 测试因趋势卡没有当前投资值语义 key 失败。首轮紧凑图例改为横向并排名称/金额后，320dp/1.6 倍字号暴露 RenderFlex 横向溢出（最大 72dp）；图例紧凑模式改为名称、金额、占比三行后解决，项目金额/占比仍右对齐。旧 v6 migration 测试断言 schemaVersion 18 与 Task 1 当前 schemaVersion 22 不符，按指挥层要求更新为 22。
- Modal 复现与根因：真实 `ModalBottomSheetRoute<void>` 在测试 View 同时设置 `padding`/`viewPadding` 的 24dp 底部系统安全区后，透明 route 背景下 `_AssetSheetFrame` 的外层 `SafeArea` 把 FractionallySizedBox/Material 提前截在安全区上方；被 route barrier 暗化的底层 surface 露出全屏横带。RED 截图 frame.bottom 为 y=879、root 高 935；y=879–902 连续 24 行每行 207/207 个采样点 RGB<128，测得 RGB 约 115–117。仅调整该页弹层：外层 SafeArea 不消费 bottom inset，让 Material 填到底部安全区；内容 ListView 内使用 SafeArea。GREEN frame.bottom 到 y=903 覆盖该带，底部 80px 范围无全屏暗行（剩余行 RGB 约 245–249）。已检查完整 route 截图：顶边圆角与表面完整，投资金额/百分比清晰，底部没有条纹；真实 sheet 的滚动、关闭、周期按钮与图表拖动交互均通过。诊断 PNG/打印逻辑已从测试移除，保留稳定的底部像素断言。
- GREEN/最终测试：`flutter test --no-pub test/asset_management_test.dart test/asset_overview_layout_test.dart test/asset_overview_interaction_test.dart` 共 13 项通过；覆盖排除账户、投资管理单独行/金额/百分比、零总额、320/393/430dp 同一行与无溢出、趋势当前投资与 ledger delta 分离、route footer 无暗条和 modal 滚动/交互。执行后精确恢复了布局测试生成的两张开工前 clean QA PNG。
- 检查：6 个目标 Dart 文件的 `flutter analyze --no-pub ...` 输出 `No issues found!`；目标文件 `git diff --check` 退出码 0。对 domain/chart/三份测试运行 `dart format`，资产总览页只做局部编辑以保留开工前流水长按 `showTransactionActions` 改动，未整文件格式化。Flutter 输出仓库既有 `alipay_kit_ios` 插件声明警告与测试环境 LiquidGlass refraction fallback 提示。
- 剩余风险：没有 Android 真机连接；footer 由真实 Flutter modal route + 24dp system-safe-area widget viewport 覆盖。未提交代码。

#### Quality review 返修：紧凑图例固定滚动视口
- 复核发现 compact legend 的纵向 `SingleChildScrollView` 在 `_ChartPair` 的无界垂直约束下没有有限 viewport，多账户时会把资产分布卡撑高。先加入 8 条账户的 regression test 并观察 RED：viewport 实测 315dp，目标 95dp。
- 仅 compact 分支将滚动区域包进 `SizedBox(height: 95)`，为滚动视口增加 `asset-distribution-legend-scroll` key；回归断言固定视口为 95dp、卡片高度小于 200dp、向上滚动后账户 8 位置上移且无 Flutter exception。
- GREEN：新增回归单测通过；完整 `test/asset_overview_interaction_test.dart` 5 项通过；`test/asset_overview_layout_test.dart` 在 320/393/430dp 三种宽度 3 项通过。布局测试运行后精确恢复了原先干净的 `asset-overview-393-top.png` 与 `asset-overview-393-lower.png` 两张 QA 图，最终这两个路径无工作区差异。
- 最终用稳定 key 重新运行完整 interaction 文件：5 项通过；3 个返修目标 Dart 文件 analyze 输出 `No issues found!`，对应源/测试/进度文件 `git diff --check` 通过。两张参考 PNG 状态干净。测试输出仍有既有 `alipay_kit_ios` 插件警告与测试环境 LiquidGlass fallback 提示。

### 指挥层最终验收
- RED/GREEN 目标测试、追加图例 viewport 修复后的独立 spec review、quality review 均通过；quality review 的 95dp 滚动视口发现已返修并复审为 Ready yes。
- 独立组合命令 `flutter test --no-pub test/investment_repository_test.dart test/account_management_schema_test.dart test/investment_flow_test.dart test/home_asset_card_test.dart test/home_asset_scope_test.dart test/asset_management_test.dart test/asset_overview_layout_test.dart test/asset_overview_interaction_test.dart` 共 59 项通过。
- 16 个本任务目标源码与测试文件 `flutter analyze --no-pub` 输出 `No issues found!`；`git diff --check` 通过；最终 `flutter build apk --debug --no-pub` 成功，APK 位于 `build/app/outputs/flutter-apk/app-debug.apk`。
- 已独立复核 Task 1–3 关键 diff、全量 `git status --short` 与保留的 `asset_overview_page.dart` 流水长按改动；布局测试写入的两张 QA PNG 已恢复至开工前干净状态。其他开工前用户未提交修改均保留，未清理/覆盖，未提交代码。
- 验收完成。构建/测试仅出现既有 `alipay_kit_ios` 插件声明警告、`cryptography_flutter` KGP 迁移提示及测试环境无 Impeller 的 LiquidGlass fallback 提示。

## 2026-09-24 消费日历、反馈提示与统一日期时间样式

- 当前阶段：实现、测试、独立审查和构建均通过；验收完成。
- 任务文档：`docs/superpowers/specs/2026-09-24-calendar-feedback-time-style-design.md`、`docs/superpowers/plans/2026-09-24-calendar-feedback-time-style-plan.md`。
- 已发现根因：日历内部 `extendBody` 让正文穿透固定概览；默认 SnackBar 落在全局导航/FAB 后；8 个业务入口仍直接调用旧 `showDatePicker`。
- 修改范围：日历页、共享 SnackBar/日期组件、记一笔和上述 6 个业务页面，以及对应测试；不覆盖任务前已有未提交内容。
- 当前进行：无；任务验收完成。
- 测试结果：37 项主回归、7 项日期组件兼容测试通过；14 项范围静态分析无问题；Debug APK build 成功。
- 已发现问题/剩余风险：Flutter 测试输出既有 `alipay_kit_ios` 插件声明缺失警告；Android build 输出既有 `cryptography_flutter` Kotlin Gradle Plugin 迁移提示，均不影响本次测试/构建。

### Task 1：修复消费日历正文被本月概览遮挡
- 修改文件：`lib/features/calendar/presentation/consumption_calendar_page.dart`（移除内部 Scaffold 的 `extendBody: true`）；`test/consumption_calendar_test.dart`（在既有固定概览滚动测试中断言正文 ListView 底部不越过“本月概览”标题顶部）；`.agent/PROGRESS.md`。
- RED：`flutter test test/consumption_calendar_test.dart --plain-name "monthly overview stays visible while calendar body scrolls"` 失败，断言 `bodyRect.bottom <= overviewRect.top` 实际为 `640.0 <= 391.917...` 不成立，确认正文延伸到概览卡片后方。
- GREEN：移除 `extendBody: true` 后同一单测通过（`All tests passed!`）；`flutter test test/consumption_calendar_test.dart` 共 6 项通过。
- 格式与差异检查：`dart format lib/features/calendar/presentation/consumption_calendar_page.dart test/consumption_calendar_test.dart` 完成；`git diff --check` 退出码 0。测试期间 Flutter 反复提示已有 `alipay_kit_ios` iOS 默认实现缺失警告。
- 剩余风险：本次仅验证消费日历目标测试文件；Flutter 插件警告与本任务布局修复无关。日历源码和测试原已有其他未提交改动，保留未覆盖。

### Task 2：统一记账反馈提示的颜色和层级
- 修改文件：新增 lib/core/widgets/app_snack_bar.dart；局部接入 lib/features/bookkeeping/presentation/quick_add_sheet.dart；新增 test/app_snack_bar_test.dart，并在 test/quick_add_redesign_test.dart 的真实保存用例中增加反馈样式断言。
- TDD RED：运行 `flutter test --no-pub test/app_snack_bar_test.dart`，确认因 AppSnackBar 文件/API 不存在而编译失败。
- TDD GREEN：实现基于 AppNavGeometry 的浮动 SnackBar；helper 单测通过；真实记一笔保存用例验证消息仍为“已保存到本地账本”、浮动行为、主题背景色和底部间距均通过。
- 测试：`flutter test --no-pub test/app_snack_bar_test.dart test/quick_add_redesign_test.dart` 共 30 项通过；目标 `flutter analyze --no-pub` 输出 No issues found!。新增覆盖旧提示队列清理；真实保存用例覆盖浮动位置、主题底色和安全区间距。
- 独立审查返修：附件读取、替换、重试错误均已改走共享 helper；helper 清理待显示队列。成功/部分成功路径在 pop 前捕获 messenger 与 SnackBar，并在显示新反馈前清队列，避免旧提示插队。
- 既有 test/widget_test.dart 中一个完整导航用例在当前工作树仍因找不到 QuickAddButton 而失败；该文件的临时修改已撤回，不纳入本任务修复范围。
- 剩余风险：待最终组合回归检查；所有记一笔内部校验、附件异常、保存成功和部分成功提示目前均使用统一浮动主题样式。

### Task 3：统一日期选择器样式
- 新增 `AppDatePicker` 范围参数和初始日期夹取逻辑；范围回归测试先因 `minimumDate` 参数不存在而编译失败，随后实现并通过。
- 纯日期和日期+时间公共样式分别由 `AppDatePicker` 与记一笔的 `TimeSelector` 提供；扫描确认其他模块无直接 Cupertino/Material 时间选择器。
- 已迁移 8 个业务 `showDatePicker` 调用，涉及应收详情/表单、受限账户详情/表单、财务中心和目标创建；保留各自原最早/最晚日期。
- 范围回归覆盖边界传递与超范围 initial clamp；`flutter test --no-pub test/app_date_picker_test.dart test/recurring_bill_create_sheet_test.dart test/investment_responsive_test.dart` 共 7 项通过。
- 全部 14 个相关源文件/测试的 `flutter analyze --no-pub` 输出 `No issues found!`；`rg` 确认 `lib/` 中没有业务 `showDatePicker` 或 `showTimePicker`；`git diff --check` 退出码 0。
- 日期入口迁移具体边界：应收提醒当天至 +5 年、发生日期 −10 至 +5 年、预计到账 −5 至 +10 年；应收表单 −5 至 +20 年；受限账户 −1 至 +20 年；财务中心 2000–2100；目标创建今天至约 +50 年。

### 最终组合复核补充
- 为直接覆盖用户提到的两个底部元素，日历测试滚动到底后新增真实当天消费流水，并断言该流水标题、“记一笔”和“本月概览”都 hit-testable。
- 首次带真实记录的 320dp/1.8 倍字号测试暴露选中日期格 RenderFlex 底部溢出 4.4dp。根因是格高自适应最多按 1.6 倍计算；上限提高到 1.8 倍并复跑后，日期记录和按钮可点，测试无溢出。
- `flutter test --no-pub test/app_date_picker_test.dart test/app_snack_bar_test.dart test/quick_add_redesign_test.dart test/consumption_calendar_test.dart` 共 37 项通过；日期组件补充 `test/recurring_bill_create_sheet_test.dart`、`test/investment_responsive_test.dart` 共 7 项通过。
- 14 个目标源文件与测试范围 `flutter analyze --no-pub` 输出 `No issues found!`；`git diff --check` 通过；最终 Debug APK 构建和独立复审待完成。
- 两轮独立只读审查均 PASS；第二轮确认 1.8 倍字号高度上限、真实记录/按钮 hit-test 和日期最大边界夹取测试无具体问题。
- 最终 `flutter build apk --debug --no-pub` 成功生成 `build/app/outputs/flutter-apk/app-debug.apk`；最终 `git diff --check` 退出码 0，业务层旧 Material 日期/时间弹窗扫描无匹配。
- 指挥层检查了本轮目标文件差异和全量 `git status --short`；工作区开工前已有的其他修改/未跟踪文件均保留，未提交代码。
- 验收完成。

### Task 2：新增投资计入首页开关与首页 provider 接线
- 修改文件：`lib/features/investments/presentation/investment_add_page.dart`（表单默认关闭开关、标题旁可点击 tips、请求带入开关状态）；`lib/features/investments/data/investment_repository.dart`（新增按币种过滤的 `includedInvestmentValueByCurrencyProvider`，完整 provider 保留）；`lib/features/home/presentation/home_page.dart` 与 `lib/features/home/presentation/home_expense_trend.dart`（首页资产卡和趋势当期金额改读 filtered provider）；`test/investment_flow_test.dart`、`test/home_asset_scope_test.dart`。
- 表单 RED：先改 `test/investment_flow_test.dart` 并运行对应 manual-add 用例，失败在预期断言：`investment-include-in-home-net-assets` 为 0 widgets。提示精确文案与切换保存断言随该用例覆盖。
- Provider RED：先加默认关闭/显式开启、CNY/USD 多币种组合测试；运行 `flutter test --no-pub test/home_asset_scope_test.dart`，因新 provider 尚未定义而在 provider 标识处编译失败，确认新 API 缺失。初次 GREEN 测试因 ProviderContainer 没有持续监听 StreamProvider 而等待超时；测试调整为显式 listen 后立即通过，无产品逻辑变更。
- GREEN：表单测试分别验证默认关闭持久化 false、点击提示显示完整原文、启用后持久化 true；provider 测试验证完整 map 为 CNY 125/USD 12，filtered map 为 CNY 25/USD 3。完整投资组合 provider 未过滤，投资管理总览继续直接消费完整 `investmentPortfolioProvider`；首页资产卡与趋势当期 provider 读取点已审查为 filtered provider。
- 指定目标测试 `flutter test --no-pub test/investment_flow_test.dart test/home_asset_card_test.dart test/home_asset_scope_test.dart test/investment_repository_test.dart` 通过（42 项）；目标 Dart 源与测试范围 `flutter analyze --no-pub` 输出 `No issues found!`；`git diff --check` 退出码 0。
- 初审发现的首页 consumer 测试缺口已通过独立 `/` HomePage 集成用例关闭：full portfolio 130 CNY、HomeAssetCard filtered 值 30 CNY、HomeExpenseTrend 当日 Semantics 30 CNY；消费者接线临时改回 full provider 时 RED，恢复后 GREEN。独立 spec re-review 与格式返修后的 quality re-review 均通过；目标测试最终 43 项通过。仅保留 Flutter 已有插件/无 Impeller 环境提示。

#### 独立 spec review 返修：首页 consumer integration coverage
- 新增 `investment_flow_test.dart` 真实首页集成测试：memory DB + 真实 ProviderContainer/GoRouter 渲染 `/`；经真实投资仓储写入默认关闭的 CNY 100 与显式开启的 CNY 30 两仓；断言完整 portfolio 保留两仓且总值 130，HomeAssetCard consumer 实际收到 `{'CNY': 30}`，`home-trend-chart` Semantics 当日总资产为 `30.00 CNY`。
- TDD RED：新增断言后，在现有 filtered consumer 下首次运行业务断言已满足；按 review 要求临时将首页资产卡与趋势两个生产读取点改回 full provider，定向测试按预期失败：资产卡实际 `{'CNY': 130.0}`，预期 `{'CNY': 30}`。随后恢复两个 filtered provider，定向测试 GREEN。
- 测试 harness：首页 provider 存在 650ms 的既有 insight 延时定时器；测试末尾受控 pump 700ms 后 teardown 清洁，无定时器泄漏。
- 返修后目标测试四文件共 43 项通过；7 个范围 Dart 文件 analyze 输出 `No issues found!`；`git diff --check` 退出码 0。测试输出仍有既有 `alipay_kit_ios` 插件警告与无 Impeller 下的 glass refraction 提示。

#### Quality review Minor 返修：测试格式
- 按 `git diff HEAD -- test/home_asset_scope_test.dart` 定位本次新增 provider 测试中长 `test(...)` 声明、provider override 与 listen 调用的 formatter 换行，并仅修正新增块；未对整个文件运行写入式 format，既有账本作用域测试未改动。
- 重跑 Task 2 四个目标测试文件共 43 项通过；7 个范围 Dart 文件 analyze 输出 `No issues found!`；`git diff --check` 退出码 0。

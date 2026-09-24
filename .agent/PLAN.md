# 2026-09-23 二级分类浮层交互恢复

指挥层维护本计划；执行子代理只读。用户最新要求覆盖先前“移除滑动手势”与保留“不细分”的旧结论。

## 目标
记一笔二级分类浮层不再显示“不细分”分类入口；保留分类数据不变；保留液态玻璃模糊效果；恢复手指跟随类别图标放大/轻移的选择动画；验证快速打开记一笔的转场和返回手势没有异常。

## 当前问题
- 当前网格由普通 GridView 与 InkWell 实现，丢失 Git HEAD 中 `_MagneticSubcategoryPicker` 的指针跟随放大/拖动松手选择能力。
- 上一轮视觉改动将“不细分”移到 48dp footer，现在需按最新指示删掉，不可再次放回其他位置。
- `AppGlassSurface` 在 liquidGlass theme 下提供 BackdropFilter blur，需保留该路径。
- `showQuickAddSheet` 使用 `MaterialPageRoute(fullscreenDialog: true)`；点击入口采用现有转场，edge swipe 对 modal 路由禁用属于当前路由设计，需要系统返回和入口转场覆盖。

## 涉及文件
- `lib/features/bookkeeping/presentation/quick_add_sheet.dart`
- `test/quick_add_redesign_test.dart`
- 验证 `test/ios_swipe_back_parity_test.dart`
- `docs/development/2026-09-23-category-bubble-and-taxonomy.md`
- `docs/superpowers/plans/2026-09-23-category-bubble.md`

## 实施顺序
1. 先更新 widget 测试：二级列表无“不细分”；指针滑动时焦点项放大、松手选择原类别 ID；列表滚动仍可用；液态玻璃保持 BackdropFilter；系统返回按顺序关闭浮层与记一笔。
2. 运行测试看缺失动画/入口断言按预期失败。
3. 恢复 stateful pointer tracking，将视觉包裹在现有主题色裸图标样式内；类别 count 只等于实际二级分类数，不生成 parent/null category；去掉 footer。
4. 运行测试与 analyze，复核被测路由 transition、系统返回、edge swipe 对 modal 路由的预期。
5. 构建 Debug APK，安装到当前 ADB 真机 145a0a68，现场启动记一笔查看。

## 验收标准
- 一级与二级分类模板、ID、名称、排序和数据库数据不改。
- 浮层中 Text/semantics/key 均无“不细分”parent 选择项。
- 图标保持28px主题色裸图标，指针进入附近范围会放大并轻微随动；放手选择手指下类别。
- 点击单选正常；多项长列表滚动正常且纯滚动不误选。
- liquidGlass theme 的浮层含 BackdropFilter blur，截图显示可见背景的磨砂玻璃效果。
- 点记一笔后页面转场完整；系统返回先关闭 popover，随后关闭 quick-add 并完成反向转场；既有 Android edge-swipe 测试通过，fullscreenDialog 不响应边缘返回。
- 相关测试、scope analyze、Debug APK 构建、diff-check 通过；APK 安装并在真机运行。

## 风险与约束
- 当前工作树有大量任务外未提交变更，绝不能 reset/clean、覆盖或格式化整个大文件。只编辑本任务相关片段。
- 不修改分类种子、持久化分类、历史记录、账单导入、语音、全局主题/玻璃、通用路由转换。
- 用户已授权实施，无需暂停询问；不提交代码。

## 用户补充：提高二级浮层视觉焦点（2026-09-23）

### 目标与当前问题
真机截图显示打开二级分类后，浮层内部仍能清楚透见一级分类的图标与文字。用户要求页面背景进一步压暗，液态玻璃浮层更模糊且充分遮住底层内容，让二级分类成为视觉焦点。

### 实施范围
- `lib/features/bookkeeping/presentation/quick_add_sheet.dart`：浮层 route barrier 与该浮层的玻璃参数。
- `lib/core/widgets/app_glass_surface.dart`：如需新增可选的局部玻璃遮盖度参数，默认值/默认渲染必须保持原样。
- `test/quick_add_redesign_test.dart`：明确覆盖 scrim、模糊强度、遮盖度及其他主题的实色浮层。
- `.agent/ACCEPTANCE.md`、`.agent/PROGRESS.md`、`docs/qa/category-compact-2026-09-23/results.md`：同步记录和验收。

### 方案及顺序
1. 先增加 widget 断言：浮层 barrier 使用更深的主题遮罩；Liquid Glass 浮层明确使用高于全局默认的 blur sigma 和约 0.96 的玻璃层覆盖度；实色主题浮层使用不透明主题表面。
2. 运行目标测试，确认新断言在实现前按预期失败。
3. 为 `AppGlassSurface` 增加可选局部玻璃覆盖度（不改变现有调用默认外观）；二级浮层单独使用 blur sigma 32、glass opacity 0.96，并将 route barrier 提升至约 0.58。
4. 保留玻璃高光、描边和主题染色；检查真机截图中浮层外背景更暗、浮层内背景内容不可辨认，同时类别图标/文字清晰。
5. 运行目标测试、scope analyze、diff-check，重建并更新安装真机 APK，复查浮层和返回顺序。

### 避坑点
- 遮罩只压暗浮层外部；局部玻璃覆盖度必须覆盖浮层内部所有渐变 stops，否则高光/渐变的透明 stop 仍会让图标文字透出。
- 不调整全局 glass blur、不透明度或其他 AppGlassSurface 调用，也不修改分类、手势、导航和 route transition。
- 保留无子分类的 null 二级分类数据语义；不改变已有手指跟随动画和可滚动点击区域。

# 2026-09-23 页面转场旧内容穿透

## 目标与根因
- 所有普通 push、记一笔 fullscreenDialog 和 iOS/Android 侧滑返回期间，新页面的空白处不能绘出旧页面内容。
- 当前 `AppTheme.light` 将 `scaffoldBackgroundColor` 设为透明；`context.appBackground` 直接读取该值，记一笔等页面因此也是透明的。Navigator 在转场中保留前页，导致它透过新页卡片间隙可见。转场结束前页停止绘制，症状消失。

## 涉及模块与方案
- `lib/app/theme/app_theme.dart`：将默认 Scaffold 底色改为当前主题的不透明 `background`；在共用 `PageTransitionsTheme` 内给所有 Material 路由的 child 加入随转场移动的不透明底层，覆盖只返回 `SafeArea` 的页面。
- `lib/core/widgets/app_scaffold.dart`：保留 Shell Scaffold 现有显式透明与注释，让主页的 mesh 背景仍可被液态玻璃导航采样。
- `lib/core/widgets/app_page_background.dart`：背景仍在 Shell 中绘制；无需改动玻璃折射、模糊参数。
- `lib/features/autobookkeeping/presentation/ios_shortcut_bookkeeping_page.dart`：检查显式透明的整页 Scaffold；共用转场底层已覆盖，避免单页打补丁。
- `test/route_background_isolation_test.dart`：以转场中途与侧滑中途的实际像素证明新页空白区没有旧页红色内容；覆盖液态玻璃与普通主题。

## 顺序与风险
1. 加入复现测试，确认当前代码失败且确实暴露旧页像素。
2. 修改主题默认底色；补上 content-only 页面失败测试后，在共用转场内绘制路由级底层。
3. 运行定向测试、已有导航/记一笔测试、analyze、build；审查 diff/status。
- 不修改卡片间距、分类弹层、数据层或液态玻璃组件的透明度。
- 工作树现有未跟踪文件属于用户，保留原样；不 reset/clean/覆盖。

# 2026-09-23 液态玻璃导航栏选中态明度

## 任务目标与当前问题
- 用户确认修复液态玻璃主题下导航胶囊偏深、点击时选中区域与胶囊融为一体的视觉问题。
- 手机木木记账 8.2.7 的浅色栏体与浅色选中层、以及本地 8.2.8 AOT 复核，为视觉参考；两版具体色值可能不同，不照搬其他业务逻辑。
- 当前栏体由 `plateTint` 将主题表面按 `.88` 压暗后以 `.38` 透明度叠加；静止选中层是主题主色 `.26`；移动层默认透明，导致整体偏灰且运动时缺少色彩区分。

## 涉及模块与修改方案
- `lib/core/widgets/app_bottom_navigation.dart`：仅液态玻璃普通对比度模式改用浅白透明栏体；移动选中玻璃保留少量主题色；静止层保持淡主题色；保留运动、折射、几何与图标颜色。
- `test/app_scaffold_navigation_test.dart`：先加失败断言，覆盖液态玻璃栏体、移动/静止选中层与其他主题和高对比度分支。
- `.agent/ACCEPTANCE.md`、`.agent/PROGRESS.md`：记录可验证验收与执行进度。

## 开发顺序
1. 增加导航样式回归测试，确认当前栏体和移动层不满足浅色层级，观察 RED。
2. 修改液态玻璃主题样式，保留其他主题与高对比度配置，运行 GREEN。
3. 检查点击路由与导航几何测试；分析相关文件；构建 Debug APK。
4. 指挥层独立审阅 diff/status，检查对比度与视觉样张；不占用用户正在使用的真机做自动安装。

## 指挥层视觉复核补充
- 静止样张已显示栏体变浅；但移动层主题色 alpha `.08` 按液态玻璃页面底色合成后与栏体仅约 1.10:1，仍可能在点击过程中融入背景。
- 将移动层调到仍为低透明度、且在主题页面底色上的计算对比度至少 1.15:1；先更新/运行失败断言，再实现并复验。不要调整静止层、图标或动画。

## 风险、避坑点和禁止修改范围
- 白色栏体须保留玻璃边缘与阴影，否则会在浅色页面上消失；选中图标和文字仍须满足 4.5:1 对比度。
- 移动层只加少量色彩，不改变库的折射/弹簧配置，不把玻璃变成不透明色块。
- 不修改 `third_party/liquid_glass_easy`、全局主题、路由、分类与记账数据；不覆盖工作树已有的 `.agent` 文档内容、`lib/app/theme/app_theme.dart` 和未跟踪文件。

# 2026-09-23 导航选中态全主题二次调整

## 目标与根因
- 用户真机反馈其他主题的静止选中底色也需要调浅；上次只改了 Liquid Glass 胶囊底色，静止选中层仍沿用主题色 alpha `.26`。
- Liquid Glass 按住移动层被定制成主题色 alpha `.14`，与其他主题默认透明玻璃行为不一致。

## 修改范围与方案
- `lib/core/widgets/app_bottom_navigation.dart`：普通主题的静止选中填充从主题色 alpha `.26` 降至 `.18`；高对比度固定填充不变；去掉 Liquid Glass 移动层的主题色覆盖，回到默认透明玻璃。
- `test/app_scaffold_navigation_test.dart`：先更新断言，让旧填充和有色移动层明确失败；覆盖内置主题、移动层透明度、静止层颜色与选中图标对比度。
- 重建 Debug APK 并安装到已连接 Xiaomi 23116PN5BC，启动后留给用户真机查看。

## 验收顺序
1. 更新回归测试并确认 RED 原因为选中填充过深、移动玻璃有主题色。
2. 修改两个样式值/分支，运行导航与玻璃间隙测试。
3. 运行范围 analyze、Debug APK build、`git diff --check`，审查改动与工作区状态。
4. 安装并启动到真机，确认安装包和前台 Activity。

## 风险和边界
- `.18` 必须在四套普通主题保持可辨淡主题色，且选中图标文字对比度至少 4.5:1。
- 保留移动玻璃默认 blur、shadow、折射及弹簧几何；不改 Liquid Glass 胶囊、高对比度颜色、导航图标或其他业务模块。
- 不覆盖此前未提交改动，不执行清理或重置命令。

# 2026-09-23 选中图标明度微调

## 目标与当前原因
- 用户在真机查看后要求选中图标再鲜亮一些。
- 当前 `LiquidGlassTabItemStyle` 以同一个 `selectedColor` 同时绘制图标和文字；主题辅助色再乘 `.80` 以保证浅选中底上的对比度。

## 修改方案与验收
- 在四套主题共享的选中色上小幅提高系数至 `.85`；未选中文字、选中底色、Liquid Glass 透明移动玻璃、高对比度颜色及动画几何不变。
- 先增加 `.85` 配置断言并确认 RED，再调整源常量；现有全主题对比度测试必须继续满足选中 ink 4.5:1。
- 运行导航/布局测试、scope analyze、Debug APK build、`git diff --check`，更新并安装到 Xiaomi 23116PN5BC。

# 2026-09-23 木木参考下的选中态层次修正

## 任务目标与问题证据
- 用户提供真机截图：洞察选中胶囊是一整块灰蓝色，图标文字也偏暗；此前 `.18` 主题色底和 `.85` 选中墨色调整仍不足以拉开层次。
- 木木 8.2.8 本地反编译记录表明，浅色静止 pill 使用白色 alpha `.10`，移动 pill 独立使用透明玻璃折射；本 App 静止 pill 目前是主题主色 alpha `.18`。

## 涉及模块和方案
- 核对 `fanbianyi/blutter-out-20260921/asm/mutongji/pages/main/main_bottom_navigation_bar.dart` 与导航库样式，确认木木静止填充及图文颜色的数据来源；对照用户截图与本 App 当前样式。
- 在 `lib/core/widgets/app_bottom_navigation.dart` 减轻浅色静止选中 pill 的主题色负担，优先采用木木的浅白透明做法；选中图标文字使用更明亮的主题色，并按四套主题分别保持至少 4.5:1 的对比度。
- 具体首轮参数：Liquid Glass 静止填充改为白色 alpha `.10`；其余普通主题的主色 alpha `.18 → .08`；高对比度填充不变。Liquid Glass 选中图文用主题 `secondary` 与 `primary` 的中间色，其余主题选中墨色系数 `.85 → .90`，最终以真机轮廓和对比度验收为准。
- `test/app_scaffold_navigation_test.dart` 覆盖液态玻璃及其他主题的静止层颜色、移动玻璃透明、高对比度与选中墨色对比度。先 RED，再改实现。
- 通过实机截图比较改动前后；范围 analyze、Debug APK build、diff check 后更新安装 Xiaomi 23116PN5BC。

## 风险与边界
- 浅白 pill 必须能以轮廓/材质从整条栏中区分；不能只把主题色调到几乎看不见，也不能使选中图文低于 4.5:1。
- 不修改导航几何、弹簧、页面背景、中心加号、未选中项、业务与用户已有未提交文件。

# 2026-09-23 FAB 与导航栏统一玻璃材质

## 目标与现状
- 用户要求 FAB 中间加号使用各主题颜色，FAB 背景使用现有液态玻璃导航胶囊的样式，并让四套主题都沿用现有导航/FAB 结构。
- 当前 `QuickAddButton` 的圆底是主题主色 alpha `.76`、加号纯白；`AppBottomNavigation` 的胶囊在 Liquid Glass 使用白色 alpha `.24`，其他主题使用 `plateTint(scheme)`，四主题均已采用同一个玻璃导航组件。

## 设计与修改范围
- 方案选用“FAB 与当前主题的导航胶囊共享玻璃底色，图标采用导航选中强调色”：Liquid Glass 为白色 alpha `.24` 底与蓝色加号；其他三主题沿用各自导航胶囊 tint 与主题强调色。保留 FAB 的圆形、光学边缘、折射和阴影，移除浓主题色填充/有色阴影。高对比度分支继续采用不透明按钮。
- `lib/core/widgets/app_bottom_navigation.dart`：将现有胶囊 tint 和选中强调色提炼为可复用的静态计算方法，不改本轮已验收的导航颜色值、层级、动画或位置。
- `lib/core/widgets/quick_add_button.dart`：复用上述两种颜色，调整 FAB 底和加号；更新过时注释。
- `test/quick_add_button_test.dart`：先写新颜色及四主题共享样式的失败断言，再验证交互/高对比度分支；必要时在导航测试中锁定共享色值。

## 顺序、风险与边界
1. 先更新测试并确认旧 FAB 的主题色浓底/白色加号触发 RED。
2. 最小实现与定向 GREEN；核对各主题加号在实际玻璃底上的非文本对比度至少 3:1，必要时采用更深的同主题强调色。
3. 指挥层审查 diff/status；运行导航/FAB 测试、范围 analyze、Debug APK build、真机安装和截图。
- 不修改页面业务、FAB 点击/长按逻辑、导航几何和主题定义；不覆盖用户已有未提交文件。

## 2026-09-23 用户反馈后的统一样式修正
- 用户指出上一轮只统一了 FAB 对应的导航色计算，固体主题仍用彩色导航胶囊和主题色选中 pill。
- 四套主题的普通对比模式统一使用 Liquid Glass 的导航胶囊白色 alpha `.24`、静止 pill 白色 alpha `.10`、FAB 白色 alpha `.24`；不再根据主题向这些背景层叠加主色。选中图文和 FAB 加号仍使用各主题现有强调色。
- 高对比度继续走既有不透明分支；移动玻璃保持透明。更新所有主题颜色测试并重新核算导航 ink 对比度，保持 selected/unselected 至少 4.5:1 和 FAB 图标至少 3:1。
- 先让新测试在三种固体主题当前 `plateTint` / primary `.08` 配置上 RED，再调整共享颜色函数与静止 pill，跑导航/FAB 测试及范围 analyze、build。安装仍以 Xiaomi 23116PN5BC 为目标；若设备 ADB 离线如实记录。

# 2026-09-23 深灰静止胶囊网页预览

## 目标与范围
- 将普通对比度模式下四主题静止选中胶囊统一改为深灰 `#333333`、alpha `.10`。
- 保持透明移动玻璃、浅白导航栏和 FAB 玻璃底，以及主题选中墨色；确保选中文字对比度不低于 4.5:1。
- 生成可切换四主题的独立 HTML 预览供用户查看。本轮不操作手机。

## 验收步骤与风险
- 修改范围限于导航样式、导航/FAB 回归测试、任务记录和 `nav_glass_review/dark_gray_capsule_preview.html`。
- 先更新颜色断言并确认旧实现 RED，再实现样式及必要的 ink 对比度微调。
- 运行导航/FAB/间隙测试、范围 analyze、Debug APK build、`git diff --check`；保留工作区既有改动。
- 深灰底会降低明亮蓝色 ink 的对比度；所有主题需继续通过 4.5:1 断言。

# 2026-09-23 二级分类浮层导航同款玻璃与紧凑布局

## 目标
- 记一笔二级分类浮层在 Liquid Glass 主题下采用导航同款通透玻璃。
- 二级分类排列更紧凑，浮层更小。
- 一级分类“其他”固定排在第一；其余分类按现有 `sortOrder` 倒序，分类持久化数据及分类本身的 sortOrder 不变。

## 涉及范围
- `lib/features/bookkeeping/presentation/quick_add_sheet.dart`：仅改一级分类显示排序与二级浮层局部布局/材质。
- `test/quick_add_redesign_test.dart`：验证材质、尺寸、排序及选择/滚动回归。
- `.agent/ACCEPTANCE.md` 与 `.agent/PROGRESS.md`：记录验收和状态。

## 修改方案
- 一级显示排序将名称为“其他”的类别放首位，剩余类别按现有 `sortOrder` 倒序。
- Liquid Glass 使用 `AppLiquidGlassSurface`，复用导航胶囊的白色 alpha `.24` tint、5 dp 背景模糊与相近圆角；选中胶囊以相同玻璃表面移动，其他主题继续用不透明 `AppGlassSurface`。
- 浮层最大宽度 344 dp、外边距至少 32 dp；padding 6 dp；基础格高约 58 dp、图标 24 dp；字号增加时仍按实际缩放并限制在安全区域。

## 顺序与边界
1. 先添加排序、材质和紧凑尺寸回归断言并运行确认 RED。
2. 最小修改浮层和显示比较器，保持 route barrier、点击/指针手势、滚动及分类数据原样。
3. 运行相关测试、范围 analyze、diff check、Debug APK 构建，检查 git diff/status。
4. 安装到已连接 Xiaomi 真机并启动供用户查看。

## 风险与避坑点
- 普通主题浮层仍需完全不透明；Liquid Glass 主题可透见模糊后的背景，这是导航同款玻璃效果。
- 紧凑行高仍须容纳二行名称和 24 dp 图标；大字模式列数继续为四列。
- 不覆盖现有未提交修改，不更改分类模板、数据库、导航栏、全局玻璃样式或手势行为。

## 2026-09-23 静止胶囊 3% 真机复核
- 按用户明确要求，把普通模式静止胶囊从深灰 10% 改为深灰 3%；导航/FAB 其他材质和移动状态不变。
- 更新颜色回归与网页预览，完成测试、分析、Debug APK 构建后更新安装至 Xiaomi 23116PN5BC 并启动。

# 2026-09-23 二级分类弹窗亮度与中性玻璃修订

- 用户澄清：弹层外的页面遮罩仍用于压暗底层、突出二级分类；当前问题是弹窗本体看起来太暗。
- 保留浮层 route 的黑色 barrier 与点击外部关闭行为；把 Liquid Glass 二级浮层改成至少 0.94 覆盖度的中性白玻璃，维持 5 dp 导航同款模糊。
- 二级外层玻璃和移动选中胶囊关闭主题主色阴影、渐变 tint 与彩色边缘；共享 AppLiquidGlassSurface 默认分支和导航/FAB 外观保持不变。
- 修改限于共享玻璃组件的可选配置、二级浮层两处配置、相关 widget 断言和任务记录；不改变分类数据、排序、点击/滑动/滚动及移动胶囊动画。
- 顺序：改写相关回归断言确认当前实现 RED；做最小实现；跑 quick_add 测试、目标文件 analyze、Debug APK build、diff/status 检查；安装并启动 Xiaomi 真机。

# 风险与验收要点
- 高遮罩必须仍只压暗弹窗外页面，白玻璃弹窗本体保持清亮；验证 barrier 仍可关闭。
- 近不透明白层可能弱化底图折射，应保留 5 dp 模糊和白色高光，不动共享导航玻璃。
- 确认浮层的渐变、阴影、描边均不混入主题蓝色；保留选中态的移动玻璃和分类图标/文字颜色。
# 2026-09-24 支付图标、消费日历、流水操作、首页目标与导入后核算

## 任务目标与当前问题
- 所有展示微信/支付宝品牌图标的业务入口复用会员页面 `assets/images/membership/wechat-pay.png` 与 `alipay.png`；当前账户管理、资产、记一笔等入口仍使用通用 Icon/手绘 glyph。
- 消费日历的“本月概览”现位于 ListView 末尾，滚动后不可见；移入页面底部固定区域并保留安全区和长内容滚动空间。
- 主流水/搜索已有长按操作层，但日历、账户详情、资产最近变动、报销及关联流水入口未覆盖。
- 首页目标区域点击应进入 `/goals` 或对应 `/goals/:goalId`；核验目标区全区域的命中和现有预算、隐藏金额操作。
- 账单批量保存后需要基于已持久化流水重新计算目标建议/洞察；目前只显式刷新两个流水 provider，要检查实际依赖和刷新时序。

## 涉及模块与修改方案
1. 图标：抽取复用会员资产的轻量组件/常量，替换明确代表微信/支付宝的图标呈现；不改账户类型、支付逻辑或非品牌通用钱包图标。
2. 日历和流水：月概览放入 Scaffold 固定底部区域，按 SafeArea/键盘/窄屏检查；给每个真实流水卡片/行增加 `showTransactionActions` 长按，沿用现有操作层。
3. 首页与导入：扩大首页目标区域点击命中但保留内部独立操作；导入成功后确保本账本统计、建议与洞察以新数据重算，失败或全重复导入不触发刷新。

## 开发顺序
1. 各执行子代理先读本计划、验收、进度与相关源码，列出实际呈现入口及数据依赖。
2. 为缺失行为写可复现测试并观察失败；实施最小修改；运行定向测试与范围 analyze。
3. 子代理在进度文档记录修改文件、RED/GREEN、问题与风险；指挥层独立检查 git diff/status、运行组合测试、analyze 与可用构建。

## 分工和边界
- 图标代理：会员图标复用与其测试；避免修改日历、首页、导入和流水动作文件。
- 日历/流水代理：日历底部固定及非首页流水入口长按；避免修改首页、导入及支付图标相关文件。
- 首页/导入代理：首页目标卡与导入后重算；首页已有流水长按需复核；避免修改日历及图标文件。
- 保留工作区已有未提交改动，特别是主题、导航、记一笔弹层和既有 `.agent` 内容；所有 `.agent` 更新只追加本任务章节，不覆盖先前记录。
- 不改账本/分类/支付业务逻辑，不清理现有文件，不执行 reset/clean/force push/merge/rebase。

### 指挥层审查返工：跨账本流水操作作用域
- 日历与资产概览使用 `allTransactionsProvider`，可展示非当前账本的 `TransactionRecord`。通用操作层中的删除、退款及报销服务按 `activeBookIdProvider` 建立，直接使用会失败或作用到错误账本上下文。
- 在共用操作入口识别 `transaction.bookId != activeBookIdProvider`。对跨账本记录先提供明确的“切换到该账本并操作”路径，待 `ActiveBookIdController.select` 完成后再展示原操作层；同账本路径保持原样。不得对跨账本记录直接执行当前账本写入服务。
- 新增跨账本长按操作测试，验证切换前无危险写入选项、切换后可看到原操作选项；验证同账本长按无回归。

### 2026-09-24 消费日历固定卡片背景修正
- 用户反馈固定本月概览时，Scaffold 底栏所占区域的页面背景也显得固定；目标是仅固定概览卡，日历滚动内容继续延伸到卡片下方。
- 根因：Scaffold 默认把 body 布局限制在 `bottomNavigationBar` 之上，卡片之外露出固定的 Scaffold 背景带。
- 最小修改：启用 `Scaffold.extendBody`，让日历列表延伸到固定卡片背后；底栏包装保持透明，仅 `AppCard` 自身绘制卡片表面。
- 不改月概览卡尺寸/统计、日历交互、其他流水入口或全局 Scaffold 行为。

## 2026-09-24 首页分类流水弹层与多指标趋势

### 目标
- 修复首页分类支出弹层因分类统计键与流水原始分类 ID 不一致而始终为空的问题。
- 弹层显示对应分类、本周期、当前账本、CNY、未删除且符合分类统计当前 `isExpense` 支出口径的流水（包括资产支出）；日期/金额两种排序按钮位于右侧，默认日期倒序，弹层不超过屏幕高度一半，流水超出时可滚动。
- 首页趋势显示支出、收入、总资产三条线；沿用周/月/年范围及选点交互，支出用主题色、收入用现有绿色、资产用橙色。
- 采用现有业务口径：支出扣除已登记退款；总资产汇总正向账户余额并包含投资市值，不扣减负债；不改写账务模型。

### 涉及模块与顺序
1. `lib/features/home/presentation/home_page.dart`：复用与 `StatisticalAnalysisService._categoryKey` 一致的分类键；弹层加入日期/金额排序控件与方向切换，固定标题区、滚动流水区和半屏上限。
2. `lib/features/home/presentation/home_expense_trend.dart`、`lib/core/widgets/cashflow_trend_chart.dart`、必要的分析/资产模型：提供退款后支出、收入与历史总资产序列，绘制三条语义颜色曲线；按月时收支求和、总资产取当月末值。
3. 保持 `CashflowTrendChart` 现有调用方默认效果不变；检查改动仅覆盖首页专用行为，并审阅 `git diff`/`git status`。

### 风险与约束
- 当前 `main` 工作区存在大量用户未提交改动，尤其 `home_cards.dart` 有无关首页目标卡改动；只能局部修改，不覆盖、格式化或撤销它们。
- 收支和资产数量级可能不同；曲线必须可辨识，同时选中日期要能读出各序列真实净额，不伪造共用金额比例。
- 不改分类种子、持久化流水、全局主题、其它统计图调用语义或交易操作层。

## 2026-09-24 消费日历、反馈提示与统一日期时间样式

### 任务目标
- 修复消费日历滚动时末尾消费记录/“记一笔”入口被“本月概览”遮挡。
- 让记账完成、部分成功和校验反馈的提示避开全局导航栏与 FAB，并改为主题化浮动样式。
- 清理业务页面旧的 `showDatePicker`，纯日期统一使用 `AppDatePicker`，日期+时间统一使用记一笔的 `TimeSelector`。

### 当前问题与根因
- 消费日历内部 `Scaffold` 同时使用固定 `bottomNavigationBar` 和 `extendBody: true`，正文绘制到概览卡片背后。
- 记一笔保存后使用默认黑色 `SnackBar`，默认底部位置落在全局液态玻璃导航与 FAB 覆盖区域。
- 应收、受限账户、财务中心和目标页面仍直接调用 Material `showDatePicker`。

### 修改方案与顺序
1. 先为日历正文底部不得越过概览顶部补回归测试，再移除内部 Scaffold 的 `extendBody`。
2. 先为共享主题化 SnackBar 写失败测试，再实现按 `AppNavGeometry` 动态抬高的 helper，接入记一笔所有反馈路径。
3. 为 `AppDatePicker` 增加可选日期范围并写测试；随后替换所有业务层旧 `showDatePicker`，保持原范围和业务语义。
4. 指挥层独立检查 diff/status，运行定向测试、范围 analyze、Debug APK build，并完成验收。

### 风险与避坑点
- 不能回退或覆盖本任务开始前的主题、导航、记一笔及其他未提交改动；只允许局部修改相关代码。
- 日历修复不能改变统计口径、滚动内容、概览数据和点击/长按行为。
- SnackBar 不能在关闭记一笔弹层后引用已销毁的 sheet context；必须在 pop 前构造并捕获 messenger。
- 日期范围必须保留原始 `firstDate`/`lastDate` 约束，默认无范围的现有 `AppDatePicker` 调用行为不变。

# 2026-09-24 资产总览分布与投资计入首页开关

## 任务目标与当前问题
- 窄屏下 `_ChartPair` 在 380dp 以下变为纵向布局；恢复任何目标手机宽度下的并排双卡。
- 分布 donut 已把投资市值计入总额，但图例只列账户；详情缺投资行和占比，列表布局需对齐金额。
- 资产趋势历史只从账户余额/账本流水重建；卡片和详情需要另行显示当前计入首页的投资市值，不把它误称为历史投资收益。
- 新增投资缺少“计入首页账目净资产”选择；用户确认默认关闭，现有仓位升级后也默认关闭。
- 资产详情 modal 出现黑色条纹；先在真实 sheet 路由中复现、找出根因，再做局部修复。

## 涉及模块与实施方案
- 数据库与仓储：`app_database.dart` schema v22，持仓 boolean 列默认 false；迁移旧持仓时置 false；修改 `InvestmentHolding`、`AddInvestmentRequest` 的读写映射并生成 Drift 文件。
- 投资录入：首页净资产开关默认关闭；点击提示显示用户给定文案；开关值随持仓保存。
- 首页/资产数据：新增按币种过滤持仓市值的 provider；首页资产卡、首页趋势和资产总览使用过滤后数值；投资管理继续读取完整组合。
- 资产总览：分布卡与详情共用“未排除的正余额账户 + 已计入的投资管理汇总”条目，金额降序并显示金额/总资产占比；零值安全处理。窄屏持续并排，内部紧凑排版；变化卡和详情单独显示当前计入投资金额。

## 开发顺序
1. 执行子代理先在持仓仓储测试中覆盖新建默认关闭、显式开启持久化、完整投资组合不受标记影响及 v21→v22 旧持仓迁移；观察失败后实现 schema/domain/repository。
2. 为新增表单开关与点击提示补失败测试；再接入开关状态和 included-by-currency provider，首页消费该 provider，投资管理维持 full portfolio。
3. 为分布金额、百分比、投资行、零总额和 320/393dp 并排布局补失败测试；统一 compact/detail entries，显示当前投资值并保持区间趋势语义。
4. 用交互测试/图像采样复现 modal 黑条，修复其具体页面层根因，复测布局/点击/滚动。
5. 指挥层按 spec review、quality review 顺序独立验收子任务，再运行目标测试、静态分析、Debug APK build、`git diff --check`，审阅 diff/status。

## 风险和避坑点
- 切换/迁移为默认 false 会使已有投资从首页和资产总览总额中退出；不得删除或更改其投资管理记录。
- 投资快照是组合汇总且没有币种拆分；不得把旧快照错误分摊到某币种或把账本趋势说成投资回报。
- 当前工作区有大量未提交更改，尤其 `asset_overview_page.dart` 有用户长按流水改动、`home_expense_trend.dart` 有近期趋势改动；执行子代理只作局部编辑，不覆盖/格式化整文件。
- 不改投资管理总额、资产账户/流水金额、全局 modal/主题、无关首页页面或其他任务 `.agent` 内容。

## 不允许修改范围
- 除本计划列明的数据模型、数据库、投资录入、首页 provider 消费点、资产总览 UI 与对应测试外，不改其他业务逻辑。
- 不运行 `git reset --hard`、`git clean -fd`、force push、merge、rebase；不覆盖用户已有未提交修改。
- PLAN/ACCEPTANCE 仅指挥层可编辑；执行代理只读。PROGRESS 可由指挥层和执行代理更新。

### 不允许修改范围
- 数据库、账务服务、路由结构、全局导航/FAB 几何、第三方库、资产文件及与本任务无关的页面。

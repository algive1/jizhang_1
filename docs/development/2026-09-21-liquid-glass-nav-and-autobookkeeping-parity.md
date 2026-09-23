# 液态玻璃导航栏 + 自动记账对齐（对照参考实现）

日期：2026-09-21。状态：已实施，Android release 构建通过，待真机视觉验收。

本轮目标：把底部导航的液态玻璃效果对齐参考实现，并把自动记账的四个硬伤补掉、跟进 App 覆盖面。
所有判断基于对参考实现 APK（`com.jaemobird.mutongji` 8.2.8）的静态逆向，
对比报告见工作区 `报告/03-自有App与木木记账差异对比.md` 与 `报告/木木自动记账支持范围与通道.md`。

---

## 1. 导航栏液态玻璃

### 1.1 结论：改用 MIT 开源包 `liquid_glass_easy`

参考实现的液态玻璃不是自研的，它用的是 pub.dev 上的
[`liquid_glass_easy`](https://pub.dev/packages/liquid_glass_easy)（MIT，Copyright (c) 2025 Ahmed Gamil）：
APK 的 `assets/flutter_assets/packages/liquid_glass_easy/lib/assets/shaders/` 下就是它的 6 个片元着色器。

**这替代了本文档上一版 §5.7 手写 SDF 折射的计划。** 理由：同代码才能保证同效果，且该包已经处理好了
Impeller/Skia 双路径、像素对齐裁剪、uniform 打包、低端机降级这些容易翻车的地方。
`pubspec.yaml` 因此新增依赖 `liquid_glass_easy: ^4.3.1`（原 §5.10「不要新增第三方 glass 包」相应作废）。

### 1.2 现在这个导航栏是什么

`lib/core/widgets/app_bottom_navigation.dart` 重写，玻璃路径由两个包内原语组成：

| 层 | 组件 | 作用 |
|---|---|---|
| 1 | `LiquidGlassLens` | 胶囊本体。圆角矩形 SDF + 解析法线 + 边缘锚点折射 + 光学边缘光，折射的是**实时背景** |
| 2 | `LiquidGlassMotionPill` | 选中态**真玻璃透镜**。弹簧位移 + 抬起 + 加速度驱动的拉伸/压扁 |
| 3 | `_NavTabRow` | 图标与文字，画在最上层，始终锐利 |

绘制顺序是刻意的：**胶囊 → 药丸 → 图标**。在 Impeller 上叠加的 backdrop pass 会链式采样，
所以药丸折射到的不只是页面，还有它身后的胶囊玻璃。

**静止时没有第二遍 backdrop**：`LiquidGlassMotionPill` 在 rest 状态会关掉自己的 lens，
所以静态导航栏的着色器开销与改造前一致（一个捕获点）。

选中态位移的弹簧由本文件驱动（`liquidGlassSpringStep`，stiffness 280 / damping 31.4，240 Hz 子步进），
药丸在 slot 之间连续移动；`active` 在位移落定后释放，药丸按自己的软弹簧收回。

### 1.3 布局约束与 FAB 补偿（容易踩的坑）

- 中央记账按钮是 `Scaffold.floatingActionButton` + `FloatingActionButtonLocation.centerDocked`，
  **不在导航栏内部**，所以 Row 保留了 72 dp 的空档。
- `centerDocked` 的 FAB 纵向位置是 `contentBottom - fabHeight/2`，而 `contentBottom` 由
  `Scaffold` 从 `bottomWidgetsHeight` 推出 —— 也就是**导航栏自己的高度**。
- 为了给药丸留出向上抬起 9 dp 的余量，宿主高度从 88 →96，胶囊仍占 80（用 `_topInset: 8` 补上），
  **胶囊在屏幕上的位置完全没变**；但 FAB 会被抬高 8 dp，因此在 `AppScaffold` 里把
  `_CenteredDockedFabLocation.offsetY` 由 10 → `AppBottomNavigation.fabOffsetY = 18` 抵消。
  两者必须同步改，否则 FAB 会相对胶囊漂移。

### 1.4 材质取值（已按木木对齐，保留无障碍分支）

参考实现的胶囊染色是 `Color(0x16FFFFFF)`（白 8.6%，几乎全透），可读性全部靠折射和边缘光。
这会击穿本项目 §3 定的导航对比度门槛（最薄基底 `.72`、文字 ≥4.5:1）。

当前普通液态玻璃路径已经使用 `AppBottomNavigation.glassTint = Color(0x16FFFFFF)`，
与木木的基材透明度对齐；玻璃感由折射 + 模糊 + 光学边缘光提供。高对比模式仍切换到不透明表面，
避免系统辅助功能开启时文字被背景击穿。普通模式的最终对比度仍需在 Impeller 真机上复核，
因此这不是“所有背景下像素级等价”的承诺。

其余参数照抄参考实现：`distortion 0.07 / distortionWidth 28 / chromaticAberration 0.002`、
`OpticalBorder(1.2, 1.0, 0.35)`、`pillGrowHeight 9`、
`LiquidGlassLensMotionSpec(sampleWindow .3, sensitivity .00007, maxDeformation .12, responseTime .18)`。

### 1.5 保留与丢弃

- **保留**：`appUsesLiquidGlass` 主题开关（关闭时仍走纯色 + 滑动高亮的 `_PlainNavBar`）；
  高对比模式（`highContrast` 下染色不透明、折射归零）；`disableAnimations` 时位移直接落位、不做抬起。
- **丢弃**：原来的 `_LiquidGlassChromePainter` 顶缘高光与 `_ChromaticGlassBorderPainter` 青/品红双描边 ——
  光学边缘光现在由着色器算，画上去的描边会与之打架（§1/§3 已判定彩边不是折射）。
- **仍未做**：图标在药丸下滑过时变色（参考实现是两次 `ClipPath` 裁剪，纯 Dart，不需要着色器）；
  跨中央 FAB 时药丸会从按钮**背后**穿过（§4 原本要求淡出淡入，尚未实施）。

### 1.6 新增依赖的署名要求

MIT 要求在软件副本中保留版权声明与许可全文。**发布前需在「开源许可」页加入
`liquid_glass_easy` + MIT 全文。**

---

## 2. 自动记账

### 2.1 补齐的四个硬伤

| # | 问题 | 处理 |
|---|---|---|
| 1 | 无障碍配置缺 H5 增强标志，WebView 支付页控件树读不到 | `autobookkeeping_accessibility_service.xml` 加 `flagRequestEnhancedWebAccessibility` + `canRequestEnhancedWebAccessibility` + `flagDefault` |
| 2 | 没有任何手动入口 | 新增 `BookkeepingTileService`（快捷设置磁贴「记账」）+ 图标 `ic_autobook_tile.xml` + 清单注册 |
| 3 | 截图只用全屏 `takeScreenshot(DEFAULT_DISPLAY)` | `AutoBookkeepingScreenshotCapture` 在 API 34+ 走 `takeScreenshotOfWindow(目标窗口)`，只截付款 App 自己的窗口；解码移到私有 executor，回调仍回主线程；命中系统节流错误码 3 时延时 600 ms 重试一次 |
| 4 | 通知 + 悬浮窗 + 无障碍三者缺一不可，缺一个整条链路静默失效 | 见下 |

**第 4 项的改动点**（这是最要紧的一条）：

- `scanPage()` 原来在悬浮窗实例缺失时**直接 return，根本不扫描**。改为：仍然扫描，
  悬浮窗不可用时用 `notifyConfirmationAvailable()` 兜底提醒（这个方法本来就写好了、只是没人调用）。
  只有「悬浮窗还有可能起来」时才做最多 10 次 × 200 ms 的有界等待。
- `offerCandidate()` 原来在悬浮窗投递失败时调 `PendingStore.complete(remember = false)`
  **把已经解析出来的账单丢掉**。改为保留待确认记录 + 发通知。
- `MainActivity.setEnabled` 原来在缺悬浮窗或缺通知时直接 `result.error` 拒绝开启。
  改为只保留无障碍为硬要求，另外两项降级为 `Diagnostics.error` 警告。

### 2.2 新增：自定义应用（参考实现覆盖面的真正来源）

逆向发现参考实现的包名白名单**不是静态的**：它在运行时用 `setServiceInfo()` 重写，
来源是「服务端下发的规则包名 ∪ 用户在「自定义应用」里手动添加的包名」，
XML 里那 7 个只是两者都空时的兜底。所以它能在不发版的情况下覆盖新 App。

本轮把这套机制落地：

| 文件 | 作用 |
|---|---|
| `autobookkeeping/AutoBookkeepingCustomApps.kt` | 用户添加的包名集合（SharedPreferences string set，上限 32，含包名格式校验） |
| `rules/AutoBookkeepingRuleRegistry.kt` | 构造参数新增 `customPackages`；`ruleFor()` 对自定义包回落到**已有的 GENERIC 规则模板**（复用其成功/失败标记、金额标签、排除标签，不引入第二套更弱的规则）；新增 `isCustom()` / `withCustomPackages()`；`load()` 读取自定义集合 |
| `accessibility/AutoBookkeepingAccessibilityService.kt` | 首次连接时捕获 XML 声明的 `basePackages`；新增 `applyRulesAndWhitelist()`，把 `basePackages ∪ customPackages` 通过 `setServiceInfo()` 下发 —— **框架只为白名单内的包投递事件，不下发就永远不会生效** |
| `MainActivity.kt` | 通道新增 `listCustomApps` / `searchInstalledApps` / `addCustomApp` / `removeCustomApp`；增删后立即调用 `applyRulesAndWhitelist()` |
| `lib/features/autobookkeeping/auto_bookkeeping_custom_apps.dart` | Dart 侧桥 |
| `lib/features/autobookkeeping/presentation/custom_apps_page.dart` | 应用选择页（搜索 + 开关 + 手动输入包名） |
| 路由 `/profile/autobookkeeping/apps` + 设置页入口 | |

**包可见性**：应用列表用 `ACTION_MAIN` / `CATEGORY_LAUNCHER` 查询，清单里加了一条匹配的 `<queries>` 条目，
因此**不需要 `QUERY_ALL_PACKAGES`**（那是 Google Play 限制的敏感权限）。

### 2.3 App 覆盖面跟进

参考实现静态白名单 7 个：微信、支付宝、美团、云闪付、抖音、京东、**抖音极速版**。
我方原有 9 个包名，差集与处理：

| App | 包名 | 处理 |
|---|---|---|
| 抖音极速版 | `com.ss.android.ugc.aweme.lite` | 并入 `DOUYIN` 规则 + 无障碍白名单 |
| 淘宝 | `com.taobao.taobao` | 新增 `TAOBAO` 规则（GENERIC）+ 白名单；（参考实现内置了淘宝规则模板但不在白名单，推测是历史遗留） |
| 1号会员店 | `com.thestore.main` | 新增 `ONESTORE` 规则（GENERIC）+ 白名单 |
| — | `com.ss.android.ugc.aweme.mobile` | **保留**。多平台检索不到，疑似不存在，但白名单里的无效包名无副作用，删除只有下行风险 |

`ALLOWED_PACKAGES` / `ALLOWED_SOURCES` 同步放行新增项，否则规则 JSON 校验会拒绝加载。

### 2.4 明确**没有**跟进的部分

- **任意前台 App 的截图 OCR 兜底**。参考实现有一条「截屏记账」通道：无障碍截图 → ML Kit OCR → 规则/大模型，
  不读包名，任何界面都能用。这是它覆盖面广的根本原因，但它带来了模型包体积、功耗、误识别与云端隐私成本。
  本轮只做到「手动磁贴触发 + 规则解析 + 截图作为凭证」。**若要做，建议只对已存 PNG 做一次本地 OCR 作为低置信度建议值，不并入自动入账链路。**
- **服务端下发规则**。参考实现的规则在 `api.tzmutone.com/common/accessibility_rules/v3`，
  客户端没有名录。我方目前是随包发布的 `autobookkeeping_rules_v1.json`（已有 schemaVersion + 每规则 version，
  具备下发条件，但需要服务端配合）。
- **`canPerformGestures` 自动翻页/点按**。参考实现用它主动导航到账单详情；我方走「当前页面确认」，暂不需要。

---

## 3. 验证

- `flutter analyze lib/core/widgets/app_bottom_navigation.dart test/app_scaffold_navigation_test.dart`：No issues found。
- `flutter test test/app_scaffold_navigation_test.dart`：11/11 通过。
  该文件的三个断言已按新实现重写（旧断言依赖已删除的 `app-nav-glass-indicator`）：
  - 「one readable navigation glass layer」改为断言**静止时 `BackdropFilter` 恰好 1 个**
    （胶囊；药丸的 lens 在抬起前是关闭的），外加 `LiquidGlassMotionPill` 存在。
  - 「indicator moves continuously」改为逐帧读取 `LiquidGlassMotionPill.center.dx`，
    验证位移是插值而非瞬移。
  - 修掉一处回归：新实现原本对**已选中项**也调用导航，在无 `GoRouter` 祖先的 widget 测试里抛异常；
    已恢复为「仅未选中时导航」。
  - 新增长按拖动回归：药丸会在手指目标之后平滑跟随，松手后吸附并只触发一次路由切换，避免
    `PointerUp` 再次把手势当成普通点按。
- `flutter build apk --release`：通过，产物 134.2 MB。

### 3.1 全量测试基线（重要）

`flutter test` 全量有 **43 个失败**，但**与本次改造无关**，在动手之前就已存在。判定方法：
把 `app_bottom_navigation.dart` / `app_scaffold.dart` 临时切回 HEAD 版本（即完全不含玻璃的旧导航）
再跑 `flutter test test/widget_test.dart`，结果与改造后**完全一致**（`+0 -20`，同样的 `pumpAndSettle timed out`），
随后已还原本次实现。

已定位的两个既有根因（供后续排期，不在本轮范围）：

1. `lib/features/insights/application/insight_feed_provider.dart:73` 的 650 ms `Timer` 在测试中一直存活，
   导致 `pumpAndSettle` 永不收敛 —— `widget_test.dart` 整个文件因此全灭。
2. `test/asset_management_test.dart:141` 断言 `Expected: <18> Actual: <20>`（资产迁移计数不符）。

其余失败集中在数据库迁移、golden/视觉截图、`shared_backend_integration_test`（需要 Node 起本地服务）等
与导航和自动记账无关的领域。

### 3.2 仍未验证的部分

- 真机视觉效果、弹簧手感、药丸抬起时与胶囊圆角的关系、FAB 相对胶囊的位置。
- 快捷设置磁贴的实际表现、自定义应用添加后无障碍是否真的开始投递事件。
- 以上都需要真机验收。

## 4. 后续待办

1. 真机验收导航栏（重点：药丸在首/末 slot 抬起时水平方向会略微超出胶囊约 2–5 dp，
   这是 `liquid_glass_easy` 的既定比例，若观感不接受需下调 `pillActiveSize` 的宽高比）。
2. 真机复核 `Color(0x16FFFFFF)` 在不同背景上的最终对比度（观感 vs 可读性）；高对比模式已保留不透明分支。
3. 图标在药丸下滑过时变色（纯 Dart `ClipPath`，成本低、效果明显）。
4. 跨中央 FAB 时的指示层处理（§4 要求淡出淡入，目前是从按钮背后穿过）。
5. 未跟进的 §2.4 三项，按产品优先级决定。
6. 开源许可页加入 `liquid_glass_easy` + MIT 全文。

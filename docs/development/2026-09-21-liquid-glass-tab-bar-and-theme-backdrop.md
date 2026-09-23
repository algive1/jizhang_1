# 液态玻璃导航栏 v2：改用 `LiquidGlassTabBar` + 全主题玻璃底图

日期：2026-09-21。状态：已实施，`flutter analyze` 干净，导航测试 14/14 通过，
全量测试无新增失败，Android release 构建在真机与模拟器上看过。

> **2026-09-21 追加：§4.1 / §4.2 / §7 记录的「木木实测参数调优」已按用户要求回退。**
> 代码现在回到调优**之前**那一版（`glassTint = 0x38FFFFFF` 白 22%、
> `capsuleBlurSigma = 16`、未选中 `onSurfaceVariant @ .90`、选中 `primaryDark @ .86`、
> `restFillAlpha = .26`），只有本文档保留。
>
> **下面从汇编恢复出来的木木真实参数（胶囊 `surface @ 50%` + 模糊 2.5、
> 未选中 `onSurface` 全强度、选中 `surface` 近白压饱和药丸）仍然有效**，
> 是逆向结论而不是当前实现描述——下次要再对齐木木时直接照 §4 的表做即可。
> §7 的验证清单里，凡是描述调优后行为的条目同样只代表那次已回退的实现。

对应报告：工作区 `报告/04-木木APK液态玻璃参数复核.md` 的「自有 App 的接入建议」。
本文记录为什么必须再改一次，以及改动的边界。

---

## 0. 木木真实参数（逆向结论，与当前实现无关）

从 `blutter-out-20260921/asm/mutongji/pages/main/main_bottom_navigation_bar.dart`
恢复，**不是截图取样**：

| 项 | 地址 | 值 |
| --- | --- | --- |
| 胶囊 appearance | `0x1c6ac30` | `blur: 2.5/2.5`（深色 5/5）、`color: scheme.surface @ 0.5`（深色 white @ 0.44）、`saturation: 1.0` |
| 胶囊 shape | `0x1c6ada0` | `cornerRadius: 30`、`continuousRoundedRectangle` |
| 静止药丸 | `0x1c6af00` | 浅色 `context.tintColor @ 0.16`、深色 `white @ 0.1` |
| 项样式 | `0x1c6a640` | 选中 `scheme.surface`（`0x3b`）、未选中 `scheme.onSurface`（`0x3f`）、iconSize 24、labelFontSize 10、underGlassIconSize 30 |
| 移动药丸运动 | `0x1c6afac`+ | `growHeight 9`、distortion `.04` / width `12`、travel `280 / 31.4` |

**两个最容易搞错的点**：木木的模糊一直是 **2.5**（不是 5）；它看起来"背景更糊"
是因为**染色是 surface 的 50% 不透明**，不是靠大半径模糊。

---

## 1. 为什么要再来一次

上一轮（见 `2026-09-21-liquid-glass-nav-and-autobookkeeping-parity.md`）把底部导航做成
`LiquidGlassLens`（胶囊）+ 通用 `LiquidGlassMotionPill`（运动药丸）的**自研组合**，
并自建 `_NavMetrics` / `_NavTabRow` / `_NavItem`。

报告 §「自有 App 的接入建议」已经点名这条路线的问题：**这不是库的导航组件**。
后果是三条：

1. **参数层级混在一起**。库把导航拆成三套可独立调参的材质（胶囊 / 移动玻璃药丸 /
   静止胶囊），自研组合只有一个 `LiquidGlassStyle` + 一个 `LiquidGlassMotionPill`，
   木木那套 `_luminousNavBarStyle` + `_luminousNavPillStyle` 的分层无从对应。
2. **动画是手写补丁**。药丸位移、抬起、形变、手势全在 `app_bottom_navigation.dart` 里
   自己积分（240 Hz 子步进、长按拖动、吸附），而库的 `LiquidGlassAnimatedNavBar`
   已经把这些做完了，还包括像素对齐裁剪、hand-over、放大底层透镜。
3. **主题开关把玻璃挡在门外**。`appUsesLiquidGlass` 只有 `liquid_glass` 主题为真，
   其余三个主题直接走 `_PlainNavBar`——**根本没有玻璃**。

### 1.1 实测复核（不是推断）

| 检查项 | 实测结果 |
| --- | --- |
| 四个内置主题的 `AppThemeMaterial.style` | 三个 `solid`，仅 `liquid_glass` 为 `liquidGlass` |
| `scaffoldBackgroundColor` | 三个 solid 主题不透明，`liquid_glass` 透明 |
| 玻璃层实际采样区 | `BackdropFilter` 恰好 1 个，rect `(16,756)-(377,836)` |

第三条说明**底层结构原本就是对的**：`extendBody: true` + `Scaffold.bottomNavigationBar`
已经让页面画到了导航栏后面。所以「折射只能采到纯色底」的真因是**主题开关**，
不是布局遮挡。而「改用 `LiquidGlassTabBar`」是另一个独立问题。

---

## 2. 现在的结构

```
Stack
 ├─ AppPageBackground          ← 主题网格渐变（玻璃要采的那个「底」）
 ├─ Scaffold(transparent)      ← 页面，贴边绘制
 └─ AppBottomNavigation        ← LiquidGlassTabBar.withImpeller（必须是最后一个子节点）
```

### 2.1 为什么不用官方的 `LiquidGlassScaffold`

实测两条路径：

| 入口 | 结果 |
| --- | --- |
| `LiquidGlassTabBar.withImpeller` 放进 `Stack` 顶层 | `LiquidGlassLens`×1 + `BackdropFilter`×1 ✅ |
| 普通 `LiquidGlassTabBar` 放进 `LiquidGlassScaffold.bottomNavigationBar` | `BackdropFilter`×**0**（Skia 路径不装背景滤镜） |

且 `LiquidGlassScaffold` 自己拥有 body，主题底图只能作为平铺的 `backgroundColor` 交给它，
也没有给内容留白 / 停靠按钮的位置。所以走 `withImpeller` 覆盖层：
页面、主题底图、中央按钮留在同一棵子树里——这正是实时 backdrop 需要的。

**代价**：`withImpeller` 必须是全屏 `Stack` 的最后一个子节点，而且它盖住的那段空间
要由内容自己让出来。这是下一节的原因。

### 2.2 底部留白：一个真被修掉的 bug

`AppNavGeometry`（`app_bottom_navigation.dart`）现在是**唯一**的几何来源：
胶囊高度 / 底边距 / 侧边距 / 中央空档 / 按钮直径与抬升 / 内容留白，全部从这里派生。

第一版把 `reservedBottomInset` 写成「按钮中心 + 按钮半径」，结果是：
内容刚好停在**按钮底边**，而按钮比胶囊高，所以页面最后一行——或者不滚动的空状态——
仍然落在**胶囊后面**。在真机上就是这个现象：

- 空状态按钮「记一笔」的下半截压在玻璃里。

修法是从**胶囊顶边**量，而不是从按钮量：按钮向上探出胶囊，但胶囊更宽也更实，
让开胶囊就同时让开了按钮。`test/app_scaffold_navigation_test.dart` 里
「the page reserves enough room to clear the capsule」把这条钉住了（直接拿
`geometry.barTopInset` 和实际 `ListView` 的 `bottom` 比对）。

四个主路由页面（`/`、`/transactions`、`/insights`、`/profile`）因此删掉了各自写死的
`110 / 120 / 110 / 130`，统一改成 `AppScaffold.reservedBottomInset(context)`。
二级页面不受影响——它们本来就没有导航栏。

---

## 3. 中央空档：vendored fork

`LiquidGlassTabBar` 的格子布局是 `cellWidth = (width - padding*2) / itemCount`，
图标行也是 `Expanded` 均分，**没有中间空档的概念**；药丸位置
`padding + frac*cellWidth + pillWidth/2` 同样是纯线性。

而本 App 的中央记账按钮要落在**空胶囊**上（现在的设计就是 `_centerGap = 72`）。
两条路——改第三方包，或者在项目里重写它的布局——选了前者，因为后者会连带丢掉
它的动画、手势、像素对齐裁剪。

`third_party/liquid_glass_easy/` 是 4.3.1 的 vendored fork（只带 `lib/`），
通过 `pubspec.yaml` 的 `dependency_overrides` 接入。**唯一的改动**是给底部导航布局
加了可选的 `centerGap`：

- `centerGap` 用**格子单位**表示（`1` = 一个 tab 宽），`centerGapAfter` 指定插在哪个
  tab 之后；四个 tab 用 `centerGap: 1, centerGapAfter: 1`。
- 严格区分**两套索引空间**：**tab 空间**（`0..itemCount-1`，回调 / `selectedIndex` /
  弹簧的小数位置都用它，调用方永远看不到空档）和**槽位空间**（多一格给空档，
  只用于几何）。
- 药丸位移在**两个 tab 中心之间**插值（`tabFractionToSlot`），所以跨空档是匀速穿过，
  不会「冲过空档、爬过 tab」。
- 空档上的点击返回 `null`，**不吸附到邻近 tab**（`tabAtBarLocalX`）——那一下属于
  停靠按钮，不属于导航栏。

`test/liquid_glass_nav_gap_layout_test.dart` 覆盖了这几点，包括
「无空档时退化成上游算术」（保证不影响库的其他用法）。

> 维护提醒：升级 `liquid_glass_easy` 时必须把这套改动重新贴到新版本上。
> `third_party/liquid_glass_easy/pubspec.yaml` 顶部有改动摘要。

---

## 4. 材质取值

### 4.1 胶囊

**这一节的值来自木木自己的 `_luminousNavBarStyle`**（Blutter 输出
`asm/mutongji/pages/main/main_bottom_navigation_bar.dart` @ `0x1c6ac30`），
不是从截图里猜的：

```dart
// 浅色模式（else 分支），深色模式是其镜像
appearance = LiquidGlassAppearance(
  blur: LiquidGlassBlur(sigmaX: 2.5, sigmaY: 2.5),   // 深色 5 / 5
  color: Color.surface.withValues(alpha: 0.5),        // 深色 white @ 0.44
  shadow: <LiquidGlassShadow 实例>,
);
```

**两个必须纠正的认知**（旧报告和本文档上一版都写错了）：

| 项 | 旧认知 | 木木实测 |
| --- | --- | --- |
| 染色 color | 白色 @ 8.6%（`0x16FFFFFF`） | **`scheme.surface` @ alpha 0.5** |
| 模糊 sigma | 5（浅色）/ 2.5（深色） | **浅色 2.5，深色 5** |

也就是说：**木木的模糊一直只有 2.5**，它看起来「背景更糊」是因为**染色是
surface 的 50% 不透明**，不是靠大半径模糊。之前一直在调错旋钮。

本 App 的取值：

| 参数 | 取值 | 与木木的关系 |
| --- | --- | --- |
| color | `context.appSurface` @ **0.5** | 对齐 |
| blur | **14** | 高于木木的 2.5：本 App 页面把高对比正文直接压到导航栏下方，而木木下面是柔和网格渐变。模糊用来把正文打散，主要工作量由染色承担 |
| distortion / width | `.06 / 26` | 对齐 |
| chromaticAberration | `.003` | 对齐 |
| borderWidth / borderColor | `.9` / 白 42% | 木木 `.7` / 白 24% |
| shadow | blur 14, alpha .18 | 木木 blur 8, alpha .13 |
| cornerStyle / radius | 连续圆角 / `height/2` | 木木 `30`（栏高 60） |

高对比模式切到不透明表面 + 零折射（项目既定无障碍契约）。

### 4.2 静止药丸与图标墨色

**同样来自木木的 AOT 恢复，不是截图取样。** 图标样式在 `0x1c6a640` 构造，
两个颜色字段直接读自 context 的 `ColorScheme`：

| 槽位 | 木木字段 | 含义 |
| --- | --- | --- |
| 选中 | `scheme.surface`（`0x3b`，近白） | 近白 glyph 压在**饱和药丸**上 |
| 未选中 | `scheme.onSurface`（`0x3f`，**全强度近黑**） | 不是淡灰 |
| iconSize / labelFontSize | 24 / 10 | |
| underGlassIconSize | 30 | 药丸下放大（本 App 未启用） |

药丸的静止填充在 `0x1c6af00`：浅色模式是 `context.tintColor.withSafeOpacity(0.16)`，
深色是 `white @ 0.1`。

本 App 的落地与**一处必要偏离**：

- **未选中 = `onSurface` 全强度**，对齐木木。旧的 86% **alpha** 压暗只有 3.3:1，
  输给玻璃后面的页面正文。
- **选中 = 白色**，对齐木木的「近白 glyph 压饱和药丸」思路。
- **药丸填充 = 主题 accent 全强度**（`scheme.secondary`，`restFillAlpha = 1`）。
  **这是对木木的偏离**：木木可以用 16% 淡填充，因为它的选中墨色是近黑，
  药丸只需要和 glyph 有区分；而本 App 的选中墨色是**白色**，对底色苛刻得多——
  白色压半强度 accent 只有 2.4–3.8:1（绿色主题最差），全强度 accent 才到
  5.0–7.0:1。`test/app_scaffold_navigation_test.dart` 里
  「tab ink separates the selected state from the resting one」把这条钉住。

> **木木能保持淡药丸的隐含前提**：它的 `tintColor` 是**用户可选的强调色**
> （见 `AppSetting.field_1b`），在近白 glyph 下天然偏深。本 App 的 accent 是
> 每主题固定的、偏亮的品牌色，所以白色 glyph 需要实心药丸。

`glassStyle` 留库默认（纯折射），只设运动参数：`growHeight 9`、
distortion `.04 / 12`、travel spring `280 / 31.4`、形变上限 ±12%、
`magnification 1`、放大底层透镜 `.87`。

---

## 5. 中央按钮：保色 + 玻璃

### 5.1 问题

中央「记一笔」是**唯一坐在导航栏上面**的元素，而导航栏是玻璃。
原来它是一个不透明的实心色块，在折射胶囊旁边读起来像**贴上去的贴纸**——
既不同材质也不同光照，所以显得突兀。

### 5.2 做法：`LiquidGlassFab` + 半透明主题染色

改用库自己的 `LiquidGlassFab`（和参考实现配它 tab bar 的是同一个原语），
把品牌色从「不透明填充」改成**透镜染色**。着色器把染色合成为：

```
mix(refractedBackdrop, lensColor.rgb, lensColor.a * 光晕衰减 * 形状遮罩)
```

所以 `lensColor.a` 就是「颜色 vs 玻璃」的旋钮，而所有**读起来像玻璃**的部分
是在它之上独立合成的：

- **边缘折射带**及其轻微色散（在轮廓处最强）——所以按钮会真的把页面「掰弯」；
- **光学边缘高光**，角度响应跟随 `lightDirection: 80`；
- **接触阴影**，把按钮从导航栏上抬起来。

`LiquidGlassLens` 在 Impeller 上**独立可用、不需要祖先 `LiquidGlassView`**，
所以按钮在覆盖层之上照样采样实时背景。

染色传的是**半透明** `primary @ 0.76`，**不是** `Color.alphaBlend(primary, surface)`：
后者会得到 alpha=1.0，`mix()` 就没有可混的东西了，内部变成死板油漆、按钮不再是玻璃。

### 5.3 两个刻意的取舍

1. **高对比模式回到不透明实心按钮**（项目既定契约：高对比是**取消**透明，
   而不是「把模糊调轻」）。普通模式才走玻璃。
2. **按钮不再看 `appUsesLiquidGlass`**。它坐在每条主题都会跑的玻璃导航栏上，
   如果按主题开关退回实心，就正好复现了「贴纸」那个问题。
   染色来自当前主题，所以品牌色依然跟着主题走
   （`test/quick_add_button_test.dart` 逐个主题校验）。

> 实测注意：模拟器截图存在偏色，不能拿截图取色来验收颜色，
> 结构（边缘高光、内部折射、阴影）可信，色值要以真机为准。

---

## 6. 全主题玻璃

### 6.1 导航栏玻璃与主题解耦

`AppBottomNavigation` **不再**看 `appUsesLiquidGlass`。玻璃是导航栏的**材质**，
不是某个主题的皮肤——四个主题都走同一条 `LiquidGlassTabBar.withImpeller` 路径，
只有**颜色**跟主题走（见 4.1 / 4.2）。

`AppThemeMaterial.usesLiquidGlass` 保留原意，继续管**卡片 / 弹窗 / 面板**那些
非导航表面（`AppGlassSurface`、`appSheetSurface` 等），不做改动。

### 6.2 页面底图：`AppPageBackground`

玻璃只会显示它下面画了什么。底图若是平铺的 `scaffoldBackgroundColor`，
折射再强也是「带颜色的板子」。所以每个主题都在页面下面垫一层**网格渐变**：

- 底：主题自己的 `scaffoldBackgroundColor` 打底 + 一条大对角渐变压场；
- 三团径向 glow，位置与半径系数照抄木木恢复出来的装饰
  （`Alignment(-0.3, 1.15)` / `1.05`、`(1.05, -0.05)` / `1.10`、`(-0.85, -0.85)` / `1.18`）；
- 颜色从**当前 `ColorScheme`** 派生（`primaryContainer` / `primary` / `surface`），
  不是 per-theme 硬编码表——所以服务端下发的新主题、以及深色分支也自动有底图。

配套改动：`ThemeData.scaffoldBackgroundColor` 三个 solid 主题也改成透明
（`app_theme.dart`），`MaterialApp.builder` 的底渐变对**所有**主题生效
（原本只有 `liquidGlass` 才有）。主页 / 洞察页原本自带的
`DecoratedBox(color: context.appBackground)` 已删除——它们会盖住底图。

**仍未做**：木木从 GetStorage 读 `key_layout_setting_gradient_intensity`
（缺省 50，限幅 0..100）以及背景图预设（`preset1/preset2/custom`）。
现在强度是按主题推导的固定值，没有暴露给用户。

---

## 7. 验证

- `flutter analyze lib`：No issues found。
- `flutter test test/app_scaffold_navigation_test.dart`：14/14 通过。
- `flutter test test/liquid_glass_nav_gap_layout_test.dart`：6/6 通过。
- `flutter test test/quick_add_button_test.dart`：4/4 通过。
- 全量 `flutter test`：baseline 41 个失败，改后 40 个，且全部落在已知的、
  与本次改动无关的失败文件里（`widget_test.dart` 20 个等），**无新增**。
  （`ad_placement_test.dart` 出现过一次 order-dependent 抖动，单独跑 7/7 通过。）
- `flutter build apk --release` 通过，并在两种设备上看过：
  - **真机** `23116PN5BC`（小米，arm64，Android 16，Impeller/OpenGLES）：
    胶囊、光学边缘、选中药丸都渲染，`BackdropFilter` 生效；中央按钮落在空档正中、
    抬高约 2 dp；页面内容确实绘制在玻璃后面并被模糊；四个 tab 位置实测
    `51 / 148 / 245 / 342 dp`，空档中心 `196.5 dp` = 胶囊中心。
  - **模拟器** Pixel_10a_API_37_2 复核最终一版观感：实心 accent 药丸 +
    白色选中 glyph、近黑未选中墨色、surface 50% 胶囊。

### 7.1 仍未验证 / 已知限制

- **Skia 后端**：`withImpeller` 在 Skia/Web 会退化成磨砂单透镜栏，
  `LiquidGlassPillMode.impellerOnly` 不会装折射药丸。这是库的既定降级，
  没有真机验证过观感。
- **深色模式**：四个内置主题都是浅色；深色分支（`AppPageBackground.isDark`、
  高对比）只有单测覆盖，没有真机视觉验收。
- **左右滑动切换 tab**：库的 `withImpeller` 只做点击选中 + 长按拖动药丸，
  没有「滑动切页」。旧自研实现也没有，因此不是回归，但和木木不同。
- **性能**：药丸抬起时会有第二遍 backdrop（库的设计），静止时休眠；
  中央按钮现在也常驻一个透镜（它必须在玻璃之上）。真机帧率未测。
- **图标在药丸下滑过时放大**（木木的 `underGlassIconSize = 30`）：
  库支持，本 App 暂未启用。
- **玻璃后面的高对比正文**：即使胶囊是 surface 50%，页面正文（近黑）透出来
  仍有 ~15:1 的局部对比度，会压过 tab 标签。木木靠的是**页面内容不落在导航栏
  后面**（它下面是柔和网格渐变），而不是靠模糊——模糊对「高对比 + 高覆盖」的
  正文帮助有限。本 App 的缓解是滚动内容由
  `AppNavGeometry.reservedBottomInset` 让位；**首屏停着不滚的短内容**仍可能与
  导航栏重叠（实测主页空状态即如此）。彻底解决要把内容让位量再加大，
  或用 `LiquidGlassScaffold` 那种「页面根本不画在栏后」的结构——两者都需要
  产品决策。

---

## 8. 后续待办

1. 深色主题 / 深色模式下的玻璃与底图验收。
2. Skia 后端（含 Web）观感验收，必要时给低端机加 `LiquidGlassEngine.liteGlassOnSkia`。
3. 开源许可页加入 `liquid_glass_easy` + MIT 全文（迁到 `third_party/` 后仍需列）。
4. `gradientIntensity` / 背景图预设若要跟木木，需要新增设置项与读取逻辑。
5. 真机测帧率：静止、药丸移动、长按拖动、中央按钮四种状态。
6. 首屏不滚动内容与导航栏重叠的处理（见 7.1）。
7. 真机复核中央按钮的染色观感；模拟器截图偏色，不能作为取色依据。

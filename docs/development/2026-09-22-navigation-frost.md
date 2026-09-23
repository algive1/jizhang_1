# 导航栏透字修复

## 问题与结论

首页和“我的”的背景正文透过导航，干扰页签文字。仅将白色底色从约 22% 增加至 65% 后，Android 模拟器仍复现问题。当前 SDK 为 Flutter 3.47.5；设备运行 Impeller OpenGLES。

已检查参数传递：导航 appearance 正常传至 capsule lens，sigma 为 16，tint 未被自适应颜色覆盖。独立导航默认使用 batch；该分支把 blur 和 shader 合成一次背景读取。在同一 debug 会话、同一页面位置热重载对照：`batch:true` 胶囊底板消失，`batch:false` 模糊、底色和边缘恢复。故本次只绕过独立导航的批次合成路径，不推断所有设备都存在同一问题，也不改动底层 shader 坐标算法。底板曾试调为 25%，当前按用户要求降为 18%，目标是让背景更明显透出；此前 65% 仅作为遮挡文字的临时参数，已撤回。

## 修改与影响

- `lib/core/widgets/app_bottom_navigation.dart`：`glassTint = Color(0x2EFFFFFF)`，约 18% 白色；sigma 保持 16。
- `third_party/liquid_glass_easy/lib/src/widgets/components/bottom_nav_bar/liquid_glass_tab_bar.dart`：仅 `.withImpeller` 独立导航分支传入 `batch:false`，恢复先模糊、后折射的独立绘制。
- 四个主页面共用修复；普通导航构造器、带 body 的 `buildGlassPillBar` 默认值、其他玻璃组件不变。选中胶囊原本已有独立背景读取，保持原效果。
- 接口、数据库、部署配置及页面业务无改动。仍允许内容经过浮动导航背后；胶囊以外区域不做额外遮罩。

## 验证

- `flutter test test/app_scaffold_navigation_test.dart test/liquid_glass_nav_gap_layout_test.dart test/quick_add_button_test.dart --no-pub`：24 项通过，覆盖主题、对比度、高对比模式、底部留白、中心间距、切页回调、快捷记账点击/长按。
- `dart analyze lib/core/widgets/app_bottom_navigation.dart third_party/liquid_glass_easy/lib/src/widgets/components/bottom_nav_bar/liquid_glass_tab_bar.dart`：无问题。
- 模拟器 `emulator-5554`：实际检查首页、流水、洞察、我的，以及中央加号打开记账页；未提交测试账目。
- A/B 截图位于 `docs/qa/navigation-frost-2026-09-22/batch-on.png` 和 `batch-off.png`。这两张是此前 65% 底色下、同一会话同一页面位置的批次参数对照，仅用于定位渲染问题，不代表当前视觉目标。25% 试调截图为 `tint-25.png`；本轮 18% 版本随后覆盖安装到模拟器。
- `flutter build apk --release --no-pub`：构建成功，最终包已覆盖安装模拟器并复核首页透字场景；截图为 `docs/qa/navigation-frost-2026-09-22/release-home.png`。
- 先前 65% 试调的安装包：`E:/jizhang_1/dist/jizhang-navigation-frost-20260922.apk`，SHA-256：`9648ee4a70e09d34400018a9846bc21b4fcfce46a360f5dbb8b09a8ab899ce88`；它不代表当前 25% 视觉参数。25% 本轮已用 debug 包在模拟器热启动验证，截图另存为 `docs/qa/navigation-frost-2026-09-22/tint-25.png`。
- “我的”滚到末尾后服务协议行完整位于导航上方；中央加号未遮挡该行。

## 验收与局限

将首页正文、“我的”菜单行滚动到导航后方：胶囊内不应辨认出背景文字，导航图标及标签保持清晰；滚到末尾时末项能完整露出并操作；加号和页签切换可用。

导航从批次合成改为独立 blur/shader 读取，可能增加一定渲染开销；这里只有一个底板，本次未做帧耗时基准测试。未在连接的用户手机安装，也未实测其他 GPU 或 iOS。构建日志仍有既有 alipay_kit iOS 插件缺失和 cryptography_flutter KGP 迁移提示，属于现有依赖问题，本次未扩大范围处理。

---

## 追加（同日）：底板从「加白」改为「压暗色调」

### 为什么调白没有中间态

底板对外的全部外观是 `mix(模糊背景, tint.rgb, tint.a)`（`liquid_glass_common.glsl` 的
`applyLensTint`；静止态 `borderAlpha = 1`，所以混合系数就是 `tint.a`）。填充只有
**混合白**一个自由度，而页面本身近白（`#EFF1F6` 底 + 白卡片）。白叠在白上不存在
可分离量：

- 18% 白只把背景抬高约 **3/255**（实测含 rim/模糊约 +6～11），低于可见阈值 → 底板
  读起来就是「没有底板」；
- 而要让白可见必须到 **60%+**，那时模糊背景一起被洗掉 → 「看不到背景」。

两个需求落在同一根线性轴上且方向相反，所以只有两端可用。这跟 18/25/65 这些数值
无关，是旋钮选错了方向。

另有一处**真正的二态**，与取值无关：批次路径把 blur 折进同一个 filter
（`compose(outer: shader, inner: blur)`，`render_liquid_glass_lens.dart`），在
Impeller GLES 上会整块丢掉底板——`batch-on.png` 里连模糊都没有了。当前已用
`batch: false` 绕过，导航走独立 blur + shader 两遍，这一条不再复现。

### 改法

`lib/core/widgets/app_bottom_navigation.dart`：填充改为**比页面更深、更冷**的色调，
让底板靠明度/彩度而不是不透明度与页面分离。

| 项 | 旧 | 新 |
| --- | --- | --- |
| `glassTint` | `0x2EFFFFFF`（白 18%） | `0x61D2DAE8`（`#D2DAE8` 38%） |
| 合成后底板 | `#F2F4F8` | `#E4E8F1`（相对页面 −11/−9/−5） |
| `unselectedInkFactor` | .90 | **.84**（四主题最差 4.77 : 1） |
| `selectedInkFactor` | .86 | **.80**（最差 4.65 : 1） |

两个要点：

1. **低 alpha + 更深的填充**，而不是高 alpha + 白。合成结果一样深，但背景参与合成的
   权重更大（62%），也就是「背景透出」更多。
2. 底板在页面基准上是一个 −11 的台阶，在**白卡片上是 −16**；旧的白填充在白卡片上
   几乎是 0。这正是「底板看不见」的来源：不是不够不透明，而是方向不对。

墨色因子必须跟着动：底板变深会吃掉深色墨的对比，所以墨色一并压深，把**比值**
（真正要守的契约）拉回参考实现的 ~4.7 : 1。`test/app_scaffold_navigation_test.dart`
里模型化的胶囊常量同步改为 `#E4E8F1`。

### 验证

- `flutter test test/app_scaffold_navigation_test.dart test/liquid_glass_nav_gap_layout_test.dart test/quick_add_button_test.dart --no-pub`：24 项通过（含四个主题的墨色对比闸门与高对比不透明分支）。
- `flutter analyze lib/core/widgets/app_bottom_navigation.dart test/app_scaffold_navigation_test.dart`：No issues found。
- 全量 `flutter test --no-pub`：**+567 −43**，与改前基线 `fanbianyi/full_test.log`（9-21）的
  **+540 −43** 失败数完全相同，`widget_test.dart` 两边都是 20 个；失败文件里没有一个是
  导航 / 玻璃 / 快捷记账相关（那三个文件本身 24/24 通过）。本次改动零新增失败。
- `flutter build apk --release --no-pub`（`JAVA_HOME=E:\jizhang_1\tools\jdk21\jdk-21.0.12.1+1`）+ `adb install -r` 到 `emulator-5554`，首页与「我的」底部实拍见 `docs/qa/navigation-frost-2026-09-22/tonal-home.png`、`tonal-profile.png`、`tonal-profile-scrolled.png`。
- 实拍取样（「我的」列表滚到导航后，同一 y 上比较底板内外的同层内容）：
  **白卡片本体 ~247–250 → 底板体内 ~222–228，即 −20 档台阶**；旧的白填充在白卡片上
  是 +1（等于没有）。底板在页面基准上是约 −10 档。这就是「底板可见」和「背景仍透出」
  同时成立的原因。
- 安装包：`E:/jizhang_1/dist/jizhang-tonal-nav-20260922.apk`，
  SHA-256：`feb514029fae6b8dcf0c85f5e2c90defebda03c7322e8ff5430d6e829600a42b`（视口改动后重出）。

### 仍未做

- 填充仍是**均匀**色调。要让底板进一步「读作玻璃」而不靠加深，方向是边缘光学
  （rim / 折射带）或顶部渐变，不是继续加深 body。
- 正文仍会滚到底板下面（`reservedBottomInset` 只让开滚动空间）。要彻底解耦「正文
  可读性」与「底板不透明度」，需要内容接近底板时淡出，或改成页面不画在栏后的结构。
- 只测了模拟器（Impeller GLES）。真机与 Skia 未复核；批次路径（`batch: true`）
  丢底板的老问题仍在库里，本 App 靠 `batch: false` 绕过。
  → **真机已在追加三复核**（小米 23116PN5BC，Impeller/OpenGLES）：视口修复、色调填充、
    σ5 三项在真机上均成立。Skia/Web 仍未复核。

---

## 追加二：先证明模糊在工作，再修真正的那条缝

### 结论：模糊一直是接线的，问题在「哪里没有玻璃」

用一层**保证位于底板后面的高对比度图案**做了探针（图案横跨整屏，所以同一帧里就能
比较板内板外），实测：

| 位置 | y2210–2320 的笔画对比度（亮度极差） |
| --- | --- |
| 胶囊左缘**外侧**（x=4–42） | **254**（纯黑 0 ↔ 白 254，根根锐利） |
| 胶囊**内部**（x=250–380，避开导航图标） | **17**（被抹成该条纹的面积平均值） |

10 dp 周期的黑白细条在板内被抹成均匀灰（极差 254 → 17），而在同一帧、同一条 y 上、
仅隔 6 px 的板外完全锐利。**模糊是接线的，而且很强。** 探针图：
`docs/qa/navigation-frost-2026-09-22/probe-pattern.png`、`probe-text-inside.png`
（这两张来自临时探针构建，图案不是产品内容）。

### 真正的问题：胶囊底边到屏幕底那条缝没有玻璃

胶囊浮在底边上（底边距 = 安全区 + 8 dp），它**下面**那条 32 dp 的缝完全没有玻璃。
页面正文只要停在那儿，就是**锐利地贴在导航栏下面**——看起来就是「底板没糊背景」。

四个主页面的 `reservedBottomInset` 是**滚动内边距**：它只让开滚动空间，对「内容比
视口短、根本滚不动」的页面（本机空数据即如此）完全不起作用，正文照样落在缝里。
`docs/qa/navigation-frost-2026-09-22/tonal-profile-scrolled.png` 里的
「个性化设置 / 主题外观」就是这一态。

### 改法

`lib/core/widgets/app_scaffold.dart`：把**页面视口收在胶囊底边**，而不是屏幕底边。

```dart
body: Padding(
  padding: EdgeInsets.only(
    bottom: AppBottomNavigation.geometry.barBottomInset(bottomPadding),
  ),
  child: widget.child,
),
```

效果：

- 胶囊**覆盖的**那段（y 胶囊顶边…底边）仍在视口内 → 正文照旧从玻璃下面滚过并**被模糊**；
- 胶囊**下方**那条缝留给主题底图（只有渐变，没有可辨认的细节）→ 不可能再出现锐利正文。

这是一次一行的结构改动，不动 shader、不动 blur、不动几何常量。

### 验证

- `flutter analyze lib/core/widgets/app_scaffold.dart lib/core/widgets/app_bottom_navigation.dart`：No issues found。
- 导航三项测试 24/24 通过（视口改动不影响 `_shellStackChildren` 与预留量断言）。
- `emulator-5554` 实拍：`fix-home.png` / `fix-profile.png`（两帧一致，非过渡帧）。
  实测胶囊下方条带（y2345–2415）除系统手势条外**没有任何暗像素**；x=300 处亮度
  226–233，与主题底图一致。改前同一位置是正文行（`tonal-profile-scrolled.png`）。
- 安装包：`E:/jizhang_1/dist/jizhang-tonal-nav-20260922.apk`，
  SHA-256：`feb514029fae6b8dcf0c85f5e2c90defebda03c7322e8ff5430d6e829600a42b`。

### 仍未做

- 若要求「那条缝也要有玻璃」（而不是留白底图），那是**设计变更**：把浮动胶囊改成
  贴底 docked 玻璃条（底板下缘到屏幕底）。当前保持浮动胶囊，与参考实现的形态一致。

---

## 追加三：模糊半径 16 → 5（用户实测选定）

### 结论：模糊管的是「细节剩多少」，不是「透不透」

旋钮分工必须分清：

| 想要的效果 | 该动的旋钮 |
| --- | --- |
| 背景**透出多少**（明暗/彩度） | `glassTint` 的 alpha |
| 背景**细节剩多少**（糊到什么程度） | `capsuleBlurSigma` |

σ 调大**不会**让底板更「玻璃」，只会让背景更少：σ16 时底板后面被抹成一片平糊，
整块读起来像不透光的板子；σ5 时背景仍以**形体的形式**在底板下移动，这才是「像玻璃」
的来源。参考实现自己用的就是 **2.5**（见本文 §0），本 App 此前用 16 是为了「把压在
栏下的高对比正文打散」——而正文现在由 `reservedBottomInset` + 视口内缩挡在栏外
（追加二），那件事不再需要靠大半径完成。

### 改法

`lib/core/widgets/app_bottom_navigation.dart`：

- `capsuleBlurSigma`：**16 → 5**；
- 高对比分支原来写成 `sigmaX: 8, sigmaY: capsuleBlurSigma`（一个**非对称高斯**，
  应是笔误）→ 改成两轴同值。高对比下表面本来就不透明，视觉无变化。

### 代价（明确记下）

σ5 之后，滚动中从底板下穿过的正文**是可以辨认的**——这推翻了本文开头那条旧验收
「胶囊内不应辨认出背景文字」。这是用户看过预览页后的选择：**要玻璃感，不要绝对干净**。
静止状态下正文仍在栏外（`reservedBottomInset` = 110 dp，视口再内缩 32 dp），
所以「停在栏下的正文」不会出现。

### 验证

- `flutter analyze lib/core/widgets/app_bottom_navigation.dart`：No issues found。
- 导航三项测试 24/24 通过。
- `emulator-5554` 实拍对比 `docs/qa/navigation-frost-2026-09-22/cmp-blur16-vs-5.png`
  （上 σ16 / 下 σ5，同一页面同一位置）：σ16 的板内无任何结构；σ5 的板内能看见被
  糊开的形体。同帧里胶囊下方条带两种参数都保持干净（追加二的视口修复未回退）。
- 安装包：`E:/jizhang_1/dist/jizhang-tonal-nav-20260922.apk`，
  SHA-256：`b71f0fa3172e44b32d08822e93a5e78c9bf4bd29ca458a2636e077501b2f1af4`。
- **真机** `145a0a68`（小米 23116PN5BC / Android 16 / arm64-v8a，`fresh_green` 主题，
  有真实账目数据）：`adb install -r` 覆盖安装成功（同签名，**未卸载、数据未丢**）。
  实拍 `docs/qa/navigation-frost-2026-09-22/phone-home.png`、`phone-scrolled.png`：
  滚动中同帧可见「胶囊上方正文锐利 ↔ 板内被糊成形体（图标/金额的软色斑、卡片圆角被
  抹开）」，胶囊下方条带保持干净（无锐利正文），手势条正常。真机滚动可用
  （采样 859/1710 变化），静止时正文仍在栏外。

### 网页预览

`E:/jizhang_1/dist/nav-preview/`（`node serve.js`，http://127.0.0.1:8787/）是这次调参
用的等价页面：同一套几何与材质、CSS `backdrop-filter` 等价于库里的独立 blur pass、
带 σ / 填充 alpha / 填充 RGB 滑块与四个预设，以及一键切换的三个状态
（`?probe=1` 压力测试图案、`?strip=1` 缝也加玻璃、`?viewport=0` 修复前）。
**它不是 App**：web/Skia 没有折射，边缘只有 rim 近似。

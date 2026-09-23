# Liquid Glass — Luna 开发指令

日期：2026-09-21。状态：Android 首版已实施，待模拟器/真机视觉验收。
目标：先解决底部导航可读性，再建立透射、边缘折射和受触摸驱动的材质反馈。
执行栈：本地 Flutter 3.47.5 / Dart 3.13.4，Android 优先。Luna 使用当前支持的最高推理档 max；该模型不支持 ultra。

本轮已落地：`AppBottomNavigation` 使用单一导航层 `BackdropFilter`，选中态使用可受外部位置驱动的 lens 胶囊；`QuickAddButton` 移除玻璃套玻璃；新增 `AppLiquidGlassSurface` 与 `shaders/liquid_glass.frag`。Impeller 支持时使用边缘轻微折射 + 五点软化 shader，不支持或加载失败时回退为相同几何的普通 blur。导航当前实际参数为宿主高 96、顶部 8、左右 16、底部 8、圆角 32；静止选中态使用 `Color(0x16FFFFFF)` 薄基材，长按约 100ms 后胶囊按 fractional slot 以一阶低通跟随手指，松手吸附到最近入口并抑制重复点按；按下 scale `.97/60ms`，松开回到 `1/140ms`。普通 `AppCard` 默认使用接近不透明的 content 材质，重点摘要卡显式使用 `AppCardMaterial.frosted`。

## 1. 设计决策与边界

- 采用现有 Flutter 组件 + 单层背景滤镜 + 能力检测后的局部折射 shader。纯 blur/gradient 可作为降级，但不能称为真实折射；迁移 SwiftUI 导航会扩大路由和平台边界，当前不采用。
- 玻璃用于浮动导航和重要控制层；财务数据、列表、分类网格采用稳定的内容表面。遵循 [Apple HIG Materials](https://developer.apple.com/design/human-interface-guidelines/materials)。
- 导航基材采用 regular 的设计方向。选中态是基材上的薄填充，不再叠加第二层玻璃。[Apple WWDC25](https://developer.apple.com/videos/play/wwdc2025/219/) 明确建议避免玻璃叠玻璃。
- 下列数字是本项目的工程设计值，不是 Apple 公布的私有材质参数，也不代表与原生 Liquid Glass 像素等同。
- 四个路由、中央记账入口、语音长按、会员鉴权、主题目录保持原有行为。系统字体沿用平台默认；不将 SF 字体或 SF Symbols 打包到 Android。
- 当前浅色主题保持浅色可读基底，不在滚动中猜测背景亮度并翻转文字颜色。以后若增加暗色模式，需要独立配色与验收，不通过整体反色实现。

## 2. 已确认的代码风险

| 文件 | 当前实现 | 对本需求的影响 |
|---|---|---|
| `lib/core/widgets/app_bottom_navigation.dart` | 选中项白字；未选中文字 alpha .74 | 明亮高光下选中态反差不足，未选中态进一步变淡 |
| 同上 | 外壳使用单一玻璃层，选中胶囊由 MotionPill 驱动 | 静止态不重复采样；拖动时只让选中焦点产生动态玻璃反馈 |
| 同上 | 字号 11、TextScaler.noScaling | 固定小字阻断系统文字放大 |
| 同上 | .92 → 1.04 → 1 的定时缩放 | 弹性过强，取消手势也触发回弹序列 |
| `lib/core/widgets/app_glass_surface.dart` | blur + 透明渐变 + 青/品红描边 | 没有背景采样位移；彩边属于绘制效果，并非光学折射 |
| `app_card.dart`、HomeSurface、分类网格等 | 普通内容卡片改用 content，重点摘要卡显式使用 frosted | 普通内容保持稳定清晰；重点卡保留玻璃质感 |

以上是静态代码证据；导航在具体设备上“完全不可见”的完整原因仍需截图与布局复现，不能只凭颜色代码断言已定位全部原因。

## 3. 生产参数基线

单位：几何为 Flutter logical px（本文简称 dp），时间为 ms，颜色 alpha 为 0–1。`ImageFilter.blur` 的 sigma 是标准差，不是 CSS blur radius；不要跨 API 直接复制数值。

| 参数 | 常规值 | 约束 / 降级 |
|---|---|---|
| 导航几何 | 宿主高 96；顶部 8；左右 16；底部 8 + SafeArea；圆角 32；中央间隔 72 | 宿主保持全宽；不修改 Scaffold FAB 坐标系 |
| 文字与图标 | 图标 23；标签 12，未选中 w500 / 选中 w600 | 标签接受系统缩放；点击区域至少 48×48；选中状态另有图形填充及语义 |
| 标签前景 | 未选中 `#344054`；选中 `#243F73`；均 alpha 1 | 禁止给整个导航或标签加 Opacity |
| 导航基底 | `#F7FAFF`，上→下 alpha `.82/.76/.72`，stops `0/.5/1` | 字形背景不得低于 .72；阴影绘在基底后方 |
| 背景模糊 | sigmaX = sigmaY = 16 | 无 shader 时保留 blur；减少透明度时 sigma 0、填充 alpha 1 |
| 选中薄层 | 静止时为稳定主题填充；拖动/吸附时由 `LiquidGlassMotionPill` 提供 lens 反馈；圆角跟随槽位几何 | 放大文字时宽≥实测文字宽+4，高≥图标/标签实测总高+8；宽不超过槽位；不新增全屏滤镜 |
| 顶缘反光 | 内描边 1；白色 alpha 上 .70 → 下 .16 | 只限轮廓，不覆盖文字；取消青/品红双描边 |
| 外缘轮廓 | 1；`#344054 @ .24` | 高对比模式 1.5，`#243F73 @ .65` |
| 层次阴影 | `#101828 @ .12`，blur 24，offset(0,8)；辅阴影 alpha .06、blur 3、offset(0,1) | 阴影在 clip 外绘制；避免大面积发光 |
| 折射 | 内缘宽 6；峰值位移 1.5；总位移上限 2 | 中心无静态位移；仅滤镜输入背景发生位移 |
| 触摸光 | 白色 alpha ≤ .12；半径 28；光心相对默认位置最多移动 6 | 无交互时静止；不使用陀螺仪常驻动画 |
| 触摸涟漪 | 位移幅度 .30；波长 24；传播速度 140 dp/s；生命周期 400 | 每次有效按下最多一个；只影响基材，不能摇晃数字和字形 |
| 中央加号 | 56×56；`#385995 @ .96` 底、白色加号；细白描边 .45 | 维持点击/长按语义；不在导航上再叠一层 BackdropFilter |
| 内容卡片 | `AppCardMaterial.content` 使用 appSurface，液态主题 alpha .96；保留原圆角、留白 | 不折射，不动态高光，不逐卡片做 backdrop blur；重点摘要卡才显式使用 `frosted` |

色彩计算校验：上述最薄基底 `.72` 覆盖纯黑时，`#344054` 的理论 sRGB 对比度约 5.03:1；选中字色在纯 `#DCE8FF` 上约 8.37:1。此计算不替代最终合成截图检测。

导航文字最终合成对比度 ≥4.5:1，必要图标/焦点/状态边界 ≥3:1；用填充、字重、图标状态和语义共同表达选中状态。可访问性方向参考 [Apple HIG Accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility)。

## 4. 动效契约

| 事件 | 参数 | 实现与约束 |
|---|---|---|
| 按下 | scale 1 → .97，60，easeOutCubic | 只缩放视觉子层，点击区域不缩小；导航槽位不移动 |
| 松开 / 取消 | 从当前值回到 1；m=1、k=400、ζ=.88，c=35.2 | SpringSimulation；目标约 300–380 内稳定；超调 ≤1%；取消不产生跳转/触感 |
| 切换选中项 | 指示层位置采用同一弹簧；拖动时使用 fractional slot；字色 120 easeOut | 用固定布局 + 外部 center 驱动 MotionPill；不动画修改 Row 宽度或 FAB 位置 |
| 跨越中央加号 | 新旧选中薄层 120 淡出/淡入 | 避免指示层穿过中央主操作按钮；同侧相邻项才滑移 |
| 光心跟随 | 一阶低通 τ=50；最大位移 6 | `x += (target-x)*(1-exp(-dt/.050))`；仅触摸活跃时更新 |
| 光效退场 | alpha → 0，180，Cubic(.2,0,0,1) | 结束即停止 ticker，不循环呼吸 |
| 触摸波 | 400，指数衰减 exp(−t/.12) | 限制单波；取消时 80 内淡出；末端平滑衰减到 0 |
| 触感 | 有效切换一次 `HapticFeedback.selectionClick()` | 同项重按、程序路由更新、取消无触感；触感失败不阻塞导航 |

Flutter 用 `AnimationController` + `SpringDescription.withDampingRatio(mass:1, stiffness:400, ratio:.88)` + `SpringSimulation`。重定向动画继承当前位置与速度；若初始速度使超调超过上限则限速。废弃多段 `Future.delayed` 动画。采用 `AnimationController` 正常 tick 与局部 repaint；动画结束必须 dispose/stop。这些是项目自定义反馈，不声称复制 Apple 内部物理引擎。

## 5. Flutter 渲染指令

1. **渲染顺序**：页面内容 → 导航外阴影 → ClipRRect 内背景滤镜 → 可读性 tint → 选中薄层 → 轮廓/局部光 → 完整不透明图标文字。光效不得在字形前景上进行白色覆盖。
2. **可读性基线**：先完成普通 `BackdropFilter(ImageFilter.blur(...))`。选中层改为普通装饰组件；修改 QuickAddButton 避免叠加滤镜。完整基线应独立通过验收。
3. **真实背景折射**：本地 SDK 已提供 `ImageFilter.shader`、`ImageFilter.isShaderFilterSupported`。仅支持时创建着色器滤镜；用 `FragmentProgram.fromAsset` 加载，文件在 `pubspec.yaml` 的 `flutter.shaders` 中声明。失败回到上述基线，导航不可变空白。[Flutter API](https://api.flutter.dev/flutter/dart-ui/ImageFilter/ImageFilter.shader.html)
4. **第一版组合**：导航只保留一个 `BackdropFilter`。Impeller 路径使用 `ImageFilter.shader`（shader 内含五点软化与边缘采样位移）；其他后端使用 `ImageFilter.blur`。widget 树保持一个导航背景捕获点。强模糊会减弱边缘折射细节；在格线夹具上验证，不为追求夸张效果降低字形后方 tint。
5. **shader 约定**：首个 float uniform 为输入尺寸 vec2；首个 sampler2D 由引擎提供背景输入，Dart 不覆盖这三项。自行传递局部几何、触点、时间、实际坐标比例；OpenGLES 的输入采样执行正确 Y 翻转。输出保持 premultiplied alpha。[Flutter shader 文档](https://docs.flutter.dev/ui/design/graphics/fragment-shaders)
6. **坐标门槛**：滤镜输入纹理不保证等于导航局部矩形。先用 identity shader + 校准格线验证 clip、画布原点、filter bounds、DPR，再实现 SDF。几何只能在同一坐标系计算；禁止把屏幕坐标直接当纹理坐标或对 sigma/位移重复乘 DPR。检查 DPR 1/2/3、非零偏移、旋转后的结果。
7. **折射地图**：局部圆角矩形 SDF 计算边缘内距 `d` 与法线 `n`。`u=clamp(d/6,0,1)`，边缘权重 `E=sin(πu)^2`（仅 d∈[0,6]）；背景采样偏移 `δ=1.5*E*n`，边界与中心均归零。此为受控视觉近似，不设置虚构的 Apple 折射率。
8. **涟漪地图**：触点 p0，r=|p−p0|，t 秒；位移增量沿径向，幅度 `.30*exp(−t/.12)*sin(2π*(r−140*t)/24)`。仅波前附近 18 dp 内有效，并以 smoothstep 淡出空间边界和生命周期尾部；r≈0 时强制增量 0。合并后的 δ 长度限制为 2。触摸文字不位移。
9. **采样与性能**：UV 限制在有效输入内并保留采样边距；只处理轮廓内区域。禁止 `toImage()`、屏幕截图、CPU 逐帧读像素。默认单路 RGBA 采样，不做 RGB 色散和全屏噪声。折射位移贴图由几何解析生成，不新增 PNG 材质包。
10. **复用**：继续使用 AppThemeMaterial 与 AppGlassSurface 边界；仅补充实际会被多处使用的语义值。不要新增远端调参协议、通用材质框架或第三方 glass 包。shader 启动加载一次，每实例管理 uniforms，离开页面释放实例资源。
11. **分组限制**：避免背景滤镜重复叠加。若以后使用 BackdropGroup，重叠区域不能共享同一 backdrop key；不能靠 RepaintBoundary 假定滚动背景不会重绘。[BackdropFilter 文档](https://api.flutter.dev/flutter/widgets/BackdropFilter-class.html)

## 6. 可访问性与适配

- `MediaQuery.disableAnimationsOf(context)`：立即停止弹簧、涟漪、移动高光、位移跟随；选中状态立即更新，静态材质可保留。运行中切换也生效。
- `MediaQuery.highContrastOf(context)`：基底 alpha 1、无折射/涟漪，前景 `#18243A`，采用加强轮廓。不要仅减少 blur 而留下透明背景。
- 减少透明度与减少动态效果是不同设置。本地 Flutter MediaQuery 没有单独的 Reduce Transparency 字段；iOS 发布前需要小型平台桥读取 `UIAccessibility.isReduceTransparencyEnabled` 并订阅 `reduceTransparencyStatusDidChangeNotification`，启用时使用完全不透明底且移除滤镜。[Apple API](https://developer.apple.com/documentation/uikit/uiaccessibility/isreducetransparencyenabled)
- 标签移除 `TextScaler.noScaling`，通过文字测量扩展导航/选中层高度，不缩小字体抵消系统设置。320 dp 下验证四项触区宽度≥48；1.6×和2×文字不溢出。
- 若导航高度变化，同步核对 AppScaffold 的 FAB 锚点、页尾滚动空间、键盘与安全区域；不能只增高导航而遮挡最后一条流水。
- 保留 selected/button/label 语义，补齐可聚焦与键盘激活路径；焦点环 2 dp、深色高对比。TalkBack/VoiceOver 必须能识别当前页与记账/语音动作。
- 若将来独立实现 iOS 原生视图，优先使用系统 TabView/toolbar 或 `.glassEffect(.regular.interactive())`；由系统处理原生材质适配。不能把 SwiftUI modifier 当作 Flutter Widget API 使用。[SwiftUI 官方示例](https://developer.apple.com/videos/play/wwdc2025/323/)

## 7. 按顺序执行与关联影响

1. **复现并留基线**：液态玻璃主题分别打开首页、流水、洞察、我的；保存浅底/深图/密集文字滚动到导航后的截图。检查路由是否构建底栏、布局遮挡、合成层，再验证颜色问题。执行已有导航测试获取基线。
2. **修复导航对比度**：改 `app_bottom_navigation.dart`，先修前景、取消指示器的 AppGlassSurface、恢复文字缩放，再加入内容/指示层测量。关联 `app_scaffold.dart`、`quick_add_button.dart` 的布局与手势必须同步回归。
3. **确定材质边界**：在 `app_theme_definition.dart` / `app_theme.dart` / `app_theme_tokens.dart` 收拢玻璃前景与材质数值，默认纯色主题保持现有结果；`app_glass_surface.dart` 落实 tint/轮廓/阴影和可访问性分支。
4. **同步内容层**：`app_card.dart`、`home_cards.dart` 的 HomeSurface、`home_promotional_cards.dart`、`category_grid.dart`、`recurring_bill_create_sheet.dart` 的内容表面取消 backdrop。逐一检查 `quick_add_sheet.dart` 的 AppGlassSurface 用途：浮动工具可留，整页数据与已在 sheet 上的内层表面不再叠玻璃。不同步将继续出现层级混乱与多滤镜开销。
5. **接入动效**：局部控制器驱动导航、光效与触感；优先验证快速连续切换、取消、跨中央按钮、无动画设置。不能把高频动画状态放进全局主题 Provider。
6. **接入折射**：新增一个 shader 文件并声明资源；先验证 identity 与坐标，再加 SDF、涟漪。更新此文档记录资源声明、运行后端、降级条件；不改主题服务端 JSON 与数据库。
7. **真机性能及回归**：按下一节验收；以截图与 profile 帧时数据确认效果。若设备档位无法达到预算，该档构建使用无 shader 基线；不引入未经证实的设备型号黑名单或自动帧率调参系统。

范围：主题材质、导航及公共内容表面；配置变化仅可能包含 shader 资源注册。现有记账、账户余额、会员权益、远端主题接口、数据库与部署不在改动范围。iOS 可访问性桥若实施，需补充方法/事件契约与平台验证记录。

## 8. 验收与交付门槛

| 类别 | 必须验证 |
|---|---|
| 对比度 | 白、黑、密集流水文字、彩色图片四种背景；四个标签持续可读，合成后文字≥4.5:1、必要图标/状态边界≥3:1 |
| 布局 | 320/393/430 dp；文字1×/1.6×/2×；安全区0/34；无溢出、FAB遮挡或末行不可达 |
| 行为 | 四个一级路由；中央点击打开记账；长按语音；取消不跳页；键盘与弹层叠放；快速重复切换 |
| 材质 | 导航无二层 backdrop；财务文字始终锐利；彩边消失；格线背景在边缘可见位移且中心无静态位移 |
| 辅助功能 | 高对比、减少动态、iOS减少透明度（发布前）；设置在运行中改变；屏幕阅读器、焦点与系统文字缩放 |
| 性能 | Profile 真机；60Hz UI/raster各自 p95<16.7ms，120Hz各自 p95<8.3ms；记录设备/后端/刷新率，检查首次加载和交互峰值；静止时无常驻动画 ticker |
| 兼容 | Shader能力 false、加载失败路径仍可操作；三套纯色主题布局/导航回归；无需修改会员主题目录 |

优先复用并必要时扩展 `test/app_scaffold_navigation_test.dart`、`test/product_visual_regression_test.dart`、`test/quick_add_redesign_test.dart`。行为与布局断言优先；截图验证真实合成材质。Widget 测试不承担证明 GPU shader 光学结果的职责；shader 路径必须在 Impeller 真机验证。

现有导航测试已同步为单层 `BackdropFilter`、连续位置过渡、100ms 长按跟手以及 `.97 → 1` 的克制缩放；不能为通过旧断言恢复双层滤镜或 `.92/.104` 回弹。卡片材质测试覆盖 content 无滤镜、frosted 保留共享玻璃层。

本轮开发交付包含：受影响文件、shader 资源声明、导航专项测试和 release APK。仍缺少真实设备截图、GPU profile 与 iOS Reduce Transparency 桥接验证；因此当前结论是 Android 可编译的视觉基线已修复，不能替代真机视觉验收。

Luna 只读复核结果：已接收本指令；确认本地 shader API、双滤镜/文字风险、内容组件影响范围及旧测试契约。基线方案未发现 API 阻塞；实际设备后端、shader 坐标边界和 iOS 减少透明度桥接仍须按上文验证。

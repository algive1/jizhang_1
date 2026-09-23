# 液态玻璃卡片与导航手势设计

日期：2026-09-21
状态：已实施，待模拟器/真机视觉验收

## 目标

参考木木记账的层级策略，建立可读、可维护的玻璃材质体系，并修复当前底部导航选中胶囊不能跟随手指移动的问题。

目标不是让所有卡片都使用实时折射，而是把玻璃效果放到真正需要强调的层级：

1. 普通内容卡稳定清晰；
2. 首页摘要、资产摘要和分析摘要使用轻磨砂；
3. 导航、中央记账入口和少量选中交互使用液态透镜；
4. 导航选中胶囊在按住后随手指移动，松手吸附到最近入口。

## 证据与当前问题

木木记账的静态证据能明确确认 `liquid_glass_easy`/`LiquidGlassLens` 用于导航和 Motion Pill；普通卡片存在 `MMGlassContainer`、`MMGlassPanel`、`FrostedGlassFallback` 等玻璃/磨砂组件，但不能证明每张普通卡都使用同一套实时折射 shader。

当前项目已将 `AppCard` 默认材质切换为接近不透明的 content，仅由重点摘要卡显式选择 `frosted`。导航通过父级统一手势层处理点击与长按，`LiquidGlassMotionPill` 的 center 在拖动期间接受 fractional slot；松手后按最近入口吸附。`LiquidGlassMotionPill.motion` 仍只负责对外部位置变化进行形变采样，手势和路由由外层状态机负责。

## 设计

### 1. 卡片材质

增加一个轻量的材质枚举：

```dart
enum AppCardMaterial { content, frosted }
```

`AppCard` 默认使用 `content`：

- 使用接近不透明的 `appSurface`；
- 保留现有圆角、padding、边框和阴影；
- 不执行逐卡片 `BackdropFilter`；
- 不改变卡片内部的数据、事件和语义。

`frosted` 显式复用当前 `AppGlassSurface`，只用于有背景插画、渐变或摘要层的重点卡。`AppLiquidGlassSurface` 不用于普通卡片。

第一阶段迁移范围：

- `home_cards.dart`：月度摘要使用 `frosted`；预算/目标图文卡保持重点卡层级；
- `home_promotional_cards.dart`：保留 `frosted`；
- `transaction_summary_card.dart`：使用 `frosted`；
- `transaction_date_group.dart`：使用 `content`；
- `asset_overview_page.dart`：后续迁移时资产摘要使用 `frosted`，账户明细使用 `content`；本轮未批量改动该页面；
- `cashflow_cards.dart`：趋势摘要使用 `frosted`，普通分析明细使用 `content`。

设置、家庭、目标、自动记账确认页等大量次级页面暂不批量迁移，待第一阶段截图和性能结果稳定后再处理。

### 2. 导航手势与液态透镜

保留现有 `AppBottomNavigation` 的路由、中央 FAB、SafeArea 和主题分支。只重构 `_LiquidGlassNavBar` 的输入和位置驱动：

1. 在视觉层上方增加统一的 `RawGestureDetector` 手势层；
2. 普通抬起执行单击切换；
3. 按住约 100ms 后进入抓取状态，位置转为连续的 fractional slot；
4. 使用导航布局计算把手指横坐标转换为 0…3 的胶囊位置；
5. 拖动时更新 `LiquidGlassMotionPill.center`，保持 `active=true`，让包内 ticker 采样移动轨迹并驱动拉伸/压缩；
6. 松手时按最近入口吸附，复用现有弹簧参数，并只在目标变化时调用路由回调；
7. 无动画模式直接定位并取消形变；高对比模式继续关闭折射；
8. 中央 FAB 区域不触发导航切换，保留其点击和长按行为。

静止时的选中状态仍保留统一的可见填充和边界，不能依赖某个页面背景才能看出选中状态。导航不新增第二个全屏背景采样层。

### 3. 影响边界

影响文件主要在 Flutter UI 公共组件、首页/流水/资产/分析页面和导航测试。不会修改数据库、接口、自动记账规则、Android 无障碍服务、通知监听、会员权益或部署配置。

已实现收益：普通列表滚动减少背景滤镜开销，财务文字更稳定；首页/流水摘要和分析摘要保留玻璃质感；导航交互具备按住拖动、弹簧吸附和形变反馈。仍需设备视觉验收确认与木木的光学效果差异。

主要风险：`AppCard` 默认材质变化会影响第一阶段以外仍复用它的页面，因此实施时只改变明确纳入范围的调用点或提供兼容默认值；每次迁移都要做页面截图回归。

## 验收标准

### 卡片

- 液态玻璃主题下，普通流水卡不再逐卡模糊，金额、商户和状态保持清晰；
- 首页、资产和分析重点卡仍有轻微磨砂与背景层次；
- 固定主题、浅色主题和大字号下无溢出；
- 滚动列表不新增常驻 ticker，不改变交互语义。

### 导航

- 四个入口点击切换仍正确；
- 选中胶囊在按住并横向移动时，位置在连续帧中连续变化；
- 松手后吸附到最近入口并只触发一次路由变化；
- 快速点击、取消、反向拖动、跨中央 FAB、连续切换均不跳错；
- 无动画、高对比和固体主题保持可用；
- 导航选中效果在四个入口视觉一致，不再只有“我的”显得明显半透明。

## 验证计划

先增加导航拖动的失败测试和材质分支测试，再实现最小代码改动。随后运行：

- `flutter test test/app_scaffold_navigation_test.dart`；
- 首页、流水、资产、分析相关 widget/视觉测试；
- `flutter analyze`；
- `flutter build apk --release`；
- 模拟器截图以及至少一次真机/Impeller 视觉检查。

截图只验证合成后的视觉结果；Flutter widget 测试不承担证明 GPU shader 光学效果的职责。

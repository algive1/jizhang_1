# 个人中心页面升级（2026-09-12）

## 目标

按最终确认的个人中心原型图升级 Flutter 页面，同时保留现有路由、Riverpod 数据源和底部导航行为。

## 修改

- `lib/features/profile/presentation/profile_page.dart`：重排个人中心结构，接入真实的账本、账户、分类、预算、流水、周期账单、会员和共享会话状态；保留现有入口路由。
- `lib/features/profile/presentation/profile_cards.dart`：新增顶部资料、会员卡、快捷统计、月度进度和分组菜单的视觉组件。
- `lib/features/profile/data/profile_stats.dart`：集中计算连续记账/月度进度，并从有效流水附件查询记账照片数量。
- `lib/core/widgets/app_bottom_navigation.dart`：将底部导航调整为原型的暖白圆角容器，并处理大字体下的标签缩放溢出。
- `lib/core/constants/app_assets.dart`：登记两张个人中心装饰素材。
- `test/widget_test.dart`：同步个人中心会员文案断言，避免旧的 `Free 方案` 断言阻断核心路由回归测试。
- `assets/images/profile_header_scene.webp`：顶部沙发、猫、边桌和植物透明插画。
- `assets/images/monthly_progress_scene.webp`：月度进度卡的山丘、嫩芽和太阳透明插画。

## 数据与旧逻辑

账本、账户、分类、预算、流水、周期账单和附件统计使用本地 Drift 数据库；会员仍由当前本地免费方案仓储提供，付费订阅没有虚构到期时间；积分和个性化设置当前没有后端能力，页面明确提示未开放或跟随系统。设置、通知、会员、共享账本、数据导出、账户资产、分类、预算、周期账单、支付提醒和分期入口均继续使用原有路由或现有功能。

## 验证

- `flutter analyze lib/features/profile lib/core/widgets/app_scaffold.dart lib/core/widgets/app_bottom_navigation.dart`：通过。
- `flutter test test/profile_reference_test.dart`：通过，覆盖 320/360/393/430 宽度和 1.0/1.6 字体缩放，并生成 `docs/qa/profile-reference-2026-09-12/` 截图。
- `flutter test test/widget_test.dart`：通过，18 项核心导航与记账流程回归测试。
- `flutter build apk --debug`：通过；修正后的 APK 已重新安装到 Android 真机。
- 已检查两张 WebP 资源为 RGBA 且保留透明通道。
- 初始本地检查时仅有 macOS/Chrome Flutter 设备，Android 真机连接后已按下方记录完成复验；iOS Simulator 仍不可用。

## Android 真机复验（2026-09-12）

- 设备：`23116PN5BC`，Android 16（API 36），1080×2400，420 dpi。
- `flutter run -d 145a0a68 --no-pub` 安装并启动成功。
- 真机检查顶部安全区、插画裁切、会员卡、统计卡、进度卡、列表滚动和底部导航；第二组菜单在滚动到底部后完整显示，没有横向滚动或 Flutter 布局异常。
- 点击顶部设置打开设置面板；点击顶部铃铛进入已有的支付通知记账页面，系统开关正常显示。
- 真机截图保存于 `docs/qa/profile-device-2026-09-12/`。
- 设备日志未发现 `E/flutter`、`FATAL EXCEPTION` 或 `RenderFlex overflow`。启动时存在一次首帧跳帧和设备厂商图形缓冲区警告，未影响页面功能。

## 右侧箭头与记一笔按钮修正（2026-09-12）

- 复核原型和真机后确认：菜单行的右侧文案长度不同，原布局让箭头跟随文案位置；现将文案与箭头放入右对齐区域，四个页面中的菜单箭头保持同一右边界。
- 个人中心顶部姓名信息卡原有的 chevron 已移除；会员卡自身的权益入口箭头保留。
- 记一笔按钮问题来自 `AppScaffold` 的全局 `centerDocked` 定位，而不是个人中心页面。已在公共 Scaffold 使用带垂直偏移的自定义 `FloatingActionButtonLocation`，让 FAB 和 `BottomAppBar` notch 同时移动，避免 widget transform 留下背景接缝；首页、流水、目标、我的四个导航页逐一测量确认位置一致：按钮中心与屏幕中心重合，按钮顶部与底部导航栏上沿对齐。
- 修正后重新构建并安装 Android 真机包，四个导航页均完成检查。

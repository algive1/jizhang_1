# 2026-09-22 Android 左滑返回与 iOS 转场对齐

## 背景与结论

参考应用（木木记账）在 Android 上也有"从左往右滑动返回"，且是**跟手**的 iOS 风格：手指按住左边缘时页面 1:1 跟随、被压在下面的页面以 1/3 速度视差跟进、松手按距离/速度决定完成返回还是弹回。

逆向确认它并不是系统动画，也不是自研手势：它用的就是 Flutter 的 Cupertino 返回手势 + `CupertinoPageTransition`，只是通过 GetX 的 `popGesture`（默认开）在 Android 上也生效（详见 `fanbianyi/报告` 与本次会话的分析）。这套手势**内建在 `CupertinoRouteTransitionMixin.buildPageTransitions` 里**（`enabledCallback: () => route.popGestureEnabled`），而 `CupertinoPageTransitionsBuilder` 正是委托给它。

所以我们不需要移植任何手势代码，只需要把 Android 平台的转场构建器换成 Cupertino：转场视觉与返回手势一起到位。

## 改动

- `lib/app/theme/app_theme.dart`：新增 `_pageTransitions`，在 Flutter 默认构建器映射的基础上把 `TargetPlatform.android` 覆盖为 `CupertinoPageTransitionsBuilder`，并挂到 `ThemeData.pageTransitionsTheme`。其他平台保持 Flutter 默认（iOS/macOS 仍是 Cupertino，桌面仍是 Zoom）。
- `test/ios_swipe_back_parity_test.dart`：锁定映射关系与真实手势行为。

生效范围：`MaterialApp.router` 下的所有 `PageRoute`，即 go_router 的默认页面（`builder:` 生成的 `MaterialPage`）以及直接 `Navigator.push` 的 `MaterialPageRoute`。

## 行为参数（本仓 Flutter 3.47.5 实测）

| 项 | 值 |
|---|---|
| 触发区 | 左边缘 `max(该方向安全区宽度, 20)` 逻辑像素的竖条，仅 LTR 左侧 |
| 拖动映射 | `delta = 手指水平位移 / 页面宽度`，随后 `controller.value -= delta`（线性跟手） |
| 退出页位移 | 0 → (1, 0)，整屏宽度 |
| 下层页位移 | 0 → (−1/3, 0)，视差 1/3 |
| 松手判定 | 归一化速度 ≥ 1 屏宽/秒 按方向；否则 `controller.value > 0.5` 才完成返回 |
| 收尾动画 | `Curves.fastEaseInToSlowEaseOut`，350ms |

## 不生效的页面（预期行为）

- 路由栈首屏：`ModalRoute.popGestureEnabled` 对 `isFirst` 返回 false。
- `fullscreenDialog: true` 的页面：例如 `showQuickAddSheet`（记一笔）。这类页面渲染 `CupertinoFullscreenDialogTransition`（自下而上），且不挂返回手势——记一笔保持模态语义。
- `NoTransitionPage` 的主标签页（首页/流水/洞察/我的）本来就在 Shell 内切换，不参与 push/pop。

## 取舍

- Android 系统"预测性返回"（`PredictiveBackPageTransitionsBuilder`，Flutter 3.47 的 Android 默认值）会被替换掉。当前 `AndroidManifest.xml` 未声明 `android:enableOnBackInvokedCallback`，所以系统层面本就没有预测性返回动画，替换无感知。若将来要接入预测性返回，需要重新评估：Cupertino 构建器不实现 `PredictiveBackRoute`。
- 桌面端不受影响；iOS 仍是 Cupertino（本来就是）。

## 回归验证

- `flutter test test/ios_swipe_back_parity_test.dart`：5 项全过
  - Android 映射到 Cupertino 构建器，其他平台保持默认；
  - 从左边缘拖动时页面跟手位移 > 100px，松手后路由出栈；
  - 屏幕中间起手的拖动不触发返回；
  - `fullscreenDialog` 页面不触发返回；
  - go_router 实际路由栈（`context.push`）同样支持边缘返回。
- `flutter test` 全量回归与 `flutter analyze` 见本次交付说明。

## 后续维护

- 新增全屏/模态页面时，如果它**不应该**被左滑返回，用 `fullscreenDialog: true`（或让它是栈首），不要靠坐标或条件判断去关手势。
- 如果要做参考应用那种"转场期把整页栅格化"的快照优化（`SnapshotWidget` + `SnapshotController`），这是独立的一层，和本次主题开关互不冲突；仅当横滑过程中整页重建成为瓶颈时再做。

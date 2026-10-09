# 个人中心真机渲染对照（2026-10-01）

真机采样表明，个人中心滚动主要受渲染开销影响。共享毛玻璃输入后，渲染 P95 从 23.15ms 降至 19.57–19.78ms，仍有帧超过 60Hz 的 16.67ms 预算，不能据此宣称掉帧已完全消除。

## 条件与方法

- 设备：23116PN5BC；Android 当前刷新率约 60Hz；应用使用 Impeller/Vulkan；屏幕逻辑输出为 1080×2400。
- 使用当前真机账本、液态玻璃主题及设备当前外观设置，不修改账单或预算数据；逐帧数据未单独记录亮暗模式。
- 同一个诊断 profile 包通过 `SchedulerBinding.addTimingsCallback` 记录 UI build 和 raster 耗时。诊断入口位于 `.agent/profile-performance-20261001/`，正式包使用正常的 `lib/main.dart`，不包含该入口。
- 每轮隐藏调节面板、回到顶部、等待 1.5 秒，再执行 8 次往返滚动；每次滑动 450ms、间隔 150ms；最后等待 1.5 秒让帧数据上报完成。
- 独立模糊通过临时清除个人中心滤镜的 `RenderBackdropFilter.backdropKey` 模拟旧行为；共享模糊使用页面 `BackdropGroup` 的 key。底部导航和记账按钮保持原样。
- UI 与 raster 任一耗时超过 16.67ms 计入超预算帧。这是渲染耗时指标，不等同于屏幕实际丢帧数或 FPS。

## 结果

| 条件 | 采样帧 | UI P95 | Raster P95 | 超预算帧占比 |
| --- | ---: | ---: | ---: | ---: |
| 独立模糊，强度 5 | 424 | 1.98ms | 23.15ms | 13.7% |
| 关闭卡片模糊 | 443 | 1.96ms | 15.85ms | 3.4% |
| 共享模糊，强度 5 | 439 | 2.15ms | 19.57ms | 10.5% |
| 共享模糊，强度 3 | 440 | 1.87ms | 19.16ms | 9.8% |
| 共享模糊，强度 5，复测 | 440 | 2.08ms | 19.78ms | 10.7% |

原始逐帧数据见 [profile-performance-2026-10-01](profile-performance-2026-10-01/)。上述结果来自单台设备、当前账本及滚动操作，未分别对亮暗模式、其他设备或大量账单刷新场景做完整对照。

## 改动与验证

- 个人中心毛玻璃面板改用 `BackdropFilter.grouped`，由页面专属 `BackdropGroup` 共享模糊输入。底部导航不加入这个组。
- 保留不透明度 0.56、模糊强度 5、高光 0.72、阴影 0.12 的默认值。强度 3 的额外收益较小，暂不改变视觉默认值。
- release 测试包可通过 `--dart-define=PROFILE_GLASS_TUNER=true` 显示调节入口；未传入时 release 仍隐藏入口，debug/profile 默认显示。入口仅适用于液态玻璃主题的个人中心。
- 修复记账弹窗四个组件中主题文件导入路径多写一层的问题；这是构建阻塞修复。
- `liquid_glass_profile_test.dart`、`profile_quick_actions_test.dart`、`quick_add_redesign_test.dart` 共 36 项测试通过；检查共享滤镜 key、将模糊调至 0 后移除滤镜、调节面板不改变导航位置，以及原有页面交互。
- 修改文件的 Dart 静态分析通过，相关差异的 `git diff --check` 通过。
- 正常入口的 arm64 release 测试包构建并覆盖安装成功，版本码保持 2010；真机截图确认个人中心右下角显示蓝色调节入口，见 [release-profile.png](profile-performance-2026-10-01/release-profile.png)。该测试包传入 `PROFILE_GLASS_TUNER=true`，正式发布构建应省略这个参数。

构建命令：`flutter build apk --release --split-per-abi --target-platform android-arm64 --build-number=10 --dart-define=PROFILE_GLASS_TUNER=true --no-pub`。

APK SHA256：`5DE2C0877B7364F528B5F6136B95092F94550C6CFE5449B9E2D8397733093F8A`。

本轮没有修改预算计算或数据刷新逻辑：滚动采样的 UI P95 约 2ms，证据优先指向玻璃合成。后续若继续优化，可单独测量底部导航、记账按钮及阴影的开销；预算计算应另用数据更新场景验证。

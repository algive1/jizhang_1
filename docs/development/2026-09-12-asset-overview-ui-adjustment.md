# 资产总览页面 UI 适配完成记录（2026-09-12）

## 问题原因

资产总览最近一次高保真适配保留了较紧凑的内部尺寸：页面左右边距为 `12dp`，区块标题为 `13sp`，近期资产变动行使用 `10sp` 和 `30dp` 图标；趋势图在固定卡片宽度内压缩全部采样点，没有水平滚动容器；详情面板固定占用 `84%` 高度且没有分析总结。右上角“全部账本”则是资产页自身的 PopupMenu。

## 本次修改

### 页面与卡片层级

- `lib/features/accounts/presentation/asset_overview_page.dart`
  - 资产页左右内容边距调整为 `16dp`，与首页一致。
  - 区块标题和快捷入口文字层级提升，账户小卡字号适度增加；账户卡固定高度从 `82dp` 调整为 `84dp`，解决大字号/长内容下的 `1px` 溢出。
  - 删除资产页右上角“全部账本”按钮及页面内部账本筛选状态；保留多币种时的币种选择，默认资产汇总口径不变。

- `lib/features/accounts/presentation/asset_dashboard_cards.dart`
  - `AssetSectionHeading` 默认字号调整为 `16sp`，操作文字调整为 `12sp`。
  - 快捷入口标题/副标题调整为 `12sp/11sp`。

### 近期资产变动

- `lib/features/accounts/presentation/asset_overview_page.dart`
  - 主标题、日期/分类元信息、金额字号和行间距调整为接近首页 `TransactionTile(homeStyle: true)` 的阅读节奏。
  - 增加行间分隔；保留按账户余额影响计算的金额、现有筛选项、最多 3 条记录、小贴士和详情操作。

### 趋势交互

- `lib/features/accounts/presentation/asset_dashboard_charts.dart`
  - `AssetTrend` 改为带 `ScrollController` 的 Stateful widget。
  - 30 天和 1 年趋势按采样点提供更宽的绘图区，并在卡片内部使用水平 `SingleChildScrollView`。
  - 周期切换后自动定位到最新日期一侧；拖动趋势不会触发趋势详情弹窗，也不会撑宽资产页。
  - 保留金额隐藏、未来流水提示、最新值气泡、坐标标签和语义描述。

### 详情弹窗与分析总结

- `lib/features/accounts/presentation/asset_overview_page.dart`
  - 详情面板高度从固定 `84%` 调整为约 `52%`，内容通过面板内部滚动承载。

- `lib/features/accounts/presentation/asset_dashboard_charts.dart`
  - 资产分布详情增加账户数量、最大账户占比和集中/分散提示。
  - 资产变化详情增加区间净变化方向和百分比说明，并明确这是账面流水/余额校准变化，不代表投资收益。
  - 金额隐藏、无正余额、起始基数不足和未来日期流水均显示保守说明，不生成示例数据。

## 测试与验证

- `flutter analyze`：通过，No issues found。
- 资产布局测试：320/393/430dp，1.6 倍字体，无布局溢出。
- `test/asset_overview_interaction_test.dart`：通过，覆盖右上角按钮移除、趋势横向滚动、拖动、弹窗高度、分析摘要和周期按钮行为。
- `test/asset_visual_qa_test.dart`：通过，视觉截图无异常。
- `flutter test --no-pub`：253 项全部通过。
- `git diff --check`：通过。
- `flutter build apk --debug`：通过。

Debug APK：`build/app/outputs/flutter-apk/app-debug.apk`

## 风险与边界

- 当前趋势仍是账面净资产趋势，不是市场行情或投资收益；总结文案已明确这一点。
- 本次未进行 Android 真机安装验收；Debug APK 构建成功。构建仍有项目原有 `speech_to_text` KGP 兼容性 warning。
- 全量测试仍会输出项目原有 Drift 多数据库生命周期 warning，但没有测试失败。
- 工作区在本次任务前已有大量未提交修改，本次未执行提交、回滚或清理。

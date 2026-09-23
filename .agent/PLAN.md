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

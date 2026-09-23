# 验收标准

- [x] 一级、二级分类种子、ID、名称、顺序和存储关联保持现状。
- [x] 二级分类弹层中没有“不细分”文本、parent tile 或 footer 入口。
- [x] 二级裸图标仍为28px主题色，指针滑动时邻近图标放大并随动，松手选中原分类 ID。
- [x] 普通点击只选择一项；多项列表仍可滚动，滚动操作不误选。
- [x] liquidGlass 主题下的弹层仍使用 BackdropFilter 模糊与主题色玻璃质感。
- [x] 点击记一笔的页面转场顺畅完成；系统返回先关闭浮层、再关闭记一笔并完成反向动画。
- [x] 普通页面 Android edge swipe 返回测试通过；fullscreenDialog 按设计仍是模态，不触发 edge swipe。
- [x] 相关 widget 测试通过；scope analyze 无问题；diff check 通过；Debug APK 构建通过。
- [x] 最新 APK 安装到真机并启动，现场检查记一笔浮层与动画。

## 二级浮层对比度补充验收（用户 2026-09-23 最新反馈）

- [x] 浮层打开后，外部整页遮罩明显压暗背景（barrier alpha 至少 0.55），焦点落在浮层。
- [x] Liquid Glass 浮层使用 blur sigma 至少 30、玻璃层覆盖度至少 0.94；最新主题截图中背景分类图标/文字不可辨认，浮层内二级图标与名称清楚。
- [x] 非 Liquid Glass 主题的浮层背景完全不透明并使用对应主题表面色。
- [x] 全局其他 AppGlassSurface 默认外观、二级分类内容/图标主题色、跟手放大手势、点击和滚动行为均不变。
- [x] 新增视觉配置断言先 RED 后 GREEN；quick-add 相关测试、scope analyze、diff-check 通过。
- [ ] 最新 APK 重建并安装到 Xiaomi 23116PN5BC；现场查看以上对比度要求及返回行为。

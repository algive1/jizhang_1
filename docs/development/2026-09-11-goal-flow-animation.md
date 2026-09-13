# 目标阶梯流光试作

## 实现

- 新增 `lib/features/home/presentation/goal_flow_track.dart`，用 AnimationController 和 CustomPainter 在独立重绘区域绘制循环流光。
- 3.6 秒一轮，从起点流向实际当前节点；流光经过已完成节点时增加柔光，当前节点有轻微呼吸外圈。
- 终点使用奶油金、橄榄绿小宝箱及错峰闪烁星点，大小限制在原节点区域内。
- `home_cards.dart` 接入绘制层，保留普通节点尺寸、金额、隐私状态及等间距阶梯语义。金额百分比不会用来替代当前节点的屏幕坐标。
- 后台、TickerMode 禁用、系统减少动画及非活跃目标均停止循环；dispose 释放控制器和生命周期监听。

## 测试方式

- 新增 `goal_flow_track_test.dart`：对比不同时间的渲染像素，验证动画变化、跨周期运行、减少动画后的稳定画面与销毁。
- `flutter_test_config.dart` 只冻结该装饰动画；动画测试显式开启。避免无限循环导致已有静态 UI 测试 pumpAndSettle 超时，不改变全局系统动画或 HTTP 测试绑定。

## 范围

验证结果：`flutter analyze --no-pub` 无问题，`flutter test --no-pub` 共 205 项通过，Android debug APK 构建通过。已检查首页静态截图；真实手机的动画帧率和观感尚未验证。

这是首版循环效果试作，未增加真正完成目标时的开箱庆祝事件；该事件应复用目标达成状态与既有庆祝记录，防止重复庆祝。本次没有改动任何资产、流水、目标金额或同步逻辑。

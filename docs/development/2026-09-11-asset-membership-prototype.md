# 首页资产摘要与会员页面原型

日期：2026-09-11

## 需求与原因

- 首页已有预算、目标、趋势和分类视觉体系，但真实账户资产只在 `/profile/assets` 展示，首页缺少资产概览入口。
- 会员页原本是三张说明卡，当前方案、会员价值和数据安全之间层级不够清晰。
- 当前会员购买、支付验签、云同步和权益刷新尚未接入，页面不能伪造购买成功或已完成云备份。

## 实现规则

- 首页在预算/目标卡下、支出趋势上方加入紧凑资产摘要。
- 主信息为当前账本的首要币种净资产，辅信息为同币种总资产和总负债。
- 复用 `AssetOverview.group`，不同币种分开统计；多币种只提示还有其他币种，不做汇率折算。
- 账户列表为空时展示添加账户入口；账户加载中或读取失败时分别展示明确状态，不把错误显示成 0 元。
- 首页小眼睛状态提升到 `HomePage`，资产摘要与预算/目标/收支结余/目标金额共享隐私开关。
- 会员页改为“数据安全 Hero → 当前 Free 权益 → Pro/Family 规划 → 数据安全说明”的层级；Pro/Family 可查看权益说明，但仍标记“筹备中”，不提供假购买按钮。
- 页面保持首页既有暖米白、植物绿、生活方式插画、圆角卡片和底部导航视觉语言。

## 修改文件

- `lib/features/home/presentation/home_asset_card.dart`
  - 新增首页资产摘要卡，覆盖数据、空态、加载态、错误态、多币种和隐私掩码。
- `lib/features/home/presentation/home_page.dart`
  - 将资产摘要接入预算卡和支出趋势之间；接入 `/profile/assets` 及账户重试入口。
  - 在首页层维护金额隐私状态。
- `lib/features/home/presentation/home_cards.dart`
  - 为预算/目标卡增加可选的受控隐私状态，保留原有独立使用方式的兼容性。
- `lib/features/membership/presentation/membership_page.dart`
  - 重做会员与数据安全原型，增加 Hero、当前方案权益标签、Pro/Family 权益卡、说明弹层和安全说明。
- `test/home_asset_card_test.dart`
  - 覆盖资产金额、多币种、空/加载/错误态，以及首页隐私联动。
- `test/membership_page_ui_test.dart`
  - 覆盖 320/393dp、1.0/1.6 倍字号、滚动到 Pro 和权益说明弹层。
- `test/asset_membership_prototype_capture_test.dart`
  - 生成原型截图，并覆盖实际 App Shell 下的会员页底部导航渲染。

## 原型截图

- [首页资产摘要](../qa/asset-membership-prototype-2026-09-11/home-asset-card-393.png)
- [会员页原型](../qa/asset-membership-prototype-2026-09-11/membership-page-393.png)
- [会员页实际 App Shell](../qa/asset-membership-prototype-2026-09-11/membership-page-shell-393.png)
- [首页实际集成效果](../qa/home-reference-2026-09-10/home-upper.png)

## 验证结果

- `flutter analyze`：通过，No issues found。
- `flutter test --reporter compact`：通过，184 个测试全部通过。
- `flutter test test/home_asset_card_test.dart`：通过。
- `flutter test test/membership_page_ui_test.dart`：通过，4 个尺寸/字号组合全部通过。
- `flutter test test/asset_membership_prototype_capture_test.dart`：通过，3 张截图生成成功。
- `flutter build apk --debug`：通过，产物为 `build/app/outputs/flutter-apk/app-debug.apk`。
- 已用 `view_image` 检查 393dp 资产卡、会员页和 App Shell 截图；未发现遮挡或明显溢出。

## 仍存在的风险

- 会员购买、支付验签、订单服务、云备份和权益刷新仍未接入；本轮只完成真实状态下的 UI 原型和权益说明交互。
- 截图 QA 使用本机 Flutter widget 渲染；当前没有连接 Android 真机，本轮未宣称完成真机触摸验收。
- 工作区在任务开始前已有多处未提交修改，本轮保留这些修改，未整体回滚，也未将其混入本轮范围。

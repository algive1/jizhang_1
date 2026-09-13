# 资产趋势与会员能力接口（2026-09-12）

## 本次完成

- 修复资产变化卡片和资产变化详情共用的趋势绘制逻辑：曲线由二次曲线中点插值改为带 Hyman 过滤的 monotone cubic，路径经过每个采样点且不会在突变处产生虚假凹陷。
- 抽出 `AssetTrendPeriodSelector`，资产变化详情弹窗增加“近7天 / 近30天 / 近1年”，切换后同步更新统计区间、金额变化和分析文案，并回写资产总览当前区间。
- 新增 `MembershipFeature`、`MembershipFeaturePolicy` 和 `MembershipFeatureAccessService`，为自动记账、账本同步、资产报表、数据导出、共享资产预留后台开关与权益判定接口。
- 新增 `ensureMembershipFeatureAvailable` 和 `showMembershipUpgradePrompt`，后端策略返回会员限制后，功能入口可复用统一的快捷开通弹窗并跳转 `/profile/membership`。

## 当前行为边界

本地会员仓储尚未接入服务端策略，因此缺少策略时按 `local_default` 透传，现有自动记账、同步、报表、导出和共享能力不会被本次改动锁死。当前没有伪造支付成功、会员成功或服务端权益；真实会员状态仍由后端仓储接入。

## 后端接入约定

后端仓储实现 `MembershipRepository` 后，在 `MembershipSnapshot.featurePolicies` 填充对应的 `MembershipFeaturePolicy`：

| 功能 | 稳定 API key | 默认权益映射 |
| --- | --- | --- |
| 自动记账 | `automatic_bookkeeping` | `automaticBookkeeping` |
| 账本同步 | `ledger_sync` | `cloudSync` |
| 资产报表 | `asset_reports` | `advancedReport` |
| 数据导出 | `data_export` | `dataExport` |
| 共享资产 | `shared_assets` | `familyBook` |

后台关闭功能时返回 `enabled: false`；后台开启且仅会员可用时返回 `requiresMembership: true`，并提供 `entitlement` 或 `minimumPlan`。功能入口调用 `ensureMembershipFeatureAvailable(context, ref, feature)`，返回 `false` 时停止原操作，若属于会员限制会自动弹出快捷开通弹窗。

## 验证

- 资产与会员定向 `flutter analyze`：通过。
- `test/asset_overview_interaction_test.dart`、`test/membership_test.dart`、`test/membership_feature_prompt_test.dart`：通过。
- `test/asset_visual_qa_test.dart`：通过。
- 全量 `flutter test --no-pub`：256 项通过。
- `flutter build apk --debug`：通过；已覆盖安装到 Android 模拟器 `145a0a68`。

## 后续接入点

待后端接口和实际会员购买/验签完成后，将同一 helper 接入资产报表、数据导出、支付通知/周期账单自动记账、共享账本同步和“使用主账本资产”开关的入口；本次不改变这些入口的现有可用性。

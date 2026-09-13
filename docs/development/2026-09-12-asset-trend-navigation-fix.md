# 资产趋势过冲与二级页面导航（2026-09-12）

## 问题原因

资产趋势的原实现使用 Catmull-Rom 转 Bezier。当前后端/本地数据在最后一天可能出现较大的余额跳变；当跳变前是一段平线时，Catmull-Rom 会利用后一个高点计算切线，导致前一段曲线被拉到采样点范围之外，于是出现截图中箭头所指的凹陷。该凹陷是插值过冲，不是资产余额真的先下降。

## 修改方案

- 趋势 painter 改为 monotone cubic，并用 Hyman 过滤限制每个 cubic segment 的切线，确保曲线经过采样点且不越过相邻采样值范围。
- 在 `AppScaffold` 统一定义一级路由白名单：`/`、`/transactions`、`/goals`、`/profile`。
- 仅一级路由显示全局底部导航和“+ 记一笔”；其他路由保留各自页面的返回按钮和业务操作，但隐藏全局导航与全局新增入口。
- 同步移除二级管理、详情和工具页为旧底栏预留的 `100/120` 底部滚动空间，统一保留 `24` 的页面内边距；首页、流水、目标一级工作区保持原值。

## 已盘点的二级页面

以下页面统一隐藏全局导航和“+”：

- 资产与账户：`/profile/assets`、`/profile/accounts`、`/profile/accounts/:accountId`。
- 分析与设置：`/analysis`、`/profile/categories`、`/profile/budgets`、`/profile/data`、`/profile/membership`。
- 共享与自动化：`/profile/family`、`/profile/payment-notifications`、`/profile/recurring-bills`、`/profile/installments`、`/profile/installments/:planId`。
- 流水与目标详情：`/transactions/search`、`/transactions/inbox`、`/transactions/reimbursements`、`/transactions/calendar`、`/transactions/:transactionId`、`/goals/:goalId`。

一级页面仍保留全局导航和“+”，因为它们是主工作区，新增入口语义明确为全局“记一笔”。

## 验证标准

- 趋势在平线后突然上升时不能出现低于平线的人工凹陷。
- 二级页面不得出现 `AppBottomNavigation` 或 `FloatingActionButton`。
- 一级页面的导航切换和“+ 记一笔”行为不受影响。
- 二级页面底部保留页面自身内容与返回/新增/编辑等业务操作。

## 本次验证结果

- `flutter analyze`：通过，No issues found。
- 定向 widget/UI 回归：通过，21 项。
- `flutter test --no-pub`：通过，257 项。
- `flutter build apk --debug`：通过，生成 `build/app/outputs/flutter-apk/app-debug.apk`。
- 已安装到 Android emulator `145a0a68`，实际检查资产总览、资产变化详情弹窗和账户管理页。

## 后续约束

新增页面如果属于二级管理、详情或工具页，应继续保持“页面自有操作 + 返回”的结构，不要默认接入全局底部导航。若未来增加新的一级工作区，再把它显式加入 `isPrimaryAppRoute` 的白名单并补充路由测试。

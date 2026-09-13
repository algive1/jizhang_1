# 交易记录显示链路检查与修复

## 问题

需要确认手动记账保存后，交易能否从 Drift 数据库正确回读并在首页、流水、搜索和详情中显示。产品规则是：有备注时显示备注；没有备注时，已选择分类的交易显示分类名。

## 根因

保存链路会持久化 `categoryId`、`merchant` 和 `note`，交易仓库回读时也会按交易所属账本解析分类名称。问题出在展示层：`TransactionTile` 和交易详情页使用 `merchant ?? note ?? '未命名交易'`，没有备注或商户时直接显示“未命名交易”，没有使用已解析的分类名；同时有商户和备注时商户会覆盖备注。

## 修改

- 在 `TransactionRecord` 增加统一的 `displayCategoryLabel` 和 `displayTitle`：
  - 备注有内容时优先显示备注。
  - 没有备注时保留商户作为次级回退。
  - 没有备注和商户时显示分类名；转账、余额校准显示各自固定标签；分类未解析时显示“未分类”。
- 首页最近交易、流水列表、搜索结果复用 `TransactionTile` 的统一规则。
- 交易详情页复用同一规则，避免列表与详情显示不一致。
- 增加保存后重新从数据库读取的分类名/备注回归测试，以及交易卡片的实际 widget 测试。

## 验证

- `flutter analyze --no-pub`：通过。
- `flutter test --no-pub`：208 项全部通过。
- `flutter build apk --release`：通过；包名 `com.algive.jizhang_app`，版本 `1.0.0`，APK v2 签名校验通过。

安装包：`build/app/outputs/flutter-apk/app-release.apk`

## 风险记录

构建时 Flutter 对 `speech_to_text` 插件使用 Kotlin Gradle Plugin 给出迁移提示；本次构建未受影响，后续可随插件升级处理。

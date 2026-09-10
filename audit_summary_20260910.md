# 只读审计记录（2026-09-10）

范围：分类显示与企业模板、目标首页排序、首页金额隐藏布局。未修改业务代码和测试。

## 验证结果

- `flutter test --no-pub test/home_amount_visibility_test.dart`：4 个场景通过，覆盖 320/393dp、1.0/1.6 文本缩放，以及显示→隐藏→显示；卡片、预算入口、结算入口矩形保持不变。
- `flutter test --no-pub test/book_category_scope_test.dart test/home_redesign_domain_test.dart`：10 个测试通过。
- `flutter analyze --no-pub`：No issues found。

## 发现

1. 企业模板存在旧账本补齐缺口。`DatabaseSeeder._upgradeCategoryTemplate` 以 `expense-food` 作为 marker；该 marker 已存在时直接返回，因此旧企业账本若已存在旧模板但缺少当前企业模板新增的 `expense-payroll`（工资薪酬），不会调用 `_seedCategories` 补齐。新建企业账本路径使用 `categoryTemplates(BookType.enterprise)`，当前测试能覆盖新建路径，但未覆盖旧账本升级路径。建议增加迁移/补齐策略，并测试“marker 存在、payroll 缺失”场景。

2. 目标创建时 `Goal.sortOrder` 使用默认值 0。`GoalsPage` 取活动目标列表首项作为首页目标；`GoalRepository.getAll` 先按状态、再按 `sortOrder`、最后按 `createdAt` 倒序。因此未显式排序时，新创建目标在同为 0 的目标中按创建时间排在最前，会抢占首页首位。现有排序持久化测试覆盖 reorder/update，但未覆盖“已有排序后新建目标”的行为。需要产品确认新目标应置顶还是追加；若应追加，应在 create 时取当前账本活动目标最大 sortOrder + 1，并补回归测试。

3. 首页金额隐藏布局当前结构稳定。主金额区域和目标金额区域均使用固定 `SizedBox` 高度；结算文本也在固定槽位内，隐藏状态只替换文本。现有测试的几何断言足以捕捉上下跳动，且已实测通过。未发现需要修复的首页隐藏金额问题。

## 后续处理

主代理已按上述证据完成分类显示、旧账本模板补齐和目标新建排序修复，并在
[2026-09-10-ledger-budget-home-fixes.md](docs/development/2026-09-10-ledger-budget-home-fixes.md)
记录最终改动和验证结果。

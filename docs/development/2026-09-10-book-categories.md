# 账本分类关联修复（2026-09-10）

## 问题原因

分类仓储已经按 `activeBookIdProvider` 使用 `bookId` 查询，但旧账本可能没有本账本分类；另外 `BookRepository.changeType` 只更新 `books.type`，不会触发旧数据补齐。新建账本的默认分类 ID 已是账本作用域 ID。

## 修改

- `category_templates.dart` 集中定义个人、家庭、企业三套默认分类；个人 Seed IDs 保持兼容，家庭/企业使用类型前缀作用域 ID。企业“工资薪酬”为 expense，`income-salary` 为“主营业务收入” income。
- `DatabaseSeeder.seedBookDefaults` 改为幂等补齐，缺失的默认账户和分类才插入，不覆盖已有数据。
- 启动 bootstrap 扫描未归档本地账本，升级旧模板时只精确归档未改动且无自定义子类的内置分类，并幂等补齐当前模板中缺失的默认分类；不恢复用户主动归档项。
- 已绑定 `sync_books` 的共享账本跳过补齐，分类由远端快照同步，避免重复生成或覆盖。
- `changeType` 在同一数据库事务内归档旧类型内置模板、恢复/补齐目标类型模板；仅显式切换恢复目标模板，已有自定义、归档分类和历史流水引用保持不变。
- 商户规则仅在规则 ID 不存在时插入，默认兜底分类按账本类型解析；bootstrap 不恢复用户主动归档模板。
- 账本抽屉使用真实账本类型和副标题，切换成功/失败会提示；分类页面通过 `categoriesProvider` 自动随 active book 重建。

## 验证

- `flutter test test/book_category_scope_test.dart`：7 tests passed，增加 marker 已存在但模板分类缺失时的 bootstrap 修复。
- `flutter test test/book_scope_test.dart test/database_seeder_test.dart test/book_repository_test.dart`：9 tests passed。
- 定向 `flutter analyze`（本次修改文件）：No issues found。

## 遗留

个人、家庭、企业现在使用不同的默认分类名称和账本作用域 ID；个人原有 Seed IDs 保持不变。家庭/企业旧账本升级时只归档未改动的个人默认分类，存在自定义子分类、改名或改图标的旧分类保留；新模板按类型补齐。

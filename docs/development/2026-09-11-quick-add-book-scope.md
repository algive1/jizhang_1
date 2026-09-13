# 记一笔选择账本与首页账本标题

日期：2026-09-11

## 问题原因

- “记一笔”原本只读取全局当前账本的分类、账户和流水排序数据，表单内没有目标账本。
- 记账服务使用绑定全局当前账本的 Transaction Repository；如果只增加界面选择，保存时会写错账本或被账本边界校验拒绝。
- 首页顶部标题和书架抽屉标题固定为“我的账本”，切换账本后无法确认当前账本上下文。

## 本次修改

- `lib/features/bookkeeping/presentation/quick_add_sheet.dart`
  - 在“记一笔”表单顶部增加“记入账本”选择项。
  - 选择账本后按目标 `bookId` 重新读取分类、账户和分类使用次数；同时清空旧账本的分类、账户选择，避免跨账本引用。
  - 保存请求显式携带目标 `bookId`，编辑已有流水仍锁定原账本，不允许借编辑移动流水。
  - 语音/AI 记账入口继承当前表单的账本选择。
- `lib/features/accounts/data/account_repository.dart`
  - 增加按账本读取账户的 `accountsByBookProvider`。
- `lib/features/categories/data/category_repository.dart`
  - 增加按账本读取分类的 `categoriesByBookProvider`。
- `lib/features/transactions/data/transactions_repository.dart`
  - 增加按账本读取流水的 `transactionsByBookProvider`。
- `lib/features/bookkeeping/application/quick_bookkeeping_service.dart`
  - 快速记账写入改为使用不预绑定浏览账本的 Repository，仍由交易、账户和分类的 `bookId` 校验保证数据边界。
- `lib/features/books/presentation/book_selector.dart`
  - 提供紧凑的记账账本选择底部面板，并将书架顶部标题同步为当前账本名。
- `lib/features/home/presentation/home_page.dart`
  - 首页顶部标题读取当前账本名；单行超长时使用省略号，并提供 Tooltip 展示完整名称。
- `lib/features/voice/presentation/voice_bookkeeping_sheet.dart`
  - 支持接收表单传入的目标账本，语音/AI 保存与手动记账保持同一账本。
- `lib/features/intelligence/*`
  - 记账后的分类/重复检查改为按流水自身账本处理，避免目标账本不是当前浏览账本时后处理失败或跨账本比较。

## 展示规则

- 标题优先展示账本的真实名称：个人默认账本显示“个人账本”，家庭/公司或自定义账本显示创建时的账本名。
- 不截断数据库中的名称；首页标题最多占一行，空间不足显示 `…`。
- 长名称可通过标题 Tooltip 查看完整内容；选择面板中的账本行同样是一行省略。
- 没有可用账本数据时才回退显示“我的账本”。

## 验证结果

- 新增 `test/quick_add_book_scope_test.dart`：确认选择家庭账本后分类来自家庭账本、流水保存到家庭账本、全局浏览账本仍保持个人账本。
- `test/widget_test.dart` 增加首页自定义账本标题和单行省略规则验证。
- `flutter analyze`：通过。
- 相关 Widget 测试：通过。
- 全量 Flutter tests：通过（186 个）。
- `flutter build apk --debug`：通过，产物为 `build/app/outputs/flutter-apk/app-debug.apk`。

## 风险与后续

- 本次验证覆盖 Flutter Widget、内存 SQLite、代码级布局和 Debug APK 构建；未连接实体设备，尚未覆盖不同厂商字体渲染和真实触控。
- 会员、共享同步和生产后端不需要新增接口，本次只复用现有本地账本数据链路；生产环境仍需按既有计划做真实服务联调。

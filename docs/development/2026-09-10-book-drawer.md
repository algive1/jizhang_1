# 账本抽屉 UI 修复记录

日期：2026-09-10

## 问题原因

`book_selector.dart` 将“选择账本”、管理按钮和关闭按钮作为书架图片前的独立栏渲染，导致木质顶栏留白，实机结构与原型不一致。书架行也只展示账本名称与通用信息，未展示真实账本类型对应的图标和副标题。

## 修改内容

- 将选择标题、副标题、管理和关闭操作叠加到书架图片的木质顶栏。
- 按素材坐标收紧书架行与新建区域：书脊图标移入白色图标框，新建卡片限制在素材卡片内并补充虚线内框。
- 关闭按钮缩小并限制在木板标题栏，副标题上移；新建虚线框四周保留素材卡片边距。
- 书架槽位继续只从真实 `LedgerBook` 列表渲染，不为缺少的类型生成伪账本。
- 按 `BookType` 显示个人、家庭、企业图标及对应副标题。
- “查看更多账本”在超过 3 本时打开全部真实账本列表，支持切换与长按管理。
- 名称输入改为独立有状态对话框，由对话框自身负责 `TextEditingController` 的释放。
- 重复选择当前账本会关闭抽屉并提示“当前已是…”，不会再次持久化切换。
- 账本切换完成并持久化成功后，关闭抽屉并显示“已切换到「账本名」”；切换异常只显示错误提示。
- 新增 `test/book_selector_ui_test.dart`，覆盖真实账本类型、空位和成功切换提示。
- UI 测试补充全部账本入口与素材区域几何断言，并覆盖大字模式下不溢出。
- UI 测试覆盖重复选择和归档账本选择失败时 active id 不变。

## 验证

- `flutter analyze lib/features/books/presentation/book_selector.dart`：通过。
- `flutter test test/home_books_month_test.dart`：6 个测试通过，覆盖 320×700、390×844 普通/大字、800×320 横屏。
- `flutter test test/book_selector_ui_test.dart`：通过。
- `flutter test test/home_reference_page_capture_test.dart`：通过。
- 参考截图：`docs/qa/home-reference-2026-09-10/bookshelf.png`。

## 限制

截图和 widget 测试使用内存数据库与本地字体，未替代 pixel_7 实机 APK 验证；实机核对由主代理继续完成。

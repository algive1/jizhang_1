# 账本抽屉执行记录：切片 2

日期：2026-09-10

## 问题原因

超过三本账本时，旧实现只是临时 `ListView`，没有名称搜索、显式管理入口或同步状态；新建账本仍先弹用途对话框、再弹名称对话框，流程割裂，也无法在同一处预览用途和封面。窄屏大字模式下，抽屉顶栏标题固定横排，标题列不足时会发生 Flutter layout overflow。

## 本切片修改

- 新增 `_AllBooksSheet`：可滚动展示全部真实账本，支持名称搜索、当前选中状态、类型、本机/同步状态、显式新建和账本管理按钮。
- 全部列表继续使用 `booksProvider` 的实时数据，不复制另一套账本读取逻辑；加入共享账本的额度说明沿用统一 `ownedCount` 规则。
- 新增 `_CreateBookSheet`：名称、个人/家庭/企业用途选择、封面预览和创建按钮同屏展示，默认个人用途；表单控制器由自身释放。
- 创建成功后先通过现有 Repository 持久化，再用现有 active book controller 切换，关闭抽屉并显示“已创建并切换到…”。创建失败保留当前账本并显示真实错误。
- 大字模式顶栏标题使用可换行布局并增加头部高度；窄屏表单使用安全区内滚动，避免内容截断。

## 验证

```text
flutter test test/book_selector_ui_test.dart
→ 8 tests passed

flutter analyze lib/features/books/presentation/book_selector.dart
→ No issues found

git diff --check
→ passed

flutter build apk --debug
→ Built `build/app/outputs/flutter-apk/app-debug.apk`; emitted the existing
  `speech_to_text` Kotlin Gradle Plugin compatibility warning.
```

覆盖场景：搜索命中/无命中、全部账本入口、显式管理、创建取消、创建成功切换、默认个人用途、家庭用途封面预览，以及 320dp + 1.6 字号可达性。

## 未完成与风险

- 书架背景图仍内置三本装饰书，真实 1/2/3 本时空层板尚未完成拆分；本机本次没有连接 Android 模拟器/物理设备，尚未进行安装截图验收。
- 同步状态目前根据现有 `sharedPhase` 显示“仅本机/同步中/已同步”，待同步失败、冲突等状态要等同步协议补齐后再扩展。
- 创建表单的模板入口属于阶段二，当前不生成示例数据，也不自动开启共享。

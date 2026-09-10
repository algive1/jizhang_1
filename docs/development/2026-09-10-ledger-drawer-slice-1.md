# 账本抽屉执行记录：切片 1

日期：2026-09-10

## 问题原因

抽屉此前把 `BookType` 作为预览排序依据，导致账本不能按创建顺序展示；活动账本在第四本及以后时也不会出现在三层预览中。创建上限的 UI 使用全部可见账本计数，而 Repository 使用自有账本计数，两端规则不一致。Free 上限仍为旧值 3，底部还保留“3 个以上”的旧文案。

## 本切片修改

- `BookLimitPolicy.free` 改为 10，并新增统一的 `ownedCount` 规则；共享他人账本不占创建额度。
- Repository 查询使用 `created_at, rowid`，在旧数据时间精度相同时保留插入顺序。
- 抽屉使用 Repository 提供的创建顺序；活动账本不在前三本时替换第三预览位。
- 抽屉创建入口改用自有账本数量判断，底部文案改为“共 N 个账本”或“查看全部账本（N）”。
- 更新 Repository、抽屉 UI 和 UI/领域回归测试。

## 验证

```text
flutter test test/book_repository_test.dart test/book_selector_ui_test.dart test/home_books_month_test.dart
→ 13 tests passed

flutter analyze lib/features/books/data/book_repository.dart lib/features/books/presentation/book_selector.dart
→ No issues found

git diff --check
→ passed
```

## 未完成与风险

- 书架图片仍把三本装饰书绘制在背景中，空层板/真实书本的彻底拆分留在下一切片；本切片没有声称完成该视觉目标。
- “全部账本”仍是旧的底部列表，尚未具备搜索、显式新建、同步状态和独立管理入口。
- 尚未进行本切片对应的 Android Release 安装截图验收；当前证据是内存数据库 Widget/Repository 测试。

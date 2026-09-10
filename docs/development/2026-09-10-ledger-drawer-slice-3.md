# 账本抽屉执行记录：切片 3

日期：2026-09-10

## 问题原因

原书架 PNG 同时包含木柜和三本绿色、米色、蓝色账本。应用再叠加真实账本时，背景本身仍会显示固定书本，造成“空层板有伪账本”、账本数量与画面不一致，也无法安全支持 1/2/3 本预览。

## 本切片修改

- 基于原书架参考图生成 `assets/images/bookshelf_empty_background_v1.png`，只移除上层三本装饰书，保留木柜、层板、植物、底层白色装饰书和尺寸比例；原参考图不覆盖，仍保留作设计参考。
- 在 `AppAssets` 增加 `bookshelfEmpty`，抽屉背景切换为新素材。
- 重写 `_ShelfBookRow` 的视觉层：每一本账本由独立的 Flutter gradient、书脊、类型图标、标题、副标题、选中态和阴影组成，交互仍复用原有切换与长按管理回调。
- 更新首页参考截屏测试的资源预缓存清单，确保新背景在截屏前完成加载；QA 截图已重新生成并确认三本真实账本叠加在空层板上。

## 验证

```text
flutter test test/book_selector_ui_test.dart test/book_repository_test.dart
→ All tests passed（11 个）

flutter test test/home_reference_page_capture_test.dart
→ All tests passed（1 个）；新背景预缓存成功，截图已检查

flutter analyze
→ No issues found

flutter test --reporter compact
→ All tests passed（153 个）

flutter build apk --debug
→ Built build/app/outputs/flutter-apk/app-debug.apk

adb devices
→ 没有连接 Android 设备，因此未进行安装和真机截图验收
```

## 未完成与风险

- 书本仍是确定性的代码绘制层，尚未引入用户自定义封面文件；当前已经满足背景与账本实体解耦，但模板封面属于阶段二。
- 底层白色书本和大面积留白面板是背景装饰的一部分，不代表业务账本；业务账本只由 `_ShelfBookRow` 绘制。
- 创建顺序目前仍依赖同时间戳时的 SQLite `rowid` 兼容排序；跨设备稳定业务序号需后续加入模型和同步协议。
- 最近交易 10 条、交易详情与附件预览尚未开始，不能将本切片视为阶段一全部完成。

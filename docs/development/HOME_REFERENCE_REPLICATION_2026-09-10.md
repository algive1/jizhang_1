# 首页三张原型还原：开发前评估

## 用户要求
- 卡片1.png：首页上半部分；卡片2.png：首页下半部分；卡片3.png：账本选择抽屉。
- 三张原图位于 /Users/algive/Desktop/。
- 先研究方案，遇到无法确定的问题先询问，不立即开发。
- 确认可行后创建一个 GPT-5.6 Luna 子代理，主代理逐项派发、验收，通过后再派下一项。

## 本轮状态
仅阅读代码和评估，未修改应用代码，未启动开发子代理，未运行测试。不应宣称已实现或已经验证视觉一致。

## 已确认
- 项目为 Flutter，使用 Riverpod、GoRouter、Drift。
- 首页：lib/features/home/presentation/home_page.dart。
- 预算和目标：lib/features/home/presentation/home_cards.dart。
- 趋势：lib/features/home/presentation/home_expense_trend.dart。
- 账本选择：lib/features/books/presentation/book_selector.dart。
- 当前首页包含原图没有的月度汇总、净资产区，分类为四项；现有抽屉为多列列表，需改为原图横向书册布局。
- assets/images 有家具场景、头像、目标车等图片，未发现独立木纹书架、书册素材；pubspec.yaml 未声明自定义字体。
- 已有 test/home_redesign_visual_test.dart 主要验证窄屏、大字体和交互，不等于与新原图做像素比对。
- 当前目录不是 Git 仓库；后续修改前应建立文件备份，不能依赖 Git 回滚。

## 待确认的关键条件
仅有合成 PNG 无法保证可交互 UI 在不同设备、字体渲染和真实数据条件下逐像素相同。需询问是否有原始设计文件、无文字背景/分层素材及字体；若无，需要用户接受以截图为基准尽量逼近、逐卡视觉验收的标准，不能擅自将“100%”降级。

## 建议执行与验收
1. 确定统一逻辑宽度、目标设备、字体和素材策略（三图原始宽度不同）。
2. 先完成素材与一张预算/目标卡试样，主代理以同尺寸截图叠加对照；未通过不继续铺开。
3. 顺序实施顶部与上半区、下半区与导航、账本抽屉。每项由同一 Luna 子代理完成并汇报，主代理检查后继续。
4. 装饰图片与动态文字、金额、图表、点击区分离，生产数据使用真实 Repository/Provider；测试参考数据只用于隔离视觉测试。
5. 检查预算切换、金额隐藏、目标、分类、流水、新建/切换/管理账本、会员入口以及空数据和长文本。
6. 执行现有相关测试、Flutter analyze 和目标平台 build，输出截图及剩余差异。不得以检查通过替代视觉验收。

## 下一步
等待用户确认素材可用性和像素一致验收边界，再决定开发。无需重复询问是否允许使用指定 Luna 子代理，用户已授权，但前提是先解决上述可行性问题。

## 用户后续确认（2026-09-10）
- 接受按参考图尽量逼近，允许使用内置 imagegen 生成相似素材。
- 本周预算保留入口并明确提示暂未开放；铃铛进入现有支付通知记账页面。本轮不新增独立周预算或通用通知系统。
- 顶部皇冠会员入口和下方 Pro 卡片都必须保留并连接会员页面。
- 已启动唯一 GPT-5.6 Luna 子代理 luna_home，先完成只读审查，随后分步实施，每项完成后由主代理验收再派下一项。
- 修改前源码归档：docs/qa/home-reference-2026-09-10/backup/source-before.tar.gz。

## 素材来源
均使用内置 imagegen，以用户原图作为参考，不使用外部 API 密钥。
- assets/images/bookshelf_reference_v1.png：以卡片3为编辑目标，去掉手机头部及所有字/图标，保留木柜、三色横向书册、藤叶、盆栽和空白新建面板。动态账本仍必须由组件绘制，不能将装饰书册视为真实存在的账本。
- assets/images/pro_cloud_reference_v1.png：以卡片1中 Pro 云备份图案为参考，生成透明底浅奶油/鼠尾草绿叠放卡片和云朵，无文字。
- assets/images/leaves_reference_v1.png：以卡片1右上植物为参考，生成透明底右上角垂落绿叶，无文字或家具。
- assets/images/home_living_scene.png：复用项目原有透明底家具及藤叶素材。

## 阶段验收记录
### 第一项：预算与目标组合卡
- Luna 完成 home_cards.dart、隔离预览测试以及旧高度断言调整。
- 主代理进行三轮代码/截图复核，修复了时间线丢失当前节点、金额隐私覆盖不全、测试字体/素材未加载、卡片被画布拉伸、眼睛偏移、线段越过首末节点等问题。
- 最新隔离截图：docs/qa/home-reference-2026-09-10/home-spending-goal-card.png。
- Luna 实际报告 visual/preview/books_month 三文件测试和 flutter analyze 通过。
- 主代理独立执行 test/home_reference_interaction_test.dart：金额全部隐藏和恢复、周入口诚实提示、较多里程碑保留当前与目标，3项通过。
- 隔离预览数据不写入生产账本，字体仅本机测试加载，不随应用分发。
- 进入第二项：顶部/值得关注/Pro卡与首页结构；下半区和书架仍待后续实施验收。

### 第二项：顶部、值得关注、Pro 与首页下半区
- 已完成 `home_page.dart` 首页结构调整：顶部头像/账本标题/皇冠会员/铃铛/搜索入口、预算目标卡、值得关注卡、Pro 卡、趋势、分类、最近交易和底部导航按原型顺序排列。
- 皇冠和 Pro 卡都连接既有会员路由；铃铛连接既有支付通知记账页面；本周预算入口保留并提示“本周预算暂未开放”，没有新增虚假周预算数据。
- `home_expense_trend.dart` 使用真实收支 Provider 绘制预算切换、周/月/年视图、折线及选中点，不再依赖固定演示金额；`transaction_tile.dart` 增加首页两行式交易布局并显示真实账户名。
- `app_bottom_navigation.dart`、`quick_add_button.dart` 调整为原型中的绿色主色和悬浮加号样式。

### 第三项：账本选择抽屉
- `book_selector.dart` 改为木质书架抽屉：标题、管理入口、关闭按钮、个人/家庭/企业横向书册、新建账本入口及“查看更多账本”均由组件绘制。
- 抽屉顶部保留与首页一致的头像、账本标题、铃铛和搜索入口；铃铛/搜索仍分别进入现有通知和流水搜索路由。
- 书架纹理、藤叶和三种空白书册背景来自 `assets/images/bookshelf_reference_v1.png`，账本名称、类型、选中状态和管理操作仍来自真实 `LedgerBook` 数据，未把图片中的文字当作数据。
- 账本切换、关闭、长按管理、新建入口以及首页月份/账本联动测试均通过。

## 当前验收产物
- 原型备份：`docs/qa/home-reference-2026-09-10/originals/`。
- 首页上半区截图：[home-upper.png](../qa/home-reference-2026-09-10/home-upper.png)。
- 首页下半区截图：[home-lower.png](../qa/home-reference-2026-09-10/home-lower.png)。
- 账本抽屉截图：[bookshelf.png](../qa/home-reference-2026-09-10/bookshelf.png)。
- 预算/目标卡截图：[home-spending-goal-card.png](../qa/home-reference-2026-09-10/home-spending-goal-card.png)。

## 验证结果（2026-09-10）
- `flutter analyze`：通过，无问题。
- `flutter test`：全量通过，125 个测试通过。
- `test/home_reference_page_capture_test.dart`：真实 Provider + 隔离内存数据库截图通过，并生成上述三张 QA 截图。
- `flutter build apk --debug`：构建成功，产物为 `build/app/outputs/flutter-apk/app-debug.apk`。
- 主要交互覆盖：隐私金额隐藏/恢复、周预算诚实提示、预算/月切换、目标节点、账本切换/关闭/管理、会员入口、铃铛入口、首页交易行及小屏大字号无布局溢出。

## 仍需说明
- 三张输入图是合成 PNG，且尺寸分别为 643×1036、632×901、677×590；应用必须保留真实数据、可访问字体和不同屏幕适配，因此实现目标是按 PNG 逐卡逼近，而不是承诺跨设备逐像素完全相同。
- 当前截图数据来自隔离内存数据库，金额、分类和流水会随真实用户账本数据变化；装饰图片为本地生成素材，不包含动态文字。
- Android 构建仍会提示现有 `speech_to_text` 插件使用旧 Kotlin Gradle Plugin；这不是本轮 UI 改动引入的问题，但后续升级 Flutter 时需要单独处理。

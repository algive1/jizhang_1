# 开通会员页原型复刻（2026-09-17）

## 范围与实现原则

当前项目为 Flutter / Dart，沿用原有 Riverpod、路由、会员目录与支付服务，没有引入 React / Vue 或 WebView。页面主体使用真实 Flutter 组件；标题、套餐价格、权益、评价、支付方式和底部栏均由代码布局。原型参考保存在 `docs/qa/member-open-2026-09-17/reference.png`。

旧页使用独立矩形王冠 Banner，套餐数据为 12 / 30 / 98 元，支付方式放在弹窗内；这些结构与新原型的沉浸式松鼠 Hero、8 / 22 / 68 元套餐及页内支付选择不同，是本次修改的主要原因。

## 素材

使用内置 image_gen 分别生成以下素材，用户确认沿用首轮结果：

- `assets/images/membership/hero-bg.webp`：1536×1024，浅绿色自然环境，保留左侧留白。
- `assets/images/membership/hero-mascot.png`：1024×1536，松鼠抱皇冠，保留透明通道。
- `assets/images/membership/hero-leaves.png`：1536×1024，透光叶片，保留透明通道。

未额外生成可选草地素材，背景中已有草地。完整提示词、工具与透明通道验证见 `docs/qa/member-open-2026-09-17/asset-prompts.md`。素材中没有文字、按钮或价格；原始生成文件保留在 Codex generated_images 中。

## 实现文件与组件树

本次页面实现集中在以下文件，沿用 Flutter 原生 widgets 与现有 Riverpod/服务层：

- `lib/features/membership/presentation/membership_page.dart`：`MembershipPage` 入口、目录加载、当前套餐选择、购买与状态刷新；包含 `_MemberHeader`、`_CatalogContent`、`_CatalogError`。
- `lib/features/membership/presentation/membership_visuals.dart`：`MembershipHero`、`MemberPlanSection`、`MembershipPlanCard`、`MemberBenefits`、`MemberTestimonials`、`PaymentMethodSection`、`MemberBottomPayBar` 与 `MemberSectionCard`。
- `lib/features/membership/data/membership_catalog.dart`：`MembershipCatalog`、`MembershipProduct`、`MembershipBenefit`、`MembershipFaq`，以及 `ConfiguredMembershipCatalogRepository` / `membershipCatalogProvider`。
- `lib/features/membership/data/payment_service.dart`：`RemotePaymentService` 与支付异常处理，继续连接微信/支付宝真实下单链路。
- `assets/config/membership_catalog.json`：离线默认目录与展示文案。

页面结构为：

```text
MembershipPage
└─ CustomScrollView
   ├─ MembershipHero
   ├─ MemberPlanSection
   │  └─ MembershipPlanCard × 3
   ├─ MemberBenefits
   ├─ MemberTestimonials
   ├─ PaymentMethodSection
   └─ MemberBottomPayBar
```

## 交互与金额口径

目录加载遵循“远端目录优先、配置目录兜底”的现有 repository 逻辑。用户点击套餐卡后更新当前选择，底部实付栏同步更新；点击支付按钮后由 `MembershipPage._purchase` 使用所选目录商品发起下单，成功后刷新会员状态，失败显示可理解的错误反馈。支付方式选择仍由页内 `PaymentMethodSection` 管理，并交给现有支付服务执行。

面向用户的主价格固定为无小数显示：月卡 `¥8`、季卡 `¥22`、年卡 `¥68`；对应日均折合分别显示 `¥0.27`、`¥0.24`、`¥0.19`。服务层和目录仍以整数分传递（800 / 2200 / 6800），页面不使用客户端传价。

验收参考为 `docs/qa/member-open-2026-09-17/reference.png`；实现后的顶部、主体和底部截图放在同目录，待实现代理完成最终截图后补齐最终验证结论。当前文档只记录已确认的服务端 typecheck/test（10 项）/build、此前 Flutter analyze 与 debug APK 构建结果；不把最终实现后的检查写成已通过。

## 目录与服务端一致性

`assets/config/membership_catalog.json` 同时作为 App 离线展示与服务端初始目录，套餐改为 800 / 2200 / 6800 分。权益名称和排列按原型更新；保留 CSV 导出范围、云同步配置和客服未开放等真实说明。新增 `categories`、`adfree` ID，服务端 schema 同时接受旧 ID，保证已保存目录的兼容性。

用户最终要求套餐价格和底部实付不显示小数点，呈现为 ¥8 / ¥22 / ¥68；日均折合费用仍显示 ¥0.27 / ¥0.24 / ¥0.19，避免取整为零。存储和下单继续使用整数分。

服务端已有数据库的运营目录不会被启动时覆盖。已部署环境如需启用新价格，应使用现有受管理员令牌保护的 `PUT /api/v1/admin/membership/catalog` 发布目录。App 配置服务端地址后以远端目录为准；页面金额与下单均来自该目录，不使用客户端传价。未在本次任务中操作任何生产数据库或真实扣款。

## 2026-09-18 复核与补齐

对照用户提供的原型复核后，会员页补齐了以下细节：

- 顶部继续使用透明系统状态栏与页面背景，标题、返回、购买记录和 Hero 共用沉浸式背景；正文底部增加滚动安全空间，支付卡片不会被固定支付栏遮挡。
- 套餐、权益、评价和支付卡统一使用浅色边界、双层柔和阴影；推荐套餐保留绿色描边与推荐标签，权益网格在 320dp 和大字号下不再溢出。
- 新增可复用资产 `assets/images/membership/wechat-pay.png` 与 `assets/images/membership/alipay.png`，由内置 image_gen 生成透明品牌图标后压缩为 128×128 PNG；支付宝图标已重新生成为可识别的蓝底白色支付宝标志。支付区通过 `PaymentBrandIcon` 统一渲染，缺失资产时有 glyph fallback。
- 底部支付栏只保留“《会员服务协议》”链接，点击打开会员服务协议页面。个人中心菜单改为单一“服务协议”入口，进入 `/profile/legal` 后显示用户协议、隐私协议、会员服务协议三个协议卡片；点击卡片会在弹窗内显示对应内容，点击“确定”关闭。原有 `/profile/membership/agreement` 与 `/profile/privacy` 页面路由仍保留，便于直接访问。
- 支付回调在网络/SDK 完成后立即停止无限进度动画，再展示结果弹窗；底部支付按钮会按点击时的当前套餐读取目录，避免快速切换套餐后仍提交旧套餐。

本轮验证：`test/membership_legal_document_test.dart` 3 项通过，会员支付用例通过，会员原型截图用例通过；整套 `membership_page_ui_test.dart` 在当前 Flutter 测试进程中第二个字号用例会长时间停留，已用各个 plain-name 用例单独验证。`flutter analyze` 仍只有投资模块和既有测试文件的 4 条 warning，与本轮文件无关。

协议页面目前是应用内可读的产品条款草案，正式发布前仍需由法务/运营审核内容、退款渠道和客服联系方式。

## 联调与发布边界

- 微信、支付宝保留现有真实下单和 SDK 调起链路。商户配置、证书、移动端注册值及公网回调地址仍需部署环境提供：**代码完成但未实际联调**。
- 页面已提供用户协议、会员服务协议和隐私协议的可读入口；会员页底部仅保留会员服务协议链接，个人中心的“服务协议”菜单提供三类协议弹窗。条款内容仍需上线前经过法务审核，并补充真实客服渠道。
- 两条评价来自用户原型示例，并非接口返回的真实用户评价；上线时应替换为已授权的评价数据。
- 当前只有 CSV 数据导出；原型的“支持多种格式”文案不表示本次新增了导出格式。

## 新窗口继续

在 Codex 新建本项目任务，发送：

> 继续 /Users/algive/jizhang_01 的开通会员页。先阅读 docs/development/2026-09-17-member-open-prototype.md，并对照 docs/qa/member-open-2026-09-17/reference.png 和验收截图。保留工作区已有修改；沿用 Flutter 与现有支付链路。后续重点是真实商户联调、正式会员协议、真实评价数据和图标精细化。

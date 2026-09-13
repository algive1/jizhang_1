# 会员中心升级记录（2026-09-12）

## 问题原因

原会员页仍是 Free/Pro/Family 的功能状态说明，缺少原型中的会员套餐、权益、评价、FAQ 等营销内容；项目现有会员仓库只有本地 Free 快照，服务端也没有可编辑的套餐配置接口。

## 修改内容

- `lib/features/membership/presentation/membership_page.dart` 改为原型结构：顶部导航、Hero、月/季/年三档套餐、4×2 权益、两张评价卡、可展开 FAQ、品牌页脚。
- `lib/features/membership/presentation/membership_visuals.dart` 提供 Banner 和套餐卡的视觉组件，支持小屏横向滑动与大字体布局。
- `lib/features/membership/data/membership_catalog.dart` 增加 catalog 数据模型、远端读取和本地资源回退，并校验套餐/权益数量与价格。
- `server/src/membership_catalog.ts` 增加公共 `GET /api/v1/membership/catalog` 及受 `MEMBERSHIP_ADMIN_TOKEN` 保护的 `PUT /api/v1/admin/membership/catalog`；配置存入服务端 SQLite。
- `assets/config/membership_catalog.json` 集中维护初始套餐、权益和 FAQ 文案。
- 新增 `/profile/membership/records` 会员记录路由，读取服务端真实订单状态。
- `assets/images/membership/` 保存压缩后的 WebP 场景与两张示例评价头像。示例头像只用于营销内容，不绑定登录用户。

## 业务边界（已更新）

套餐价格来自 catalog；推荐套餐由 `recommended` 字段控制，缺少字段时按中间档兜底。支付入口已接入微信/支付宝订单、原生 SDK 调起和服务端回调验签，会员有效期只在服务端确认支付成功后更新。

## 验证

- `flutter analyze lib/features/membership lib/app/router/app_router.dart` 通过。
- `flutter test test/membership_test.dart test/asset_membership_prototype_capture_test.dart` 通过（相关定向测试）。
- `npm run typecheck`、`npm test`（server）通过（10 tests，含微信/支付宝回调验签）。
- `flutter build apk --debug` 通过，产物为 `build/app/outputs/flutter-apk/app-debug.apk`。
- 393dp 截图已保存至 `docs/qa/asset-membership-prototype-2026-09-11/membership-page-393.png`，已检查 Hero、三列套餐和权益网格。

## 注意事项

服务端 catalog 更新需要设置至少 32 字符的 `MEMBERSHIP_ADMIN_TOKEN`。App 只有在构建时提供 `SHARED_API_BASE_URL` 时读取服务端 catalog，否则使用本地配置。真实支付联调需要微信/支付宝商户证书和公网 HTTPS 回调地址。

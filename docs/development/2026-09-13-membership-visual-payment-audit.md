# 会员中心原型复刻与支付接入记录（2026-09-13）

## 视觉审计

原页面没有复原到原型的主要原因是旧实现只保留了 Free/Pro/Family 的功能说明，没有按原型的内容层级实现套餐、权益、评价、FAQ 和会员记录入口；Banner 也曾用低密度的局部场景，王冠、拱窗、靠垫、叶片和金色球体的层次不足。小屏和大字体下，权益网格还使用了同一套比例，导致正常字号出现过大的纵向空白。

本次已补齐：

- 会员中心按原型拆成顶部导航、宣传 Banner、三档套餐、4×2 权益、两张评价卡、FAQ 和页脚。
- 右侧 Banner 重新用 image-gen 生成透明场景，保留左侧文案留白；新场景增加大王冠、拱窗、两层米色靠垫、密集橄榄叶、金色球体、布料前景和右下横向空白留言卡。
- 空白留言卡的爱心改为 Material 图标，避免字体缺字方框；权益网格根据文字缩放在正常字号和大字体之间使用不同纵横比。
- 新图以 WebP 接入 `assets/images/membership/membership-hero-scene.webp`，原始 PNG 保存在 `docs/generated_assets/membership/membership-hero-scene-v2.png` 供设计复核。

仍需接受的视觉差异是：原型使用定制王冠和权益图标字体，当前使用 Material Icons；系统状态栏时间和底部手势条由设备系统绘制，页面无法直接控制。

## 支付链路

点击“立即开通”后依次执行：登录校验、选择微信支付或支付宝、携带幂等键请求服务端、服务端从后台 catalog 读取价格并创建订单、按官方 APP 支付协议签名下单、Flutter 原生 SDK 调起支付、服务端回调验签后更新订单和会员有效期。支付客户端返回后页面会立即及延迟刷新订单/会员状态，但服务端回调仍是授予权益的唯一依据。客户端提交的金额不会参与定价，也不会根据客户端回调直接授予会员。

服务端接口：

- `POST /api/v1/membership/orders`
- `GET /api/v1/membership/orders`
- `GET /api/v1/membership/orders/:id`
- `GET /api/v1/membership/current`
- `POST /api/v1/payments/wechat/notify`
- `POST /api/v1/payments/alipay/notify`

微信使用 APP 下单 `/v3/pay/transactions/app`，生成 `prepay_id` 和 APP 调起签名；支付宝使用 `alipay.trade.app.pay` 生成 order string。回调分别执行 RSA 验签、微信 APIv3 AES-GCM 解密或支付宝参数验签，并校验订单号、应用和金额。

需要在部署环境配置商户参数：`WECHAT_APP_ID`、`WECHAT_MCH_ID`、`WECHAT_SERIAL_NO`、`WECHAT_PRIVATE_KEY(_PATH)`、`WECHAT_NOTIFY_URL`、`WECHAT_PLATFORM_PUBLIC_KEY(_PATH)`、`WECHAT_PLATFORM_SERIAL_NO`、`WECHAT_API_V3_KEY`，以及 `ALIPAY_APP_ID`、`ALIPAY_PRIVATE_KEY(_PATH)`、`ALIPAY_PUBLIC_KEY(_PATH)`、`ALIPAY_NOTIFY_URL`。密钥只放服务端环境变量或受限文件，不进入 App。

Flutter 使用 `wechat_kit` 和 `alipay_kit` 原生 SDK。`pubspec.yaml` 中的微信 AppID、Universal Link 和支付宝 scheme 是发布配置占位值，提交商店前必须替换成开放平台登记值；包名、签名和 Universal Link 需要与微信开放平台配置一致。

## 验证

- `flutter analyze` 通过。
- `flutter test test/membership_test.dart test/membership_purchase_bookkeeping_test.dart test/asset_membership_prototype_capture_test.dart` 通过（9 tests）。
- `npm run typecheck`、`npm test` 通过（10 tests），支付测试覆盖服务端定价、幂等、微信/支付宝 APP 参数、微信回调 AES-GCM 验签、支付宝回调 RSA2 验签和会员权益授予。
- `npm run build` 通过，服务端 TypeScript 可生成生产构建。
- `flutter build apk --debug` 通过，产物为 `build/app/outputs/flutter-apk/app-debug.apk`。
- `pod install --project-directory=ios` 通过；iOS Runner 已挂载支付宝 scheme、微信 URL scheme 和 Universal Link entitlements。
- 已重新生成并检查 393dp 会员中心截图，Banner 与套餐、权益布局均已更新。

发布构建需要同时提供服务端地址和已登记的移动端参数，例如：

```bash
flutter build apk --release \
  --dart-define=SHARED_API_BASE_URL=https://api.example.com \
  --dart-define=WECHAT_UNIVERSAL_LINK=https://pay.example.com/universal_link/jizhang/wechat/
```

服务端进程还必须注入上面的微信/支付宝商户配置，并让两个 notify URL 可被公网 HTTPS 访问；本地默认地址只用于开发机联调。

实现依据的是官方协议：微信 [APP 下单](https://pay.wechatpay.cn/doc/v3/merchant/4013070347)、[APP 调起](https://pay.wechatpay.cn/doc/v3/merchant/4013070351) 和 [APP 支付开发指引](https://pay.wechatpay.cn/doc/v3/merchant/4013070176)；支付宝 [alipay.trade.app.pay](https://developer.alibaba.com/docs/api.htm?apiId=1162&docType=4) 及其 [APP 支付接入说明](https://opendocs.alipay.com/open-v3/05vuxe)。

## 联调边界

当前环境没有真实微信/支付宝商户号、证书、APIv3 密钥、回调公网 HTTPS 地址和已登记的移动 App，因此未执行真实扣款联调；代码已完成协议、验签、订单和 SDK 调用链，部署时需要填入上述配置后再用微信/支付宝沙箱或小额真实订单验证下单、回调、查单和退款流程。
当前机器只有 Xcode Command Line Tools，`flutter build ios --no-codesign` 仍会被 Flutter 的 iOS 工程配置检查阻断；iOS 原生依赖已完成 Pod 安装，需在完整 Xcode 和已签名工程环境继续真机验证。

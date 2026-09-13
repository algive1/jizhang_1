import 'dart:io' show Platform;

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:alipay_kit/alipay_kit.dart';
import 'package:wechat_kit/wechat_kit.dart';

import '../../sharing/data/session_repository.dart';
import '../../sharing/data/shared_api.dart';
import '../domain/commercial_service_contracts.dart';

/// The mobile SDKs receive only short-lived, server-generated parameters.
/// Merchant keys and provider signing never enter the Flutter process.
class RemotePaymentService implements PaymentService {
  RemotePaymentService(this.api, this.session);

  final SharedApi api;
  final SessionRepository session;

  @override
  Future<PaymentOrder> createOrder(CreatePaymentOrderRequest request) async {
    await session.initialize();
    final user = session.user;
    if (user == null) throw const PaymentException('请先登录后再开通会员');
    final response = await api.request(
      '/membership/orders',
      method: 'POST',
      body: {
        'productId': request.productId,
        'channel': request.channelValue,
        'idempotencyKey': request.idempotencyKey,
        'platform': Platform.isIOS
            ? 'ios'
            : Platform.isAndroid
            ? 'android'
            : 'other',
      },
    );
    return PaymentOrder.fromJson(response);
  }

  @override
  Future<PaymentOrder> refreshOrder(String orderId) async {
    final response = await api.request('/membership/orders/$orderId');
    return PaymentOrder.fromJson(response);
  }

  @override
  Future<List<PaymentOrder>> listOrders() async {
    await session.initialize();
    if (session.user == null) return const [];
    final response = await api.request('/membership/orders');
    final values = response['orders'];
    if (values is! List) return const [];
    return values
        .whereType<Map>()
        .map((value) => PaymentOrder.fromJson(Map<String, dynamic>.from(value)))
        .toList();
  }

  @override
  Future<void> invoke(PaymentOrder order) async {
    if (order.invokePayload.isEmpty) {
      throw const PaymentException('支付参数为空，请重新发起订单');
    }
    try {
      if (order.channel == PaymentChannel.wechatPay) {
        final payload = order.invokePayload;
        final appId = payload['appId'] as String?;
        final partnerId = payload['partnerId'] as String?;
        final prepayId = payload['prepayId'] as String?;
        final packageValue = payload['packageValue'] as String?;
        final nonceStr = payload['nonceStr'] as String?;
        final timeStamp = payload['timeStamp'] as String?;
        final sign = payload['sign'] as String?;
        if ([
          appId,
          partnerId,
          prepayId,
          packageValue,
          nonceStr,
          timeStamp,
          sign,
        ].any((value) => value == null || value.isEmpty)) {
          throw const PaymentException('微信支付参数不完整，请重新发起订单');
        }
        await WechatKitPlatform.instance.registerApp(
          appId: appId!,
          universalLink:
              payload['universalLink'] as String? ??
              const String.fromEnvironment(
                'WECHAT_UNIVERSAL_LINK',
                defaultValue: 'https://YOUR_DOMAIN.example/universal_link/jizhang/wechat/',
              ),
        );
        await WechatKitPlatform.instance.pay(
          appId: appId,
          partnerId: partnerId!,
          prepayId: prepayId!,
          package: packageValue!,
          nonceStr: nonceStr!,
          timeStamp: timeStamp!,
          sign: sign!,
        );
      } else {
        final orderString = order.invokePayload['orderString'] as String?;
        if (orderString == null || orderString.isEmpty) {
          throw const PaymentException('支付宝支付参数不完整，请重新发起订单');
        }
        await AlipayKitPlatform.instance.pay(orderInfo: orderString);
      }
    } on MissingPluginException {
      throw const PaymentException('当前安装包未包含支付 SDK，请重新构建正式包');
    } on PlatformException catch (error) {
      throw PaymentException(error.message ?? '支付 SDK 调起失败');
    }
  }
}

class PaymentException implements Exception {
  const PaymentException(this.message);
  final String message;
  @override
  String toString() => message;
}

final paymentServiceProvider = Provider<PaymentService>((ref) {
  return RemotePaymentService(
    ref.watch(sharedApiProvider),
    ref.watch(sessionRepositoryProvider),
  );
});

final membershipOrdersProvider = FutureProvider.autoDispose<List<PaymentOrder>>(
  (ref) => ref.watch(paymentServiceProvider).listOrders(),
);

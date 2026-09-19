import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../../sharing/data/session_repository.dart';
import '../../sharing/data/shared_api.dart';

/// iOS StoreKit bridge. The server remains authoritative: the client sends
/// StoreKit verification data and never grants membership locally.
class AppleMembershipPurchaseService {
  AppleMembershipPurchaseService(this.api, this.session);

  final SharedApi api;
  final SessionRepository session;
  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _subscription;

  static const productIds = <String>{
    'haohaojizhang.membership.monthly',
    'haohaojizhang.membership.quarterly',
    'haohaojizhang.membership.yearly',
  };

  Future<void> start() async {
    if (!Platform.isIOS || _subscription != null) return;
    _subscription = _iap.purchaseStream.listen(_handlePurchases);
  }

  Future<List<ProductDetails>> products() async {
    if (!Platform.isIOS || !await _iap.isAvailable()) return const [];
    final response = await _iap.queryProductDetails(productIds);
    if (response.error != null) {
      throw StateError(response.error!.message);
    }
    return response.productDetails;
  }

  Future<void> buy(String productId) async {
    await session.initialize();
    if (session.user == null) throw StateError('请先登录后再开通会员');
    final items = await products();
    ProductDetails? product;
    for (final item in items) {
      if (item.id == productId) { product = item; break; }
    }
    if (product == null) throw StateError('App Store 会员商品尚未配置');
    await start();
    final launched = await _iap.buyNonConsumable(
      purchaseParam: PurchaseParam(productDetails: product),
    );
    if (!launched) throw StateError('未能调起 App Store 支付');
  }

  Future<void> restore() async {
    await session.initialize();
    if (session.user == null) throw StateError('请先登录后恢复购买');
    await start();
    await _iap.restorePurchases();
  }

  Future<void> _handlePurchases(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      if (purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored) {
        try {
          await api.request(
            '/membership/apple/transactions',
            method: 'POST',
            body: {
              'productId': purchase.productID,
              'purchaseId': purchase.purchaseID,
              'source': purchase.verificationData.source,
              'verificationData': purchase.verificationData.serverVerificationData,
              'restored': purchase.status == PurchaseStatus.restored,
            },
          );
        } catch (_) {
          // Do not finish a transaction the server failed to verify. StoreKit
          // can redeliver it on a later launch.
          continue;
        }
      }
      if (purchase.pendingCompletePurchase &&
          purchase.status != PurchaseStatus.pending) {
        await _iap.completePurchase(purchase);
      }
    }
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
  }
}

final appleMembershipPurchaseServiceProvider =
    Provider<AppleMembershipPurchaseService>((ref) {
  final service = AppleMembershipPurchaseService(
    ref.watch(sharedApiProvider),
    ref.watch(sessionRepositoryProvider),
  );
  ref.onDispose(service.dispose);
  return service;
});

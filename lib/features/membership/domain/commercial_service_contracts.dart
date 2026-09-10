enum PaymentChannel { appleInAppPurchase, wechatPay }

enum PaymentOrderStatus { created, pending, paid, failed, refunded }

class CreatePaymentOrderRequest {
  const CreatePaymentOrderRequest({
    required this.userId,
    required this.productId,
    required this.channel,
    required this.idempotencyKey,
  });

  final String userId;
  final String productId;
  final PaymentChannel channel;
  final String idempotencyKey;
}

class PaymentOrder {
  const PaymentOrder({
    required this.id,
    required this.status,
    required this.channel,
    required this.idempotencyKey,
    required this.createdAt,
  });

  final String id;
  final PaymentOrderStatus status;
  final PaymentChannel channel;
  final String idempotencyKey;
  final DateTime createdAt;
}

abstract interface class PaymentService {
  Future<PaymentOrder> createOrder(CreatePaymentOrderRequest request);
  Future<PaymentOrder> refreshOrder(String orderId);
}

enum CloudSyncAvailability { notConfigured, available, temporarilyUnavailable }

class CloudSyncState {
  const CloudSyncState({
    required this.availability,
    this.lastSuccessfulSyncAt,
    this.message,
  });

  final CloudSyncAvailability availability;
  final DateTime? lastSuccessfulSyncAt;
  final String? message;
}

abstract interface class CloudSyncService {
  Future<CloudSyncState> status();
  Future<CloudSyncState> synchronize();
}

abstract interface class ObjectStorageService {
  Future<Uri> uploadAttachment({
    required String localPath,
    required String contentType,
  });
}

class UnconfiguredCloudSyncService implements CloudSyncService {
  const UnconfiguredCloudSyncService();

  @override
  Future<CloudSyncState> status() async => const CloudSyncState(
    availability: CloudSyncAvailability.notConfigured,
    message: '尚未配置服务端同步协议',
  );

  @override
  Future<CloudSyncState> synchronize() => status();
}

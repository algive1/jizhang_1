import '../../../core/models/membership.dart';

enum PaymentChannel { wechatPay, alipay }

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

  String get channelValue => switch (channel) {
    PaymentChannel.wechatPay => 'wechat',
    PaymentChannel.alipay => 'alipay',
  };
}

class PaymentOrder {
  const PaymentOrder({
    required this.id,
    required this.status,
    required this.channel,
    required this.idempotencyKey,
    required this.createdAt,
    required this.productId,
    required this.amountInCents,
    this.invokePayload = const {},
  });

  final String id;
  final PaymentOrderStatus status;
  final PaymentChannel channel;
  final String idempotencyKey;
  final DateTime createdAt;
  final String productId;
  final int amountInCents;
  final Map<String, dynamic> invokePayload;

  factory PaymentOrder.fromJson(Map<String, dynamic> json) {
    final rawCreatedAt = json['createdAt'];
    final createdAt = rawCreatedAt is int
        ? DateTime.fromMillisecondsSinceEpoch(rawCreatedAt * 1000)
        : DateTime.tryParse(rawCreatedAt?.toString() ?? '') ?? DateTime.now();
    final channel = json['channel']?.toString() == 'alipay'
        ? PaymentChannel.alipay
        : PaymentChannel.wechatPay;
    final rawStatus = json['status']?.toString() ?? 'created';
    final status = PaymentOrderStatus.values.firstWhere(
      (value) => value.name == rawStatus,
      orElse: () => PaymentOrderStatus.created,
    );
    return PaymentOrder(
      id: json['id'] as String,
      status: status,
      channel: channel,
      idempotencyKey: json['idempotencyKey'] as String? ?? '',
      createdAt: createdAt,
      productId: json['productId'] as String? ?? '',
      amountInCents: (json['amountInCents'] as num?)?.toInt() ?? 0,
      invokePayload: json['invoke'] is Map
          ? Map<String, dynamic>.from(json['invoke'] as Map)
          : const {},
    );
  }
}

abstract interface class PaymentService {
  Future<PaymentOrder> createOrder(CreatePaymentOrderRequest request);
  Future<PaymentOrder> refreshOrder(String orderId);
  Future<void> invoke(PaymentOrder order);
  Future<List<PaymentOrder>> listOrders();
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

class MembershipFeatureAccess {
  const MembershipFeatureAccess({
    required this.feature,
    required this.enabled,
    required this.allowed,
    required this.requiresUpgrade,
    required this.policy,
  });

  final MembershipFeature feature;
  final bool enabled;
  final bool allowed;
  final bool requiresUpgrade;
  final MembershipFeaturePolicy policy;
}

/// Resolves a business feature against the current membership snapshot.
///
/// A server-backed implementation can replace the repository/provider later;
/// feature pages only need to depend on this contract and the shared upgrade
/// prompt.
abstract interface class MembershipFeatureAccessService {
  Future<MembershipFeatureAccess> accessFor(MembershipFeature feature);
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

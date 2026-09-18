class PaymentNotification {
  const PaymentNotification({
    required this.id,
    required this.packageName,
    required this.title,
    required this.text,
    required this.postedAt,
  });

  final String id;
  final String packageName;
  final String title;
  final String text;
  final DateTime postedAt;

  String get content => '$title $text'.trim();
}

abstract interface class PaymentNotificationBridge {
  Future<bool> isAccessGranted();
  Future<void> openAccessSettings();
  Future<bool> isEnabled();
  Future<void> setEnabled(bool enabled);
  Future<bool> isNotificationGranted();
  Future<void> requestNotificationPermission();
  Future<List<PaymentNotification>> getPending();
  Future<void> acknowledge(Iterable<String> ids);
}

import 'package:flutter_riverpod/flutter_riverpod.dart';

enum AccountPendingAction {
  membershipPurchase,
  joinSharedLedger,
  enableSharedLedger,
  cloudSync,
  serverAi,
}

class AccountPendingIntent {
  const AccountPendingIntent({
    required this.id,
    required this.action,
    required this.returnLocation,
    this.payload = const <String, String>{},
  });

  final String id;
  final AccountPendingAction action;
  final String returnLocation;
  final Map<String, String> payload;
}

class AccountPendingIntentController {
  AccountPendingIntent? _current;

  AccountPendingIntent? get current => _current;

  void set(AccountPendingIntent intent) => _current = intent;

  AccountPendingIntent? consume(String id) {
    final value = _current;
    if (value == null || value.id != id) return null;
    _current = null;
    return value;
  }

  void clear([String? id]) {
    if (id == null || _current?.id == id) _current = null;
  }
}

final accountPendingIntentProvider = Provider<AccountPendingIntentController>(
  (_) => AccountPendingIntentController(),
);

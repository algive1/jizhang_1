import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/database_provider.dart';
import 'auto_bookkeeping_pending.dart';

class PendingPaymentReview {
  const PendingPaymentReview(this.candidate, {this.ignored = false});
  final PendingAutoBookkeepingCandidate candidate;
  final bool ignored;
}

class AutoBookkeepingInboxBridge {
  const AutoBookkeepingInboxBridge();
  static const _channel = MethodChannel('jizhang/autobookkeeping_pending');

  Future<List<PendingPaymentReview>> getInbox() async {
    try {
      final values = await _channel.invokeListMethod<Object?>('getInbox');
      return [
        for (final value in values ?? const [])
          if (value is Map)
            PendingPaymentReview(
              PendingAutoBookkeepingCandidate.fromMap(value),
              ignored: value['status'] == 'ignored',
            ),
      ];
    } on MissingPluginException {
      return const [];
    }
  }

  Future<bool> select(String fingerprint) async =>
      await _channel.invokeMethod<bool>('select', {
        'fingerprint': fingerprint,
      }) ??
      false;

  Future<void> ignore(String fingerprint) async {
    final ignored = await _channel.invokeMethod<bool>('ignore', {
      'fingerprint': fingerprint,
    });
    if (ignored != true) throw StateError('账单已发生变化，请刷新后重试');
  }

  Future<void> defer(String fingerprint) async {
    final deferred = await _channel.invokeMethod<bool>('defer', {
      'fingerprint': fingerprint,
    });
    if (deferred != true) throw StateError('账单已发生变化，请刷新后重试');
  }

  Future<void> markRecorded(String fingerprint) => _channel.invokeMethod<void>(
    'complete',
    {'fingerprint': fingerprint, 'keepScreenshot': true},
  );
}

final autoBookkeepingInboxBridgeProvider = Provider<AutoBookkeepingInboxBridge>(
  (ref) => const AutoBookkeepingInboxBridge(),
);

final pendingPaymentInboxProvider = FutureProvider<List<PendingPaymentReview>>((
  ref,
) async {
  final bridge = ref.watch(autoBookkeepingInboxBridgeProvider);
  final values = await bridge.getInbox();
  if (values.isEmpty) return values;
  final database = ref.watch(databaseProvider);
  final pending = <PendingPaymentReview>[];
  for (final item in values) {
    // Saved reviews retain their original identity even if the user edits
    // the merchant, amount or time. Amount alone cannot identify an order.
    final saved = await database.transactionDao.findActiveById(
      'auto-${item.candidate.fingerprint}',
    );
    if (saved == null) {
      pending.add(item);
    } else {
      await bridge.markRecorded(item.candidate.fingerprint);
    }
  }
  return pending;
});

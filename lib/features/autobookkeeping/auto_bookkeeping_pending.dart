import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum AutoBookkeepingEnqueueResult { accepted, duplicate, busy }

class PendingAutoBookkeepingCandidate {
  const PendingAutoBookkeepingCandidate({
    required this.fingerprint,
    required this.amountInCents,
    required this.merchant,
    required this.paymentMethod,
    required this.timestamp,
    required this.sourceApp,
    required this.scene,
    required this.transactionType,
  });

  factory PendingAutoBookkeepingCandidate.fromMap(Map<Object?, Object?> map) {
    final amount = map['amountInCents'];
    final timestamp = map['timestamp'];
    if (amount is! num || timestamp is! num) {
      throw const FormatException('自动记账候选数据不完整');
    }
    return PendingAutoBookkeepingCandidate(
      fingerprint: map['fingerprint']?.toString() ?? '',
      amountInCents: amount.toInt(),
      merchant: map['merchant']?.toString() ?? '',
      paymentMethod: map['paymentMethod']?.toString() ?? 'UNKNOWN',
      timestamp: DateTime.fromMillisecondsSinceEpoch(timestamp.toInt()),
      sourceApp: map['sourceApp']?.toString() ?? 'UNKNOWN',
      scene: map['scene']?.toString() ?? 'PAYMENT_SUCCESS',
      transactionType: map['transactionType']?.toString() ?? 'EXPENSE',
    );
  }

  final String fingerprint;
  final int amountInCents;
  final String merchant;
  final String paymentMethod;
  final DateTime timestamp;
  final String sourceApp;
  final String scene;
  final String transactionType;
}

abstract interface class AutoBookkeepingPendingBridge {
  Future<PendingAutoBookkeepingCandidate?> getPending();
  Future<AutoBookkeepingEnqueueResult> enqueue(
    PendingAutoBookkeepingCandidate candidate,
  );
  Future<void> complete();
}

class MethodChannelAutoBookkeepingPendingBridge
    implements AutoBookkeepingPendingBridge {
  const MethodChannelAutoBookkeepingPendingBridge();

  static const _channel = MethodChannel('jizhang/autobookkeeping_pending');

  @override
  Future<PendingAutoBookkeepingCandidate?> getPending() async {
    try {
      final raw = await _channel.invokeMethod<Map<Object?, Object?>>(
        'getPending',
      );
      if (raw == null) return null;
      return PendingAutoBookkeepingCandidate.fromMap(raw);
    } on MissingPluginException {
      return null;
    }
  }

  @override
  Future<AutoBookkeepingEnqueueResult> enqueue(
    PendingAutoBookkeepingCandidate candidate,
  ) async {
    try {
      final raw = await _channel.invokeMethod<Object?>('enqueue', {
        'amountInCents': candidate.amountInCents,
        'merchant': candidate.merchant,
        'paymentMethod': candidate.paymentMethod,
        'timestamp': candidate.timestamp.millisecondsSinceEpoch,
        'sourceApp': candidate.sourceApp,
        'scene': candidate.scene,
        'transactionType': candidate.transactionType,
      });
      if (raw is bool) {
        // Backward compatibility with older native builds during hot reload.
        return raw
            ? AutoBookkeepingEnqueueResult.accepted
            : AutoBookkeepingEnqueueResult.busy;
      }
      if (raw is Map) {
        return switch (raw['status']?.toString()) {
          'accepted' => AutoBookkeepingEnqueueResult.accepted,
          'duplicate' => AutoBookkeepingEnqueueResult.duplicate,
          _ => AutoBookkeepingEnqueueResult.busy,
        };
      }
      return AutoBookkeepingEnqueueResult.busy;
    } on MissingPluginException {
      return AutoBookkeepingEnqueueResult.busy;
    }
  }

  @override
  Future<void> complete() async {
    try {
      await _channel.invokeMethod<void>('complete');
    } on MissingPluginException {
      throw StateError('自动记账确认页仅支持 Android');
    }
  }
}

final autoBookkeepingPendingBridgeProvider =
    Provider<AutoBookkeepingPendingBridge>(
      (ref) => const MethodChannelAutoBookkeepingPendingBridge(),
    );

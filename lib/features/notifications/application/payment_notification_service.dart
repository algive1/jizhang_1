import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_seeder.dart';
import '../../../core/database/database_provider.dart';
import '../../books/data/book_repository.dart';
import '../../settings/data/app_settings_repository.dart';
import '../../../core/models/transaction_record.dart';
import '../../bookkeeping/application/quick_bookkeeping_service.dart';
import '../../transactions/data/transactions_repository.dart';
import '../domain/payment_notification.dart';

class MethodChannelPaymentNotificationBridge
    implements PaymentNotificationBridge {
  const MethodChannelPaymentNotificationBridge();

  static const _channel = MethodChannel('jizhang/payment_notifications');

  @override
  Future<bool> isAccessGranted() async {
    try {
      return await _channel.invokeMethod<bool>('isAccessGranted') ?? false;
    } on MissingPluginException {
      return false;
    }
  }

  @override
  Future<void> openAccessSettings() async {
    try {
      await _channel.invokeMethod<void>('openAccessSettings');
    } on MissingPluginException {
      throw StateError('支付通知监听仅支持 Android');
    }
  }

  @override
  Future<bool> isEnabled() async {
    try {
      return await _channel.invokeMethod<bool>('isEnabled') ?? false;
    } on MissingPluginException {
      return false;
    }
  }

  @override
  Future<void> setEnabled(bool enabled) async {
    try {
      await _channel.invokeMethod<void>('setEnabled', enabled);
    } on MissingPluginException {
      throw StateError('支付通知监听仅支持 Android');
    }
  }

  @override
  Future<List<PaymentNotification>> getPending() async {
    try {
      final raw = await _channel.invokeMethod<List<Object?>>('getPending');
      return (raw ?? const <Object?>[])
          .whereType<Map>()
          .map((item) {
            final postedAt = DateTime.tryParse(
              item['postedAt']?.toString() ?? '',
            );
            if (postedAt == null) throw const FormatException('无效通知时间');
            return PaymentNotification(
              id: item['id']?.toString() ?? '',
              packageName: item['packageName']?.toString() ?? '',
              title: item['title']?.toString() ?? '',
              text: item['text']?.toString() ?? '',
              postedAt: postedAt,
            );
          })
          .where((item) => item.id.isNotEmpty)
          .toList(growable: false);
    } on MissingPluginException {
      return const [];
    }
  }

  @override
  Future<void> acknowledge(Iterable<String> ids) async {
    try {
      await _channel.invokeMethod<void>('acknowledge', ids.toList());
    } on MissingPluginException {
      // Unsupported platforms have no native queue to acknowledge.
    }
  }
}

class ParsedPaymentNotification {
  const ParsedPaymentNotification({
    required this.amount,
    required this.accountId,
    required this.merchant,
    required this.occurredAt,
    required this.orderId,
  });

  final double amount;
  final String accountId;
  final String? merchant;
  final DateTime occurredAt;
  final String? orderId;
}

class PaymentNotificationParser {
  const PaymentNotificationParser();

  ParsedPaymentNotification? parse(PaymentNotification notification) {
    final accountId = _accountFor(notification.packageName);
    if (accountId == null) return null;
    final content = notification.content;
    if (!RegExp(r'支付|付款|消费|扣款|收款').hasMatch(content)) return null;
    final amount = _amountFor(content);
    if (amount == null || amount <= 0) return null;
    return ParsedPaymentNotification(
      amount: amount,
      accountId: accountId,
      merchant: _merchantFor(content),
      occurredAt: notification.postedAt,
      orderId: _orderIdFor(content),
    );
  }

  String? _accountFor(String packageName) => switch (packageName) {
    'com.tencent.mm' => SeedIds.wechatAccount,
    'com.eg.android.AlipayGphone' => SeedIds.alipayAccount,
    'com.unionpay' => SeedIds.bankAccount,
    _ => null,
  };

  double? _amountFor(String content) {
    final matches = RegExp(
      r'(?:¥|￥|金额|支付|消费|扣款)[^0-9]{0,10}([0-9]{1,9}(?:[.,][0-9]{1,2})?)',
    ).allMatches(content).toList();
    if (matches.isNotEmpty) {
      return double.tryParse(matches.last.group(1)!.replaceAll(',', '.'));
    }
    final fallback = RegExp(r'[¥￥]\s*([0-9]+(?:[.,][0-9]{1,2})?)')
        .firstMatch(content);
    return double.tryParse(fallback?.group(1)?.replaceAll(',', '.') ?? '');
  }

  String? _merchantFor(String content) {
    final match = RegExp(r'(?:向|在|商户(?:名称)?[：:]?)[\s：:]*([^，。；;\n]{2,32})')
        .firstMatch(content);
    final value = match?.group(1)?.trim();
    return value == null || value.isEmpty ? null : value;
  }

  String? _orderIdFor(String content) {
    final match = RegExp(r'(?:订单号|交易单号|流水号)[：:\s]*([A-Za-z0-9_-]{6,64})')
        .firstMatch(content);
    return match?.group(1);
  }
}

class NotificationAutoBookkeepingSummary {
  const NotificationAutoBookkeepingSummary({
    required this.created,
    required this.duplicates,
    required this.unrecognized,
    this.waiting = 0,
  });

  final int created;
  final int duplicates;
  final int unrecognized;
  final int waiting;
}

class PaymentNotificationAutoBookkeepingService {
  PaymentNotificationAutoBookkeepingService({
    required this.bridge,
    required this.transactions,
    required this.bookkeeping,
    this.parser = const PaymentNotificationParser(),
    this.resolveTarget,
    this.alreadyHandled,
  });

  final PaymentNotificationBridge bridge;
  final TransactionRepository transactions;
  final QuickBookkeepingService bookkeeping;
  final PaymentNotificationParser parser;
  final Future<({String bookId, String accountId})?> Function(String channel)?
  resolveTarget;
  final Future<bool> Function(
    String notificationId,
    String? orderId,
    String packageName,
  )?
  alreadyHandled;

  Future<NotificationAutoBookkeepingSummary>? _processing;
  Future<NotificationAutoBookkeepingSummary> processPending() =>
      _processing ??= _processPending().whenComplete(() => _processing = null);
  Future<NotificationAutoBookkeepingSummary> _processPending() async {
    if (!await bridge.isEnabled()) {
      return const NotificationAutoBookkeepingSummary(
        created: 0,
        duplicates: 0,
        unrecognized: 0,
      );
    }
    final pending = await bridge.getPending();
    var created = 0;
    var duplicates = 0;
    var unrecognized = 0;
    var waiting = 0;
    final acknowledged = <String>[];
    for (final notification in pending) {
      final parsed = parser.parse(notification);
      if (parsed == null) {
        unrecognized++;
        continue;
      }
      final notificationKey = notification.id;
      if (await _isAlreadyHandled(
        notificationKey,
        parsed.orderId,
        notification.packageName,
      )) {
        duplicates++;
        acknowledged.add(notification.id);
        continue;
      }
      final target = resolveTarget == null
          ? (bookId: SeedIds.personalBook, accountId: parsed.accountId)
          : await resolveTarget!(parsed.accountId);
      if (target == null) {
        waiting++;
        continue;
      }
      final id = 'auto-notification-${stableNotificationKey(notificationKey)}';
      final request = QuickBookkeepingRequest(
        transactionId: id,
        bookId: target.bookId,
        type: TransactionType.expense,
        amount: parsed.amount,
        accountId: target.accountId,
        occurredAt: parsed.occurredAt,
        categoryId: null,
        merchant: parsed.merchant,
        note: '支付通知自动记账',
        source: TransactionSource.auto,
        metadata: {
          'autoType': 'paymentNotification',
          'notificationKey': notificationKey,
          'notificationOrderId': parsed.orderId,
          'paymentPackageName': notification.packageName,
        },
      );
      try {
        await bookkeeping.save(request);
        created++;
        acknowledged.add(notification.id);
      } on StateError {
        if (!await _isAlreadyHandled(
          notificationKey,
          parsed.orderId,
          notification.packageName,
        )) {
          rethrow;
        }
        duplicates++;
        acknowledged.add(notification.id);
      }
    }
    await bridge.acknowledge(acknowledged);
    return NotificationAutoBookkeepingSummary(
      created: created,
      duplicates: duplicates,
      unrecognized: unrecognized,
      waiting: waiting,
    );
  }

  Future<bool> _isAlreadyHandled(
    String notificationKey,
    String? orderId,
    String packageName,
  ) async {
    if (alreadyHandled != null) {
      return alreadyHandled!(notificationKey, orderId, packageName);
    }
    return await _findExisting(notificationKey, orderId) != null;
  }

  Future<TransactionRecord?> _findExisting(
    String notificationKey,
    String? orderId,
  ) async {
    for (final transaction in await transactions.getAll()) {
      final raw = transaction.metadataJson;
      if (raw == null || raw.isEmpty) continue;
      try {
        final value = jsonDecode(raw);
        if (value is Map &&
            (value['notificationKey'] == notificationKey ||
                (orderId != null && value['notificationOrderId'] == orderId))) {
          return transaction;
        }
      } on FormatException {
        // Ignore legacy metadata that cannot describe an auto event.
      }
    }
    return null;
  }
}

String stableNotificationKey(String value) {
  var hash = 17;
  for (final unit in value.codeUnits) {
    hash = hash * 31 + unit;
  }
  return hash.abs().toRadixString(16);
}

final paymentNotificationBridgeProvider = Provider<PaymentNotificationBridge>(
  (ref) => const MethodChannelPaymentNotificationBridge(),
);

final paymentNotificationAutoBookkeepingProvider =
    Provider<PaymentNotificationAutoBookkeepingService>((ref) {
      final database = ref.read(databaseProvider);
      // Notifications follow the fixed target setting, so this writer cannot
      // be scoped to the book currently visible on the home page.
      final notificationTransactions = DriftTransactionRepository(database);
      final settings = ref.read(appSettingsRepositoryProvider);
      return PaymentNotificationAutoBookkeepingService(
        resolveTarget: (channel) async {
          final database = ref.read(databaseProvider);
          final book =
              await settings.get(notificationTargetBookKey) ??
              SeedIds.personalBook;
          final accessible = await ref
              .read(bookRepositoryProvider)
              .getForUser(SeedIds.localUser);
          if (!accessible.any((b) => b.id == book)) return null;
          final accountId =
              await settings.get(notificationAccountKey(book, channel)) ??
              (book == SeedIds.personalBook ? channel : null);
          if (accountId == null) return null;
          final account = await database.accountDao.findById(accountId);
          if (account == null || account.bookId != book || account.isArchived)
            return null;
          return (bookId: book, accountId: accountId);
        },
        alreadyHandled: (id, order, package) async {
          final targetBook =
              await settings.get(notificationTargetBookKey) ??
              SeedIds.personalBook;
          final rows = await database
              .customSelect(
                'SELECT metadata_json FROM transactions WHERE book_id=? AND metadata_json IS NOT NULL',
                variables: [Variable(targetBook)],
              )
              .get();
          for (final row in rows) {
            final raw = row.read<String>('metadata_json');
            dynamic metadata;
            try {
              metadata = jsonDecode(raw);
            } on FormatException {
              continue;
            }
            if (metadata is Map &&
                (metadata['notificationKey'] == id ||
                    (order != null &&
                        metadata['notificationOrderId'] == order &&
                        metadata['paymentPackageName'] == package)))
              return true;
          }
          return false;
        },
        bridge: ref.watch(paymentNotificationBridgeProvider),
        transactions: notificationTransactions,
        bookkeeping: QuickBookkeepingService(
          notificationTransactions,
          settings,
          activeBookId: () => ref.read(activeBookIdProvider),
        ),
      );
    });

const notificationTargetBookKey = 'notifications.target_book';
String notificationAccountKey(String book, String channel) =>
    'notifications.account.$book.$channel';

class NotificationProcessingError extends Notifier<String?> {
  @override
  String? build() => null;
  void setError(String? value) {
    state = value;
  }
}

final notificationProcessingErrorProvider =
    NotifierProvider<NotificationProcessingError, String?>(
      NotificationProcessingError.new,
    );

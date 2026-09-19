import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_seeder.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/models/account.dart';
import '../../books/data/book_repository.dart';
import '../../settings/data/app_settings_repository.dart';
import '../../../core/models/transaction_record.dart';
import '../../../core/platform/bookkeeping_feedback.dart';
import '../../autobookkeeping/auto_bookkeeping_pending.dart';
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
  Future<bool> isConnected() async {
    try {
      return await _channel.invokeMethod<bool>('isConnected') ?? false;
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
  Future<bool> isNotificationGranted() async {
    try {
      return await _channel.invokeMethod<bool>('isNotificationGranted') ??
          false;
    } on MissingPluginException {
      return false;
    }
  }

  @override
  Future<bool> requestNotificationPermission() async {
    try {
      return await _channel.invokeMethod<bool>('requestNotificationPermission') ??
          false;
    } on MissingPluginException {
      return false;
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
    required this.channel,
    required this.merchant,
    required this.occurredAt,
    required this.orderId,
    required this.transactionType,
    required this.paymentMethod,
    this.identifierSuffix,
    this.note,
    this.originalAmount,
    this.discountAmount,
  });

  final double amount;
  final String? accountId;
  final String channel;
  final String? merchant;
  final DateTime occurredAt;
  final String? orderId;
  final String transactionType;
  final String paymentMethod;
  final String? identifierSuffix;
  final String? note;
  final double? originalAmount;
  final double? discountAmount;
}

class PaymentNotificationParser {
  const PaymentNotificationParser();

  ParsedPaymentNotification? parse(PaymentNotification notification) {
    final channel = _channelFor(notification.packageName);
    if (channel == null) return null;
    final content = notification.content;

    final transactionType = switch (content) {
      final value when RegExp(
        r'退款成功|退款到账|退款已到账|已退款|退款完成',
      ).hasMatch(value) => 'REFUND',
      final value when RegExp(
        r'收款到账|收款成功|收款已到账|收入到账',
      ).hasMatch(value) => 'INCOME',
      _ => 'EXPENSE',
    };

    if (notification.packageName == 'com.tencent.mm' &&
        transactionType != 'EXPENSE' &&
        !RegExp(r'微信支付|支付凭证|付款凭证|服务通知').hasMatch(content)) {
      return null;
    }

    if (transactionType == 'EXPENSE') {
      if (RegExp(
        r'转入提醒|入账提醒|到账提醒|退回失败|待支付|待付款|去支付|去付款|未支付|未付款|支付失败|付款失败|交易失败|支付取消|付款取消|取消支付|重新支付|支付提醒|请支付',
      ).hasMatch(content)) {
        return null;
      }

      final hasStrongSuccess = RegExp(
        r'支付成功|付款成功|交易成功|扣款成功|消费成功|已支付|已付款|支付完成|付款完成|订单支付成功|订单已支付|订单支付完成|支付已完成|付款已完成|交易已完成',
      ).hasMatch(content);
      final hasWalletDebit = RegExp(r'消费|扣款|支出').hasMatch(content);
      final hasNonTransactionSignal = RegExp(
        r'优惠券|消费券|立减券|活动提醒|付款码|收款码',
      ).hasMatch(content);
      if (notification.packageName == 'com.tencent.mm' &&
          hasStrongSuccess &&
          !RegExp(r'微信支付|支付凭证|付款凭证|服务通知').hasMatch(content)) {
        return null;
      }
      if (_isMarketplaceChannel(channel)) {
        if (!hasStrongSuccess) return null;
      } else if (!hasStrongSuccess && (!hasWalletDebit || hasNonTransactionSignal)) {
        return null;
      }
    }

    final amount = _amountFor(content);
    if (amount == null || amount <= 0) return null;
    final merchant = _merchantFor(content) ?? _counterpartyFor(content);
    if (merchant == null) return null;
    final breakdown = _amountBreakdownFor(content, amount);
    return ParsedPaymentNotification(
      amount: amount,
      accountId: _accountFor(channel),
      channel: channel,
      merchant: merchant,
      occurredAt: notification.postedAt,
      orderId: _orderIdFor(content),
      transactionType: transactionType,
      paymentMethod:
          _paymentMethodFor(content) ?? _displayPaymentMethod(channel),
      identifierSuffix: _identifierSuffixFor(content),
      note: _noteFor(content),
      originalAmount: breakdown.$1,
      discountAmount: breakdown.$2,
    );
  }

  bool _isMarketplaceChannel(String channel) =>
      const {'meituan', 'jd', 'pinduoduo', 'douyin'}.contains(channel);

  String? _channelFor(String packageName) {
    if (packageName == 'com.sankuai.meituan' ||
        packageName == 'com.sankuai.meituan.takeout') {
      return 'meituan';
    }
    return switch (packageName) {
      'com.tencent.mm' => SeedIds.wechatAccount,
      'com.eg.android.AlipayGphone' => SeedIds.alipayAccount,
      'com.unionpay' => SeedIds.bankAccount,
      'com.jingdong.app.mall' => 'jd',
      'com.xunmeng.pinduoduo' => 'pinduoduo',
      'com.ss.android.ugc.aweme' ||
      'com.ss.android.ugc.aweme.mobile' => 'douyin',
      _ => null,
    };
  }

  String? _accountFor(String channel) => switch (channel) {
    SeedIds.wechatAccount => SeedIds.wechatAccount,
    SeedIds.alipayAccount => SeedIds.alipayAccount,
    SeedIds.bankAccount => SeedIds.bankAccount,
    'meituan' || 'jd' || 'pinduoduo' || 'douyin' => null,
    _ => null,
  };

  double? _amountFor(String content) {
    final explicit = RegExp(
      r'(?:实付金额?|实际支付|付款金额|支付金额|消费金额|扣款金额|退款金额|收款金额|到账金额|收入金额)[^0-9]{0,10}(?:¥|￥)?\s*([0-9]{1,9}(?:[.,][0-9]{1,2})?)',
    ).allMatches(content).map(_parseAmount).whereType<double>().toSet();
    if (explicit.length == 1) return explicit.single;
    if (explicit.length > 1) return null;

    final status = RegExp(
      r'(?:支付|付款|消费|扣款)[^0-9]{0,12}(?:¥|￥)?\s*([0-9]{1,9}(?:[.,][0-9]{1,2})?)',
    ).allMatches(content).map(_parseAmount).whereType<double>().toSet();
    if (status.length == 1) return status.single;
    if (status.length > 1) return null;

    final currency = RegExp(r'[¥￥]\s*([0-9]+(?:[.,][0-9]{1,2})?)')
        .allMatches(content)
        .map(_parseAmount)
        .whereType<double>()
        .toSet();
    return currency.length == 1 ? currency.single : null;
  }

  double? _parseAmount(RegExpMatch match) =>
      double.tryParse(match.group(1)!.replaceAll(',', '.'));

  (double?, double?) _amountBreakdownFor(
    String content,
    double paidAmount,
  ) {
    double? single(RegExp pattern) {
      final values = pattern
          .allMatches(content)
          .map(_parseAmount)
          .whereType<double>()
          .toSet();
      return values.length == 1 ? values.single : null;
    }

    var original = single(
      RegExp(
        r'(?:原价|订单金额|商品金额|合计|应付金额)[^0-9]{0,8}(?:¥|￥)?\s*([0-9]{1,9}(?:[.,][0-9]{1,2})?)',
      ),
    );
    var discount = single(
      RegExp(
        r'(?:优惠金额|优惠|立减|红包|优惠券)[^0-9]{0,8}(?:¥|￥)?\s*([0-9]{1,9}(?:[.,][0-9]{1,2})?)',
      ),
    );
    if (original != null && original < paidAmount) original = null;
    if (original != null && discount == null) {
      final delta = original - paidAmount;
      if (delta > 0) discount = delta;
    }
    if (discount != null && original == null) {
      original = paidAmount + discount;
    }
    if (original != null &&
        discount != null &&
        ((original - discount) - paidAmount).abs() > .005) {
      return (null, null);
    }
    return (original, discount);
  }

  String? _noteFor(String content) {
    final match = RegExp(
      r'(?:备注|订单备注|付款备注)[：:\s]+([^，。；;\n]{2,80})',
    ).firstMatch(content);
    final value = match?.group(1)?.trim();
    return value == null || value.isEmpty ? null : value;
  }

  String? _paymentMethodFor(String content) {
    final explicit = RegExp(
      r'(?:支付方式|付款方式|支付渠道)[：:\s]*([^，。；;\n]{2,40})',
    ).firstMatch(content)?.group(1)?.trim();
    if (explicit != null && explicit.isNotEmpty) return explicit;
    if (content.contains('支付宝')) return '支付宝';
    if (content.contains('微信支付')) return '微信支付';
    if (content.contains('云闪付')) return '云闪付';
    if (content.contains('信用卡')) return '信用卡';
    if (content.contains('储蓄卡')) return '储蓄卡';
    if (content.contains('银行卡')) return '银行卡';
    return null;
  }

  String? _counterpartyFor(String content) {
    final match = RegExp(
      r'(?:来自|付款方|付款人|退款方|对方)[：:\s]*([^，。；;\n]{2,32})',
    ).firstMatch(content);
    final value = match?.group(1)?.trim();
    if (value == null || value.isEmpty) return null;
    if (RegExp(
      r'[¥￥]|支付成功|付款成功|交易成功|实付金额|支付金额',
    ).hasMatch(value)) {
      return null;
    }
    return value;
  }

  String? _merchantFor(String content) {
    final explicit = RegExp(
      r'(?:商户名称|商户|商家名称|商家|店铺名称|店铺|门店|收款方)[：:\s]+([^，。；;\n]{2,32})',
    ).firstMatch(content);
    final directional = RegExp(
      r'(?:向|在)\s*([^，。；;\n]{2,32}?)(?:支付|付款|消费)',
    ).firstMatch(content);
    final value = (explicit?.group(1) ?? directional?.group(1))?.trim();
    if (value == null || value.isEmpty) return null;
    if (RegExp(r'[¥￥]|支付成功|付款成功|交易成功|实付金额|支付金额').hasMatch(value)) {
      return null;
    }
    return value;
  }

  String? _orderIdFor(String content) {
    final match = RegExp(
      r'(?:订单号|交易单号|交易号|流水号|支付单号)[：:\s]*([A-Za-z0-9_-]{6,64})',
    )
        .firstMatch(content);
    return match?.group(1);
  }

  String? _identifierSuffixFor(String content) {
    final match = RegExp(
      r'(?:尾号|后四位|卡号后四位|手机号后四位)[^0-9]{0,8}([0-9]{4})|(?:银行卡|信用卡|储蓄卡)[^0-9]{0,8}([0-9]{4})(?![0-9])',
    ).firstMatch(content);
    return match?.group(1) ?? match?.group(2);
  }
}

class NotificationAutoBookkeepingSummary {
  const NotificationAutoBookkeepingSummary({
    required this.created,
    required this.duplicates,
    required this.unrecognized,
    this.waiting = 0,
    this.queued = 0,
  });

  final int created;
  final int duplicates;
  final int unrecognized;
  final int waiting;
  final int queued;
}

class PaymentNotificationAutoBookkeepingService {
  PaymentNotificationAutoBookkeepingService({
    required this.bridge,
    required this.transactions,
    required this.bookkeeping,
    this.parser = const PaymentNotificationParser(),
    this.resolveTarget,
    this.alreadyHandled,
    this.alreadyHandledFingerprint,
    this.pendingBridge,
  });

  final PaymentNotificationBridge bridge;
  final TransactionRepository transactions;
  final QuickBookkeepingService bookkeeping;
  final PaymentNotificationParser parser;
  final Future<({String bookId, String accountId})?> Function(
    String channel,
    String? identifierSuffix,
  )?
  resolveTarget;
  final Future<bool> Function(
    String notificationId,
    String? orderId,
    String packageName,
  )?
  alreadyHandled;
  final Future<bool> Function(String fingerprint)? alreadyHandledFingerprint;
  final AutoBookkeepingPendingBridge? pendingBridge;

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
    var queued = 0;
    final acknowledged = <String>[];
    for (final notification in pending) {
      final parsed = parser.parse(notification);
      if (parsed == null) {
        unrecognized++;
        acknowledged.add(notification.id);
        continue;
      }
      final notificationKey = notification.id;
      final fingerprint = _notificationFingerprint(notification, parsed);
      if (await _isAlreadyHandled(
        notificationKey,
        parsed.orderId,
        notification.packageName,
        fingerprint,
      )) {
        duplicates++;
        acknowledged.add(notification.id);
        continue;
      }
      if (pendingBridge != null) {
        // Confirmation-mode bookkeeping does not need a preconfigured target
        // account: the confirmation page lets the user choose book/account/
        // category. Requiring resolveTarget here used to block marketplace
        // notifications (Meituan/JD/etc.) before they could ever show a card.
        final merchant = parsed.merchant?.trim();
        if (merchant == null || merchant.isEmpty) {
          unrecognized++;
          acknowledged.add(notification.id);
          continue;
        }
        final enqueueResult = await pendingBridge!.enqueue(
          PendingAutoBookkeepingCandidate(
            fingerprint: stableNotificationKey(fingerprint),
            amountInCents: (parsed.amount * 100).round(),
            merchant: merchant,
            paymentMethod: parsed.paymentMethod,
            timestamp: parsed.occurredAt,
            sourceApp: _sourceApp(parsed.channel),
            scene: switch (parsed.transactionType) {
              'REFUND' => 'PAYMENT_NOTIFICATION_REFUND',
              'INCOME' => 'PAYMENT_NOTIFICATION_INCOME',
              _ => 'PAYMENT_NOTIFICATION',
            },
            transactionType: parsed.transactionType,
            orderId: parsed.orderId,
            note: parsed.note,
            originalAmountInCents: parsed.originalAmount == null
                ? null
                : (parsed.originalAmount! * 100).round(),
            discountAmountInCents: parsed.discountAmount == null
                ? null
                : (parsed.discountAmount! * 100).round(),
            identifierSuffix: parsed.identifierSuffix,
          ),
        );
        switch (enqueueResult) {
          case AutoBookkeepingEnqueueResult.accepted:
            queued++;
            acknowledged.add(notification.id);
            break;
          case AutoBookkeepingEnqueueResult.duplicate:
            duplicates++;
            acknowledged.add(notification.id);
            break;
          case AutoBookkeepingEnqueueResult.busy:
            waiting++;
            break;
        }
        continue;
      }

      final target = resolveTarget == null
          ? parsed.accountId != null && parsed.identifierSuffix == null
                ? (bookId: SeedIds.personalBook, accountId: parsed.accountId!)
                : null
          : await resolveTarget!(parsed.channel, parsed.identifierSuffix);
      if (target == null) {
        waiting++;
        continue;
      }
      final id = 'auto-notification-${stableNotificationKey(fingerprint)}';
      final request = QuickBookkeepingRequest(
        transactionId: id,
        bookId: target.bookId,
        type: _transactionTypeForNotification(parsed.transactionType),
        amount: parsed.amount,
        accountId: target.accountId,
        occurredAt: parsed.occurredAt,
        categoryId: null,
        merchant: parsed.merchant,
        note: parsed.note ?? '支付通知自动记账',
        source: TransactionSource.auto,
        metadata: {
          'autoType': 'paymentNotification',
          'notificationKey': notificationKey,
          'paymentFingerprint': fingerprint,
          'notificationOrderId': parsed.orderId,
          'paymentPackageName': notification.packageName,
          'transactionType': parsed.transactionType,
          if (parsed.identifierSuffix != null)
            'accountIdentifierSuffix': parsed.identifierSuffix,
          if (parsed.originalAmount != null)
            'originalAmountInCents': (parsed.originalAmount! * 100).round(),
          if (parsed.discountAmount != null)
            'discountAmountInCents': (parsed.discountAmount! * 100).round(),
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
          fingerprint,
        )) {
          rethrow;
        }
        duplicates++;
        acknowledged.add(notification.id);
      }
    }
    await bridge.acknowledge(acknowledged);
    await BookkeepingFeedback.notifySuccess(count: created);
    return NotificationAutoBookkeepingSummary(
      created: created,
      duplicates: duplicates,
      unrecognized: unrecognized,
      waiting: waiting,
      queued: queued,
    );
  }

  Future<bool> _isAlreadyHandled(
    String notificationKey,
    String? orderId,
    String packageName,
    String fingerprint,
  ) async {
    if (alreadyHandledFingerprint != null &&
        await alreadyHandledFingerprint!(fingerprint)) {
      return true;
    }
    if (alreadyHandled != null) {
      return alreadyHandled!(notificationKey, orderId, packageName);
    }
    return await _findExisting(notificationKey, orderId, fingerprint) != null;
  }

  Future<TransactionRecord?> _findExisting(
    String notificationKey,
    String? orderId,
    String fingerprint,
  ) async {
    for (final transaction in await transactions.getAll()) {
      final raw = transaction.metadataJson;
      if (raw == null || raw.isEmpty) continue;
      try {
        final value = jsonDecode(raw);
        if (value is Map &&
            (value['notificationKey'] == notificationKey ||
                value['paymentFingerprint'] == fingerprint ||
                (orderId != null && value['notificationOrderId'] == orderId))) {
          return transaction;
        }
      } on FormatException {
        // Ignore malformed metadata that cannot describe an automatic event.
      }
    }
    return null;
  }

  String _notificationFingerprint(
    PaymentNotification notification,
    ParsedPaymentNotification parsed,
  ) {
    final order = parsed.orderId;
    if (order != null && order.isNotEmpty) {
      return '${notification.packageName}|${parsed.transactionType}|order|$order';
    }
    final merchant = (parsed.merchant ?? '').trim().toLowerCase();
    final minute = parsed.occurredAt.millisecondsSinceEpoch ~/ 60000;
    return '${notification.packageName}|${parsed.transactionType}|${parsed.amount.toStringAsFixed(2)}|$merchant|$minute';
  }
}

TransactionType _transactionTypeForNotification(String value) => switch (value) {
  'INCOME' => TransactionType.income,
  'REFUND' => TransactionType.refund,
  'REIMBURSEMENT' => TransactionType.reimbursement,
  _ => TransactionType.expense,
};

String _sourceApp(String channel) => switch (channel) {
  SeedIds.wechatAccount => 'WECHAT',
  SeedIds.alipayAccount => 'ALIPAY',
  SeedIds.bankAccount => 'UNIONPAY',
  'meituan' => 'MEITUAN',
  'jd' => 'JD',
  'pinduoduo' => 'PINDUODUO',
  'douyin' => 'DOUYIN',
  _ => 'PAYMENT_APP',
};

String _displayPaymentMethod(String channel) => switch (channel) {
  SeedIds.wechatAccount => '微信支付',
  SeedIds.alipayAccount => '支付宝',
  SeedIds.bankAccount => '云闪付',
  'meituan' => '美团支付',
  'jd' => '京东支付',
  'pinduoduo' => '拼多多支付',
  'douyin' => '抖音支付',
  _ => '支付应用',
};

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
        resolveTarget: (channel, identifierSuffix) async {
          final database = ref.read(databaseProvider);
          final book =
              await settings.get(notificationTargetBookKey) ??
              SeedIds.personalBook;
          final accessible = await ref
              .read(bookRepositoryProvider)
              .getForUser(SeedIds.localUser);
          if (!accessible.any((b) => b.id == book)) return null;
          if (identifierSuffix != null) {
            final candidates =
                (await database.accountDao.getActive(bookId: book)).where(
                  (account) =>
                      _notificationTypes(channel)
                          .contains(AccountType.values.byName(account.type)) &&
                      account.identifierSuffix == identifierSuffix,
                );
            if (candidates.length != 1) return null;
            return (bookId: book, accountId: candidates.single.id);
          }
          final accountId =
              await settings.get(notificationAccountKey(book, channel)) ??
              (book == SeedIds.personalBook &&
                      !const {'meituan', 'jd', 'pinduoduo', 'douyin'}
                          .contains(channel)
                  ? channel
                  : null);
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
        alreadyHandledFingerprint: (fingerprint) async {
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
            try {
              final metadata = jsonDecode(raw);
              if (metadata is Map &&
                  metadata['paymentFingerprint'] == fingerprint) {
                return true;
              }
            } on FormatException {
              continue;
            }
          }
          return false;
        },
        bridge: ref.watch(paymentNotificationBridgeProvider),
        pendingBridge: ref.watch(autoBookkeepingPendingBridgeProvider),
        transactions: notificationTransactions,
        bookkeeping: QuickBookkeepingService(
          notificationTransactions,
          settings,
          activeBookId: () => ref.read(activeBookIdProvider),
        ),
      );
    });

Set<AccountType> _notificationTypes(String channel) => switch (channel) {
  SeedIds.wechatAccount => {AccountType.wechat},
  SeedIds.alipayAccount => {AccountType.alipay},
  SeedIds.bankAccount => {AccountType.debitCard, AccountType.creditCard},
  'meituan' || 'jd' || 'pinduoduo' || 'douyin' => {
    AccountType.wechat,
    AccountType.alipay,
    AccountType.debitCard,
    AccountType.creditCard,
    AccountType.other,
  },
  _ => const {},
};

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

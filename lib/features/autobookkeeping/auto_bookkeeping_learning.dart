import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/database_seeder.dart';
import '../../core/models/transaction_intelligence.dart';
import '../../core/models/transaction_record.dart';
import '../intelligence/data/merchant_rule_repository.dart';
import '../intelligence/domain/merchant_classification_service.dart';
import '../settings/data/app_settings_repository.dart';
import 'auto_bookkeeping_pending.dart';

class AutoBookkeepingRecommendation {
  const AutoBookkeepingRecommendation({
    this.bookId,
    this.accountId,
    this.categoryId,
    this.subcategoryId,
    this.tags = const [],
    this.useCount = 0,
    this.categorySource = ClassificationSource.pending,
  });

  final String? bookId;
  final String? accountId;
  final String? categoryId;
  final String? subcategoryId;
  final List<String> tags;
  final int useCount;
  final ClassificationSource categorySource;

  bool get learnedFromMerchant => useCount > 0;
}

class AutoBookkeepingLearningService {
  AutoBookkeepingLearningService(
    this._settings,
    this._merchantRules, {
    this.normalizer = const MerchantNormalizer(),
  });

  static const preferenceKey = 'autobookkeeping.preferences.v1';
  static const accountMappingKey = 'autobookkeeping.accounts.v1';

  final AppSettingsRepository _settings;
  final MerchantRuleRepository _merchantRules;
  final MerchantNormalizer normalizer;

  Future<AutoBookkeepingRecommendation> recommend({
    required PendingAutoBookkeepingCandidate candidate,
    required String fallbackBookId,
    required TransactionType transactionType,
  }) async {
    final merchantKey = normalizer.normalize(candidate.merchant);
    final typedKey = _typedMerchantKey(transactionType, merchantKey);
    final preferences = await _jsonMap(preferenceKey);
    final rawPreference = _map(preferences[typedKey]);

    final rememberedBook = _text(rawPreference?['bookId']);
    final targetBook = rememberedBook ?? fallbackBookId;
    final rememberedAccount = _text(rawPreference?['accountId']);
    final rememberedCategory = _text(rawPreference?['categoryId']);
    final rememberedSubcategory = _text(rawPreference?['subcategoryId']);
    final tags = _stringList(rawPreference?['tags']);
    final useCount = (rawPreference?['useCount'] as num?)?.toInt() ?? 0;

    final classification = await _merchantRules.classify(
      merchant: candidate.merchant,
      userId: SeedIds.localUser,
      transactionType: transactionType,
      bookId: targetBook,
    );

    var accountId = rememberedAccount;
    if (accountId == null && candidate.paymentMethod != 'UNKNOWN') {
      final mappings = await _jsonMap(accountMappingKey);
      accountId = _text(mappings['$targetBook|${candidate.paymentMethod}']);
    }

    return AutoBookkeepingRecommendation(
      bookId: targetBook,
      accountId: accountId,
      categoryId: rememberedCategory ?? classification.categoryId,
      subcategoryId: rememberedSubcategory ?? classification.subcategoryId,
      tags: tags,
      useCount: useCount,
      categorySource: rememberedCategory != null
          ? ClassificationSource.personalRule
          : classification.source,
    );
  }

  Future<void> remember({
    required String transactionId,
    required PendingAutoBookkeepingCandidate candidate,
    required String bookId,
    required String accountId,
    required String categoryId,
    String? subcategoryId,
    List<String> tags = const [],
    required bool rememberForMerchant,
  }) async {
    if (!rememberForMerchant) return;

    final transactionType = _transactionType(candidate.transactionType);
    if (transactionType == TransactionType.expense) {
      await _merchantRules.correctTransaction(
        transactionId: transactionId,
        categoryId: categoryId,
        subcategoryId: subcategoryId,
        rememberForMerchant: true,
      );
    }

    final merchantKey = normalizer.normalize(candidate.merchant);
    if (merchantKey.isEmpty) return;

    final typedKey = _typedMerchantKey(transactionType, merchantKey);
    final preferences = await _jsonMap(preferenceKey);
    final previous = _map(preferences[typedKey]);
    preferences[typedKey] = {
      'merchantKey': merchantKey,
      'transactionType': transactionType.name,
      'merchantDisplay': candidate.merchant,
      'categoryId': categoryId,
      'subcategoryId': ?subcategoryId,
      'accountId': accountId,
      'bookId': bookId,
      'tags': tags,
      'useCount': ((previous?['useCount'] as num?)?.toInt() ?? 0) + 1,
      'lastUsedAt': DateTime.now().millisecondsSinceEpoch,
    };
    await _settings.set(preferenceKey, jsonEncode(preferences));

    if (candidate.paymentMethod != 'UNKNOWN') {
      final mappings = await _jsonMap(accountMappingKey);
      mappings['$bookId|${candidate.paymentMethod}'] = accountId;
      await _settings.set(accountMappingKey, jsonEncode(mappings));
    }
  }

  String _typedMerchantKey(
    TransactionType type,
    String merchantKey,
  ) => '${type.name}|$merchantKey';

  TransactionType _transactionType(String value) => switch (value) {
    'INCOME' => TransactionType.income,
    'REFUND' => TransactionType.refund,
    'REIMBURSEMENT' => TransactionType.reimbursement,
    _ => TransactionType.expense,
  };

  Future<Map<String, dynamic>> _jsonMap(String key) async {
    final raw = await _settings.get(key);
    if (raw == null || raw.trim().isEmpty) return <String, dynamic>{};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return decoded.map(
          (key, value) => MapEntry(key.toString(), value),
        );
      }
    } on FormatException {
      // Corrupt optional learning data should never block bookkeeping.
    }
    return <String, dynamic>{};
  }

  Map<String, dynamic>? _map(Object? value) {
    if (value is! Map) return null;
    return value.map((key, item) => MapEntry(key.toString(), item));
  }

  String? _text(Object? value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }

  List<String> _stringList(Object? value) =>
      value is List
          ? value
                .map((item) => item.toString().trim())
                .where((item) => item.isNotEmpty)
                .toList(growable: false)
          : const [];
}

final autoBookkeepingLearningServiceProvider =
    Provider<AutoBookkeepingLearningService>((ref) {
      return AutoBookkeepingLearningService(
        ref.watch(appSettingsRepositoryProvider),
        ref.watch(merchantRuleRepositoryProvider),
      );
    });

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/account.dart';
import '../intelligence/domain/merchant_classification_service.dart';
import '../settings/data/app_settings_repository.dart';
import 'auto_bookkeeping_pending.dart';

enum AutoBookkeepingRepaymentEvidence {
  none,
  targetIdentifierSuffix,
  learnedDestination,
}

class AutoBookkeepingRepaymentRecommendation {
  const AutoBookkeepingRepaymentRecommendation({
    this.destinationAccountId,
    this.evidence = AutoBookkeepingRepaymentEvidence.none,
  });

  final String? destinationAccountId;
  final AutoBookkeepingRepaymentEvidence evidence;

  bool get hasDestination => destinationAccountId != null;
}

class AutoBookkeepingRepaymentResolver {
  AutoBookkeepingRepaymentResolver(
    this._settings, {
    this.normalizer = const MerchantNormalizer(),
  });

  static const preferenceKey = 'autobookkeeping.repayment_destinations.v1';

  final AppSettingsRepository _settings;
  final MerchantNormalizer normalizer;

  Future<AutoBookkeepingRepaymentRecommendation> recommend({
    required PendingAutoBookkeepingCandidate candidate,
    required String bookId,
    required List<Account> accounts,
    required String? sourceAccountId,
  }) async {
    if (candidate.transactionType != 'REPAYMENT') {
      return const AutoBookkeepingRepaymentRecommendation();
    }

    final debtAccounts = accounts
        .where(
          (account) =>
              account.id != sourceAccountId &&
              (account.type == AccountType.creditCard ||
                  account.type == AccountType.liability),
        )
        .toList(growable: false);

    final targetSuffix = candidate.targetIdentifierSuffix?.trim();
    if (targetSuffix != null && targetSuffix.isNotEmpty) {
      final matches = debtAccounts
          .where((account) => account.identifierSuffix == targetSuffix)
          .toList(growable: false);
      if (matches.length == 1) {
        return AutoBookkeepingRepaymentRecommendation(
          destinationAccountId: matches.single.id,
          evidence: AutoBookkeepingRepaymentEvidence.targetIdentifierSuffix,
        );
      }
    }

    final merchantKey = normalizer.normalize(candidate.merchant);
    if (merchantKey.isEmpty) {
      return const AutoBookkeepingRepaymentRecommendation();
    }
    final preferences = await _jsonMap();
    final learnedId = _text(preferences[_key(bookId, merchantKey)]);
    if (learnedId != null &&
        debtAccounts.any((account) => account.id == learnedId)) {
      return AutoBookkeepingRepaymentRecommendation(
        destinationAccountId: learnedId,
        evidence: AutoBookkeepingRepaymentEvidence.learnedDestination,
      );
    }

    return const AutoBookkeepingRepaymentRecommendation();
  }

  Future<void> remember({
    required PendingAutoBookkeepingCandidate candidate,
    required String bookId,
    required String destinationAccountId,
    required bool remember,
  }) async {
    if (!remember || candidate.transactionType != 'REPAYMENT') return;
    final merchantKey = normalizer.normalize(candidate.merchant);
    if (merchantKey.isEmpty) return;

    final preferences = await _jsonMap();
    preferences[_key(bookId, merchantKey)] = destinationAccountId;
    await _settings.set(preferenceKey, jsonEncode(preferences));
  }

  Future<Map<String, dynamic>> _jsonMap() async {
    final raw = await _settings.get(preferenceKey);
    if (raw == null || raw.trim().isEmpty) return <String, dynamic>{};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return decoded.map(
          (key, value) => MapEntry(key.toString(), value),
        );
      }
    } on FormatException {
      // Optional learning data must never block confirmation.
    }
    return <String, dynamic>{};
  }

  String _key(String bookId, String merchantKey) => '$bookId|$merchantKey';

  String? _text(Object? value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }
}

final autoBookkeepingRepaymentResolverProvider =
    Provider<AutoBookkeepingRepaymentResolver>((ref) {
      return AutoBookkeepingRepaymentResolver(
        ref.watch(appSettingsRepositoryProvider),
      );
    });

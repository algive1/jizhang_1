import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/account.dart';
import '../intelligence/domain/merchant_classification_service.dart';
import '../settings/data/app_settings_repository.dart';
import 'auto_bookkeeping_pending.dart';

enum AutoBookkeepingTransferEvidence {
  none,
  targetIdentifierSuffix,
  learnedDestination,
}

class AutoBookkeepingTransferRecommendation {
  const AutoBookkeepingTransferRecommendation({
    this.destinationAccountId,
    this.evidence = AutoBookkeepingTransferEvidence.none,
  });

  final String? destinationAccountId;
  final AutoBookkeepingTransferEvidence evidence;

  bool get suggestsInternalTransfer => destinationAccountId != null;
}

class AutoBookkeepingTransferResolver {
  AutoBookkeepingTransferResolver(
    this._settings, {
    this.normalizer = const MerchantNormalizer(),
  });

  static const preferenceKey = 'autobookkeeping.transfer_destinations.v1';

  final AppSettingsRepository _settings;
  final MerchantNormalizer normalizer;

  Future<AutoBookkeepingTransferRecommendation> recommend({
    required PendingAutoBookkeepingCandidate candidate,
    required String bookId,
    required List<Account> accounts,
    required String? sourceAccountId,
  }) async {
    if (candidate.transactionType != 'TRANSFER') {
      return const AutoBookkeepingTransferRecommendation();
    }

    final targetSuffix = candidate.targetIdentifierSuffix?.trim();
    if (targetSuffix != null && targetSuffix.isNotEmpty) {
      final matches = accounts
          .where(
            (account) =>
                account.id != sourceAccountId &&
                account.identifierSuffix == targetSuffix,
          )
          .toList(growable: false);
      if (matches.length == 1) {
        return AutoBookkeepingTransferRecommendation(
          destinationAccountId: matches.single.id,
          evidence: AutoBookkeepingTransferEvidence.targetIdentifierSuffix,
        );
      }
    }

    final merchantKey = normalizer.normalize(candidate.merchant);
    if (merchantKey.isEmpty) {
      return const AutoBookkeepingTransferRecommendation();
    }
    final preferences = await _jsonMap();
    final key = _key(bookId, merchantKey);
    final learnedId = _text(preferences[key]);
    if (learnedId != null &&
        learnedId != sourceAccountId &&
        accounts.any((account) => account.id == learnedId)) {
      return AutoBookkeepingTransferRecommendation(
        destinationAccountId: learnedId,
        evidence: AutoBookkeepingTransferEvidence.learnedDestination,
      );
    }

    return const AutoBookkeepingTransferRecommendation();
  }

  Future<void> rememberDecision({
    required PendingAutoBookkeepingCandidate candidate,
    required String bookId,
    required bool internalTransfer,
    required String? destinationAccountId,
    required bool remember,
  }) async {
    if (!remember || candidate.transactionType != 'TRANSFER') return;
    final merchantKey = normalizer.normalize(candidate.merchant);
    if (merchantKey.isEmpty) return;

    final preferences = await _jsonMap();
    final key = _key(bookId, merchantKey);
    if (internalTransfer && destinationAccountId != null) {
      preferences[key] = destinationAccountId;
    } else {
      preferences.remove(key);
    }
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

final autoBookkeepingTransferResolverProvider =
    Provider<AutoBookkeepingTransferResolver>((ref) {
      return AutoBookkeepingTransferResolver(
        ref.watch(appSettingsRepositoryProvider),
      );
    });

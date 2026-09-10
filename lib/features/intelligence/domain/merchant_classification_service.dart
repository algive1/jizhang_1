import '../../../core/models/transaction_intelligence.dart';

class MerchantNormalizer {
  const MerchantNormalizer();

  String normalize(String? merchant) {
    var value = (merchant ?? '').trim().toLowerCase();
    for (final prefix in const ['支付宝', '微信支付', '财付通', '银联']) {
      if (value.startsWith(prefix)) value = value.substring(prefix.length);
    }
    return value
        .replaceAll(RegExp(r'[\s\-_·•（）()【】\[\].,，。]+'), '')
        .replaceAll('有限公司', '')
        .replaceAll('旗舰店', '');
  }
}

class MerchantClassificationService {
  const MerchantClassificationService({
    this.normalizer = const MerchantNormalizer(),
  });

  final MerchantNormalizer normalizer;

  ClassificationResult classify({
    required String? merchant,
    required List<MerchantRule> rules,
    required String? userId,
    String? defaultCategoryId,
  }) {
    final normalized = normalizer.normalize(merchant);
    if (normalized.isNotEmpty) {
      final personal = _first(
        rules,
        (rule) =>
            rule.source == MerchantRuleSource.userCorrection &&
            rule.userId == userId &&
            _matches(rule, normalized),
      );
      if (personal != null) {
        return _result(personal, ClassificationSource.personalRule);
      }

      final exact = _first(
        rules,
        (rule) =>
            rule.source == MerchantRuleSource.exactMerchant &&
            rule.matchType == MerchantRuleMatchType.exact &&
            _matches(rule, normalized),
      );
      if (exact != null) {
        return _result(exact, ClassificationSource.exactMerchant);
      }

      final keyword = _first(
        rules,
        (rule) =>
            rule.source == MerchantRuleSource.keyword &&
            rule.matchType == MerchantRuleMatchType.keyword &&
            _matches(rule, normalized),
      );
      if (keyword != null) {
        return _result(keyword, ClassificationSource.keyword);
      }
    }

    if (defaultCategoryId != null) {
      return ClassificationResult(
        categoryId: defaultCategoryId,
        source: ClassificationSource.defaultCategory,
        confidence: .35,
      );
    }
    return const ClassificationResult(
      source: ClassificationSource.pending,
      confidence: 0,
    );
  }

  MerchantRule? _first(
    List<MerchantRule> rules,
    bool Function(MerchantRule rule) test,
  ) {
    for (final rule in rules) {
      if (test(rule)) return rule;
    }
    return null;
  }

  bool _matches(MerchantRule rule, String merchant) {
    return switch (rule.matchType) {
      MerchantRuleMatchType.exact => merchant == rule.normalizedPattern,
      MerchantRuleMatchType.keyword => merchant.contains(
        rule.normalizedPattern,
      ),
    };
  }

  ClassificationResult _result(MerchantRule rule, ClassificationSource source) {
    return ClassificationResult(
      categoryId: rule.categoryId,
      subcategoryId: rule.subcategoryId,
      source: source,
      confidence: rule.confidence,
      matchedRuleId: rule.id,
    );
  }
}

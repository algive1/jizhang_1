enum BookkeepingIntent {
  controlSpending,
  understandSpending,
  saveForGoal,
  optimizeFinances,
  familyFinances,
  improveHabits,
  recordLife,
}

extension BookkeepingIntentLabel on BookkeepingIntent {
  String get label => switch (this) {
    BookkeepingIntent.controlSpending => '控制消费',
    BookkeepingIntent.understandSpending => '看懂消费',
    BookkeepingIntent.saveForGoal => '存钱 / 达成目标',
    BookkeepingIntent.optimizeFinances => '优化财务',
    BookkeepingIntent.familyFinances => '家庭财务',
    BookkeepingIntent.improveHabits => '改善生活习惯',
    BookkeepingIntent.recordLife => '记录生活',
  };
}

enum InsightFocus {
  dining,
  shopping,
  travel,
  healthHabits,
  savings,
  credit,
  family,
  learning,
}

extension InsightFocusLabel on InsightFocus {
  String get label => switch (this) {
    InsightFocus.dining => '餐饮',
    InsightFocus.shopping => '购物',
    InsightFocus.travel => '旅行',
    InsightFocus.healthHabits => '身材 / 健康习惯',
    InsightFocus.savings => '储蓄',
    InsightFocus.credit => '信用账户',
    InsightFocus.family => '家庭支出',
    InsightFocus.learning => '学习成长',
  };
}

enum InsightTone { strict, balanced, quiet }

extension InsightToneLabel on InsightTone {
  String get label => switch (this) {
    InsightTone.strict => '严格一点',
    InsightTone.balanced => '平衡一点',
    InsightTone.quiet => '少打扰我',
  };
}

enum FinancialInsightKind {
  financial,
  behavior,
  risk,
  goal,
  discovery,
  positive,
  life,
}

extension FinancialInsightKindLabel on FinancialInsightKind {
  String get label => switch (this) {
    FinancialInsightKind.financial => '财务',
    FinancialInsightKind.behavior => '习惯',
    FinancialInsightKind.risk => '提醒',
    FinancialInsightKind.goal => '目标',
    FinancialInsightKind.discovery => '发现',
    FinancialInsightKind.positive => '好变化',
    FinancialInsightKind.life => '生活',
  };
}

enum InsightResponse { notice, advice, encouragement, record }

enum InsightPriority { info, attention, important, critical }

enum InsightOrigin { local, serverConfirmed }

class InsightConfidence {
  const InsightConfidence({
    required this.data,
    required this.completeness,
    required this.classification,
    required this.baseline,
  });

  final double data;
  final double completeness;
  final double classification;
  final double baseline;

  double get overall =>
      (data * .30 + completeness * .25 + classification * .20 + baseline * .25)
          .clamp(0, 1)
          .toDouble();

  InsightConfidence copyWith({double? baseline}) => InsightConfidence(
        data: data,
        completeness: completeness,
        classification: classification,
        baseline: baseline ?? this.baseline,
      );
}

class InsightEvidence {
  const InsightEvidence({
    required this.label,
    required this.value,
    this.baselineValue,
    this.unit,
    this.note,
    this.transactionIds = const [],
  });

  final String label;
  final double value;
  final double? baselineValue;
  final String? unit;
  final String? note;
  final List<String> transactionIds;

  factory InsightEvidence.fromJson(Map<String, dynamic> json) =>
      InsightEvidence(
        label: json['label'] as String? ?? '',
        value: (json['value'] as num?)?.toDouble() ?? 0,
        baselineValue: (json['baselineValue'] as num?)?.toDouble(),
        unit: json['unit'] as String?,
        note: json['note'] as String?,
        transactionIds: (json['transactionIds'] as List? ?? const [])
            .whereType<String>()
            .toList(growable: false),
      );
}

class FinancialInsightItem {
  const FinancialInsightItem({
    required this.id,
    required this.kind,
    required this.priority,
    required this.title,
    required this.summary,
    required this.analysis,
    required this.meaning,
    required this.response,
    required this.score,
    required this.confidence,
    required this.generatedAt,
    this.suggestion,
    this.actionLabel,
    this.actionRoute,
    this.categoryId,
    this.amount,
    this.changePercent,
    this.evidence = const [],
    this.relatedTransactionIds = const [],
    this.aiInterpretation,
  });

  final String id;
  final FinancialInsightKind kind;
  final InsightPriority priority;
  final String title;
  final String summary;
  final String analysis;
  final String meaning;
  final InsightResponse response;
  final double score;
  final InsightConfidence confidence;
  final DateTime generatedAt;
  final String? suggestion;
  final String? actionLabel;
  final String? actionRoute;
  final String? categoryId;
  final double? amount;
  final double? changePercent;
  final List<InsightEvidence> evidence;
  final List<String> relatedTransactionIds;
  final String? aiInterpretation;

  bool get isImportant =>
      priority == InsightPriority.important ||
      priority == InsightPriority.critical;

  factory FinancialInsightItem.fromJson(Map<String, dynamic> json) {
    T enumValue<T extends Enum>(List<T> values, Object? raw, T fallback) {
      for (final value in values) {
        if (value.name == raw) return value;
      }
      return fallback;
    }

    final confidenceJson =
        (json['confidence'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};
    return FinancialInsightItem(
      id: json['id'] as String? ?? '',
      kind: enumValue(
        FinancialInsightKind.values,
        json['kind'],
        FinancialInsightKind.discovery,
      ),
      priority: enumValue(
        InsightPriority.values,
        json['priority'],
        InsightPriority.info,
      ),
      title: json['title'] as String? ?? '',
      summary: json['summary'] as String? ?? '',
      analysis: json['analysis'] as String? ?? '',
      meaning: json['meaning'] as String? ?? '',
      response: enumValue(
        InsightResponse.values,
        json['response'],
        InsightResponse.notice,
      ),
      score: (json['score'] as num?)?.toDouble() ?? 0,
      confidence: InsightConfidence(
        data: (confidenceJson['data'] as num?)?.toDouble() ?? 0,
        completeness:
            (confidenceJson['completeness'] as num?)?.toDouble() ?? 0,
        classification:
            (confidenceJson['classification'] as num?)?.toDouble() ?? 0,
        baseline: (confidenceJson['baseline'] as num?)?.toDouble() ?? 0,
      ),
      generatedAt: DateTime.fromMillisecondsSinceEpoch(
        (json['generatedAt'] as num?)?.toInt() ?? 0,
      ),
      suggestion: json['suggestion'] as String?,
      actionLabel: json['actionLabel'] as String?,
      actionRoute: json['actionRoute'] as String?,
      categoryId: json['categoryId'] as String?,
      amount: (json['amount'] as num?)?.toDouble(),
      changePercent: (json['changePercent'] as num?)?.toDouble(),
      evidence: (json['evidence'] as List? ?? const [])
          .whereType<Map>()
          .map(
            (value) =>
                InsightEvidence.fromJson(value.cast<String, dynamic>()),
          )
          .toList(growable: false),
      relatedTransactionIds:
          (json['relatedTransactionIds'] as List? ?? const [])
              .whereType<String>()
              .toList(growable: false),
      aiInterpretation: json['aiInterpretation'] as String?,
    );
  }
}

class InsightFeed {
  const InsightFeed({
    required this.items,
    required this.dataConfidence,
    required this.completeness,
    required this.classificationConfidence,
    required this.baselineConfidence,
    this.origin = InsightOrigin.local,
    this.confirmedAt,
  });

  final List<FinancialInsightItem> items;
  final double dataConfidence;
  final double completeness;
  final double classificationConfidence;
  final double baselineConfidence;
  final InsightOrigin origin;
  final DateTime? confirmedAt;

  bool get isServerConfirmed => origin == InsightOrigin.serverConfirmed;

  FinancialInsightItem? get homeCandidate {
    for (final item in items) {
      if (item.score >= 70 && item.confidence.overall >= .55) return item;
    }
    return null;
  }

  factory InsightFeed.fromJson(Map<String, dynamic> json) {
    return InsightFeed(
      items: (json['items'] as List? ?? const [])
          .whereType<Map>()
          .map(
            (value) =>
                FinancialInsightItem.fromJson(value.cast<String, dynamic>()),
          )
          .toList(growable: false),
      dataConfidence: (json['dataConfidence'] as num?)?.toDouble() ?? 0,
      completeness: (json['completeness'] as num?)?.toDouble() ?? 0,
      classificationConfidence:
          (json['classificationConfidence'] as num?)?.toDouble() ?? 0,
      baselineConfidence:
          (json['baselineConfidence'] as num?)?.toDouble() ?? 0,
      origin: json['origin'] == 'serverConfirmed'
          ? InsightOrigin.serverConfirmed
          : InsightOrigin.local,
      confirmedAt: json['confirmedAt'] is num
          ? DateTime.fromMillisecondsSinceEpoch(
              (json['confirmedAt'] as num).toInt(),
            )
          : null,
    );
  }
}

class InsightPreferences {
  const InsightPreferences({
    this.intents = const {},
    this.focus = const {},
    this.tone = InsightTone.balanced,
    this.configured = false,
    this.dismissedIds = const {},
    this.kindAdjustments = const {},
  });

  final Set<BookkeepingIntent> intents;
  final Set<InsightFocus> focus;
  final InsightTone tone;
  final bool configured;
  final Set<String> dismissedIds;
  final Map<FinancialInsightKind, double> kindAdjustments;

  InsightPreferences copyWith({
    Set<BookkeepingIntent>? intents,
    Set<InsightFocus>? focus,
    InsightTone? tone,
    bool? configured,
    Set<String>? dismissedIds,
    Map<FinancialInsightKind, double>? kindAdjustments,
  }) {
    return InsightPreferences(
      intents: intents ?? this.intents,
      focus: focus ?? this.focus,
      tone: tone ?? this.tone,
      configured: configured ?? this.configured,
      dismissedIds: dismissedIds ?? this.dismissedIds,
      kindAdjustments: kindAdjustments ?? this.kindAdjustments,
    );
  }
}

class BudgetRecommendation {
  const BudgetRecommendation({
    required this.recommended,
    required this.rangeMin,
    required this.rangeMax,
    required this.maintain,
    required this.moderateControl,
    required this.activeSaving,
    required this.historicalMedian,
    required this.confidence,
    required this.reason,
  });

  final double recommended;
  final double rangeMin;
  final double rangeMax;
  final double maintain;
  final double moderateControl;
  final double activeSaving;
  final double historicalMedian;
  final double confidence;
  final String reason;
}

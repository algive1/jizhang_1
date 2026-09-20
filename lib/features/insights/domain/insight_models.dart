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

  bool get isImportant =>
      priority == InsightPriority.important ||
      priority == InsightPriority.critical;
}

class InsightFeed {
  const InsightFeed({
    required this.items,
    required this.dataConfidence,
    required this.completeness,
    required this.classificationConfidence,
    required this.baselineConfidence,
  });

  final List<FinancialInsightItem> items;
  final double dataConfidence;
  final double completeness;
  final double classificationConfidence;
  final double baselineConfidence;

  FinancialInsightItem? get homeCandidate {
    for (final item in items) {
      if (item.score >= 70 && item.confidence.overall >= .55) return item;
    }
    return null;
  }
}

class InsightPreferences {
  const InsightPreferences({
    this.intents = const {},
    this.focus = const {},
    this.tone = InsightTone.balanced,
    this.configured = false,
    this.dismissedIds = const {},
  });

  final Set<BookkeepingIntent> intents;
  final Set<InsightFocus> focus;
  final InsightTone tone;
  final bool configured;
  final Set<String> dismissedIds;

  InsightPreferences copyWith({
    Set<BookkeepingIntent>? intents,
    Set<InsightFocus>? focus,
    InsightTone? tone,
    bool? configured,
    Set<String>? dismissedIds,
  }) {
    return InsightPreferences(
      intents: intents ?? this.intents,
      focus: focus ?? this.focus,
      tone: tone ?? this.tone,
      configured: configured ?? this.configured,
      dismissedIds: dismissedIds ?? this.dismissedIds,
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

import 'dart:math' as math;

import '../../../core/models/account.dart';
import '../../../core/models/analysis.dart';
import '../../../core/models/budget.dart';
import '../../../core/models/transaction_record.dart';
import 'insight_models.dart';

class FinancialInsightEngine {
  const FinancialInsightEngine();

  InsightFeed build({
    required List<TransactionRecord> transactions,
    required AnalysisSnapshot analysis,
    required BudgetOverview budgets,
    required List<Account> accounts,
    required InsightPreferences preferences,
    DateTime? now,
  }) {
    final clock = now ?? DateTime.now();
    final eligible = transactions
        .where(
          (item) =>
              item.deletedAt == null &&
              !item.occurredAt.isAfter(clock) &&
              item.currency.toUpperCase() == analysis.currency.toUpperCase(),
        )
        .toList(growable: false);
    final expenses = eligible
        .where((item) => item.isConsumptionExpense)
        .toList(growable: false);
    final quality = _quality(expenses, clock);
    final candidates = <FinancialInsightItem>[];

    if (quality.baseline >= .35) {
      for (final source in analysis.insights) {
        candidates.add(_fromAnalysis(source, preferences, quality));
      }
      final positive = _positiveChange(
        analysis,
        preferences,
        quality,
        clock,
      );
      if (positive != null) candidates.add(positive);
    }

    final budget = _budgetInsight(
      budgets.total,
      preferences,
      quality,
      clock,
    );
    if (budget != null) candidates.add(budget);

    final credit = _creditInsight(
      accounts,
      preferences,
      quality,
      clock,
    );
    if (credit != null) candidates.add(credit);

    final family = _familyInsight(
      eligible,
      preferences,
      quality,
      clock,
    );
    if (family != null) candidates.add(family);

    final beauty = _beautyInsight(
      expenses,
      preferences,
      quality,
      clock,
    );
    if (beauty != null) candidates.add(beauty);

    final reimbursement = _reimbursementInsight(
      expenses,
      preferences,
      quality,
      clock,
    );
    if (reimbursement != null) candidates.add(reimbursement);

    if (quality.classification < .68 && expenses.length >= 12) {
      candidates.add(
        _item(
          id: 'data:classification',
          kind: FinancialInsightKind.discovery,
          priority: InsightPriority.attention,
          title: '有些分类值得先校正',
          summary: '当前部分流水的分类可信度偏低，先把账分准，后面的消费结论才可靠。',
          analysis: '系统发现未分类、低置信度分类或疑似重复记录占比偏高。',
          meaning: '这类问题会直接影响餐饮、购物等分类占比和趋势判断。',
          response: InsightResponse.advice,
          suggestion: '建议先检查最近的未分类和自动识别流水。',
          actionLabel: '检查分类',
          actionRoute: '/profile/categories',
          baseScore: 72,
          preferences: preferences,
          confidence: quality,
          generatedAt: clock,
        ),
      );
    }

    final deduped = <String, FinancialInsightItem>{};
    for (final item in candidates) {
      final existing = deduped[item.id];
      if (existing == null || item.score > existing.score) {
        deduped[item.id] = item;
      }
    }
    final items = deduped.values
        .where((item) => !preferences.dismissedIds.contains(item.id))
        .where((item) => item.confidence.overall >= .38)
        .toList()
      ..sort((a, b) => b.score.compareTo(a.score));

    return InsightFeed(
      items: items,
      dataConfidence: quality.data,
      completeness: quality.completeness,
      classificationConfidence: quality.classification,
      baselineConfidence: quality.baseline,
    );
  }

  FinancialInsightItem _fromAnalysis(
    AnalysisInsight source,
    InsightPreferences preferences,
    InsightConfidence quality,
  ) {
    final priority = switch (source.severity) {
      AnalysisInsightSeverity.info => InsightPriority.info,
      AnalysisInsightSeverity.attention => InsightPriority.attention,
      AnalysisInsightSeverity.important => InsightPriority.important,
    };
    final currentCount = (source.metadata['currentCount'] as num?)?.toDouble();
    final previousCount = (source.metadata['previousCount'] as num?)?.toDouble();
    return _item(
      id: 'analysis:${source.id}',
      kind: FinancialInsightKind.behavior,
      priority: priority,
      title: source.title,
      summary: source.description,
      analysis: _analysisText(source),
      meaning: '这是一项相对你自己上一可比周期的变化，不是拿你和其他用户比较。',
      response: InsightResponse.notice,
      suggestion: switch (source.type) {
        AnalysisInsightType.deliveryIncrease =>
          '如果你正在控制消费，可以先从恢复平时的外卖频率开始。',
        AnalysisInsightType.lateNightIncrease =>
          '可以看看增加主要发生在哪几天，再决定是否需要调整习惯。',
        AnalysisInsightType.weekendIncrease =>
          '可以为周末单独留出可用额度，避免影响整月预算。',
        AnalysisInsightType.categoryIncrease =>
          '建议先确认增加来自次数还是单次金额，再决定是否调整预算。',
      },
      actionLabel: '查看趋势',
      actionRoute: '/analysis',
      categoryId: source.categoryId,
      amount: source.amount,
      changePercent: source.deltaPercent,
      evidence: [
        InsightEvidence(
          label: source.metricName,
          value: source.amount,
          baselineValue: source.baselineAmount,
          unit: source.metricName.contains('金额') ? 'CNY' : null,
        ),
        if (currentCount != null)
          InsightEvidence(
            label: '消费次数',
            value: currentCount,
            baselineValue: previousCount,
            unit: '次',
          ),
      ],
      baseScore: priority == InsightPriority.important ? 76 : 64,
      preferences: preferences,
      confidence: quality,
      generatedAt: source.generatedAt,
    );
  }

  String _analysisText(AnalysisInsight source) {
    return switch (source.reasonCode) {
      'frequency_increase' => '增长主要由消费次数增加带来，单次金额不是主要原因。',
      'average_ticket_increase' => '增长主要由单次消费金额变高带来。',
      'frequency_and_ticket_increase' => '消费次数和单次金额都在推动本期增长。',
      'delivery_frequency_increase' => '增长主要集中在外卖频率，而不是普通堂食。',
      'late_night_frequency_increase' => '增长主要集中在深夜时段的消费次数。',
      _ => '系统根据当前周期与个人历史可比周期进行了归因。',
    };
  }

  FinancialInsightItem? _budgetInsight(
    BudgetProgress? progress,
    InsightPreferences preferences,
    InsightConfidence quality,
    DateTime now,
  ) {
    if (progress == null) return null;
    final lastDay = DateTime(now.year, now.month + 1, 0).day;
    final timeProgress = (now.day / lastDay).clamp(.03, 1.0);
    final usage = progress.percentage;
    final forecast = progress.used / timeProgress;
    final overspend = forecast - progress.budget.amount;
    if (usage - timeProgress < .12 &&
        overspend <= progress.budget.amount * .05) {
      return null;
    }
    final critical = usage > 1 || overspend > progress.budget.amount * .25;
    return _item(
      id: 'budget:${progress.budget.monthKey}:total',
      kind: FinancialInsightKind.risk,
      priority: critical ? InsightPriority.important : InsightPriority.attention,
      title: usage > 1 ? '本月预算已经超出' : '本月预算消耗有点快',
      summary: usage > 1
          ? '本月支出已经超过预算 ¥${progress.budget.amount.toStringAsFixed(0)}。'
          : '本月过去 ${(timeProgress * 100).round()}%，预算已使用 ${(usage * 100).round()}%。',
      analysis:
          '按目前消费速度，月底预计约 ¥${forecast.toStringAsFixed(0)}'
          '${overspend > 0 ? '，比预算高约 ¥${overspend.toStringAsFixed(0)}' : ''}。',
      meaning: '预算控制应该看“消费速度”和“时间进度”，而不是等月底超支后再提醒。',
      response: InsightResponse.advice,
      suggestion: '打开预算可以查看剩余额度和日均可用金额，再决定是否调整接下来的消费节奏。',
      actionLabel: '查看预算',
      actionRoute: '/profile/budgets',
      amount: progress.used,
      changePercent: (usage - timeProgress) * 100,
      evidence: [
        InsightEvidence(label: '预算已使用', value: usage * 100, unit: '%'),
        InsightEvidence(label: '月份已过去', value: timeProgress * 100, unit: '%'),
        InsightEvidence(
          label: '月底预测',
          value: forecast,
          baselineValue: progress.budget.amount,
          unit: 'CNY',
        ),
      ],
      baseScore: critical ? 86 : 74,
      preferences: preferences,
      confidence: quality.copyWith(baseline: math.max(.65, quality.baseline)),
      generatedAt: now,
    );
  }

  FinancialInsightItem? _creditInsight(
    List<Account> accounts,
    InsightPreferences preferences,
    InsightConfidence quality,
    DateTime now,
  ) {
    final credit = accounts
        .where(
          (account) =>
              !account.isArchived &&
              (account.type.isDebt || _looksLikeCredit(account.name)),
        )
        .toList();
    if (credit.length < 2) return null;
    final names = credit.take(3).map((e) => e.name).join('、');
    return _item(
      id: 'accounts:multiple-credit',
      kind: FinancialInsightKind.financial,
      priority: InsightPriority.attention,
      title: '你在使用多个信用 / 后付账户',
      summary: '已识别 ${credit.length} 个信用或负债账户${names.isEmpty ? '' : '：$names'}。',
      analysis: '消费分散在多个待还账户后，只看银行卡余额容易高估真正可用的钱。',
      meaning: '把待还金额和还款日期集中看，会比单独看每张卡更接近真实财务状态。',
      response: InsightResponse.advice,
      suggestion: '建议确认这些账户的待还金额和还款日，避免消费与还款被重复理解成两次支出。',
      actionLabel: '管理账户',
      actionRoute: '/profile/accounts',
      baseScore: 68,
      preferences: preferences,
      confidence: quality.copyWith(baseline: 1),
      generatedAt: now,
    );
  }

  FinancialInsightItem? _familyInsight(
    List<TransactionRecord> records,
    InsightPreferences preferences,
    InsightConfidence quality,
    DateTime now,
  ) {
    final cutoff = now.subtract(const Duration(days: 90));
    final family = records.where((item) {
      if (item.occurredAt.isBefore(cutoff)) return false;
      final text =
          '${item.note ?? ''} ${item.merchant ?? ''} ${item.categoryName ?? ''}';
      return RegExp(r'爸爸|妈妈|父母|家人|家里|爸妈').hasMatch(text);
    }).toList();
    if (family.length < 2) return null;
    final amount = family.fold<double>(
      0,
      (sum, item) =>
          sum + (item.isExpense ? item.netExpenseAmount : item.amount),
    );
    if (amount < 100) return null;
    return _item(
      id: 'life:family-support',
      kind: FinancialInsightKind.life,
      priority: InsightPriority.info,
      title: '家人是你近期支出里很特别的一部分',
      summary: '近 90 天记录到 ${family.length} 笔与父母或家人相关的资金往来。',
      analysis: '这些记录更像家庭支持，不适合简单归为“社交消费变多”。',
      meaning: '钱也在记录生活关系。对这类支出，理解用途比单纯压低金额更重要。',
      response: InsightResponse.encouragement,
      suggestion: '如果这是稳定支持，可以单独设为家庭预算，让其他消费分析更准确。',
      actionLabel: '查看流水',
      actionRoute: '/transactions',
      amount: amount,
      relatedTransactionIds: family.map((e) => e.id).toList(),
      evidence: [
        InsightEvidence(
          label: '家庭相关记录',
          value: family.length.toDouble(),
          unit: '笔',
          transactionIds: family.map((e) => e.id).toList(),
        ),
        InsightEvidence(label: '涉及金额', value: amount, unit: 'CNY'),
      ],
      baseScore: 55,
      preferences: preferences,
      confidence: quality,
      generatedAt: now,
    );
  }

  FinancialInsightItem? _beautyInsight(
    List<TransactionRecord> expenses,
    InsightPreferences preferences,
    InsightConfidence quality,
    DateTime now,
  ) {
    final cutoff = now.subtract(const Duration(days: 90));
    final items = expenses.where((item) {
      if (item.occurredAt.isBefore(cutoff)) return false;
      final text =
          '${item.categoryName ?? ''} ${item.merchant ?? ''} ${item.note ?? ''}';
      return RegExp(r'美妆|护肤|彩妆|口红|面膜|美容|香水').hasMatch(text);
    }).toList();
    if (items.length < 4) return null;
    final amount = items.fold<double>(
      0,
      (sum, item) => sum + item.netExpenseAmount,
    );
    return _item(
      id: 'life:beauty-care',
      kind: FinancialInsightKind.life,
      priority: InsightPriority.info,
      title: '最近挺重视美妆护理',
      summary: '近 90 天有 ${items.length} 笔美妆或护理相关消费。',
      analysis: '这类消费已经形成比较稳定的生活投入，可以单独观察频率和预算变化。',
      meaning: '账单能说明你近期比较重视这类生活投入，但不会据此猜测你的性别或外貌。',
      response: InsightResponse.encouragement,
      suggestion:
          preferences.intents.contains(BookkeepingIntent.controlSpending)
          ? '如果你希望控制消费，可以给美妆护理单独留一个可持续预算。'
          : null,
      actionLabel: '查看流水',
      actionRoute: '/transactions',
      amount: amount,
      relatedTransactionIds: items.map((e) => e.id).toList(),
      evidence: [
        InsightEvidence(
          label: '相关消费',
          value: items.length.toDouble(),
          unit: '笔',
          transactionIds: items.map((e) => e.id).toList(),
        ),
        InsightEvidence(label: '涉及金额', value: amount, unit: 'CNY'),
      ],
      baseScore: 48,
      preferences: preferences,
      confidence: quality,
      generatedAt: now,
    );
  }

  FinancialInsightItem? _reimbursementInsight(
    List<TransactionRecord> expenses,
    InsightPreferences preferences,
    InsightConfidence quality,
    DateTime now,
  ) {
    final pending = expenses
        .where(
          (item) =>
              item.reimbursementStatus == ReimbursementStatus.pending,
        )
        .toList();
    if (pending.isEmpty) return null;
    final amount = pending.fold<double>(
      0,
      (sum, item) =>
          sum + (item.reimbursementAmount ?? item.netExpenseAmount),
    );
    return _item(
      id: 'money:pending-reimbursement',
      kind: FinancialInsightKind.discovery,
      priority:
          amount >= 500 ? InsightPriority.attention : InsightPriority.info,
      title: '有待报销支出还没闭环',
      summary: '当前有 ${pending.length} 笔待报销，涉及约 ¥${amount.toStringAsFixed(0)}。',
      analysis: '待报销支出会暂时占用现金，但不应长期被当成你的真实个人消费。',
      meaning: '把报销状态补全后，预算、分类占比和消费趋势都会更准确。',
      response: InsightResponse.advice,
      suggestion: '报销到账后及时标记已报销。',
      actionLabel: '处理报销',
      actionRoute: '/transactions/reimbursements',
      amount: amount,
      relatedTransactionIds: pending.map((e) => e.id).toList(),
      baseScore: amount >= 500 ? 72 : 58,
      preferences: preferences,
      confidence: quality,
      generatedAt: now,
    );
  }

  FinancialInsightItem? _positiveChange(
    AnalysisSnapshot analysis,
    InsightPreferences preferences,
    InsightConfidence quality,
    DateTime now,
  ) {
    final candidates = analysis.categoryTrends
        .where(
          (item) =>
              item.previousAmount >= 100 &&
              item.currentAmount < item.previousAmount * .75,
        )
        .toList()
      ..sort(
        (a, b) => (a.currentAmount - a.previousAmount)
            .compareTo(b.currentAmount - b.previousAmount),
      );
    if (candidates.isEmpty) return null;
    final trend = candidates.first;
    final drop = trend.previousAmount - trend.currentAmount;
    final percent =
        trend.previousAmount == 0 ? 0 : drop / trend.previousAmount * 100;
    return _item(
      id: 'positive:category:${trend.categoryId}',
      kind: FinancialInsightKind.positive,
      priority: InsightPriority.info,
      title: '${trend.name}支出有所下降',
      summary:
          '和上一可比周期相比少了约 ¥${drop.toStringAsFixed(0)}（${percent.toStringAsFixed(0)}%）。',
      analysis: trend.currentCount < trend.previousCount
          ? '变化主要伴随着消费次数减少。'
          : '消费次数变化不大，单次金额下降更明显。',
      meaning: '这是一个相对你自己历史习惯的积极变化。',
      response: InsightResponse.encouragement,
      suggestion: preferences.intents.any(
        (item) =>
            item == BookkeepingIntent.controlSpending ||
            item == BookkeepingIntent.saveForGoal,
      )
          ? '这个变化和你当前的记账目标方向一致。'
          : null,
      actionLabel: '查看趋势',
      actionRoute: '/analysis',
      categoryId: trend.categoryId,
      amount: trend.currentAmount,
      changePercent: -percent,
      evidence: [
        InsightEvidence(
          label: trend.name,
          value: trend.currentAmount,
          baselineValue: trend.previousAmount,
          unit: analysis.currency,
        ),
      ],
      baseScore: 50,
      preferences: preferences,
      confidence: quality,
      generatedAt: now,
    );
  }

  InsightConfidence _quality(
    List<TransactionRecord> expenses,
    DateTime now,
  ) {
    if (expenses.isEmpty) {
      return const InsightConfidence(
        data: .2,
        completeness: .1,
        classification: .2,
        baseline: .1,
      );
    }
    final cutoff = now.subtract(const Duration(days: 90));
    final recent =
        expenses.where((item) => !item.occurredAt.isBefore(cutoff)).toList();
    final months = <String>{};
    for (final item in recent) {
      months.add('${item.occurredAt.year}-${item.occurredAt.month}');
    }
    final completeness =
        (.6 * math.min(1, recent.length / 45) +
                .4 * math.min(1, months.length / 3))
            .clamp(0, 1)
            .toDouble();
    var classTotal = 0.0;
    var dataTotal = 0.0;
    for (final item in recent) {
      classTotal += item.userCorrected
          ? 1
          : item.aiConfidence ?? (item.categoryId == null ? .55 : .9);
      final duplicatePenalty = item.duplicateConfidence == null
          ? 0.0
          : (item.duplicateConfidence! * .6);
      dataTotal += (1 - duplicatePenalty).clamp(.2, 1);
    }
    final classification = recent.isEmpty
        ? .2
        : (classTotal / recent.length).clamp(0, 1).toDouble();
    final data = recent.isEmpty
        ? .2
        : (dataTotal / recent.length).clamp(0, 1).toDouble();
    final baseline =
        (.45 * math.min(1, recent.length / 40) +
                .55 * math.min(1, months.length / 3))
            .clamp(0, 1)
            .toDouble();
    return InsightConfidence(
      data: data,
      completeness: completeness,
      classification: classification,
      baseline: baseline,
    );
  }

  bool _looksLikeCredit(String name) =>
      RegExp(r'花呗|月付|白条|信用|分期|先用后付').hasMatch(name);

  FinancialInsightItem _item({
    required String id,
    required FinancialInsightKind kind,
    required InsightPriority priority,
    required String title,
    required String summary,
    required String analysis,
    required String meaning,
    required InsightResponse response,
    required double baseScore,
    required InsightPreferences preferences,
    required InsightConfidence confidence,
    required DateTime generatedAt,
    String? suggestion,
    String? actionLabel,
    String? actionRoute,
    String? categoryId,
    double? amount,
    double? changePercent,
    List<InsightEvidence> evidence = const [],
    List<String> relatedTransactionIds = const [],
  }) {
    var score = baseScore;
    score += _intentBoost(kind, preferences);
    score += _focusBoost('$title $summary', preferences);
    score += (confidence.overall - .5) * 16;
    if (preferences.tone == InsightTone.quiet) score -= 7;
    if (preferences.tone == InsightTone.strict &&
        (kind == FinancialInsightKind.risk ||
            kind == FinancialInsightKind.behavior)) {
      score += 4;
    }
    return FinancialInsightItem(
      id: id,
      kind: kind,
      priority: priority,
      title: title,
      summary: summary,
      analysis: analysis,
      meaning: meaning,
      response: response,
      suggestion: suggestion,
      actionLabel: actionLabel,
      actionRoute: actionRoute,
      categoryId: categoryId,
      amount: amount,
      changePercent: changePercent,
      evidence: evidence,
      relatedTransactionIds: relatedTransactionIds,
      score: score.clamp(0, 100).toDouble(),
      confidence: confidence,
      generatedAt: generatedAt,
    );
  }

  double _intentBoost(
    FinancialInsightKind kind,
    InsightPreferences preferences,
  ) {
    var boost = 0.0;
    for (final intent in preferences.intents) {
      boost = math.max(
        boost,
        switch (intent) {
          BookkeepingIntent.controlSpending =>
            kind == FinancialInsightKind.behavior ||
                    kind == FinancialInsightKind.risk
                ? 12
                : 0,
          BookkeepingIntent.understandSpending =>
            kind == FinancialInsightKind.behavior ||
                    kind == FinancialInsightKind.discovery
                ? 8
                : 0,
          BookkeepingIntent.saveForGoal =>
            kind == FinancialInsightKind.risk ||
                    kind == FinancialInsightKind.positive ||
                    kind == FinancialInsightKind.goal
                ? 12
                : 0,
          BookkeepingIntent.optimizeFinances =>
            kind == FinancialInsightKind.financial ||
                    kind == FinancialInsightKind.risk ||
                    kind == FinancialInsightKind.discovery
                ? 12
                : 0,
          BookkeepingIntent.familyFinances =>
            kind == FinancialInsightKind.life ||
                    kind == FinancialInsightKind.financial
                ? 12
                : 0,
          BookkeepingIntent.improveHabits =>
            kind == FinancialInsightKind.behavior ||
                    kind == FinancialInsightKind.life
                ? 10
                : 0,
          BookkeepingIntent.recordLife =>
            kind == FinancialInsightKind.life ||
                    kind == FinancialInsightKind.positive
                ? 12
                : 0,
        },
      );
    }
    return boost;
  }

  double _focusBoost(String text, InsightPreferences preferences) {
    var boost = 0.0;
    for (final focus in preferences.focus) {
      final matched = switch (focus) {
        InsightFocus.dining => RegExp(r'餐饮|外卖|吃|夜').hasMatch(text),
        InsightFocus.shopping =>
          RegExp(r'购物|淘宝|拼多多|京东|美妆').hasMatch(text),
        InsightFocus.travel => RegExp(r'旅行|出行|交通|住宿').hasMatch(text),
        InsightFocus.healthHabits =>
          RegExp(r'健康|健身|餐饮|夜|美妆').hasMatch(text),
        InsightFocus.savings => RegExp(r'预算|储蓄|支出下降').hasMatch(text),
        InsightFocus.credit => RegExp(r'信用|月付|负债|还款').hasMatch(text),
        InsightFocus.family => RegExp(r'家庭|家人|父母').hasMatch(text),
        InsightFocus.learning => RegExp(r'学习|教育|课程|书').hasMatch(text),
      };
      if (matched) boost = math.max(boost, 10);
    }
    return boost;
  }
}

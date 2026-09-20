import 'dart:math' as math;

import '../../../core/models/account.dart';
import '../../../core/models/analysis.dart';
import '../../../core/models/budget.dart';
import '../../../core/models/goal.dart';
import '../../../core/models/recurring_bill.dart';
import 'budget_recommendation_service.dart';
import '../../../core/models/transaction_record.dart';
import 'insight_models.dart';

class FinancialInsightEngine {
  const FinancialInsightEngine();

  List<TransactionRecord> normalizeAnalysisTransactions(
    List<TransactionRecord> transactions,
  ) {
    final result = <TransactionRecord>[];
    for (final item in transactions) {
      if (!item.isConsumptionExpense) {
        result.add(item);
        continue;
      }
      final personal = item.personalExpenseAmount;
      if (personal <= .005) continue;
      if ((personal - item.netExpenseAmount).abs() < .005) {
        result.add(item);
        continue;
      }
      result.add(
        item.copyWith(
          amount: personal,
          reimbursementStatus: ReimbursementStatus.none,
          reimbursementAmount: null,
          refundStatus: RefundStatus.none,
          clearRefundAmount: true,
        ),
      );
    }
    return List.unmodifiable(result);
  }

  InsightFeed build({
    required List<TransactionRecord> transactions,
    required AnalysisSnapshot analysis,
    required BudgetOverview budgets,
    required List<Account> accounts,
    List<Goal> goals = const [],
    List<RecurringBill> recurringBills = const [],
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
    final consumptionRows = eligible
        .where((item) => item.isConsumptionExpense)
        .toList(growable: false);
    final expenses = consumptionRows
        .where((item) => item.personalExpenseAmount > .005)
        .toList(growable: false);
    final quality = _quality(expenses, clock);
    final candidates = <FinancialInsightItem>[];

    final balance = _comparableBalanceInsight(
      eligible,
      preferences,
      quality,
      clock,
    );
    if (balance != null) candidates.add(balance);

    if (quality.baseline >= .35) {
      final oneTimeSpikes = _oneTimeCategoryInsights(
        expenses,
        preferences,
        quality,
        clock,
      );
      candidates.addAll(oneTimeSpikes);
      final specialCategoryIds = oneTimeSpikes
          .map((item) => item.categoryId)
          .whereType<String>()
          .toSet();

      for (final source in analysis.insights) {
        final stableCategoryId = _stableCategoryId(source, expenses);
        final isCategoryTrend =
            source.type == AnalysisInsightType.categoryIncrease ||
            source.type == AnalysisInsightType.deliveryIncrease;
        if (isCategoryTrend &&
            stableCategoryId != null &&
            specialCategoryIds.contains(stableCategoryId)) {
          continue;
        }
        candidates.add(
          _fromAnalysis(source, expenses, preferences, quality),
        );
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
      expenses,
      preferences,
      quality,
      clock,
    );
    if (budget != null) {
      candidates.add(budget);
    } else {
      final recommendation =
          const BudgetRecommendationService().recommendTotal(
        transactions: eligible,
        preferences: preferences,
        now: clock,
      );
      if (recommendation != null &&
          (preferences.intents.contains(BookkeepingIntent.controlSpending) ||
              preferences.intents.contains(BookkeepingIntent.saveForGoal))) {
        candidates.add(
          _item(
            id: 'budget:recommendation',
            kind: FinancialInsightKind.goal,
            priority: InsightPriority.attention,
            title: '可以用你的真实消费来设预算了',
            summary:
                '根据最近完整月份，当前建议总预算约 ¥${recommendation.recommended.toStringAsFixed(0)}。',
            analysis:
                '系统不是把历史平均直接当预算，而是结合稳定消费区间和你的记账目标给出档位。',
            meaning: '先从可持续的预算开始，比随手填一个过紧或过松的数字更容易长期执行。',
            response: InsightResponse.advice,
            suggestion: '你可以在“保持、适度控制、积极节省”三个档位之间自己选择。',
            actionLabel: '设置预算',
            actionRoute: '/profile/budgets',
            amount: recommendation.recommended,
            evidence: [
              InsightEvidence(
                label: '历史月中位数',
                value: recommendation.historicalMedian,
                unit: 'CNY',
              ),
              InsightEvidence(
                label: '建议预算',
                value: recommendation.recommended,
                unit: 'CNY',
              ),
            ],
            baseScore: 70,
            preferences: preferences,
            confidence: quality.copyWith(
              baseline: math.max(
                recommendation.confidence,
                quality.baseline,
              ),
            ),
            generatedAt: clock,
          ),
        );
      }
    }

    final goal = _goalInsight(goals, preferences, quality, clock);
    if (goal != null) candidates.add(goal);

    final credit = _creditInsight(
      accounts,
      preferences,
      quality,
      clock,
    );
    if (credit != null) candidates.add(credit);

    final recurringCashflow = _recurringCashflowInsight(
      recurringBills,
      accounts,
      preferences,
      quality,
      clock,
    );
    if (recurringCashflow != null) candidates.add(recurringCashflow);

    final family = _familyInsight(
      expenses,
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
      consumptionRows,
      preferences,
      quality,
      clock,
    );
    if (reimbursement != null) candidates.add(reimbursement);

    final anomaly = _dataAnomalyInsight(
      eligible,
      preferences,
      quality,
      clock,
    );
    if (anomaly != null) candidates.add(anomaly);

    if (anomaly == null &&
        quality.classification < .68 &&
        expenses.length >= 12) {
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

  List<FinancialInsightItem> _oneTimeCategoryInsights(
    List<TransactionRecord> expenses,
    InsightPreferences preferences,
    InsightConfidence quality,
    DateTime now,
  ) {
    final currentStart = DateTime(now.year, now.month);
    final currentEnd = DateTime(now.year, now.month, now.day + 1);
    final previousStart = DateTime(now.year, now.month - 1);
    final previousLastDay = DateTime(now.year, now.month, 0).day;
    final comparableDay = now.day.clamp(1, previousLastDay);
    final previousEnd = DateTime(
      previousStart.year,
      previousStart.month,
      comparableDay + 1,
    );

    final keys = <String>{
      for (final item in expenses)
        if (!item.occurredAt.isBefore(currentStart) &&
            item.occurredAt.isBefore(currentEnd))
          _stableRowCategoryId(item),
    };
    final results = <FinancialInsightItem>[];
    for (final categoryId in keys) {
      final currentRows = expenses.where(
        (item) =>
            _stableRowCategoryId(item) == categoryId &&
            !item.occurredAt.isBefore(currentStart) &&
            item.occurredAt.isBefore(currentEnd),
      ).toList(growable: false);
      final previousRows = expenses.where(
        (item) =>
            _stableRowCategoryId(item) == categoryId &&
            !item.occurredAt.isBefore(previousStart) &&
            item.occurredAt.isBefore(previousEnd),
      ).toList(growable: false);
      final currentAmount = currentRows.fold<double>(
        0,
        (sum, item) => sum + item.personalExpenseAmount,
      );
      final previousAmount = previousRows.fold<double>(
        0,
        (sum, item) => sum + item.personalExpenseAmount,
      );
      if (previousAmount < 100) continue;
      final delta = currentAmount - previousAmount;
      final change = delta / previousAmount;
      if (delta < 100 || change < .30) continue;

      var explicitAmount = 0.0;
      final explicitIds = <String>[];
      TransactionRecord? largest;
      var largestAmount = 0.0;
      for (final item in currentRows) {
        final amount = item.personalExpenseAmount;
        if (amount > largestAmount) {
          largest = item;
          largestAmount = amount;
        }
        if (item.isLargeTransaction) {
          explicitAmount += amount;
          explicitIds.add(item.id);
        }
      }
      final inferred =
          explicitAmount <= 0 &&
          largest != null &&
          largest.isOneTime &&
          largestAmount >= 500 &&
          largestAmount >= math.max(delta * .6, previousAmount * .5);
      final specialAmount = explicitAmount > 0
          ? explicitAmount
          : inferred
          ? largestAmount
          : 0.0;
      final ids = explicitIds.isNotEmpty
          ? explicitIds
          : inferred
          ? <String>[largest.id]
          : const <String>[];
      if (specialAmount <= 0 ||
          (specialAmount < delta * .6 &&
              specialAmount < currentAmount * .5)) {
        continue;
      }

      final categoryName =
          currentRows
              .map((item) => item.categoryName?.trim())
              .whereType<String>()
              .firstWhere(
                (value) => value.isNotEmpty,
                orElse: () => '这类消费',
              );
      results.add(
        _item(
          id: 'category:$categoryId:one-time',
          kind: FinancialInsightKind.discovery,
          priority: InsightPriority.attention,
          title: '$categoryName增加主要来自一次性支出',
          summary:
              '本期 $categoryName 比上一可比周期多 '
              '¥${delta.toStringAsFixed(0)}，其中一次性/大额记录约 '
              '¥${specialAmount.toStringAsFixed(0)}。',
          analysis: '这次变化不适合直接解释为消费习惯持续变差，系统会把一次性支出和常规消费分开看。',
          meaning: '特殊支出会影响当月总额，但不应该自动被当作长期消费趋势。',
          response: InsightResponse.notice,
          suggestion:
              preferences.intents.contains(
                BookkeepingIntent.controlSpending,
              )
              ? '可以先确认这笔支出是否确实是一次性的，再决定要不要调整日常预算。'
              : null,
          actionLabel: '查看相关流水',
          actionRoute: '/transactions',
          categoryId: categoryId,
          amount: currentAmount,
          changePercent: change * 100,
          evidence: [
            InsightEvidence(
              label: categoryName,
              value: currentAmount,
              baselineValue: previousAmount,
              unit: 'CNY',
            ),
            InsightEvidence(
              label: '一次性/大额支出',
              value: specialAmount,
              unit: 'CNY',
              transactionIds: ids,
            ),
          ],
          relatedTransactionIds: ids,
          baseScore: 59,
          preferences: preferences,
          confidence: quality,
          generatedAt: now,
        ),
      );
    }
    return results;
  }

  String _stableRowCategoryId(TransactionRecord item) {
    final id = item.categoryId?.trim();
    if (id != null && id.isNotEmpty) return id;
    final name = item.categoryName?.trim();
    if (name != null && name.isNotEmpty) return 'name:$name';
    return 'uncategorized';
  }


  String _analysisCategoryKey(TransactionRecord item) {
    final name = item.categoryName?.trim();
    if (name != null && name.isNotEmpty) return 'name:$name';
    final id = item.categoryId?.trim();
    if (id != null && id.isNotEmpty) return 'id:${item.bookId}:$id';
    return 'uncategorized';
  }

  String? _stableCategoryId(
    AnalysisInsight source,
    List<TransactionRecord> expenses,
  ) {
    final sourceKey = source.categoryId;
    if (sourceKey == null) return null;
    for (final item in expenses) {
      if (_analysisCategoryKey(item) != sourceKey) continue;
      final id = item.categoryId?.trim();
      if (id != null && id.isNotEmpty) return id;
    }
    return sourceKey;
  }

  FinancialInsightItem _fromAnalysis(
    AnalysisInsight source,
    List<TransactionRecord> expenses,
    InsightPreferences preferences,
    InsightConfidence quality,
  ) {
    final stableCategoryId = _stableCategoryId(source, expenses);
    final priority = switch (source.severity) {
      AnalysisInsightSeverity.info => InsightPriority.info,
      AnalysisInsightSeverity.attention => InsightPriority.attention,
      AnalysisInsightSeverity.important => InsightPriority.important,
    };
    final currentCount = (source.metadata['currentCount'] as num?)?.toDouble();
    final previousCount = (source.metadata['previousCount'] as num?)?.toDouble();
    return _item(
      id: source.id.startsWith('category:') && stableCategoryId != null
          ? 'analysis:category:$stableCategoryId'
          : 'analysis:${source.id}',
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
      categoryId: stableCategoryId ?? source.categoryId,
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
    List<TransactionRecord> expenses,
    InsightPreferences preferences,
    InsightConfidence quality,
    DateTime now,
  ) {
    if (progress == null) return null;
    final lastDay = DateTime(now.year, now.month + 1, 0).day;
    final timeProgress = (now.day / lastDay).clamp(.03, 1.0).toDouble();
    final used = expenses
        .where(
          (item) =>
              item.occurredAt.year == now.year &&
              item.occurredAt.month == now.month,
        )
        .fold<double>(0, (sum, item) => sum + item.personalExpenseAmount);
    final committed = used + progress.goalReservation;
    final usage = committed / progress.budget.amount;
    final forecast = used / timeProgress + progress.goalReservation;
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
      title: usage > 1
          ? progress.goalReservation > 0
              ? '本月预算已被支出和目标预留占满'
              : '本月预算已经超出'
          : '本月预算消耗有点快',
      summary: usage > 1
          ? progress.goalReservation > 0
              ? '本月个人支出与目标预留合计已超过预算 ¥${progress.budget.amount.toStringAsFixed(0)}。'
              : '本月支出已经超过预算 ¥${progress.budget.amount.toStringAsFixed(0)}。'
          : '本月过去 ${(timeProgress * 100).round()}%，预算已占用 ${(usage * 100).round()}%。',
      analysis:
          '按目前消费速度，月底预计约 ¥${forecast.toStringAsFixed(0)}'
          '${overspend > 0 ? '，比预算高约 ¥${overspend.toStringAsFixed(0)}' : ''}。',
      meaning: '预算控制应该看“消费速度”和“时间进度”，而不是等月底超支后再提醒。',
      response: InsightResponse.advice,
      suggestion: '打开预算可以查看剩余额度和日均可用金额，再决定是否调整接下来的消费节奏。',
      actionLabel: '查看预算',
      actionRoute: '/profile/budgets',
      amount: used,
      changePercent: (usage - timeProgress) * 100,
      evidence: [
        InsightEvidence(label: '预算已占用', value: usage * 100, unit: '%'),
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

  FinancialInsightItem? _comparableBalanceInsight(
    List<TransactionRecord> records,
    InsightPreferences preferences,
    InsightConfidence quality,
    DateTime now,
  ) {
    final currentStart = DateTime(now.year, now.month);
    final previousStart = DateTime(now.year, now.month - 1);
    final previousLastDay = DateTime(now.year, now.month, 0).day;
    final comparableDay = now.day.clamp(1, previousLastDay);
    final previousEnd = DateTime(
      previousStart.year,
      previousStart.month,
      comparableDay + 1,
    );

    ({double income, double expense}) totals(
      DateTime start,
      DateTime endExclusive,
    ) {
      var income = 0.0;
      var expense = 0.0;
      for (final item in records) {
        if (item.occurredAt.isBefore(start) ||
            !item.occurredAt.isBefore(endExclusive)) {
          continue;
        }
        if (item.type == TransactionType.income) income += item.amount;
        if (item.isConsumptionExpense) expense += item.personalExpenseAmount;
      }
      return (income: income, expense: expense);
    }

    final current = totals(
      currentStart,
      DateTime(now.year, now.month, now.day + 1),
    );
    final previous = totals(previousStart, previousEnd);
    if (current.income < 500 || previous.income < 500) return null;
    final currentBalance = current.income - current.expense;
    final previousBalance = previous.income - previous.expense;
    final delta = currentBalance - previousBalance;
    final denominator = math.max(current.income, previous.income);
    if (delta.abs() < 300 || delta.abs() / denominator < .10) return null;
    final improved = delta > 0;
    return _item(
      id: 'financial:comparable-balance',
      kind: improved
          ? FinancialInsightKind.positive
          : FinancialInsightKind.financial,
      priority: improved ? InsightPriority.info : InsightPriority.attention,
      title: improved ? '本月可比结余有所改善' : '本月可比结余有所收紧',
      summary:
          '截至当前日期，收支结余约 ¥${currentBalance.toStringAsFixed(0)}，'
          '上一可比周期约 ¥${previousBalance.toStringAsFixed(0)}。',
      analysis: improved
          ? '在收入达到可比水平的前提下，当前结余比上一同期更高。'
          : '在收入达到可比水平的前提下，当前结余比上一同期更低；这不等于“花错了”，但值得看看主要变化来自哪里。',
      meaning: '结余只和你自己的可比周期比较，并扣除已知退款和可报销部分。',
      response: improved
          ? InsightResponse.encouragement
          : InsightResponse.notice,
      suggestion:
          !improved &&
              preferences.intents.contains(BookkeepingIntent.optimizeFinances)
          ? '可以先看支出增加最大的分类和近期固定支出，再决定是否需要调整。'
          : null,
      actionLabel: '查看趋势',
      actionRoute: '/analysis',
      amount: currentBalance,
      changePercent: previousBalance == 0
          ? null
          : delta / math.max(1.0, previousBalance.abs()) * 100,
      evidence: [
        InsightEvidence(
          label: '本期收入',
          value: current.income,
          baselineValue: previous.income,
          unit: 'CNY',
        ),
        InsightEvidence(
          label: '本期个人消费',
          value: current.expense,
          baselineValue: previous.expense,
          unit: 'CNY',
        ),
        InsightEvidence(
          label: '收支结余',
          value: currentBalance,
          baselineValue: previousBalance,
          unit: 'CNY',
        ),
      ],
      baseScore: improved ? 49 : 66,
      preferences: preferences,
      confidence: quality,
      generatedAt: now,
    );
  }

  FinancialInsightItem? _recurringCashflowInsight(
    List<RecurringBill> bills,
    List<Account> accounts,
    InsightPreferences preferences,
    InsightConfidence quality,
    DateTime now,
  ) {
    final today = DateTime(now.year, now.month, now.day);
    final endExclusive = DateTime(now.year, now.month, now.day + 15);
    final active = bills.where(
      (bill) =>
          bill.status == RecurringBillStatus.active &&
          !bill.nextDate.isBefore(today) &&
          bill.nextDate.isBefore(endExclusive),
    );
    final expenses = active.where((bill) => !bill.isIncome).toList();
    final incomes = active.where((bill) => bill.isIncome).toList();
    final upcomingExpense = expenses.fold<double>(
      0,
      (sum, bill) => sum + bill.amount,
    );
    final upcomingIncome = incomes.fold<double>(
      0,
      (sum, bill) => sum + bill.amount,
    );
    if (expenses.length < 2 && upcomingExpense < 300) return null;

    final liquid = accounts
        .where(
          (account) =>
              !account.isArchived &&
              !account.type.isDebt &&
              (account.assetForm == AssetForm.cash ||
                  account.assetForm == AssetForm.walletBalance ||
                  account.assetForm == AssetForm.demandDeposit ||
                  account.assetForm == AssetForm.unspecified),
        )
        .fold<double>(
          0,
          (sum, account) => sum + math.max(0.0, account.balance),
        );
    final netUpcoming = math.max(0.0, upcomingExpense - upcomingIncome);
    final risk =
        liquid > 0 &&
        quality.completeness >= .65 &&
        netUpcoming > liquid * .7;
    return _item(
      id: 'cashflow:upcoming-recurring',
      kind: risk
          ? FinancialInsightKind.risk
          : FinancialInsightKind.discovery,
      priority: risk ? InsightPriority.important : InsightPriority.attention,
      title: risk ? '未来两周固定支出比较集中' : '未来两周有几项固定支出',
      summary:
          '已知周期支出约 ¥${upcomingExpense.toStringAsFixed(0)}，共 ${expenses.length} 项。',
      analysis: upcomingIncome > 0
          ? '同期已知周期收入约 ¥${upcomingIncome.toStringAsFixed(0)}，会把两边一起看。'
          : '这里只基于已经记录的周期账单，不会把未知收入或支出当成事实。',
      meaning: risk
          ? '结合当前记录的流动资产，这段时间的现金流余量可能偏紧。'
          : '提前看固定支出，可以避免只凭账户当前余额判断“还能花多少”。',
      response: risk ? InsightResponse.advice : InsightResponse.notice,
      suggestion: risk ? '建议先确认近期收入与待还账户，再决定可调整消费额度。' : null,
      actionLabel: '查看周期账单',
      actionRoute: '/profile/recurring-bills',
      amount: upcomingExpense,
      evidence: [
        InsightEvidence(
          label: '未来14天周期支出',
          value: upcomingExpense,
          unit: 'CNY',
        ),
        if (upcomingIncome > 0)
          InsightEvidence(
            label: '未来14天周期收入',
            value: upcomingIncome,
            unit: 'CNY',
          ),
        if (liquid > 0)
          InsightEvidence(
            label: '当前记录的流动资产',
            value: liquid,
            unit: 'CNY',
          ),
      ],
      baseScore: risk ? 82 : 61,
      preferences: preferences,
      confidence: quality,
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
      if (item.type != TransactionType.expense &&
          item.type != TransactionType.lend) {
        return false;
      }
      final text =
          '${item.note ?? ''} ${item.merchant ?? ''} ${item.categoryName ?? ''}';
      return RegExp(r'爸爸|妈妈|父母|家人|家里|爸妈').hasMatch(text);
    }).toList();
    if (family.length < 2) return null;
    final amount = family.fold<double>(
      0,
      (sum, item) => sum + item.personalExpenseAmount,
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
      if (item.personalExpenseAmount <= .005) return false;
      final text =
          '${item.categoryName ?? ''} ${item.merchant ?? ''} ${item.note ?? ''}';
      return RegExp(r'美妆|护肤|彩妆|口红|面膜|美容|香水').hasMatch(text);
    }).toList();
    if (items.length < 4) return null;
    final amount = items.fold<double>(
      0,
      (sum, item) => sum + item.personalExpenseAmount,
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

  FinancialInsightItem? _dataAnomalyInsight(
    List<TransactionRecord> records,
    InsightPreferences preferences,
    InsightConfidence quality,
    DateTime now,
  ) {
    final cutoff = now.subtract(const Duration(days: 30));
    final rows = records.where((item) {
      if (item.occurredAt.isBefore(cutoff)) return false;
      final duplicate = (item.duplicateConfidence ?? 0) >= .75;
      final lowConfidence =
          (item.source == TransactionSource.auto ||
              item.source == TransactionSource.ocr ||
              item.source == TransactionSource.import) &&
          item.aiConfidence != null &&
          item.aiConfidence! < .55;
      final missingCategory =
          item.type == TransactionType.expense &&
          item.categoryId == null &&
          (item.categoryName?.trim().isEmpty ?? true);
      return duplicate || lowConfidence || missingCategory;
    }).toList();
    if (rows.length < 2) return null;
    final duplicateCount =
        rows.where((item) => (item.duplicateConfidence ?? 0) >= .75).length;
    return _item(
      id: 'data:review-needed',
      kind: FinancialInsightKind.discovery,
      priority: rows.length >= 6
          ? InsightPriority.important
          : InsightPriority.attention,
      title: '有几笔流水值得人工确认',
      summary: '近 30 天发现 ${rows.length} 笔疑似重复、低置信度或未分类流水。',
      analysis:
          '其中疑似重复 $duplicateCount 笔，其余主要来自自动记账、OCR、导入或未分类记录。',
      meaning: '先把这些记录确认清楚，比在可疑数据上继续生成更多消费结论更可靠。',
      response: InsightResponse.advice,
      suggestion: '建议优先检查最近的自动识别与导入流水。',
      actionLabel: '检查流水',
      actionRoute: '/transactions',
      relatedTransactionIds: rows.map((item) => item.id).toList(),
      evidence: [
        InsightEvidence(
          label: '待确认流水',
          value: rows.length.toDouble(),
          unit: '笔',
          transactionIds: rows.map((item) => item.id).toList(),
        ),
      ],
      baseScore: rows.length >= 6 ? 80 : 70,
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

  FinancialInsightItem? _goalInsight(
    List<Goal> goals,
    InsightPreferences preferences,
    InsightConfidence quality,
    DateTime now,
  ) {
    final active = goals
        .where((goal) => goal.status == GoalStatus.active)
        .toList()
      ..sort((a, b) => a.targetDate.compareTo(b.targetDate));
    if (active.isEmpty) return null;
    final goal = active.first;
    final targetEndExclusive = DateTime(
      goal.targetDate.year,
      goal.targetDate.month,
      goal.targetDate.day + 1,
    );
    final total = targetEndExclusive.difference(goal.createdAt);
    if (total <= Duration.zero || goal.targetAmount <= 0) return null;
    final elapsed = now.difference(goal.createdAt).inMilliseconds;
    final timeProgress =
        (elapsed / total.inMilliseconds).clamp(0, 1).toDouble();
    final moneyProgress = goal.progress;
    final gap = timeProgress - moneyProgress;
    final overdue =
        !now.isBefore(targetEndExclusive) && moneyProgress < 1;

    if (!overdue && gap.abs() < .10) return null;
    final behind = overdue || gap > 0;
    return _item(
      id: 'goal:${goal.id}:progress',
      kind: behind ? FinancialInsightKind.goal : FinancialInsightKind.positive,
      priority: overdue
          ? InsightPriority.important
          : behind
          ? InsightPriority.attention
          : InsightPriority.info,
      title: behind ? '${goal.name}需要再追一点进度' : '${goal.name}进度走在计划前面',
      summary:
          '资金进度 ${(moneyProgress * 100).round()}%，时间进度 ${(timeProgress * 100).round()}%。',
      analysis: behind
          ? '按当前目标时间看，资金积累速度低于时间进度。'
          : '当前资金积累速度高于目标时间进度。',
      meaning: behind
          ? '目标洞察会把消费、预算和储蓄放到同一个目标里看，而不是只评价某一笔支出。'
          : '这是与你设定的目标方向一致的积极变化。',
      response: behind ? InsightResponse.advice : InsightResponse.encouragement,
      suggestion: behind
          ? '可以先查看目标每月预留，再决定是否调整预算或目标日期。'
          : '保持当前节奏即可，不需要为了更快而过度压缩正常生活支出。',
      actionLabel: '查看目标',
      actionRoute: '/goals/${goal.id}',
      amount: goal.currentAmount,
      changePercent: (moneyProgress - timeProgress) * 100,
      evidence: [
        InsightEvidence(
          label: '目标资金进度',
          value: moneyProgress * 100,
          baselineValue: timeProgress * 100,
          unit: '%',
        ),
        InsightEvidence(
          label: '还差金额',
          value: math.max(0.0, goal.targetAmount - goal.currentAmount),
          unit: 'CNY',
        ),
      ],
      baseScore: behind ? 66 : 48,
      preferences: preferences,
      confidence: quality.copyWith(baseline: math.max(.65, quality.baseline)),
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
        trend.previousAmount == 0 ? 0.0 : drop / trend.previousAmount * 100;
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
          ? 1.0
          : item.aiConfidence ?? (item.categoryId == null ? .55 : .9);
      final duplicatePenalty = item.duplicateConfidence == null
          ? 0.0
          : (item.duplicateConfidence! * .6);
      dataTotal += (1 - duplicatePenalty).clamp(.2, 1).toDouble();
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
    score += preferences.kindAdjustments[kind] ?? 0;
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
                ? 12.0
                : 0.0,
          BookkeepingIntent.understandSpending =>
            kind == FinancialInsightKind.behavior ||
                    kind == FinancialInsightKind.discovery
                ? 8.0
                : 0.0,
          BookkeepingIntent.saveForGoal =>
            kind == FinancialInsightKind.risk ||
                    kind == FinancialInsightKind.positive ||
                    kind == FinancialInsightKind.goal
                ? 12.0
                : 0.0,
          BookkeepingIntent.optimizeFinances =>
            kind == FinancialInsightKind.financial ||
                    kind == FinancialInsightKind.risk ||
                    kind == FinancialInsightKind.discovery
                ? 12.0
                : 0.0,
          BookkeepingIntent.familyFinances =>
            kind == FinancialInsightKind.life ||
                    kind == FinancialInsightKind.financial
                ? 12.0
                : 0.0,
          BookkeepingIntent.improveHabits =>
            kind == FinancialInsightKind.behavior ||
                    kind == FinancialInsightKind.life
                ? 10.0
                : 0.0,
          BookkeepingIntent.recordLife =>
            kind == FinancialInsightKind.life ||
                    kind == FinancialInsightKind.positive
                ? 12.0
                : 0.0,
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
      if (matched) boost = math.max(boost, 10.0);
    }
    return boost;
  }
}

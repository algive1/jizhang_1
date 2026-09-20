import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/formatters/money_formatter.dart';
import '../../../core/models/transaction_record.dart';
import '../../../core/widgets/app_card.dart';
import '../application/analysis_report_export_service.dart';
import '../data/analysis_repository.dart';
import '../domain/annual_financial_report_service.dart';
import '../../intelligence/application/financial_truth_provider.dart';
import '../../../app/theme/app_theme_tokens.dart';

class AnnualReportPage extends ConsumerStatefulWidget {
  const AnnualReportPage({super.key});

  @override
  ConsumerState<AnnualReportPage> createState() => _AnnualReportPageState();
}

class _AnnualReportPageState extends ConsumerState<AnnualReportPage> {
  final _reportKey = GlobalKey();
  int _year = DateTime.now().year;
  bool _sharing = false;

  @override
  Widget build(BuildContext context) {
    final transactionsAsync = ref.watch(analysisTransactionsProvider);
    final currency = ref.watch(analysisCurrencyProvider);
    final scope = ref.watch(analysisScopeProvider);
    final transactions = transactionsAsync.value ?? const <TransactionRecord>[];
    final currentYear = DateTime.now().year;
    final earliest = transactions.isEmpty
        ? currentYear
        : transactions
              .map((item) => item.occurredAt.year)
              .reduce((a, b) => a < b ? a : b);
    final years = [
      for (var year = currentYear; year >= earliest; year--) year,
    ];
    final selectedYear = years.contains(_year) ? _year : currentYear;
    final report = ref
        .watch(annualFinancialReportServiceProvider)
        .build(
          transactions,
          year: selectedYear,
          currency: currency,
          excludedTransactionIds:
              ref.watch(financialTruthSuppressedTransactionIdsProvider),
        );

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () =>
                    context.canPop() ? context.pop() : context.go('/analysis'),
                icon: const Icon(Icons.arrow_back),
                tooltip: '返回',
              ),
              Expanded(
                child: Text(
                  '年度报告 · 财务体检',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ),
              PopupMenuButton<String>(
                enabled: !_sharing && !transactionsAsync.isLoading,
                tooltip: '分享年度报告',
                icon: _sharing
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.ios_share_outlined),
                onSelected: (value) =>
                    _share(context, value, selectedYear, scope.label),
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'image', child: Text('分享图片')),
                  PopupMenuItem(value: 'pdf', child: Text('分享 PDF')),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<int>(
                  initialValue: selectedYear,
                  decoration: const InputDecoration(labelText: '报告年份'),
                  items: [
                    for (final year in years)
                      DropdownMenuItem(value: year, child: Text('$year 年')),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => _year = value);
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: currency,
                  decoration: const InputDecoration(labelText: '币种'),
                  items: _currencies(transactions, currency)
                      .map(
                        (value) =>
                            DropdownMenuItem(value: value, child: Text(value)),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      ref
                          .read(analysisCurrencyProvider.notifier)
                          .select(value);
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _ScopeSelector(scope: scope),
          const SizedBox(height: 16),
          if (transactionsAsync.isLoading)
            const Center(child: CircularProgressIndicator())
          else if (transactionsAsync.hasError)
            AppCard(
              child: Column(
                children: [
                  const Text('年度数据读取失败'),
                  TextButton(
                    onPressed: () {
                      ref.invalidate(analysisTransactionsProvider);
                    },
                    child: const Text('重新加载'),
                  ),
                ],
              ),
            )
          else
            RepaintBoundary(
              key: _reportKey,
              child: _AnnualReportCard(
                report: report,
                scopeLabel: scope.label,
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _share(
    BuildContext context,
    String format,
    int year,
    String scopeLabel,
  ) async {
    if (_sharing) return;
    setState(() => _sharing = true);
    try {
      final service = ref.read(analysisReportExportServiceProvider);
      final baseName = '好好记账-$year年度报告';
      if (format == 'pdf') {
        await service.sharePdf(
          context,
          _reportKey,
          fileName: baseName,
          text: '$year 年年度报告 · $scopeLabel',
        );
      } else {
        await service.shareImage(
          context,
          _reportKey,
          fileName: baseName,
          text: '$year 年年度报告 · $scopeLabel',
        );
      }
    } on Object catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('报告分享失败：$error')));
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  List<String> _currencies(
    List<TransactionRecord> transactions,
    String current,
  ) {
    return {
      'CNY',
      current,
      ...transactions.map((item) => item.currency.toUpperCase()),
    }.toList()
      ..sort();
  }
}

class _ScopeSelector extends ConsumerWidget {
  const _ScopeSelector({required this.scope});

  final AnalysisScope scope;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      children: [
        Text(
          '统计范围',
          style: TextStyle(
            color: context.appSecondaryText,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 12),
        for (final value in AnalysisScope.values) ...[
          ChoiceChip(
            label: Text(value.label),
            selected: value == scope,
            showCheckmark: false,
            onSelected: (_) =>
                ref.read(analysisScopeProvider.notifier).select(value),
          ),
          const SizedBox(width: 8),
        ],
      ],
    );
  }
}

class _AnnualReportCard extends StatelessWidget {
  const _AnnualReportCard({
    required this.report,
    required this.scopeLabel,
  });

  final AnnualFinancialReport report;
  final String scopeLabel;

  @override
  Widget build(BuildContext context) {
    final maxMonthly = report.months.fold<double>(
      0,
      (value, item) =>
          item.expense > value ? item.expense : value,
    );
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      padding: const EdgeInsets.only(bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppCard(
            color: const Color(0xFFF2F5E4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${report.year} 年财务概览',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 4),
                Text(
                  '$scopeLabel · ${report.currency}',
                  style: TextStyle(color: context.appSecondaryText),
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 20,
                  runSpacing: 14,
                  children: [
                    _Metric(
                      label: '收入',
                      value: '¥${MoneyFormatter.decimal(report.totalIncome)}',
                    ),
                    _Metric(
                      label: '支出',
                      value: '¥${MoneyFormatter.decimal(report.totalExpense)}',
                    ),
                    _Metric(
                      label: '年度结余',
                      value:
                          '${report.netCashflow < 0 ? '-' : '+'}¥${MoneyFormatter.decimal(report.netCashflow.abs())}',
                    ),
                    _Metric(
                      label: '结余率',
                      value: report.savingsRate == null
                          ? '—'
                          : '${(report.savingsRate! * 100).toStringAsFixed(1)}%',
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _YearOverYearLine(
                  label: '支出同比',
                  value: report.expenseYearOverYearPercent,
                ),
                _YearOverYearLine(
                  label: '收入同比',
                  value: report.incomeYearOverYearPercent,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text('财务体检', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          for (final check in report.checks) ...[
            _HealthCheckTile(check: check),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 8),
          Text('月度支出', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          AppCard(
            child: Column(
              children: [
                for (final month in report.months)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(
                      children: [
                        SizedBox(width: 36, child: Text('${month.month}月')),
                        Expanded(
                          child: LinearProgressIndicator(
                            value: maxMonthly <= 0
                                ? 0
                                : (month.expense / maxMonthly).clamp(0, 1),
                            minHeight: 8,
                            borderRadius: BorderRadius.circular(8),
                            backgroundColor: context.appPrimarySoft,
                          ),
                        ),
                        const SizedBox(width: 10),
                        SizedBox(
                          width: 88,
                          child: Text(
                            '¥${MoneyFormatter.whole(month.expense)}',
                            textAlign: TextAlign.right,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text('年度支出分类', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          AppCard(
            child: report.topExpenseCategories.isEmpty
                ? Text(
                    '本年度暂无支出记录',
                    style: TextStyle(color: context.appSecondaryText),
                  )
                : Column(
                    children: [
                      for (final item in report.topExpenseCategories)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 7),
                          child: Row(
                            children: [
                              Expanded(child: Text(item.name)),
                              Text('${item.count} 笔'),
                              const SizedBox(width: 16),
                              Text(
                                '¥${MoneyFormatter.decimal(item.amount)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 135,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: context.appSecondaryText)),
        const SizedBox(height: 3),
        Text(
          value,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
      ],
    ),
  );
}

class _YearOverYearLine extends StatelessWidget {
  const _YearOverYearLine({required this.label, required this.value});

  final String label;
  final double? value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 4),
    child: Text(
      value == null
          ? '$label：上年数据不足'
          : '$label：${value! >= 0 ? '+' : ''}${value!.toStringAsFixed(1)}%',
      style: TextStyle(color: context.appSecondaryText, fontSize: 12),
    ),
  );
}

class _HealthCheckTile extends StatelessWidget {
  const _HealthCheckTile({required this.check});

  final FinancialHealthCheck check;

  @override
  Widget build(BuildContext context) {
    final icon = switch (check.status) {
      FinancialHealthStatus.positive => Icons.check_circle_outline,
      FinancialHealthStatus.watch => Icons.info_outline,
      FinancialHealthStatus.attention => Icons.warning_amber_rounded,
      FinancialHealthStatus.insufficient => Icons.more_horiz,
    };
    return AppCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: context.appPrimary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        check.title,
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    Text(check.value),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  check.description,
                  style: TextStyle(
                    color: context.appSecondaryText,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

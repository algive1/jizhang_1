import '../../../core/models/analysis.dart';
import '../../analysis/domain/statistical_analysis_service.dart';

String assistantDate(DateTime value) =>
    '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

/// A query plan contains only read parameters; it cannot execute model code.
class AssistantQuery {
  const AssistantQuery({
    required this.range,
    this.period,
    this.categoryId,
    this.currency = 'CNY',
    this.advice = false,
  });
  final AnalysisDateRange range;
  final AnalysisPeriod? period;
  final String? categoryId;
  final String currency;
  final bool advice;

  static AssistantQuery? parse(String text, DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    final currencies = {
      for (final entry in const {
        'CNY': r'人民币|CNY|RMB',
        'USD': r'美元|美金|USD',
        'HKD': r'港币|港元|HKD',
        'JPY': r'日元|JPY',
        'EUR': r'欧元|EUR',
      }.entries)
        if (RegExp(entry.value, caseSensitive: false).hasMatch(text)) entry.key,
    };
    if (currencies.length > 1 ||
        RegExp(r'英镑|澳元|加元|GBP|AUD|CAD', caseSensitive: false).hasMatch(text))
      return null;
    var end = DateTime(today.year, today.month, today.day + 1);
    DateTime? start;
    AnalysisPeriod? period;
    final days = RegExp(r'(?:最近|近|过去)\s*([0-9]+)\s*天').firstMatch(text);
    if (days != null) {
      final count = int.parse(days.group(1)!);
      if (count < 1 || count > 366) return null;
      start = DateTime(today.year, today.month, today.day - count + 1);
    } else if (RegExp(r'最近|近期|近来|这段时间|(?:过去|近)(?:一个月|一周|一个星期|三个月)')
        .hasMatch(text)) {
      if (RegExp(r'(?:[0-9]+|两|二|四|五|六|七|八|九|十)\s*(?:个?月|周|年)').hasMatch(text))
        return null;
      period = RegExp(r'一周|一个星期|七天').hasMatch(text)
          ? AnalysisPeriod.last7Days
          : RegExp(r'三个月|一个季度').hasMatch(text)
          ? AnalysisPeriod.last90Days
          : AnalysisPeriod.last30Days;
    } else if (text.contains('昨天')) {
      start = DateTime(today.year, today.month, today.day - 1);
      end = today;
    } else if (text.contains('今天')) {
      start = today;
    } else if (RegExp(r'上周|本周|这周').hasMatch(text)) {
      start = DateTime(today.year, today.month, today.day - today.weekday + 1);
      if (text.contains('上周')) {
        end = start;
        start = DateTime(start.year, start.month, start.day - 7);
      }
    } else if (RegExp(r'上个月|上月').hasMatch(text)) {
      period = AnalysisPeriod.previousMonth;
    } else if (RegExp(r'本月|这个月|当月').hasMatch(text)) {
      period = AnalysisPeriod.currentMonth;
    } else if (RegExp(r'今年|本年').hasMatch(text)) {
      period = AnalysisPeriod.currentYear;
    } else if (RegExp(r'月|年|天|周|日|号|前|过去').hasMatch(text)) {
      return null;
    } else {
      period = AnalysisPeriod.last30Days;
    }
    // Reject conflicting or unsupported dates instead of silently using a default.
    if (RegExp(r'明天|下周|下月|下个月|去年|前年|前天|[0-9]+[年月日号]').hasMatch(text)) {
      return null;
    }
    final range = period == null
        ? AnalysisDateRange(start: start!, endExclusive: end)
        : const StatisticalAnalysisService().rangeFor(period, now);
    return AssistantQuery(
      range: range,
      period: period,
      currency: currencies.firstOrNull ?? 'CNY',
      advice: RegExp(r'分析|建议|合理|省钱|节省|为什么|总结|消费情况|消费习惯|消费结构').hasMatch(text),
    );
  }

  factory AssistantQuery.fromJson(Map<String, dynamic> json, DateTime now) {
    DateTime date(Object? value) {
      if (value is! String || !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) {
        throw const FormatException('查询日期无效');
      }
      final parsed = DateTime.parse(value);
      if (assistantDate(parsed) != value) throw const FormatException('查询日期无效');
      return parsed;
    }

    final start = date(json['startDate']), last = date(json['endDate']);
    final end = DateTime(last.year, last.month, last.day + 1);
    if (last.isAfter(DateTime(now.year, now.month, now.day)) ||
        !end.isAfter(start) ||
        end.difference(start).inDays > 366 ||
        !const ['CNY', 'USD', 'HKD', 'JPY', 'EUR'].contains(json['currency']) ||
        json['advice'] is! bool ||
        (json['categoryId'] != null && json['categoryId'] is! String)) {
      throw const FormatException('查询条件无效');
    }
    return AssistantQuery(
      range: AnalysisDateRange(start: start, endExclusive: end),
      currency: json['currency'] as String,
      categoryId: json['categoryId'] as String?,
      advice: json['advice'] as bool,
    );
  }

  String detailsRoute(
    String bookId, {
    String? categoryId,
    String kind = 'expense',
  }) => Uri(
    path: '/transactions/search',
    queryParameters: {
      'bookId': bookId,
      'start': assistantDate(range.start),
      'end': assistantDate(range.endExclusive),
      'currency': currency,
      'kind': kind,
      'categoryId': ?categoryId,
    },
  ).toString();
}

import 'dart:async';
import 'dart:convert';

import '../../../core/database/database_seeder.dart';
import '../../../core/models/transaction_record.dart';
import '../../../core/models/voice_bookkeeping.dart';

abstract interface class TransactionParser {
  Future<TransactionParseResult> parse(String text, {DateTime? now});
}

class RuleBasedTransactionParser implements TransactionParser {
  const RuleBasedTransactionParser();

  static final RegExp _timePattern = RegExp(
    r'(?:晚上|晚间|昨晚)?(?:[0-2]?\d|[一二三四五六七八九十两]+)点(?:[0-5]?\d分?)?',
  );

  @override
  Future<TransactionParseResult> parse(String text, {DateTime? now}) async {
    final clock = now ?? DateTime.now();
    final clauses = text
        .split(RegExp(r'[,，。；;\n]+'))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
    final globalAccount = _accountFor(text);
    final parsed = <ParsedVoiceTransaction>[];
    final unresolved = <String>[];
    var contextTime = clock;

    for (final clause in clauses) {
      contextTime = _resolveDateTime(clause, contextTime, clock);
      final withoutTime = clause.replaceAll(_timePattern, '');
      final amountMatches = RegExp(r'\d+(?:\.\d{1,2})?')
          .allMatches(withoutTime)
          .toList();
      if (amountMatches.isEmpty) {
        if (!_isContextOnly(clause)) unresolved.add(clause);
        continue;
      }
      final match = amountMatches.last;
      final amount = double.tryParse(match.group(0)!);
      if (amount == null || amount <= 0) {
        unresolved.add(clause);
        continue;
      }
      final type = _typeFor(clause);
      final category = _categoryFor(clause, type);
      final account = _accountFor(clause) ?? globalAccount;
      final merchant = _merchantFor(clause, match.group(0)!);
      parsed.add(
        ParsedVoiceTransaction(
          type: type,
          amount: amount,
          categoryId: category?.$1,
          categoryName: category?.$2,
          subcategoryName: category?.$3,
          accountId: account?.$1,
          accountName: account?.$2,
          merchant: merchant,
          occurredAt: contextTime,
          confidence: category == null ? .58 : (account == null ? .76 : .94),
          source: VoiceParsingSource.rule,
          rawFragment: clause,
        ),
      );
    }
    return TransactionParseResult(
      transactions: parsed,
      unresolvedFragments: unresolved,
      usedAi: false,
    );
  }

  TransactionType _typeFor(String clause) {
    return RegExp(r'工资|奖金|收入|报销|退款').hasMatch(clause)
        ? TransactionType.income
        : TransactionType.expense;
  }

  (String, String, String?)? _categoryFor(String clause, TransactionType type) {
    if (type == TransactionType.income) {
      if (clause.contains('工资')) return ('income-salary', '工资', null);
      if (clause.contains('奖金')) return ('income-bonus', '奖金', null);
      if (clause.contains('退款')) return ('income-refund', '退款', null);
      return ('income-other', '其他收入', null);
    }
    const rules = [
      (r'午饭|早餐|晚饭|吃饭|咖啡|外卖|餐厅|面馆', 'expense-food', '餐饮', null),
      (r'滴滴|打车|出租|地铁|公交|加油', 'expense-transport', '交通', '打车'),
      (r'唱歌|KTV|电影|游戏', 'expense-entertainment', '娱乐', '休闲娱乐'),
      (r'房租|物业', 'expense-housing', '住房', null),
      (r'药|医院|挂号', 'expense-medical', '医疗', null),
      (r'买菜|超市|购物|衣服', 'expense-shopping', '购物', null),
      (r'机票|酒店|旅行', 'expense-travel', '旅行', null),
    ];
    for (final rule in rules) {
      if (RegExp(rule.$1, caseSensitive: false).hasMatch(clause)) {
        return (rule.$2, rule.$3, rule.$4);
      }
    }
    return null;
  }

  (String, String)? _accountFor(String text) {
    if (text.contains('微信')) return (SeedIds.wechatAccount, '微信');
    if (text.contains('支付宝')) return (SeedIds.alipayAccount, '支付宝');
    if (text.contains('现金')) return (SeedIds.cashAccount, '现金');
    if (RegExp(r'银行卡|储蓄卡|信用卡').hasMatch(text)) {
      return (SeedIds.bankAccount, '银行卡');
    }
    return null;
  }

  DateTime _resolveDateTime(String clause, DateTime context, DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    var date = DateTime(context.year, context.month, context.day);
    if (clause.contains('前天')) {
      date = today.subtract(const Duration(days: 2));
    } else if (clause.contains('昨天') || clause.contains('昨晚')) {
      date = today.subtract(const Duration(days: 1));
    } else if (clause.contains('今天')) {
      date = today;
    } else if (clause.contains('上周六')) {
      final thisMonday = today.subtract(Duration(days: today.weekday - 1));
      date = thisMonday.subtract(const Duration(days: 2));
    }

    var hour = context.hour;
    var minute = context.minute;
    final time = _timePattern.firstMatch(clause)?.group(0);
    if (time != null) {
      final value = RegExp(r'([0-2]?\d|[一二三四五六七八九十两]+)点')
          .firstMatch(time)
          ?.group(1);
      final parsedHour = value == null ? null : _parseHour(value);
      if (parsedHour != null) hour = parsedHour;
      final parsedMinute = RegExp(r'点([0-5]?\d)分?').firstMatch(time)?.group(1);
      minute = int.tryParse(parsedMinute ?? '') ?? 0;
      if (RegExp(r'晚上|晚间|昨晚').hasMatch(time) && hour < 12) hour += 12;
    } else if (clause.contains('午饭')) {
      hour = 12;
      minute = 0;
    } else if (clause.contains('早餐')) {
      hour = 8;
      minute = 0;
    } else if (clause.contains('昨晚')) {
      hour = 20;
      minute = 0;
    }
    return DateTime(date.year, date.month, date.day, hour, minute);
  }

  int? _parseHour(String value) {
    final digits = int.tryParse(value);
    if (digits != null) return digits;
    const numbers = {
      '一': 1,
      '二': 2,
      '两': 2,
      '三': 3,
      '四': 4,
      '五': 5,
      '六': 6,
      '七': 7,
      '八': 8,
      '九': 9,
    };
    if (value == '十') return 10;
    if (value.startsWith('十')) return 10 + (numbers[value.substring(1)] ?? 0);
    if (value.endsWith('十')) return (numbers[value.substring(0, 1)] ?? 0) * 10;
    if (value.contains('十')) {
      final parts = value.split('十');
      return (numbers[parts.first] ?? 0) * 10 + (numbers[parts.last] ?? 0);
    }
    return numbers[value];
  }

  bool _isContextOnly(String clause) =>
      RegExp(r'^(?:都是|都用|使用|走的)?(?:微信|支付宝|现金|银行卡)[付款支付的]*$').hasMatch(clause);

  String? _merchantFor(String clause, String amountText) {
    final value = clause
        .replaceAll(_timePattern, '')
        .replaceAll(amountText, '')
        .replaceAll(RegExp(r'今天|昨天|昨晚|前天|上周六|都是|微信|支付宝|银行卡|现金|元|块'), '')
        .replaceAll(RegExp(r'跟朋友|回家|付款|支付|花了|花'), '')
        .trim();
    return value.isEmpty ? null : value;
  }
}

abstract interface class AiParsingGateway {
  Future<String> parseToJson({
    required String text,
    required String schemaVersion,
  });
}

class AiTransactionJsonDecoder {
  const AiTransactionJsonDecoder();

  List<ParsedVoiceTransaction> decode(String raw) {
    final value = jsonDecode(raw);
    if (value is! List) {
      throw const FormatException('AI result must be a JSON array');
    }
    return value
        .map((item) {
          if (item is! Map<String, dynamic>) {
            throw const FormatException('Every AI item must be an object');
          }
          final type = item['type'];
          final amount = item['amount'];
          final category = item['category'];
          final occurredAt = item['occurredAt'];
          final account = item['account'];
          if (type is! String ||
              amount is! num ||
              amount <= 0 ||
              category is! String ||
              occurredAt is! String ||
              account is! String) {
            throw const FormatException(
              'AI item does not match transaction schema',
            );
          }
          final parsedTime = DateTime.tryParse(occurredAt);
          if (parsedTime == null) {
            throw const FormatException('Invalid occurredAt');
          }
          final transactionType = switch (type) {
            'expense' => TransactionType.expense,
            'income' => TransactionType.income,
            _ => throw const FormatException('Unsupported transaction type'),
          };
          return ParsedVoiceTransaction(
            type: transactionType,
            amount: amount.toDouble(),
            categoryName: category,
            subcategoryName: item['subcategory'] as String?,
            accountName: account,
            merchant: item['merchant'] as String?,
            occurredAt: parsedTime,
            confidence: (item['confidence'] as num?)?.toDouble() ?? .7,
            source: VoiceParsingSource.ai,
            rawFragment: item['rawFragment'] as String? ?? '',
          );
        })
        .toList(growable: false);
  }
}

class CachedRetryingAiTransactionParser implements TransactionParser {
  CachedRetryingAiTransactionParser({
    required this.gateway,
    this.decoder = const AiTransactionJsonDecoder(),
    this.timeout = const Duration(seconds: 12),
    this.maxAttempts = 2,
  });

  final AiParsingGateway gateway;
  final AiTransactionJsonDecoder decoder;
  final Duration timeout;
  final int maxAttempts;
  final Map<String, TransactionParseResult> _cache = {};

  @override
  Future<TransactionParseResult> parse(String text, {DateTime? now}) async {
    final cached = _cache[text];
    if (cached != null) return cached;
    Object? lastError;
    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      try {
        final raw = await gateway
            .parseToJson(text: text, schemaVersion: 'voice_transaction_v1')
            .timeout(timeout);
        final result = TransactionParseResult(
          transactions: decoder.decode(raw),
          unresolvedFragments: const [],
          usedAi: true,
        );
        _cache[text] = result;
        return result;
      } on TimeoutException catch (error) {
        lastError = error;
      } on FormatException catch (error) {
        lastError = error;
      }
    }
    throw StateError(
      'AI parsing failed after $maxAttempts attempts: $lastError',
    );
  }
}

class HybridTransactionParser implements TransactionParser {
  const HybridTransactionParser({
    required this.rules,
    required this.canUseAi,
    this.ai,
  });

  final TransactionParser rules;
  final TransactionParser? ai;
  final bool Function() canUseAi;

  @override
  Future<TransactionParseResult> parse(String text, {DateTime? now}) async {
    final ruleResult = await rules.parse(text, now: now);
    final needsAi =
        ruleResult.transactions.isEmpty ||
        ruleResult.unresolvedFragments.isNotEmpty ||
        ruleResult.transactions.any((item) => item.confidence < .6);
    if (!needsAi || ai == null || !canUseAi()) return ruleResult;
    try {
      return await ai!.parse(text, now: now);
    } on StateError {
      return ruleResult;
    }
  }
}

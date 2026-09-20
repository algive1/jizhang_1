import '../../../core/models/transaction_record.dart';
import '../../../core/models/voice_bookkeeping.dart';
import 'local_ocr_service.dart';

enum BillScreenshotProvider { wechat, alipay, unknown }

class BillScreenshotParser {
  const BillScreenshotParser();

  TransactionParseResult? parse(LocalOcrResult ocr, {DateTime? now}) {
    if (ocr.elements.isEmpty) return null;
    final provider = _provider(ocr.text);
    if (provider == BillScreenshotProvider.unknown) return null;

    final rows = _rows(ocr.elements);
    final transactions = <ParsedVoiceTransaction>[];
    final seen = <String>{};
    final reference = now ?? DateTime.now();

    for (var i = 0; i < rows.length; i++) {
      final amountLine = rows[i];
      final amount = _amountIn(amountLine);
      if (amount == null || _isHeader(amountLine)) continue;

      final nearby = <_Line>[amountLine];
      for (var j = i - 2; j <= i + 3; j++) {
        if (j >= 0 &&
            j < rows.length &&
            j != i &&
            (rows[j].y - amountLine.y).abs() < 180) {
          nearby.add(rows[j]);
        }
      }
      nearby.sort((a, b) => a.y.compareTo(b.y));

      final dateLine = nearby
          .where((line) => _date(line.text, reference) != null)
          .firstOrNull;
      if (dateLine == null) continue; // Never invent finance timestamps.

      final merchant = _merchant(nearby, amountLine, reference);
      if (merchant.isEmpty) continue;

      final occurredAt = _date(dateLine.text, reference)!;
      final income = amount.sign > 0 || _incomeSemantics(merchant);
      final value = amount.abs();
      if (value <= 0 || value > 100000000) continue;

      final key =
          '${provider.name}|${occurredAt.millisecondsSinceEpoch}|'
          '${value.toStringAsFixed(2)}|${_fingerprint(merchant)}';
      if (!seen.add(key)) continue;

      final classification = _classification(
        provider: provider,
        merchant: merchant,
        nearby: nearby,
        amountLine: amountLine,
        dateLine: dateLine,
        reference: reference,
      );
      final confidence = _confidence(
        amountLine: amountLine,
        dateLine: dateLine,
        merchant: merchant,
      );

      transactions.add(
        ParsedVoiceTransaction(
          type: income ? TransactionType.income : TransactionType.expense,
          amount: value,
          occurredAt: occurredAt,
          confidence: confidence,
          source: VoiceParsingSource.rule,
          merchant: merchant,
          categoryName: classification.$1,
          subcategoryName: classification.$2,
          rawFragment: nearby.map((line) => line.text).join(' | '),
        ),
      );
    }

    if (transactions.isEmpty) return null;
    transactions.sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
    return TransactionParseResult(
      transactions: transactions,
      unresolvedFragments: const [],
      usedAi: false,
    );
  }

  BillScreenshotProvider _provider(String text) {
    if (RegExp('全部账单|查找交易|收支统计').hasMatch(text)) {
      return BillScreenshotProvider.wechat;
    }
    if (RegExp('搜索交易记录|收支分析|本月已省|退款.*订单').hasMatch(text)) {
      return BillScreenshotProvider.alipay;
    }
    return BillScreenshotProvider.unknown;
  }

  List<_Line> _rows(List<OcrElement> input) {
    final elements = [...input]
      ..sort((a, b) {
        final dy = a.rect.centerY.compareTo(b.rect.centerY);
        return dy != 0 ? dy : a.rect.left.compareTo(b.rect.left);
      });
    final rows = <_Line>[];
    for (final element in elements) {
      final tolerance =
          ((element.rect.bottom - element.rect.top).abs() * .65).clamp(8, 30);
      _Line? target;
      for (final row in rows.reversed) {
        if ((row.y - element.rect.centerY).abs() <= tolerance) {
          target = row;
          break;
        }
        if (element.rect.centerY - row.y > 35) break;
      }
      if (target == null) {
        rows.add(_Line(element.rect.centerY, [element]));
      } else {
        target.elements.add(element);
        target.elements.sort((a, b) => a.rect.left.compareTo(b.rect.left));
      }
    }
    return rows;
  }

  double? _amountIn(_Line line) {
    final right = [...line.elements]
      ..sort((a, b) => b.rect.right.compareTo(a.rect.right));
    for (final element in right.take(3)) {
      var value = element.text
          .trim()
          .replaceAll('￥', '')
          .replaceAll('¥', '')
          .replaceAll('元', '')
          .replaceAll('，', ',')
          .replaceAll('。', '.')
          .replaceAll('−', '-')
          .replaceAll('–', '-')
          .replaceAll('—', '-')
          .replaceAll(RegExp(r'\s+'), '');
      // Repair OCR confusions only after the token is known to be money-like.
      if (!RegExp(r'^[+\-]?[0-9OoIl,.]+$').hasMatch(value)) continue;
      value = value
          .replaceAll(RegExp('[Oo]'), '0')
          .replaceAll(RegExp('[Il]'), '1')
          .replaceAll(',', '');
      final parsed = double.tryParse(value);
      if (parsed != null &&
          (value.contains('.') ||
              value.startsWith('+') ||
              value.startsWith('-'))) {
        return parsed;
      }
    }
    return null;
  }

  bool _isHeader(_Line line) => RegExp(
    '支出.*收入|收入.*支出|本月已省|收支分析|收支统计|'
    '搜索交易记录|全部.*支出.*转账.*退款.*订单',
  ).hasMatch(line.text);

  String _merchant(
    List<_Line> nearby,
    _Line amountLine,
    DateTime reference,
  ) {
    final amountLineMerchant = _stripMoney(amountLine).trim();
    if (amountLineMerchant.isNotEmpty && !_uiNoise(amountLineMerchant)) {
      return _normalizeMerchant(amountLineMerchant);
    }

    final candidates = nearby
        .where(
          (line) =>
              line != amountLine &&
              _date(line.text, reference) == null &&
              !_isHeader(line),
        )
        .toList()
      ..sort(
        (a, b) => (a.y - amountLine.y)
            .abs()
            .compareTo((b.y - amountLine.y).abs()),
      );
    for (final line in candidates) {
      final text = _stripMoney(line).trim();
      if (text.isEmpty || _uiNoise(text) || _looksLikeCategory(text)) continue;
      return _normalizeMerchant(text);
    }
    return '';
  }

  String _stripMoney(_Line line) {
    var text = line.text;
    for (final element in line.elements) {
      if (_moneyLike(element.text)) {
        text = text.replaceFirst(element.text, '');
      }
    }
    return text;
  }

  (String?, String?) _classification({
    required BillScreenshotProvider provider,
    required String merchant,
    required List<_Line> nearby,
    required _Line amountLine,
    required _Line dateLine,
    required DateTime reference,
  }) {
    final utility = _utilityClassification(merchant);
    if (utility != null) return utility;
    if (provider != BillScreenshotProvider.alipay) return (null, null);

    for (final line in nearby) {
      if (line.y <= amountLine.y + 2 || line.y >= dateLine.y - 2) continue;
      if (_date(line.text, reference) != null || _isHeader(line)) continue;
      final text = _cleanCategoryLine(line.text);
      if (text.isEmpty || _uiNoise(text)) continue;
      final mapped = _mapAlipayCategory(text);
      if (mapped != null) return mapped;
    }
    return (null, null);
  }

  (String, String)? _utilityClassification(String merchant) {
    if (merchant.contains('水费')) return ('生活缴费', '水费');
    if (merchant.contains('电费')) return ('生活缴费', '电费');
    if (merchant.contains('燃气')) return ('生活缴费', '燃气费');
    if (merchant.contains('话费')) return ('生活缴费', '话费');
    if (merchant.contains('宽带')) return ('生活缴费', '宽带');
    return null;
  }

  (String, String?)? _mapAlipayCategory(String raw) {
    final value = raw.replaceAll(RegExp(r'\s+'), '');
    if (value == '其他') return null;
    if (RegExp('餐饮|美食|外卖').hasMatch(value)) return ('餐饮', null);
    if (RegExp('交通|出行|打车').hasMatch(value)) return ('交通', null);
    if (RegExp('日用百货|服饰|购物|数码|美妆|护肤').hasMatch(value)) {
      return ('购物', null);
    }
    if (RegExp('充值缴费|生活缴费').hasMatch(value)) return ('生活缴费', null);
    if (RegExp('医疗|健康').hasMatch(value)) return ('医疗', null);
    if (RegExp('教育|培训').hasMatch(value)) return ('教育培训', null);
    if (RegExp('休闲|娱乐|游戏').hasMatch(value)) return ('娱乐', null);
    if (RegExp('住房|物业|租房').hasMatch(value)) return ('住房', null);
    if (RegExp('汽车|养车').hasMatch(value)) return ('汽车', null);
    if (RegExp('旅行|酒店|机票').hasMatch(value)) return ('旅行', null);
    if (RegExp('投资|理财').hasMatch(value)) return ('投资收益', null);
    return null;
  }

  String _cleanCategoryLine(String value) => value
      .replaceAll('自动扣款成功', '')
      .replaceAll('交易成功', '')
      .replaceAll('付款成功', '')
      .trim();

  bool _looksLikeCategory(String value) => _mapAlipayCategory(
        _cleanCategoryLine(value),
      ) !=
      null;

  bool _moneyLike(String text) => RegExp(
    r'^[\s¥￥+\-−–—0-9OoIl,.]+(?:元)?$',
  ).hasMatch(text.trim());

  bool _uiNoise(String text) => RegExp(
    '全部账单|查找交易|搜索交易记录|全部|支出|转账|退款|订单|筛选|'
    '收支分析|收支统计|自动扣款成功|交易成功|付款成功|贴纸待领取',
  ).hasMatch(text);

  DateTime? _date(String input, DateTime reference) {
    final text = input.replaceAll(' ', '');
    var match = RegExp(
      r'(\d{1,2})月(\d{1,2})日(\d{1,2}):(\d{2})',
    ).firstMatch(text);
    if (match != null) {
      return _dateWithoutYear(
        reference,
        int.parse(match[1]!),
        int.parse(match[2]!),
        int.parse(match[3]!),
        int.parse(match[4]!),
      );
    }
    match = RegExp(
      r'(\d{1,2})[-/.](\d{1,2})(?:日)?(\d{1,2}):(\d{2})',
    ).firstMatch(text);
    if (match != null) {
      return _dateWithoutYear(
        reference,
        int.parse(match[1]!),
        int.parse(match[2]!),
        int.parse(match[3]!),
        int.parse(match[4]!),
      );
    }
    return null;
  }

  DateTime _dateWithoutYear(
    DateTime reference,
    int month,
    int day,
    int hour,
    int minute,
  ) {
    var candidate = DateTime(reference.year, month, day, hour, minute);
    // A transaction screenshot cannot contain a future transaction. Around
    // New Year, month/day-only rows therefore belong to the previous year.
    if (candidate.isAfter(reference.add(const Duration(days: 2)))) {
      candidate = DateTime(reference.year - 1, month, day, hour, minute);
    }
    return candidate;
  }

  bool _incomeSemantics(String merchant) => RegExp(
    '收益发放|收款|商家转账-来自|转账-来自|红包-来自|退款',
  ).hasMatch(merchant);

  String _normalizeMerchant(String value) => value
      .replaceAll('&quot;', '"')
      .replaceAll('&#34;', '"')
      .replaceAll('&amp;', '&')
      .replaceAll('&#39;', "'")
      .replaceAll('&apos;', "'")
      .replaceFirst(RegExp(r'^(扫|扫二|扫二维码|扫码)付款[-—]?给'), '')
      .replaceFirst(RegExp(r'^收钱码收款[-—]?来自'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .replaceAll(RegExp(r'^[\"“”]+|[\"“”]+$'), '')
      .trim();

  String _fingerprint(String value) => _normalizeMerchant(value)
      .replaceAll(RegExp(r'[\s*·._\-—]+'), '')
      .toLowerCase();

  double _confidence({
    required _Line amountLine,
    required _Line dateLine,
    required String merchant,
  }) {
    var score = .35 + .25 + .15 + .10;
    if (merchant.length >= 2) score += .05;
    if (amountLine.elements.length >= 2) score += .05;
    return score.clamp(0, 1);
  }
}

class _Line {
  _Line(this.y, this.elements);

  final double y;
  final List<OcrElement> elements;

  String get text => elements.map((element) => element.text).join(' ');
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

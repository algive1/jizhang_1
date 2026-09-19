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
      final amount = _amountIn(rows[i]);
      if (amount == null || _isHeader(rows[i])) continue;
      final nearby = <_Line>[rows[i]];
      for (var j = i - 2; j <= i + 3; j++) {
        if (j >= 0 && j < rows.length && j != i && (rows[j].y - rows[i].y).abs() < 150) nearby.add(rows[j]);
      }
      nearby.sort((a,b) => a.y.compareTo(b.y));
      final dateLine = nearby.where((l) => _date(l.text, reference) != null).firstOrNull;
      if (dateLine == null) continue; // finance data: never invent a timestamp
      final merchant = _merchant(nearby, rows[i], provider);
      if (merchant.isEmpty) continue;
      final occurredAt = _date(dateLine.text, reference)!;
      final income = amount.sign > 0 || _incomeSemantics(merchant);
      final value = amount.abs();
      if (value <= 0 || value > 100000000) continue;
      final key = '${provider.name}|${occurredAt.millisecondsSinceEpoch}|${value.toStringAsFixed(2)}|${_fingerprint(merchant)}';
      if (!seen.add(key)) continue;
      final confidence = _confidence(amountLine: rows[i], dateLine: dateLine, merchant: merchant);
      transactions.add(ParsedVoiceTransaction(
        type: income ? TransactionType.income : TransactionType.expense,
        amount: value,
        occurredAt: occurredAt,
        confidence: confidence,
        source: VoiceParsingSource.rule,
        merchant: _normalizeMerchant(merchant),
        rawFragment: nearby.map((e) => e.text).join(' | '),
      ));
    }
    if (transactions.isEmpty) return null;
    transactions.sort((a,b) => b.occurredAt.compareTo(a.occurredAt));
    return TransactionParseResult(transactions: transactions, unresolvedFragments: const [], usedAi: false);
  }

  BillScreenshotProvider _provider(String text) {
    if (RegExp('全部账单|查找交易|收支统计').hasMatch(text)) return BillScreenshotProvider.wechat;
    if (RegExp('搜索交易记录|收支分析|本月已省|退款.*订单').hasMatch(text)) return BillScreenshotProvider.alipay;
    return BillScreenshotProvider.unknown;
  }

  List<_Line> _rows(List<OcrElement> input) {
    final elements = [...input]..sort((a,b) {
      final dy = a.rect.centerY.compareTo(b.rect.centerY);
      return dy != 0 ? dy : a.rect.left.compareTo(b.rect.left);
    });
    final rows = <_Line>[];
    for (final e in elements) {
      final tolerance = ((e.rect.bottom - e.rect.top).abs() * .65).clamp(8, 30);
      _Line? target;
      for (final row in rows.reversed) {
        if ((row.y - e.rect.centerY).abs() <= tolerance) { target = row; break; }
        if (e.rect.centerY - row.y > 35) break;
      }
      if (target == null) {
        rows.add(_Line(e.rect.centerY, [e]));
      } else {
        target.elements.add(e);
        target.elements.sort((a,b) => a.rect.left.compareTo(b.rect.left));
      }
    }
    return rows;
  }

  double? _amountIn(_Line line) {
    final right = [...line.elements]..sort((a,b) => b.rect.right.compareTo(a.rect.right));
    for (final e in right.take(3)) {
      var s = e.text.trim()
        .replaceAll('￥','').replaceAll('¥','').replaceAll('元','')
        .replaceAll('，',',').replaceAll('。','.')
        .replaceAll('−','-').replaceAll('–','-').replaceAll('—','-')
        .replaceAll(RegExp(r'\s+'),'');
      // OCR-confusion repair is deliberately limited to amount candidates.
      if (RegExp(r'^[+\-]?[0-9OoIl,.]+$').hasMatch(s)) {
        s = s.replaceAll(RegExp('[Oo]'),'0').replaceAll(RegExp('[Il]'),'1').replaceAll(',','');
        final v = double.tryParse(s);
        if (v != null && (s.contains('.') || s.startsWith('+') || s.startsWith('-'))) return v;
      }
    }
    return null;
  }

  bool _isHeader(_Line line) => RegExp('支出.*收入|本月已省|收支分析|收支统计').hasMatch(line.text);

  String _merchant(List<_Line> nearby, _Line amountLine, BillScreenshotProvider provider) {
    final candidates = <String>[];
    for (final line in nearby) {
      if (_date(line.text, DateTime.now()) != null || _isHeader(line)) continue;
      var text = line.text;
      final amount = _amountIn(line);
      if (amount != null) {
        for (final e in line.elements) {
          if (_moneyLike(e.text)) text = text.replaceFirst(e.text, '');
        }
      }
      text = text.trim();
      if (text.isEmpty || _uiNoise(text)) continue;
      candidates.add(text);
    }
    return candidates.isEmpty ? '' : candidates.first;
  }

  bool _moneyLike(String text) => RegExp(r'^[\s¥￥+\-−–—0-9OoIl,.]+(?:元)?$').hasMatch(text.trim());
  bool _uiNoise(String text) => RegExp('全部账单|查找交易|搜索交易记录|全部|支出|转账|退款|订单|筛选|收支分析|收支统计').hasMatch(text);

  DateTime? _date(String input, DateTime ref) {
    final s = input.replaceAll(' ', '');
    var m = RegExp(r'(\d{1,2})月(\d{1,2})日(\d{1,2}):(\d{2})').firstMatch(s);
    if (m != null) return DateTime(ref.year, int.parse(m[1]!), int.parse(m[2]!), int.parse(m[3]!), int.parse(m[4]!));
    m = RegExp(r'(\d{1,2})[-/.](\d{1,2})(?:日)?(\d{1,2}):(\d{2})').firstMatch(s);
    if (m != null) return DateTime(ref.year, int.parse(m[1]!), int.parse(m[2]!), int.parse(m[3]!), int.parse(m[4]!));
    return null;
  }

  bool _incomeSemantics(String merchant) => RegExp('收益发放|收款|商家转账-来自|转账-来自|红包-来自|退款').hasMatch(merchant);
  String _normalizeMerchant(String value) => value
      .replaceFirst(RegExp(r'^(扫|扫二|扫二维码|扫码)付款[-—]?给'), '')
      .replaceFirst(RegExp(r'^收钱码收款[-—]?来自'), '')
      .trim();
  String _fingerprint(String value) => _normalizeMerchant(value).replaceAll(RegExp(r'[\s*·._\-—]+'), '').toLowerCase();

  double _confidence({required _Line amountLine, required _Line dateLine, required String merchant}) {
    var score = .35 + .25 + .15 + .10; // amount, datetime, geometry, merchant
    if (merchant.length >= 2) score += .05;
    if (amountLine.elements.length >= 2) score += .05;
    return score.clamp(0, 1);
  }
}

class _Line {
  _Line(this.y, this.elements);
  final double y;
  final List<OcrElement> elements;
  String get text => elements.map((e) => e.text).join(' ');
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

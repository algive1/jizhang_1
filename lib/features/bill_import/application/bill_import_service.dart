import 'dart:convert';
import 'dart:io';

import '../../../core/models/transaction_record.dart';

enum BillImportProvider { wechat, alipay }

class ImportedBillRow {
  const ImportedBillRow({
    required this.provider,
    required this.occurredAt,
    required this.type,
    required this.amount,
    required this.merchant,
    required this.note,
    required this.externalId,
    required this.paymentMethod,
    required this.raw,
  });

  final BillImportProvider provider;
  final DateTime occurredAt;
  final TransactionType type;
  final double amount;
  final String merchant;
  final String note;
  final String? externalId;
  final String? paymentMethod;
  final Map<String, String> raw;
}

class BillImportResult {
  const BillImportResult({
    required this.provider,
    required this.rows,
    required this.skipped,
  });

  final BillImportProvider provider;
  final List<ImportedBillRow> rows;
  final int skipped;
}

class BillImportService {
  const BillImportService();

  Future<BillImportResult> parseFile(String path) async {
    final bytes = await File(path).readAsBytes();
    final text = utf8.decode(bytes, allowMalformed: true).replaceFirst('\ufeff', '');
    return parseCsv(text);
  }

  BillImportResult parseCsv(String input) {
    final rows = _parseCsv(input)
        .where((row) => row.any((cell) => cell.trim().isNotEmpty))
        .toList(growable: false);
    if (rows.isEmpty) throw const FormatException('账单文件为空');

    final headerIndex = rows.indexWhere((row) {
      final normalized = row.map(_normalizeHeader).toSet();
      final hasAmount = normalized.any((h) => h.contains('金额'));
      final hasTime = normalized.any(
        (h) => h.contains('交易时间') ||
            h.contains('付款时间') ||
            h.contains('交易创建时间'),
      );
      return hasAmount && hasTime;
    });
    if (headerIndex < 0) {
      throw const FormatException('未识别到微信/支付宝账单表头，请导入官方 CSV 账单文件');
    }

    final headers = rows[headerIndex].map(_normalizeHeader).toList(growable: false);
    final provider = _provider(headers);
    final output = <ImportedBillRow>[];
    var skipped = 0;
    for (final values in rows.skip(headerIndex + 1)) {
      if (values.every((value) => value.trim().isEmpty)) continue;
      final map = <String, String>{
        for (var index = 0; index < headers.length; index++)
          headers[index]: index < values.length ? values[index].trim() : '',
      };
      final parsed = _parseRow(provider, map);
      if (parsed == null) {
        skipped++;
      } else {
        output.add(parsed);
      }
    }
    if (output.isEmpty) {
      throw const FormatException('账单中没有可导入的收支记录');
    }
    return BillImportResult(
      provider: provider,
      rows: output,
      skipped: skipped,
    );
  }

  BillImportProvider _provider(List<String> headers) {
    final joined = headers.join('|');
    if (joined.contains('微信支付') ||
        joined.contains('交易单号') ||
        joined.contains('商户单号') ||
        headers.any((h) => h == '收/支')) {
      // Both providers may contain 收/支; Alipay is distinguished by its
      // characteristic 商家订单号/资金状态 fields.
      if (joined.contains('商家订单号') ||
          joined.contains('资金状态') ||
          joined.contains('交易来源地')) {
        return BillImportProvider.alipay;
      }
      return BillImportProvider.wechat;
    }
    if (joined.contains('商家订单号') || joined.contains('资金状态')) {
      return BillImportProvider.alipay;
    }
    throw const FormatException('暂不支持此账单格式');
  }

  ImportedBillRow? _parseRow(
    BillImportProvider provider,
    Map<String, String> map,
  ) {
    final direction = _first(map, const ['收/支', '收支', '类型']);
    final type = _transactionType(direction);
    if (type == null) return null;

    final status = _first(map, const ['当前状态', '交易状态', '资金状态']);
    if (_isIgnoredStatus(status)) return null;

    final amountText = _first(
      map,
      const ['金额(元)', '金额（元）', '金额', '交易金额(元)', '交易金额（元）'],
    );
    final amount = _money(amountText);
    if (amount == null || amount <= 0) return null;

    final timeText = _first(
      map,
      const ['交易时间', '付款时间', '交易创建时间', '创建时间'],
    );
    final occurredAt = _time(timeText);
    if (occurredAt == null) return null;

    final merchant = _first(
      map,
      const ['交易对方', '商户', '对方', '收款方'],
    );
    final goods = _first(map, const ['商品', '商品名称']);
    final note = _first(map, const ['备注', '交易备注']);
    final externalId = _emptyToNull(
      _first(map, const ['交易单号', '交易号', '商家订单号', '商户单号']),
    );
    final paymentMethod = _emptyToNull(
      _first(map, const ['支付方式', '付款方式']),
    );

    return ImportedBillRow(
      provider: provider,
      occurredAt: occurredAt,
      type: type,
      amount: amount,
      merchant: merchant.isNotEmpty ? merchant : goods,
      note: [goods, note]
          .where((value) => value.trim().isNotEmpty)
          .toSet()
          .join(' · '),
      externalId: externalId,
      paymentMethod: paymentMethod,
      raw: map,
    );
  }

  TransactionType? _transactionType(String value) {
    final text = value.replaceAll(' ', '');
    if (text.contains('支出') || text == '支') return TransactionType.expense;
    if (text.contains('收入') || text == '收') return TransactionType.income;
    return null;
  }

  bool _isIgnoredStatus(String status) {
    final value = status.replaceAll(' ', '');
    return RegExp('已退款|退款成功|交易关闭|已关闭|已撤销|退款中').hasMatch(value);
  }

  double? _money(String value) {
    final cleaned = value
        .replaceAll(RegExp(r'[¥￥,\s]'), '')
        .replaceAll('元', '');
    return double.tryParse(cleaned);
  }

  DateTime? _time(String value) {
    final cleaned = value.trim().replaceAll('/', '-');
    return DateTime.tryParse(cleaned);
  }

  String _first(Map<String, String> map, List<String> keys) {
    for (final key in keys) {
      final exact = map[key];
      if (exact != null && exact.trim().isNotEmpty) return exact.trim();
      for (final entry in map.entries) {
        if (_normalizeHeader(entry.key) == _normalizeHeader(key) &&
            entry.value.trim().isNotEmpty) {
          return entry.value.trim();
        }
      }
    }
    return '';
  }

  String _normalizeHeader(String value) => value
      .trim()
      .replaceAll('\ufeff', '')
      .replaceAll(RegExp(r'\s+'), '')
      .replaceAll(':', '')
      .replaceAll('：', '');

  String? _emptyToNull(String value) {
    final cleaned = value.trim();
    return cleaned.isEmpty ? null : cleaned;
  }

  List<List<String>> _parseCsv(String input) {
    final rows = <List<String>>[];
    var row = <String>[];
    final field = StringBuffer();
    var quoted = false;
    for (var i = 0; i < input.length; i++) {
      final char = input[i];
      if (char == '"') {
        if (quoted && i + 1 < input.length && input[i + 1] == '"') {
          field.write('"');
          i++;
        } else {
          quoted = !quoted;
        }
        continue;
      }
      if (!quoted && char == ',') {
        row.add(field.toString());
        field.clear();
        continue;
      }
      if (!quoted && (char == '\n' || char == '\r')) {
        if (char == '\r' && i + 1 < input.length && input[i + 1] == '\n') i++;
        row.add(field.toString());
        field.clear();
        rows.add(row);
        row = <String>[];
        continue;
      }
      field.write(char);
    }
    if (field.isNotEmpty || row.isNotEmpty) {
      row.add(field.toString());
      rows.add(row);
    }
    return rows;
  }
}

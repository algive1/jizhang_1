import 'dart:convert';
import 'dart:io';

import '../../../core/models/transaction_record.dart';
import 'xlsx_table_reader.dart';

enum BillImportProvider { wechat, alipay, mumu }

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
    this.sourceCategory,
    this.sourceSubcategory,
    this.sourceBook,
    this.sourceAccount,
    this.destinationAccount,
    this.reimbursementStatus = ReimbursementStatus.none,
    this.tags = const [],
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
  final String? sourceCategory;
  final String? sourceSubcategory;
  final String? sourceBook;
  final String? sourceAccount;
  final String? destinationAccount;
  final ReimbursementStatus reimbursementStatus;
  final List<String> tags;

  /// Stable fallback for providers that do not export a transaction ID.
  String get importFingerprint => [
    provider.name,
    occurredAt.toIso8601String(),
    type.name,
    amount.toStringAsFixed(2),
    sourceAccount ?? paymentMethod ?? '',
    destinationAccount ?? '',
    sourceBook ?? '',
    sourceCategory ?? '',
    sourceSubcategory ?? '',
    reimbursementStatus.name,
    raw['成员']?.trim() ?? '',
    merchant.trim(),
    note.trim(),
  ].join('|');
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
    if (path.toLowerCase().endsWith('.xlsx')) {
      return parseMumuXlsx(bytes);
    }
    final text = utf8.decode(bytes, allowMalformed: true).replaceFirst('\ufeff', '');
    return parseCsv(text);
  }

  BillImportResult parseMumuXlsx(List<int> bytes) {
    final rows = const XlsxTableReader()
        .readFirstSheet(bytes)
        .where((row) => row.any((cell) => cell.trim().isNotEmpty))
        .toList(growable: false);
    if (rows.isEmpty) throw const FormatException('账单文件为空');

    final headerIndex = rows.indexWhere((row) {
      final normalized = row.map(_normalizeHeader).toSet();
      final hasTime = normalized.contains('日期') || normalized.contains('时间');
      final hasType =
          normalized.contains('收支类型') || normalized.contains('类型');
      final hasCategory =
          normalized.contains('类别') || normalized.contains('分类');
      return normalized.contains('金额') &&
          hasTime &&
          hasType &&
          hasCategory &&
          normalized.contains('转出账户');
    });
    if (headerIndex < 0) {
      throw const FormatException('未识别到木木记账账单表头，请导入木木导出的 XLSX 文件');
    }

    final headers = rows[headerIndex].map(_normalizeHeader).toList(growable: false);
    final output = <ImportedBillRow>[];
    var skipped = 0;
    for (final values in rows.skip(headerIndex + 1)) {
      final map = <String, String>{
        for (var index = 0; index < headers.length; index++)
          headers[index]: index < values.length ? values[index].trim() : '',
      };
      final parsed = _parseMumuRow(map);
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
      provider: BillImportProvider.mumu,
      rows: output,
      skipped: skipped,
    );
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
        (h) =>
            h.contains('交易时间') ||
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

  ImportedBillRow? _parseMumuRow(Map<String, String> map) {
    final direction = _first(map, const ['收支类型', '类型']).replaceAll(' ', '');
    final sourceCategory = _emptyToNull(
      _first(map, const ['类别', '分类']),
    );
    final sourceSubcategory = _emptyToNull(
      _first(map, const ['子类', '二级分类']),
    );

    final type = switch (direction) {
      '支出' => TransactionType.expense,
      '收入' when sourceCategory == '退款' => TransactionType.refund,
      '收入' when sourceCategory == '报销' => TransactionType.reimbursement,
      '收入' => TransactionType.income,
      '转账' => TransactionType.transfer,
      _ => null,
    };
    if (type == null) return null;

    final amountValue = _money(_first(map, const ['金额']));
    if (amountValue == null || amountValue == 0) return null;
    final amount = amountValue.abs();

    final occurredAt = _time(_first(map, const ['日期', '时间']));
    if (occurredAt == null) return null;

    final sourceAccount = _emptyToNull(_first(map, const ['转出账户']));
    final destinationAccount = _emptyToNull(_first(map, const ['转入账户']));
    if (type == TransactionType.transfer &&
        (sourceAccount == null || destinationAccount == null)) {
      return null;
    }

    final note = _first(map, const ['备注']);
    final tagText = _first(map, const ['标签']);
    final reimbursementText = _first(map, const ['报销']).replaceAll(' ', '');
    final reimbursementStatus = switch (reimbursementText) {
      '已报销' => ReimbursementStatus.reimbursed,
      '待报销' => ReimbursementStatus.pending,
      _ when sourceCategory == '待报销' => ReimbursementStatus.pending,
      _ => ReimbursementStatus.none,
    };
    return ImportedBillRow(
      provider: BillImportProvider.mumu,
      occurredAt: occurredAt,
      type: type,
      amount: amount,
      merchant: '',
      note: note,
      externalId: null,
      paymentMethod: sourceAccount,
      raw: map,
      sourceCategory: sourceCategory,
      sourceSubcategory: sourceSubcategory,
      sourceBook: _emptyToNull(_first(map, const ['所属账本', '账本'])),
      sourceAccount: sourceAccount,
      destinationAccount: destinationAccount,
      reimbursementStatus: reimbursementStatus,
      tags: tagText.isEmpty
          ? const []
          : tagText
                .split(RegExp(r'[,，、;；|]'))
                .map((value) => value.trim())
                .where((value) => value.isNotEmpty)
                .toList(growable: false),
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

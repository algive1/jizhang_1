import 'dart:convert';
import 'dart:io';

import '../../../core/models/transaction_record.dart';
import 'xlsx_table_reader.dart';

enum BillImportProvider { wechat, alipay, mumu, generic }

extension BillImportProviderCapabilities on BillImportProvider {
  bool get needsAccountMapping =>
      this == BillImportProvider.mumu || this == BillImportProvider.generic;
}

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

  /// Provider-independent identity used to recognize the same historical row
  /// even if an older app version classified an official XLSX as "generic".
  String get naturalFingerprint => [
    occurredAt.toIso8601String(),
    type.name,
    amount.toStringAsFixed(2),
    (merchant.trim().isNotEmpty ? merchant : note).trim().toLowerCase(),
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
    final lowerPath = path.toLowerCase();
    final looksLikeXlsx =
        lowerPath.endsWith('.xlsx') ||
        (bytes.length >= 4 &&
            bytes[0] == 0x50 &&
            bytes[1] == 0x4b &&
            bytes[2] == 0x03 &&
            bytes[3] == 0x04);
    if (looksLikeXlsx) return parseXlsx(bytes);

    final text = utf8.decode(bytes, allowMalformed: true).replaceFirst('\ufeff', '');
    return parseCsv(text);
  }

  BillImportResult parseXlsx(List<int> bytes) {
    final sheets = const XlsxTableReader().readSheets(bytes);
    FormatException? lastError;
    for (final sheet in sheets) {
      final rows = sheet
          .where((row) => row.any((cell) => cell.trim().isNotEmpty))
          .toList(growable: false);
      if (rows.isEmpty) continue;
      try {
        return _parseRows(rows);
      } on FormatException catch (error) {
        lastError = error;
      }
    }
    throw lastError ??
        const FormatException('Excel 文件中没有识别到可导入的账单工作表');
  }

  BillImportResult parseMumuXlsx(List<int> bytes) {
    final result = parseXlsx(bytes);
    if (result.provider != BillImportProvider.mumu) {
      throw const FormatException('未识别到木木记账账单表头，请导入木木导出的 XLSX 文件');
    }
    return result;
  }

  BillImportResult parseCsv(String input) {
    final rows = _parseDelimited(input)
        .where((row) => row.any((cell) => cell.trim().isNotEmpty))
        .toList(growable: false);
    return _parseRows(rows);
  }

  BillImportResult _parseRows(List<List<String>> rows) {
    if (rows.isEmpty) throw const FormatException('账单文件为空');

    final officialHeaderIndex = rows.indexWhere((row) {
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

    if (officialHeaderIndex >= 0) {
      final headers = rows[officialHeaderIndex]
          .map(_normalizeHeader)
          .toList(growable: false);
      final provider = _providerOrNull(headers);
      if (provider != null) {
        return _parseOfficialRows(
          provider,
          rows,
          officialHeaderIndex,
          headers,
        );
      }
    }

    return _parseSpreadsheetRows(rows);
  }

  BillImportResult _parseSpreadsheetRows(List<List<String>> rows) {
    if (rows.isEmpty) throw const FormatException('账单文件为空');

    final headerIndex = rows.indexWhere((row) {
      final normalized = row.map(_normalizeHeader).toSet();
      final hasTime = _hasAny(
        normalized,
        const ['日期', '时间', '交易时间', '记账时间', '发生时间', '创建时间'],
      );
      final hasAmount = normalized.any((value) => value.contains('金额'));
      final hasType = _hasAny(
        normalized,
        const ['收支类型', '类型', '收/支', '收支', '交易类型'],
      );
      return hasTime && hasAmount && hasType;
    });
    if (headerIndex < 0) {
      throw const FormatException(
        '未识别账单表头。至少需要时间/日期、收支类型和金额列；支持 CSV/TXT/XLSX。',
      );
    }

    final headers = rows[headerIndex].map(_normalizeHeader).toList(growable: false);
    final normalizedSet = headers.toSet();
    final isMumu =
        _hasAny(normalizedSet, const ['类别', '分类']) &&
        normalizedSet.contains('转出账户') &&
        (_hasAny(normalizedSet, const ['所属账本', '账本']) ||
            _hasAny(normalizedSet, const ['子类', '二级分类']));

    final provider =
        isMumu ? BillImportProvider.mumu : BillImportProvider.generic;
    final output = <ImportedBillRow>[];
    var skipped = 0;
    for (final values in rows.skip(headerIndex + 1)) {
      if (values.every((value) => value.trim().isEmpty)) continue;
      final map = <String, String>{
        for (var index = 0; index < headers.length; index++)
          headers[index]: index < values.length ? values[index].trim() : '',
      };
      final parsed = provider == BillImportProvider.mumu
          ? _parseMumuRow(map)
          : _parseGenericRow(map);
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

  BillImportResult _parseOfficialRows(
    BillImportProvider provider,
    List<List<String>> rows,
    int headerIndex,
    List<String> headers,
  ) {
    final output = <ImportedBillRow>[];
    var skipped = 0;
    for (final values in rows.skip(headerIndex + 1)) {
      if (values.every((value) => value.trim().isEmpty)) continue;
      final map = <String, String>{
        for (var index = 0; index < headers.length; index++)
          headers[index]: index < values.length ? values[index].trim() : '',
      };
      final parsed = _parseOfficialRow(provider, map);
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

  BillImportProvider? _providerOrNull(List<String> headers) {
    final joined = headers.join('|');
    if (joined.contains('商家订单号') ||
        joined.contains('资金状态') ||
        joined.contains('交易来源地')) {
      return BillImportProvider.alipay;
    }
    if (joined.contains('微信支付') ||
        joined.contains('交易单号') ||
        joined.contains('商户单号')) {
      return BillImportProvider.wechat;
    }
    return null;
  }

  ImportedBillRow? _parseOfficialRow(
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
    final sourceCategory = _emptyToNull(_first(map, const ['类别', '分类']));
    final sourceSubcategory = _emptyToNull(
      _first(map, const ['子类', '二级分类']),
    );

    final type = _semanticType(direction, sourceCategory);
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
      tags: _tags(tagText),
    );
  }

  ImportedBillRow? _parseGenericRow(Map<String, String> map) {
    final direction = _first(
      map,
      const ['收支类型', '类型', '收/支', '收支', '交易类型'],
    );
    final sourceCategory = _emptyToNull(
      _first(map, const ['分类', '类别', '一级分类', '大类']),
    );
    final sourceSubcategory = _emptyToNull(
      _first(map, const ['二级分类', '子类', '子分类', '小类']),
    );

    final amountValue = _money(
      _first(
        map,
        const ['金额', '金额(元)', '金额（元）', '交易金额', '交易金额(元)', '交易金额（元）'],
      ),
    );
    if (amountValue == null || amountValue == 0) return null;

    final type =
        _semanticType(direction, sourceCategory) ??
        (amountValue < 0 ? TransactionType.expense : TransactionType.income);

    final occurredAt = _time(
      _first(
        map,
        const ['日期', '时间', '交易时间', '记账时间', '发生时间', '创建时间'],
      ),
    );
    if (occurredAt == null) return null;

    final sourceAccount = _emptyToNull(
      _first(
        map,
        const [
          '转出账户',
          '账户',
          '账户名称',
          '支付账户',
          '付款账户',
          '来源账户',
          '资金账户',
        ],
      ),
    );
    final destinationAccount = _emptyToNull(
      _first(map, const ['转入账户', '目标账户', '收款账户']),
    );
    if (type == TransactionType.transfer &&
        (sourceAccount == null || destinationAccount == null)) {
      return null;
    }

    final merchant = _first(
      map,
      const ['交易对方', '商户', '商家', '对方', '收款方'],
    );
    final note = _first(
      map,
      const ['备注', '交易备注', '说明', '描述', '商品', '商品名称'],
    );
    final externalId = _emptyToNull(
      _first(
        map,
        const ['交易单号', '交易号', '订单号', '流水号', '商家订单号', '商户单号'],
      ),
    );
    final tagText = _first(map, const ['标签', 'Tag', 'Tags']);

    return ImportedBillRow(
      provider: BillImportProvider.generic,
      occurredAt: occurredAt,
      type: type,
      amount: amountValue.abs(),
      merchant: merchant,
      note: note,
      externalId: externalId,
      paymentMethod: sourceAccount,
      raw: map,
      sourceCategory: sourceCategory,
      sourceSubcategory: sourceSubcategory,
      sourceBook: _emptyToNull(_first(map, const ['账本', '所属账本'])),
      sourceAccount: sourceAccount,
      destinationAccount: destinationAccount,
      tags: _tags(tagText),
    );
  }

  TransactionType? _semanticType(String value, String? sourceCategory) {
    final text = value.replaceAll(' ', '').toLowerCase();
    if (text.contains('转账') || text == 'transfer') {
      return TransactionType.transfer;
    }
    if (text.contains('退款') || text == 'refund') {
      return TransactionType.refund;
    }
    if (text.contains('报销') || text == 'reimbursement') {
      return TransactionType.reimbursement;
    }
    if ((text.contains('收入') || text == '收' || text == 'income') &&
        sourceCategory == '退款') {
      return TransactionType.refund;
    }
    if ((text.contains('收入') || text == '收' || text == 'income') &&
        sourceCategory == '报销') {
      return TransactionType.reimbursement;
    }
    if (text.contains('支出') || text == '支' || text == 'expense') {
      return TransactionType.expense;
    }
    if (text.contains('收入') || text == '收' || text == 'income') {
      return TransactionType.income;
    }
    return null;
  }

  TransactionType? _transactionType(String value) =>
      _semanticType(value, null);

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

  List<String> _tags(String value) => value.trim().isEmpty
      ? const []
      : value
            .split(RegExp(r'[,，、;；|]'))
            .map((item) => item.trim())
            .where((item) => item.isNotEmpty)
            .toList(growable: false);

  bool _hasAny(Set<String> values, List<String> expected) =>
      expected.any(values.contains);

  String _first(Map<String, String> map, List<String> keys) {
    for (final key in keys) {
      final exact = map[key];
      if (_isMeaningfulCell(exact)) return exact!.trim();
      for (final entry in map.entries) {
        if (_normalizeHeader(entry.key) == _normalizeHeader(key) &&
            _isMeaningfulCell(entry.value)) {
          return entry.value.trim();
        }
      }
    }
    return '';
  }

  bool _isMeaningfulCell(String? value) {
    final cleaned = value?.trim() ?? '';
    if (cleaned.isEmpty) return false;
    return cleaned != '/' && cleaned != '／';
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

  List<List<String>> _parseDelimited(String input) {
    final delimiter = _detectDelimiter(input);
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
      if (!quoted && char == delimiter) {
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

  String _detectDelimiter(String input) {
    final lines = input
        .split(RegExp(r'\r?\n'))
        .where((line) => line.trim().isNotEmpty)
        .take(8)
        .toList(growable: false);
    if (lines.isEmpty) return ',';

    const candidates = [',', '\t', ';'];
    var best = ',';
    var bestScore = -1;
    for (final candidate in candidates) {
      final score = lines.fold<int>(
        0,
        (sum, line) => sum + _delimiterCountOutsideQuotes(line, candidate),
      );
      if (score > bestScore) {
        best = candidate;
        bestScore = score;
      }
    }
    return best;
  }

  int _delimiterCountOutsideQuotes(String line, String delimiter) {
    var quoted = false;
    var count = 0;
    for (var i = 0; i < line.length; i++) {
      final char = line[i];
      if (char == '"') {
        if (quoted && i + 1 < line.length && line[i + 1] == '"') {
          i++;
        } else {
          quoted = !quoted;
        }
      } else if (!quoted && char == delimiter) {
        count++;
      }
    }
    return count;
  }
}

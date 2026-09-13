import '../../../core/models/account.dart';
import '../../../core/models/transaction_record.dart';

/// Portable spreadsheet export, not a restorable database backup.
abstract final class TransactionCsv {
  static String encode(
    List<TransactionRecord> transactions,
    List<Account> accounts,
  ) {
    final names = {
      for (final account in accounts) account.id: account.displayName,
    };
    final rows = <List<String>>[
      [
        '流水ID',
        '账本ID',
        '类型',
        '金额',
        '币种',
        '账户ID',
        '账户名称',
        '转入账户ID',
        '转入账户名称',
        '分类ID',
        '分类名称',
        '子分类ID',
        '商户',
        '备注',
        '发生时间',
        '创建时间',
        '更新时间',
        '来源',
        '周期性',
        '一次性',
        '大额',
        '计划内',
      ],
      for (final item in transactions.where((t) => t.deletedAt == null))
        [
          _text(item.id),
          _text(item.bookId),
          item.type.name,
          item.amount.toStringAsFixed(2),
          _text(item.currency),
          _text(item.accountId),
          _text(names[item.accountId] ?? ''),
          _text(item.destinationAccountId ?? ''),
          _text(names[item.destinationAccountId] ?? ''),
          _text(item.categoryId ?? ''),
          _text(item.categoryName ?? ''),
          _text(item.subcategoryId ?? ''),
          _text(item.merchant ?? ''),
          _text(item.note ?? ''),
          item.occurredAt.toIso8601String(),
          item.createdAt.toIso8601String(),
          item.updatedAt.toIso8601String(),
          item.source.name,
          item.isRecurring ? '是' : '否',
          item.isOneTime ? '是' : '否',
          item.isLargeTransaction ? '是' : '否',
          item.isPlanned ? '是' : '否',
        ],
    ];
    // BOM makes Chinese readable in spreadsheet programs. Escape every cell.
    return '\uFEFF${rows.map((row) => row.map((cell) => '"${cell.replaceAll('"', '""')}"').join(',')).join('\r\n')}\r\n';
  }

  static String _text(String value) {
    // Leading whitespace/control characters must not bypass formula protection.
    if (RegExp(r'^[\s\x00-\x1f]*[=+@-]').hasMatch(value)) return "'$value";
    return value;
  }
}

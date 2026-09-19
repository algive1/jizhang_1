import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/utils/entity_id.dart';
import '../../books/data/book_repository.dart';

enum InvoiceDirection { incoming, outgoing }
enum InvoiceStatus { draft, issued, received, reimbursed, voided }
enum TaxFilingStatus { pending, filed, paid }
enum CardStatementType { debit, credit }
enum CardStatementStatus { open, paid, reconciled }

class FinanceInvoice {
  const FinanceInvoice({
    required this.id,
    required this.bookId,
    required this.direction,
    required this.invoiceNo,
    required this.counterparty,
    required this.amount,
    required this.taxAmount,
    required this.issueDate,
    required this.status,
    required this.note,
  });

  final String id;
  final String bookId;
  final InvoiceDirection direction;
  final String invoiceNo;
  final String counterparty;
  final double amount;
  final double taxAmount;
  final DateTime issueDate;
  final InvoiceStatus status;
  final String note;
}

class TaxFiling {
  const TaxFiling({
    required this.id,
    required this.bookId,
    required this.period,
    required this.taxType,
    required this.taxableAmount,
    required this.taxDue,
    required this.dueDate,
    required this.status,
    required this.note,
  });

  final String id;
  final String bookId;
  final String period;
  final String taxType;
  final double taxableAmount;
  final double taxDue;
  final DateTime dueDate;
  final TaxFilingStatus status;
  final String note;
}

class CardStatement {
  const CardStatement({
    required this.id,
    required this.bookId,
    required this.accountName,
    required this.type,
    required this.statementMonth,
    required this.openingBalance,
    required this.closingBalance,
    required this.statementAmount,
    required this.minimumDue,
    required this.paidAmount,
    required this.dueDate,
    required this.status,
    required this.note,
  });

  final String id;
  final String bookId;
  final String accountName;
  final CardStatementType type;
  final String statementMonth;
  final double openingBalance;
  final double closingBalance;
  final double statementAmount;
  final double minimumDue;
  final double paidAmount;
  final DateTime? dueDate;
  final CardStatementStatus status;
  final String note;

  double get remaining => (statementAmount - paidAmount).clamp(0, double.infinity);
}

abstract interface class FinanceCenterRepository {
  Future<List<FinanceInvoice>> invoices();
  Future<void> saveInvoice(FinanceInvoice value);
  Future<void> deleteInvoice(String id);

  Future<List<TaxFiling>> taxFilings();
  Future<void> saveTaxFiling(TaxFiling value);
  Future<void> deleteTaxFiling(String id);

  Future<List<CardStatement>> statements();
  Future<void> saveStatement(CardStatement value);
  Future<void> deleteStatement(String id);
}

class DriftFinanceCenterRepository implements FinanceCenterRepository {
  DriftFinanceCenterRepository(this._database, {required this.bookId});

  final AppDatabase _database;
  final String bookId;
  bool _ready = false;

  Future<void> _ensureSchema() async {
    if (_ready) return;
    await _database.customStatement('''
      CREATE TABLE IF NOT EXISTS finance_invoices(
        id TEXT PRIMARY KEY,
        book_id TEXT NOT NULL,
        direction TEXT NOT NULL CHECK(direction IN ('incoming','outgoing')),
        invoice_no TEXT NOT NULL DEFAULT '',
        counterparty TEXT NOT NULL DEFAULT '',
        amount REAL NOT NULL CHECK(amount >= 0),
        tax_amount REAL NOT NULL DEFAULT 0 CHECK(tax_amount >= 0),
        issue_date INTEGER NOT NULL,
        status TEXT NOT NULL CHECK(status IN ('draft','issued','received','reimbursed','voided')),
        note TEXT NOT NULL DEFAULT '',
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');
    await _database.customStatement(
      'CREATE INDEX IF NOT EXISTS idx_finance_invoices_book_date '
      'ON finance_invoices(book_id, issue_date DESC)',
    );
    await _database.customStatement('''
      CREATE TABLE IF NOT EXISTS finance_tax_filings(
        id TEXT PRIMARY KEY,
        book_id TEXT NOT NULL,
        period TEXT NOT NULL,
        tax_type TEXT NOT NULL,
        taxable_amount REAL NOT NULL DEFAULT 0 CHECK(taxable_amount >= 0),
        tax_due REAL NOT NULL DEFAULT 0 CHECK(tax_due >= 0),
        due_date INTEGER NOT NULL,
        status TEXT NOT NULL CHECK(status IN ('pending','filed','paid')),
        note TEXT NOT NULL DEFAULT '',
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        UNIQUE(book_id, period, tax_type)
      )
    ''');
    await _database.customStatement(
      'CREATE INDEX IF NOT EXISTS idx_finance_tax_book_due '
      'ON finance_tax_filings(book_id, due_date DESC)',
    );
    await _database.customStatement('''
      CREATE TABLE IF NOT EXISTS finance_card_statements(
        id TEXT PRIMARY KEY,
        book_id TEXT NOT NULL,
        account_name TEXT NOT NULL,
        card_type TEXT NOT NULL CHECK(card_type IN ('debit','credit')),
        statement_month TEXT NOT NULL,
        opening_balance REAL NOT NULL DEFAULT 0,
        closing_balance REAL NOT NULL DEFAULT 0,
        statement_amount REAL NOT NULL DEFAULT 0 CHECK(statement_amount >= 0),
        minimum_due REAL NOT NULL DEFAULT 0 CHECK(minimum_due >= 0),
        paid_amount REAL NOT NULL DEFAULT 0 CHECK(paid_amount >= 0),
        due_date INTEGER,
        status TEXT NOT NULL CHECK(status IN ('open','paid','reconciled')),
        note TEXT NOT NULL DEFAULT '',
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        UNIQUE(book_id, account_name, card_type, statement_month)
      )
    ''');
    await _database.customStatement(
      'CREATE INDEX IF NOT EXISTS idx_finance_statements_book_month '
      'ON finance_card_statements(book_id, statement_month DESC)',
    );
    _ready = true;
  }

  @override
  Future<List<FinanceInvoice>> invoices() async {
    await _ensureSchema();
    final rows = await _database.customSelect(
      'SELECT * FROM finance_invoices WHERE book_id=? ORDER BY issue_date DESC, updated_at DESC',
      variables: [Variable(bookId)],
    ).get();
    return rows.map((row) => FinanceInvoice(
      id: row.read<String>('id'),
      bookId: row.read<String>('book_id'),
      direction: InvoiceDirection.values.byName(row.read<String>('direction')),
      invoiceNo: row.read<String>('invoice_no'),
      counterparty: row.read<String>('counterparty'),
      amount: row.read<double>('amount'),
      taxAmount: row.read<double>('tax_amount'),
      issueDate: DateTime.fromMillisecondsSinceEpoch(row.read<int>('issue_date')),
      status: InvoiceStatus.values.byName(row.read<String>('status')),
      note: row.read<String>('note'),
    )).toList(growable: false);
  }

  @override
  Future<void> saveInvoice(FinanceInvoice value) async {
    await _ensureSchema();
    if (value.bookId != bookId || value.amount < 0 || value.taxAmount < 0) {
      throw ArgumentError('发票数据无效');
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    await _database.customStatement('''
      INSERT INTO finance_invoices(
        id,book_id,direction,invoice_no,counterparty,amount,tax_amount,
        issue_date,status,note,created_at,updated_at
      ) VALUES(?,?,?,?,?,?,?,?,?,?,?,?)
      ON CONFLICT(id) DO UPDATE SET
        direction=excluded.direction,
        invoice_no=excluded.invoice_no,
        counterparty=excluded.counterparty,
        amount=excluded.amount,
        tax_amount=excluded.tax_amount,
        issue_date=excluded.issue_date,
        status=excluded.status,
        note=excluded.note,
        updated_at=excluded.updated_at
    ''', [
      value.id, value.bookId, value.direction.name, value.invoiceNo.trim(),
      value.counterparty.trim(), value.amount, value.taxAmount,
      value.issueDate.millisecondsSinceEpoch, value.status.name,
      value.note.trim(), now, now,
    ]);
  }

  @override
  Future<void> deleteInvoice(String id) async {
    await _ensureSchema();
    await _database.customStatement(
      'DELETE FROM finance_invoices WHERE id=? AND book_id=?',
      [id, bookId],
    );
  }

  @override
  Future<List<TaxFiling>> taxFilings() async {
    await _ensureSchema();
    final rows = await _database.customSelect(
      'SELECT * FROM finance_tax_filings WHERE book_id=? ORDER BY due_date DESC, updated_at DESC',
      variables: [Variable(bookId)],
    ).get();
    return rows.map((row) => TaxFiling(
      id: row.read<String>('id'),
      bookId: row.read<String>('book_id'),
      period: row.read<String>('period'),
      taxType: row.read<String>('tax_type'),
      taxableAmount: row.read<double>('taxable_amount'),
      taxDue: row.read<double>('tax_due'),
      dueDate: DateTime.fromMillisecondsSinceEpoch(row.read<int>('due_date')),
      status: TaxFilingStatus.values.byName(row.read<String>('status')),
      note: row.read<String>('note'),
    )).toList(growable: false);
  }

  @override
  Future<void> saveTaxFiling(TaxFiling value) async {
    await _ensureSchema();
    if (value.bookId != bookId ||
        value.taxableAmount < 0 ||
        value.taxDue < 0 ||
        value.period.trim().isEmpty ||
        value.taxType.trim().isEmpty) {
      throw ArgumentError('报税台账数据无效');
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    await _database.customStatement('''
      INSERT INTO finance_tax_filings(
        id,book_id,period,tax_type,taxable_amount,tax_due,due_date,status,
        note,created_at,updated_at
      ) VALUES(?,?,?,?,?,?,?,?,?,?,?)
      ON CONFLICT(id) DO UPDATE SET
        period=excluded.period,
        tax_type=excluded.tax_type,
        taxable_amount=excluded.taxable_amount,
        tax_due=excluded.tax_due,
        due_date=excluded.due_date,
        status=excluded.status,
        note=excluded.note,
        updated_at=excluded.updated_at
    ''', [
      value.id, value.bookId, value.period.trim(), value.taxType.trim(),
      value.taxableAmount, value.taxDue, value.dueDate.millisecondsSinceEpoch,
      value.status.name, value.note.trim(), now, now,
    ]);
  }

  @override
  Future<void> deleteTaxFiling(String id) async {
    await _ensureSchema();
    await _database.customStatement(
      'DELETE FROM finance_tax_filings WHERE id=? AND book_id=?',
      [id, bookId],
    );
  }

  @override
  Future<List<CardStatement>> statements() async {
    await _ensureSchema();
    final rows = await _database.customSelect(
      'SELECT * FROM finance_card_statements WHERE book_id=? '
      'ORDER BY statement_month DESC, updated_at DESC',
      variables: [Variable(bookId)],
    ).get();
    return rows.map((row) => CardStatement(
      id: row.read<String>('id'),
      bookId: row.read<String>('book_id'),
      accountName: row.read<String>('account_name'),
      type: CardStatementType.values.byName(row.read<String>('card_type')),
      statementMonth: row.read<String>('statement_month'),
      openingBalance: row.read<double>('opening_balance'),
      closingBalance: row.read<double>('closing_balance'),
      statementAmount: row.read<double>('statement_amount'),
      minimumDue: row.read<double>('minimum_due'),
      paidAmount: row.read<double>('paid_amount'),
      dueDate: row.readNullable<int>('due_date') == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(row.read<int>('due_date')),
      status: CardStatementStatus.values.byName(row.read<String>('status')),
      note: row.read<String>('note'),
    )).toList(growable: false);
  }

  @override
  Future<void> saveStatement(CardStatement value) async {
    await _ensureSchema();
    if (value.bookId != bookId ||
        value.accountName.trim().isEmpty ||
        !RegExp(r'^\d{4}-(0[1-9]|1[0-2])$').hasMatch(value.statementMonth) ||
        value.statementAmount < 0 ||
        value.minimumDue < 0 ||
        value.paidAmount < 0) {
      throw ArgumentError('银行卡账单数据无效');
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    await _database.customStatement('''
      INSERT INTO finance_card_statements(
        id,book_id,account_name,card_type,statement_month,opening_balance,
        closing_balance,statement_amount,minimum_due,paid_amount,due_date,
        status,note,created_at,updated_at
      ) VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)
      ON CONFLICT(id) DO UPDATE SET
        account_name=excluded.account_name,
        card_type=excluded.card_type,
        statement_month=excluded.statement_month,
        opening_balance=excluded.opening_balance,
        closing_balance=excluded.closing_balance,
        statement_amount=excluded.statement_amount,
        minimum_due=excluded.minimum_due,
        paid_amount=excluded.paid_amount,
        due_date=excluded.due_date,
        status=excluded.status,
        note=excluded.note,
        updated_at=excluded.updated_at
    ''', [
      value.id, value.bookId, value.accountName.trim(), value.type.name,
      value.statementMonth, value.openingBalance, value.closingBalance,
      value.statementAmount, value.minimumDue, value.paidAmount,
      value.dueDate?.millisecondsSinceEpoch, value.status.name,
      value.note.trim(), now, now,
    ]);
  }

  @override
  Future<void> deleteStatement(String id) async {
    await _ensureSchema();
    await _database.customStatement(
      'DELETE FROM finance_card_statements WHERE id=? AND book_id=?',
      [id, bookId],
    );
  }
}

FinanceInvoice newInvoice(String bookId) => FinanceInvoice(
  id: 'invoice-${newEntityId()}',
  bookId: bookId,
  direction: InvoiceDirection.incoming,
  invoiceNo: '',
  counterparty: '',
  amount: 0,
  taxAmount: 0,
  issueDate: DateTime.now(),
  status: InvoiceStatus.received,
  note: '',
);

TaxFiling newTaxFiling(String bookId) {
  final now = DateTime.now();
  return TaxFiling(
    id: 'tax-${newEntityId()}',
    bookId: bookId,
    period: '${now.year}-${now.month.toString().padLeft(2, '0')}',
    taxType: '增值税',
    taxableAmount: 0,
    taxDue: 0,
    dueDate: DateTime(now.year, now.month + 1, 15),
    status: TaxFilingStatus.pending,
    note: '',
  );
}

CardStatement newStatement(String bookId) {
  final now = DateTime.now();
  return CardStatement(
    id: 'statement-${newEntityId()}',
    bookId: bookId,
    accountName: '',
    type: CardStatementType.credit,
    statementMonth: '${now.year}-${now.month.toString().padLeft(2, '0')}',
    openingBalance: 0,
    closingBalance: 0,
    statementAmount: 0,
    minimumDue: 0,
    paidAmount: 0,
    dueDate: DateTime(now.year, now.month + 1, 1),
    status: CardStatementStatus.open,
    note: '',
  );
}

final financeCenterRepositoryProvider = Provider<FinanceCenterRepository>((ref) {
  return DriftFinanceCenterRepository(
    ref.watch(databaseProvider),
    bookId: ref.watch(activeBookIdProvider),
  );
});

import 'dart:convert';

import 'package:drift/drift.dart';

import '../../core/database/app_database.dart';
import '../../core/database/database_seeder.dart';
import '../../core/models/transaction_record.dart';
import '../bookkeeping/application/quick_bookkeeping_service.dart';
import '../settings/data/app_settings_repository.dart';
import '../transactions/data/transactions_repository.dart';

/// This adapter deliberately uses the existing ledger service without its AI
/// postprocessor. All input is a payment candidate, never accessibility text.
class AutoBookkeepingRepository {
  AutoBookkeepingRepository(this.db);
  final AppDatabase db;
  static const preferenceKey = 'autobookkeeping.preferences.v1';

  Future<Map<String, dynamic>> catalog(String merchant) async {
    final books =
        await (db.select(db.bookEntries)..where(
              (b) =>
                  b.isArchived.equals(false) &
                  b.ownerUserId.equals(SeedIds.localUser) &
                  b.familyId.isNull(),
            ))
            .get();
    // Shared books require the foreground authenticated sync session in this MVP.
    final accounts = await db.accountDao.getAll();
    final categories = await db.categoryDao.getActive();
    final preferences = jsonDecode(
      await db.appSettingsDao.getValue(preferenceKey) ?? '{}',
    ) as Map<String, dynamic>;
    return {
      'books': books
          .map(
            (b) => {
              'id': b.id,
              'name': b.name,
              'bookId': b.id,
              'assetBookId': b.assetSourceBookId ?? b.id,
            },
          )
          .toList(),
      'accounts': accounts
          .where((a) => !a.isArchived && a.currency == 'CNY')
          .map(
            (a) => {
              'id': a.id,
              'name':
                  '${a.name}${a.identifierSuffix == null ? '' : '-${a.identifierSuffix}'}',
              'bookId': a.bookId,
              'type': a.type,
            },
          )
          .toList(),
      'categories': categories
          .where((c) => c.type == 'expense')
          .map(
            (c) => {
              'id': c.id,
              'name': c.name,
              'bookId': c.bookId,
              'type': c.type,
            },
          )
          .toList(),
      'preference': preferences[merchant],
      'mappings': jsonDecode(
        await db.appSettingsDao.getValue('autobookkeeping.accounts.v1') ?? '{}',
      ),
    };
  }

  Future<bool> possibleDuplicate(Map<String, dynamic> data) async {
    final cents = (data['amountInCents'] as num).toInt();
    final merchant = data['merchant'] as String;
    final since = DateTime.now().subtract(const Duration(minutes: 5));
    final rows =
        await (db.select(db.transactionEntries)..where(
              (t) =>
                  t.deletedAt.isNull() &
                  t.type.equals('expense') &
                  t.amountInCents.equals(cents) &
                  (t.createdAt.isBiggerOrEqualValue(since) |
                      t.occurredAt.isBiggerOrEqualValue(since)),
            ))
            .get();
    return rows.any((t) => t.merchant == merchant);
  }

  Future<Map<String, dynamic>> save(Map<String, dynamic> data) async {
    final id = data['requestId'] as String;
    if (!RegExp(r'^[a-zA-Z0-9-]{1,100}$').hasMatch(id))
      throw ArgumentError('无效确认编号');
    return db.transaction(() async {
      final existing = await db.transactionDao.findById('auto-$id');
      if (existing != null) return {'saved': true, 'id': existing.id};
      final bookId = data['bookId'] as String;
      final book = await db.familyDao.findBook(bookId);
      if (book == null ||
          book.isArchived ||
          book.familyId != null ||
          book.ownerUserId != SeedIds.localUser)
        throw StateError('请选择可用的个人账本');
      final accountId = data['accountId'] as String;
      final categoryId = data['categoryId'] as String;
      final account = await db.accountDao.findById(accountId);
      final category = await db.categoryDao.findById(categoryId);
      if (account == null ||
          account.isArchived ||
          account.currency != 'CNY' ||
          account.bookId != (book.assetSourceBookId ?? book.id))
        throw StateError('账户已失效，请重新选择');
      if (category == null ||
          category.isArchived ||
          category.type != 'expense' ||
          category.bookId != bookId)
        throw StateError('分类已失效，请重新选择');
      final cents = (data['amountInCents'] as num).toInt();
      if (cents <= 0 || cents > 99999999999) throw ArgumentError('金额超出范围');
      final merchant = (data['merchant'] as String).trim();
      if (merchant.isEmpty || merchant.length > 80)
        throw ArgumentError('请确认商户名称');
      if (await possibleDuplicate(data) && data['duplicateConfirmed'] != true)
        return {'saved': false, 'possibleDuplicate': true};
      final settings = DriftAppSettingsRepository(db);
      final service = QuickBookkeepingService(
        DriftTransactionRepository(db, accountBookId: book.assetSourceBookId),
        settings,
      );
      await service.save(
        QuickBookkeepingRequest(
          transactionId: 'auto-$id',
          bookId: bookId,
          type: TransactionType.expense,
          amount: cents / 100,
          accountId: accountId,
          categoryId: categoryId,
          categoryName: category.name,
          merchant: merchant,
          occurredAt: DateTime.fromMillisecondsSinceEpoch(
            (data['timestamp'] as num).toInt(),
          ),
          source: TransactionSource.auto,
          userCorrected: true,
          metadata: {
            'autobookkeeping': {
              'sourceApp': 'WECHAT',
              'scene': 'PAYMENT_SUCCESS',
              'paymentMethod': data['paymentMethod'],
              'fingerprint': data['fingerprint'],
              'ruleVersion': 1,
            },
          },
        ),
      );
      final preferences = jsonDecode(
        await settings.get(preferenceKey) ?? '{}',
      ) as Map<String, dynamic>;
      final old = preferences[merchant] as Map<String, dynamic>?;
      preferences[merchant] = {
        'merchantKey': merchant,
        'categoryId': categoryId,
        'accountId': accountId,
        'bookId': bookId,
        'tags': old?['tags'] ?? [],
        'useCount': ((old?['useCount'] as num?)?.toInt() ?? 0) + 1,
        'lastUsedAt': DateTime.now().millisecondsSinceEpoch,
      };
      await settings.set(preferenceKey, jsonEncode(preferences));
      final method = data['paymentMethod'] as String;
      if (method != 'UNKNOWN') {
        final mappings = jsonDecode(
          await settings.get('autobookkeeping.accounts.v1') ?? '{}',
        ) as Map<String, dynamic>;
        mappings['$bookId|$method'] = accountId;
        await settings.set('autobookkeeping.accounts.v1', jsonEncode(mappings));
      }
      return {'saved': true, 'id': 'auto-$id'};
    });
  }
}

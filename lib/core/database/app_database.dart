import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../utils/entity_id.dart';
import '../security/database_encryption_key_store.dart';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

part 'app_database.g.dart';
part 'book_scope_migration.dart';
part 'data_binding_schema.dart';
part 'shared_sync_schema.dart';

@DataClassName('AccountEntity')
class AccountEntries extends Table {
  @override
  String get tableName => 'accounts';

  TextColumn get id => text()();
  TextColumn get bookId =>
      text().withDefault(const Constant('book-personal'))();
  IntColumn get openingBalanceInCents =>
      integer().withDefault(const Constant(0))();
  TextColumn get name => text()();
  TextColumn get type => text()();
  IntColumn get balanceInCents => integer().withDefault(const Constant(0))();
  TextColumn get currency => text().withDefault(const Constant('CNY'))();
  TextColumn get assetForm =>
      text().withDefault(const Constant('unspecified'))();
  TextColumn get identifierSuffix => text().nullable()();
  TextColumn get icon => text()();
  IntColumn get color => integer()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('CategoryEntity')
class CategoryEntries extends Table {
  @override
  String get tableName => 'categories';

  TextColumn get id => text()();
  TextColumn get bookId =>
      text().withDefault(const Constant('book-personal'))();
  TextColumn get parentId =>
      text().nullable().references(CategoryEntries, #id)();
  TextColumn get name => text()();
  TextColumn get icon => text()();
  TextColumn get type => text()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  BoolColumn get isDefault => boolean().withDefault(const Constant(false))();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('TransactionEntity')
class TransactionEntries extends Table {
  @override
  String get tableName => 'transactions';

  TextColumn get id => text()();
  TextColumn get bookId => text()();
  TextColumn get userId => text().nullable()();
  TextColumn get type => text()();
  IntColumn get amountInCents => integer()();
  TextColumn get currency => text().withDefault(const Constant('CNY'))();
  @ReferenceName('categoryTransactions')
  TextColumn get categoryId =>
      text().nullable().references(CategoryEntries, #id)();
  @ReferenceName('subcategoryTransactions')
  TextColumn get subcategoryId =>
      text().nullable().references(CategoryEntries, #id)();
  @ReferenceName('sourceTransactions')
  TextColumn get accountId => text().references(AccountEntries, #id)();
  @ReferenceName('destinationTransactions')
  TextColumn get destinationAccountId =>
      text().nullable().references(AccountEntries, #id)();
  TextColumn get merchant => text().nullable()();
  TextColumn get note => text().nullable()();
  DateTimeColumn get occurredAt => dateTime()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  BoolColumn get isRecurring => boolean().withDefault(const Constant(false))();
  BoolColumn get isOneTime => boolean().withDefault(const Constant(true))();
  BoolColumn get isLargeTransaction =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get isPlanned => boolean().withDefault(const Constant(false))();
  TextColumn get source => text().withDefault(const Constant('manual'))();
  RealColumn get aiConfidence => real().nullable()();
  BoolColumn get userCorrected =>
      boolean().withDefault(const Constant(false))();
  TextColumn get syncStatus =>
      text().withDefault(const Constant('localOnly'))();
  TextColumn get deviceId => text().nullable()();
  TextColumn get originalTransactionId => text().nullable()();
  TextColumn get relatedTransactionId => text().nullable()();
  TextColumn get reimbursementStatus =>
      text().withDefault(const Constant('none'))();
  IntColumn get reimbursementAmountInCents => integer().nullable()();
  DateTimeColumn get reimbursementDate => dateTime().nullable()();
  TextColumn get reimbursementNote => text().nullable()();
  TextColumn get refundStatus => text().withDefault(const Constant('none'))();
  IntColumn get refundAmountInCents => integer().nullable()();
  TextColumn get metadataJson => text().nullable()();
  RealColumn get duplicateConfidence => real().nullable()();
  TextColumn get visibility => text().withDefault(const Constant('private'))();
  TextColumn get createdBy => text().nullable()();
  TextColumn get updatedBy => text().nullable()();
  IntColumn get version => integer().withDefault(const Constant(1))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('TransactionAttachmentEntity')
class TransactionAttachmentEntries extends Table {
  @override
  String get tableName => 'transaction_attachments';

  TextColumn get id => text()();
  TextColumn get bookId => text()();
  TextColumn get transactionId => text().references(TransactionEntries, #id)();
  TextColumn get path => text()();
  TextColumn get name => text()();
  TextColumn get mimeType =>
      text().withDefault(const Constant('application/octet-stream'))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  IntColumn get sizeInBytes => integer().nullable()();
  TextColumn get checksum => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('GoalEntity')
class GoalEntries extends Table {
  @override
  String get tableName => 'goals';

  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get goalType => text().withDefault(const Constant('custom'))();
  TextColumn get icon => text()();
  IntColumn get targetAmountInCents => integer()();
  IntColumn get currentAmountInCents =>
      integer().withDefault(const Constant(0))();
  DateTimeColumn get targetDate => dateTime()();
  TextColumn get status => text().withDefault(const Constant('active'))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  TextColumn get description => text().nullable()();
  TextColumn get coverPath => text().nullable()();
  BoolColumn get completionCelebrationShown =>
      boolean().withDefault(const Constant(false))();
  TextColumn get bookId =>
      text().withDefault(const Constant('book-personal'))();
  TextColumn get createdBy => text().nullable()();
  TextColumn get updatedBy => text().nullable()();
  IntColumn get version => integer().withDefault(const Constant(1))();

  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  IntColumn get monthlyReservationInCents =>
      integer().withDefault(const Constant(0))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('GoalMilestoneEntity')
class GoalMilestoneEntries extends Table {
  @override
  String get tableName => 'goal_milestones';

  TextColumn get id => text()();
  TextColumn get goalId => text().references(GoalEntries, #id)();
  IntColumn get amountInCents => integer()();
  TextColumn get title => text()();
  IntColumn get sortOrder => integer()();
  DateTimeColumn get completedAt => dateTime().nullable()();
  BoolColumn get celebrationShown =>
      boolean().withDefault(const Constant(false))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('GoalContributionEntity')
class GoalContributionEntries extends Table {
  @override
  String get tableName => 'goal_contributions';

  TextColumn get id => text()();
  TextColumn get goalId => text().references(GoalEntries, #id)();
  IntColumn get amountInCents => integer()();
  TextColumn get type => text()();
  TextColumn get sourceTransactionId => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  TextColumn get note => text().nullable()();
  TextColumn get contributorUserId => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('AppSettingEntity')
class AppSettingEntries extends Table {
  @override
  String get tableName => 'app_settings';

  TextColumn get key => text()();
  TextColumn get value => text()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}

@DataClassName('BudgetEntity')
class BudgetEntries extends Table {
  @override
  String get tableName => 'budgets';

  TextColumn get id => text()();
  TextColumn get bookId =>
      text().withDefault(const Constant('book-personal'))();
  TextColumn get monthKey => text()();
  TextColumn get categoryId =>
      text().nullable().references(CategoryEntries, #id)();
  IntColumn get amountInCents => integer()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {bookId, monthKey, categoryId},
  ];
}

@DataClassName('RecurringBillEntity')
class RecurringBillEntries extends Table {
  @override
  String get tableName => 'recurring_bills';

  TextColumn get id => text()();
  TextColumn get bookId => text()();
  TextColumn get name => text()();
  TextColumn get type => text()();
  IntColumn get amountInCents => integer()();
  TextColumn get cycle => text()();
  DateTimeColumn get startDate => dateTime()();
  DateTimeColumn get endDate => dateTime().nullable()();
  DateTimeColumn get nextDate => dateTime()();
  TextColumn get accountId => text().nullable()();
  TextColumn get categoryId => text().nullable()();
  IntColumn get customIntervalDays => integer().nullable()();
  BoolColumn get autoRecord => boolean().withDefault(const Constant(false))();
  BoolColumn get reminder => boolean().withDefault(const Constant(true))();
  TextColumn get scheduleJson => text().withDefault(const Constant('{}'))();
  TextColumn get status => text().withDefault(const Constant('active'))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('InstallmentPlanEntity')
class InstallmentPlanEntries extends Table {
  @override
  String get tableName => 'installment_plans';

  TextColumn get id => text()();
  TextColumn get bookId => text()();
  TextColumn get name => text()();
  TextColumn get originalTransactionId => text()();
  IntColumn get totalAmountInCents => integer()();
  IntColumn get totalPeriods => integer()();
  IntColumn get currentPeriod => integer()();
  IntColumn get principalPerPeriodInCents => integer()();
  IntColumn get feePerPeriodInCents => integer()();
  DateTimeColumn get startDate => dateTime()();
  IntColumn get dueDay => integer()();
  TextColumn get creditAccountId => text()();
  TextColumn get repaymentAccountId => text()();
  IntColumn get remainingPrincipalInCents => integer()();
  TextColumn get status => text().withDefault(const Constant('active'))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// A tradable instrument known to the app (股票 / 基金 / 债券 / 虚拟币).
///
/// Rows are shared by every user: two users holding `600519` resolve to the
/// same asset id, so the quote cache keyed by symbol is shared as well.
@DataClassName('InvestmentAssetEntity')
class InvestmentAssetEntries extends Table {
  @override
  String get tableName => 'investment_assets';

  TextColumn get id => text()();

  /// `stock` | `fund` | `bond` | `crypto`.
  TextColumn get type => text()();
  TextColumn get symbol => text()();
  TextColumn get name => text()();
  TextColumn get market => text().withDefault(const Constant('CN'))();
  TextColumn get currency => text().withDefault(const Constant('CNY'))();

  /// `market` | `manual`.
  TextColumn get priceSource => text().withDefault(const Constant('market'))();

  /// Last user-entered valuation, only meaningful for manual assets.
  RealColumn get manualPrice => real().nullable()();

  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// One user's position in one [InvestmentAssetEntries].
@DataClassName('InvestmentHoldingEntity')
class InvestmentHoldingEntries extends Table {
  @override
  String get tableName => 'investment_holdings';

  TextColumn get id => text()();
  TextColumn get bookId =>
      text().withDefault(const Constant('book-personal'))();
  TextColumn get assetId => text().references(InvestmentAssetEntries, #id)();

  /// Optional attribution to an existing 账户管理 account.
  TextColumn get accountId => text().nullable()();

  RealColumn get quantity => real()();
  RealColumn get averageCost => real()();
  TextColumn get note => text().nullable()();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();

  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// A buy / sell / dividend / interest applied to a holding.
///
/// These rows are NEVER written into `transactions`: buying an investment is
/// an asset-to-asset conversion, not consumption, so it must not reduce net
/// worth the way an expense does.
@DataClassName('InvestmentTransactionEntity')
class InvestmentTransactionEntries extends Table {
  @override
  String get tableName => 'investment_transactions';

  TextColumn get id => text()();
  TextColumn get bookId =>
      text().withDefault(const Constant('book-personal'))();
  TextColumn get holdingId =>
      text().references(InvestmentHoldingEntries, #id)();

  /// `buy` | `sell` | `dividend` | `interest`.
  TextColumn get type => text()();
  RealColumn get price => real()();
  RealColumn get quantity => real()();

  /// Signed cash effect. A buy is negative (money out), everything else is
  /// positive (money in).
  RealColumn get amount => real()();

  DateTimeColumn get transactionDate => dateTime()();
  TextColumn get note => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// One portfolio snapshot per ledger per calendar day.
///
/// Written lazily the first time 投资管理 is opened on a given day. No
/// background timer exists, so an inactive user costs nothing.
@DataClassName('InvestmentSnapshotEntity')
class InvestmentSnapshotEntries extends Table {
  @override
  String get tableName => 'investment_snapshots';

  TextColumn get bookId => text()();

  /// `YYYY-MM-DD`, so a day is one row regardless of timezone offsets.
  TextColumn get date => text()();
  RealColumn get investmentValue => real()();
  RealColumn get stockValue => real()();
  RealColumn get fundValue => real()();
  RealColumn get bondValue => real()();
  RealColumn get cryptoValue => real()();

  @override
  Set<Column<Object>> get primaryKey => {bookId, date};
}

@DataClassName('MerchantRuleEntity')
class MerchantRuleEntries extends Table {
  @override
  String get tableName => 'merchant_rules';

  TextColumn get id => text()();
  TextColumn get bookId =>
      text().withDefault(const Constant('book-personal'))();
  TextColumn get merchantPattern => text()();
  TextColumn get normalizedPattern => text()();
  TextColumn get matchType => text()();
  @ReferenceName('merchantRuleCategory')
  TextColumn get categoryId => text().references(CategoryEntries, #id)();
  @ReferenceName('merchantRuleSubcategory')
  TextColumn get subcategoryId =>
      text().nullable().references(CategoryEntries, #id)();
  TextColumn get userId => text().nullable()();
  RealColumn get confidence => real()();
  TextColumn get source => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {bookId, userId, normalizedPattern, matchType},
  ];
}

@DataClassName('EconomicEventEntity')
class EconomicEventEntries extends Table {
  @override
  String get tableName => 'economic_events';

  TextColumn get id => text()();
  TextColumn get bookId => text()();
  IntColumn get amountInCents => integer()();
  TextColumn get currency => text().withDefault(const Constant('CNY'))();
  DateTimeColumn get occurredAt => dateTime()();
  TextColumn get status => text().withDefault(const Constant('candidate'))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('EconomicEventRecordEntity')
class EconomicEventRecordEntries extends Table {
  @override
  String get tableName => 'economic_event_records';

  TextColumn get id => text()();
  TextColumn get eventId => text().references(EconomicEventEntries, #id)();
  TextColumn get transactionId => text().references(TransactionEntries, #id)();
  TextColumn get role => text().withDefault(const Constant('source'))();
  TextColumn get fingerprint => text()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {eventId, transactionId},
  ];
}

@DataClassName('InboxItemEntity')
class InboxItemEntries extends Table {
  @override
  String get tableName => 'inbox_items';

  TextColumn get id => text()();
  TextColumn get bookId =>
      text().withDefault(const Constant('book-personal'))();
  @ReferenceName('inboxTransaction')
  TextColumn get transactionId =>
      text().nullable().references(TransactionEntries, #id)();
  @ReferenceName('inboxCandidateTransaction')
  TextColumn get candidateTransactionId =>
      text().nullable().references(TransactionEntries, #id)();
  TextColumn get reason => text()();
  TextColumn get status => text().withDefault(const Constant('pending'))();
  RealColumn get duplicateConfidence => real().nullable()();
  TextColumn get payloadJson => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get resolvedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('FamilyEntity')
class FamilyEntries extends Table {
  @override
  String get tableName => 'families';

  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get ownerUserId => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  IntColumn get version => integer().withDefault(const Constant(1))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('BookEntity')
class BookEntries extends Table {
  @override
  String get tableName => 'books';

  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get type => text()();
  TextColumn get ownerUserId => text()();
  TextColumn get familyId => text().nullable().references(FamilyEntries, #id)();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();
  TextColumn get assetSourceBookId => text().nullable()();
  IntColumn get version => integer().withDefault(const Constant(1))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('FamilyMemberEntity')
class FamilyMemberEntries extends Table {
  @override
  String get tableName => 'family_members';

  TextColumn get id => text()();
  TextColumn get familyId => text().references(FamilyEntries, #id)();
  TextColumn get userId => text()();
  TextColumn get role => text()();
  DateTimeColumn get joinedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {familyId, userId},
  ];
}

@DataClassName('FamilyInvitationEntity')
class FamilyInvitationEntries extends Table {
  @override
  String get tableName => 'family_invitations';

  TextColumn get id => text()();
  TextColumn get familyId => text().references(FamilyEntries, #id)();
  TextColumn get code => text().unique()();
  TextColumn get invitedBy => text()();
  TextColumn get status => text().withDefault(const Constant('pending'))();
  DateTimeColumn get expiresAt => dateTime()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get resolvedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('FamilyOperationLogEntity')
class FamilyOperationLogEntries extends Table {
  @override
  String get tableName => 'family_operation_logs';

  TextColumn get id => text()();
  TextColumn get familyId => text().references(FamilyEntries, #id)();
  TextColumn get actorUserId => text()();
  TextColumn get entityType => text()();
  TextColumn get entityId => text()();
  TextColumn get action => text()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('FamilyBudgetEntity')
class FamilyBudgetEntries extends Table {
  @override
  String get tableName => 'family_budgets';

  TextColumn get id => text()();
  TextColumn get bookId => text().references(BookEntries, #id)();
  TextColumn get monthKey => text()();
  TextColumn get categoryId =>
      text().nullable().references(CategoryEntries, #id)();
  IntColumn get amountInCents => integer()();
  TextColumn get visibility => text().withDefault(const Constant('shared'))();
  TextColumn get createdBy => text()();
  TextColumn get updatedBy => text()();
  IntColumn get version => integer().withDefault(const Constant(1))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {bookId, monthKey, categoryId},
  ];
}

@DataClassName('AdEventEntity')
class AdEventEntries extends Table {
  @override
  String get tableName => 'ad_events';

  TextColumn get id => text()();
  TextColumn get placementId => text()();
  TextColumn get eventType => text()();
  TextColumn get provider => text()();
  TextColumn get sessionId => text().nullable()();
  DateTimeColumn get occurredAt => dateTime()();
  TextColumn get metadataJson => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DriftDatabase(
  tables: [
    AccountEntries,
    CategoryEntries,
    TransactionEntries,
    GoalEntries,
    GoalMilestoneEntries,
    GoalContributionEntries,
    AppSettingEntries,
    BudgetEntries,
    RecurringBillEntries,
    InstallmentPlanEntries,
    MerchantRuleEntries,
    EconomicEventEntries,
    EconomicEventRecordEntries,
    InboxItemEntries,
    FamilyEntries,
    BookEntries,
    FamilyMemberEntries,
    FamilyInvitationEntries,
    FamilyOperationLogEntries,
    FamilyBudgetEntries,
    AdEventEntries,
    TransactionAttachmentEntries,
    InvestmentAssetEntries,
    InvestmentHoldingEntries,
    InvestmentTransactionEntries,
    InvestmentSnapshotEntries,
  ],
  daos: [
    AccountDao,
    CategoryDao,
    TransactionDao,
    GoalDao,
    AppSettingsDao,
    BudgetDao,
    RecurringBillDao,
    InstallmentPlanDao,
    IntelligenceDao,
    FamilyDao,
    AdEventDao,
    TransactionAttachmentDao,
    InvestmentDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  AppDatabase.forTesting(super.executor);

  String currentActor = 'user-local';
  bool syncSchemaReady = false;
  static final _batchZone = Object();

  @override
  Future<T> transaction<T>(
    Future<T> Function() action, {
    bool requireNew = false,
  }) {
    if (!syncSchemaReady || Zone.current[_batchZone] != null) {
      return super.transaction(action, requireNew: requireNew);
    }
    return super.transaction(
      // batch_id lives in a shared row, but this update and the whole action
      // run inside the same SQLite write transaction. SQLite serializes
      // writers, so another connection cannot overwrite batch_id until this
      // transaction commits or rolls back.
      () => runZoned(() async {
        await customStatement('UPDATE sync_control SET batch_id=? WHERE id=1', [
          newEntityId(),
        ]);
        try {
          return await action();
        } finally {
          await customStatement(
            'UPDATE sync_control SET batch_id=NULL WHERE id=1',
          );
        }
      }, zoneValues: {_batchZone: true}),
      requireNew: requireNew,
    );
  }

  static const databaseFileName = 'haohao_jizhang.sqlite';
  static const pendingRestoreSuffix = '.pending-restore';

  @override
  int get schemaVersion => 21;

  static Future<void> applyPendingRestore(File databaseFile) {
    return _applyPendingDatabaseRestore(databaseFile);
  }

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) async {
      await migrator.createAll();
      await _createIndexes();
      await _createScopeIndexes();
      await ensureDataBindingSchema();
      await installSyncSchema();
      await _createAccountManagementSchema();
    },
    onUpgrade: (migrator, from, to) async {
      await transaction(() async {
        if (from >= 14 &&
            from < 17 &&
            !await _hasColumn('recurring_bills', 'schedule_json')) {
          await migrator.addColumn(
            recurringBillEntries,
            recurringBillEntries.scheduleJson,
          );
        }
        // Version 1 is the initial persistent schema. Future versions must add
        // explicit, forward-only migrations here instead of deleting the DB.
        if (from < 1) {
          await migrator.createAll();
          await _createIndexes();
        }
        if (from < 2) {
          await migrator.createTable(budgetEntries);
          await customStatement(
            'CREATE INDEX IF NOT EXISTS idx_budgets_month '
            'ON budgets(month_key)',
          );
        }
        if (from < 3) {
          await migrator.addColumn(goalEntries, goalEntries.goalType);
          await migrator.addColumn(
            goalEntries,
            goalEntries.completionCelebrationShown,
          );
        }
        if (from < 4) {
          await migrator.addColumn(
            transactionEntries,
            transactionEntries.duplicateConfidence,
          );
          await migrator.createTable(merchantRuleEntries);
          await migrator.createTable(economicEventEntries);
          await migrator.createTable(economicEventRecordEntries);
          await migrator.createTable(inboxItemEntries);
          await _createIntelligenceIndexes();
        }
        if (from < 5) {
          await migrator.addColumn(
            transactionEntries,
            transactionEntries.visibility,
          );
          await migrator.addColumn(
            transactionEntries,
            transactionEntries.createdBy,
          );
          await migrator.addColumn(
            transactionEntries,
            transactionEntries.updatedBy,
          );
          await migrator.addColumn(
            transactionEntries,
            transactionEntries.version,
          );
          await migrator.addColumn(goalEntries, goalEntries.bookId);
          await migrator.addColumn(goalEntries, goalEntries.createdBy);
          await migrator.addColumn(goalEntries, goalEntries.updatedBy);
          await migrator.addColumn(goalEntries, goalEntries.version);
          await migrator.addColumn(
            goalContributionEntries,
            goalContributionEntries.contributorUserId,
          );
          await migrator.createTable(familyEntries);
          await migrator.createTable(bookEntries);
          await migrator.createTable(familyMemberEntries);
          await migrator.createTable(familyInvitationEntries);
          await migrator.createTable(familyOperationLogEntries);
          await migrator.createTable(familyBudgetEntries);
          await _createFamilyIndexes();
        }
        if (from < 6) {
          await migrator.createTable(adEventEntries);
          await _createAdIndexes();
        }
        if (from < 7) {
          await migrator.addColumn(accountEntries, accountEntries.assetForm);
        }
        if (from < 8) {
          await migrator.addColumn(goalEntries, goalEntries.sortOrder);
          await migrator.addColumn(
            goalEntries,
            goalEntries.monthlyReservationInCents,
          );
          if (!await _hasColumn('books', 'is_archived')) {
            await migrator.addColumn(bookEntries, bookEntries.isArchived);
          }
          await _createBookIndexes();
        }
        if (from < 9) await _migrateBookScopes();
        if (from < 11) {
          await migrator.createTable(transactionAttachmentEntries);
          await _migrateLegacyTransactionAttachments();
          await _createAttachmentIndexes();
        }
        if (from < 12) {
          if (!await _hasColumn('books', 'asset_source_book_id')) {
            await migrator.addColumn(
              bookEntries,
              bookEntries.assetSourceBookId,
            );
          }
        }
        if (from < 13) {
          if (!await _hasColumn('transactions', 'related_transaction_id')) {
            await migrator.addColumn(
              transactionEntries,
              transactionEntries.relatedTransactionId,
            );
          }
          if (!await _hasColumn('transactions', 'reimbursement_status')) {
            await migrator.addColumn(
              transactionEntries,
              transactionEntries.reimbursementStatus,
            );
          }
          if (!await _hasColumn(
            'transactions',
            'reimbursement_amount_in_cents',
          )) {
            await migrator.addColumn(
              transactionEntries,
              transactionEntries.reimbursementAmountInCents,
            );
          }
          if (!await _hasColumn('transactions', 'reimbursement_date')) {
            await migrator.addColumn(
              transactionEntries,
              transactionEntries.reimbursementDate,
            );
          }
          if (!await _hasColumn('transactions', 'reimbursement_note')) {
            await migrator.addColumn(
              transactionEntries,
              transactionEntries.reimbursementNote,
            );
          }
          if (!await _hasColumn('transactions', 'refund_status')) {
            await migrator.addColumn(
              transactionEntries,
              transactionEntries.refundStatus,
            );
          }
          if (!await _hasColumn('transactions', 'refund_amount_in_cents')) {
            await migrator.addColumn(
              transactionEntries,
              transactionEntries.refundAmountInCents,
            );
          }
        }
        if (from < 14) {
          await migrator.createTable(recurringBillEntries);
        }
        if (from < 15) {
          await migrator.createTable(installmentPlanEntries);
        }
        if (from < 16) {
          if (!await _hasColumn('accounts', 'identifier_suffix')) {
            await migrator.addColumn(
              accountEntries,
              accountEntries.identifierSuffix,
            );
          }
          await _createAccountIdentifierIndex();
        }
        // Version 18 introduces the 投资管理 module. It is purely additive:
        // three new tables, no change to any existing column, so upgrading
        // users keep every account, transaction and balance untouched.
        if (from < 18) {
          await migrator.createTable(investmentAssetEntries);
          await migrator.createTable(investmentHoldingEntries);
          await migrator.createTable(investmentTransactionEntries);
          await migrator.createTable(investmentSnapshotEntries);
          await _createInvestmentIndexes();
        }
        if (from < 19) {
          await ensureDataBindingSchema();
        }
        // v20 moves sync/index schema installation out of beforeOpen. These
        // writes must run as part of the versioned migration so independent
        // foreground/background database connections don't rebuild triggers
        // every time they open the same SQLite file.
        if (from < 20) {
          await _createScopeIndexes();
          await ensureDataBindingSchema();
          await installSyncSchema();
        }
        if (from < 21) {
          await _createAccountManagementSchema();
        }
      });
    },
    beforeOpen: (details) async {
      // Connection-local safety only. Schema-changing work belongs in
      // onCreate/onUpgrade so concurrent isolates can open without racing on
      // DROP/CREATE TRIGGER and other DDL.
      await customStatement('PRAGMA foreign_keys = ON');
      syncSchemaReady = true;
    },
  );

  Future<void> _createIndexes() async {
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_transactions_occurred_at '
      'ON transactions(occurred_at DESC)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_transactions_book_deleted '
      'ON transactions(book_id, deleted_at)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_goal_milestones_goal '
      'ON goal_milestones(goal_id, sort_order)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_goal_contributions_goal '
      'ON goal_contributions(goal_id, created_at)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_budgets_month '
      'ON budgets(month_key)',
    );
    await _createIntelligenceIndexes();
    await _createFamilyIndexes();
    await _createBookIndexes();
    await _createAdIndexes();
    await _createAttachmentIndexes();
    await _createAccountIdentifierIndex();
    await _createInvestmentIndexes();
  }

  Future<void> _createInvestmentIndexes() async {
    await customStatement(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_investment_assets_symbol '
      'ON investment_assets(type, market, symbol)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_investment_holdings_book '
      'ON investment_holdings(book_id, is_archived)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_investment_holdings_asset '
      'ON investment_holdings(asset_id)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_investment_transactions_holding '
      'ON investment_transactions(holding_id, transaction_date)',
    );
  }

  Future<void> _createAccountIdentifierIndex() async {
    await customStatement(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_accounts_book_identifier_suffix '
      'ON accounts(book_id, identifier_suffix) '
      'WHERE identifier_suffix IS NOT NULL',
    );
  }

  Future<void> _createAccountManagementSchema() async {
    await customStatement(
      'CREATE TABLE IF NOT EXISTS account_management_meta ('
      'account_id TEXT PRIMARY KEY NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,'
      'fund_category TEXT NOT NULL DEFAULT "available",'
      'platform TEXT,'
      'restricted_status TEXT,'
      'expected_return_at INTEGER,'
      'include_in_total INTEGER NOT NULL DEFAULT 1,'
      'note TEXT,'
      'updated_at INTEGER NOT NULL'
      ')',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_account_management_meta_category '
      'ON account_management_meta(fund_category)',
    );
    await customStatement(
      'CREATE TABLE IF NOT EXISTS receivables ('
      'id TEXT PRIMARY KEY NOT NULL,'
      'book_id TEXT NOT NULL,'
      'name TEXT NOT NULL,'
      'type TEXT NOT NULL,'
      'counterparty TEXT NOT NULL,'
      'total_amount_in_cents INTEGER NOT NULL,'
      'received_amount_in_cents INTEGER NOT NULL DEFAULT 0,'
      'occurred_at INTEGER NOT NULL,'
      'expected_at INTEGER,'
      'status TEXT NOT NULL DEFAULT "pending",'
      'business_status TEXT NOT NULL DEFAULT "",'
      'remark TEXT,'
      'created_at INTEGER NOT NULL,'
      'updated_at INTEGER NOT NULL'
      ')',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_receivables_book_status '
      'ON receivables(book_id, status, expected_at)',
    );
    await customStatement(
      'CREATE TABLE IF NOT EXISTS receivable_events ('
      'id TEXT PRIMARY KEY NOT NULL,'
      'receivable_id TEXT NOT NULL REFERENCES receivables(id) ON DELETE CASCADE,'
      'event_type TEXT NOT NULL,'
      'title TEXT NOT NULL,'
      'description TEXT,'
      'amount_in_cents INTEGER,'
      'created_at INTEGER NOT NULL'
      ')',
    );
    final eventColumns = await customSelect(
      'PRAGMA table_info(receivable_events)',
    ).get();
    if (!eventColumns.any(
      (row) => row.read<String>('name') == 'amount_in_cents',
    )) {
      await customStatement(
        'ALTER TABLE receivable_events ADD COLUMN amount_in_cents INTEGER',
      );
    }
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_receivable_events_receivable '
      'ON receivable_events(receivable_id, created_at DESC)',
    );
  }

  Future<void> _createAttachmentIndexes() async {
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_transaction_attachments_transaction '
      'ON transaction_attachments(transaction_id, deleted_at, created_at)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_transaction_attachments_book '
      'ON transaction_attachments(book_id, deleted_at)',
    );
  }

  Future<void> _migrateLegacyTransactionAttachments() async {
    final hasMetadata = await _hasColumn('transactions', 'metadata_json');
    if (!hasMetadata) return;
    final hasBookId = await _hasColumn('transactions', 'book_id');
    final rows = await customSelect(
      'SELECT id, ${hasBookId ? 'book_id, ' : ''}metadata_json FROM transactions '
      'WHERE metadata_json IS NOT NULL',
    ).get();
    for (final row in rows) {
      final metadataJson = row.read<String>('metadata_json');
      final decoded = _decodeLegacyMetadata(metadataJson);
      if (decoded == null || !decoded.containsKey('attachments')) continue;
      final rawAttachments = decoded['attachments'];
      if (rawAttachments is! List) continue;

      final transactionId = row.read<String>('id');
      final bookId = hasBookId ? row.read<String>('book_id') : 'book-personal';
      final now = DateTime.now();
      final paths = <String>[];
      final malformedAttachments = <Object?>[];
      for (final raw in rawAttachments) {
        final path = switch (raw) {
          String value => value.trim(),
          Map value =>
            value['path'] is String ? (value['path'] as String).trim() : '',
          _ => '',
        };
        if (path.isEmpty) {
          malformedAttachments.add(raw);
          continue;
        }
        if (paths.contains(path)) continue;
        paths.add(path);
        final attachmentTime = now.add(Duration(microseconds: paths.length));
        await customStatement(
          'INSERT INTO transaction_attachments '
          '(id,book_id,transaction_id,path,name,mime_type,sort_order,created_at,updated_at) '
          'VALUES (?,?,?,?,?,?,?,?,?)',
          [
            'attachment-${newEntityId()}',
            bookId,
            transactionId,
            path,
            _attachmentName(path),
            _attachmentMimeType(path),
            paths.length - 1,
            attachmentTime.millisecondsSinceEpoch ~/ 1000,
            attachmentTime.millisecondsSinceEpoch ~/ 1000,
          ],
        );
      }

      if (malformedAttachments.isEmpty) {
        decoded.remove('attachments');
      } else {
        decoded['attachments'] = malformedAttachments;
      }
      await customStatement(
        'UPDATE transactions SET metadata_json=? WHERE id=?',
        [decoded.isEmpty ? null : jsonEncode(decoded), transactionId],
      );
    }
  }

  Map<String, dynamic>? _decodeLegacyMetadata(String value) {
    try {
      final decoded = jsonDecode(value);
      if (decoded is Map) {
        return decoded.map((key, item) => MapEntry(key.toString(), item));
      }
    } on Object {
      // Keep malformed legacy metadata untouched for the detail page to flag.
    }
    return null;
  }

  String _attachmentName(String path) {
    final normalized = path.replaceAll('\\\\', '/');
    final name = normalized.split('/').last.trim();
    return name.isEmpty ? '未命名附件' : name;
  }

  String _attachmentMimeType(String path) {
    final extension = _attachmentName(path).split('.').last.toLowerCase();
    return switch (extension) {
      'bmp' => 'image/bmp',
      'gif' => 'image/gif',
      'heic' || 'heif' => 'image/heic',
      'jpeg' || 'jpg' => 'image/jpeg',
      'pdf' => 'application/pdf',
      'png' => 'image/png',
      'webp' => 'image/webp',
      'txt' => 'text/plain',
      'csv' => 'text/csv',
      'doc' => 'application/msword',
      'docx' => 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'xls' => 'application/vnd.ms-excel',
      'xlsx' =>
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      _ => 'application/octet-stream',
    };
  }

  Future<bool> _hasColumn(String table, String column) async {
    final rows = await customSelect('PRAGMA table_info("$table")').get();
    return rows.any((row) => row.data['name'] == column);
  }

  Future<void> _createIntelligenceIndexes() async {
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_merchant_rules_pattern '
      'ON merchant_rules(normalized_pattern, match_type, user_id)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_inbox_status '
      'ON inbox_items(status, created_at DESC)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_event_records_event '
      'ON economic_event_records(event_id)',
    );
  }

  Future<void> _createFamilyIndexes() async {
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_family_members_family '
      'ON family_members(family_id, user_id)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_family_invites_code '
      'ON family_invitations(code, status)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_family_logs_entity '
      'ON family_operation_logs(family_id, entity_type, entity_id)',
    );
  }

  Future<void> _createBookIndexes() async {
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_books_owner_archived '
      'ON books(owner_user_id, is_archived, created_at)',
    );
  }

  Future<void> _createAdIndexes() async {
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_ad_events_placement_time '
      'ON ad_events(placement_id, event_type, occurred_at)',
    );
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File(p.join(directory.path, AppDatabase.databaseFileName));
    final encryptionKey = await DatabaseEncryptionKeyStore().loadOrCreate();

    await _ensureDatabaseEncrypted(file, encryptionKey);

    // Restores are staged while the live database is open and are applied only
    // after an app/process restart. Never swap the database, -wal, or -shm
    // files opportunistically from a database opener: another FlutterEngine
    // may already own a live connection to this file.
    if (await file.exists()) {
      final source = sqlite.sqlite3.open(
        file.path,
        mode: sqlite.OpenMode.readOnly,
      );
      try {
        _applyDatabaseKey(source, encryptionKey);
        if (source.userVersion < 10) {
          final backup =
              '${file.path}.pre-migration-v${source.userVersion}-${DateTime.now().microsecondsSinceEpoch}.sqlite';
          source.execute('VACUUM INTO ?', [backup]);
        }
      } finally {
        source.close();
      }
    }

    // sqlite3 is built with SQLite3MultipleCiphers. PRAGMA key must be the first
    // connection operation before Drift reads sqlite_master or user_version.
    return NativeDatabase.createInBackground(
      file,
      setup: (database) {
        _applyDatabaseKey(database, encryptionKey);
        final cipher = database.select('PRAGMA cipher');
        if (cipher.isEmpty) {
          throw StateError('当前 SQLite 构建不支持数据库加密');
        }
        // WAL lets readers proceed while another isolate is writing. A busy
        // timeout makes short write/write overlaps wait instead of failing
        // immediately with SQLITE_BUSY.
        database.execute('PRAGMA busy_timeout = 5000');
        database.execute('PRAGMA journal_mode = WAL');
        database.execute('PRAGMA foreign_keys = ON');
      },
    );
  });
}

void _applyDatabaseKey(sqlite.Database database, String key) {
  final escaped = key.replaceAll("'", "''");
  database.execute("PRAGMA key = '$escaped'");
}

bool _canReadEncryptedDatabase(File file, String key) {
  sqlite.Database? database;
  try {
    database = sqlite.sqlite3.open(file.path, mode: sqlite.OpenMode.readOnly);
    _applyDatabaseKey(database, key);
    database.select('SELECT count(*) FROM sqlite_master');
    return true;
  } on Object {
    return false;
  } finally {
    database?.close();
  }
}

bool _canReadPlainDatabase(File file) {
  sqlite.Database? database;
  try {
    database = sqlite.sqlite3.open(file.path, mode: sqlite.OpenMode.readOnly);
    database.select('SELECT count(*) FROM sqlite_master');
    return true;
  } on Object {
    return false;
  } finally {
    database?.close();
  }
}

Future<void> _ensureDatabaseEncrypted(File file, String key) async {
  if (!await file.exists()) return;
  if (_canReadEncryptedDatabase(file, key)) {
    await _removeStalePlaintextMigrationCopies(file);
    return;
  }

  final lockFile = File('${file.path}.encryption-migration.lock');
  final lock = await lockFile.open(mode: FileMode.append);
  await lock.lock(FileLock.exclusive);
  try {
    // Another isolate may have completed the migration while this isolate was
    // waiting for the OS file lock.
    if (_canReadEncryptedDatabase(file, key)) {
      await _removeStalePlaintextMigrationCopies(file);
      return;
    }
    if (!_canReadPlainDatabase(file)) {
      throw StateError(
        '本地数据库无法解密。系统安全存储中的数据库密钥可能已丢失，请从备份恢复。',
      );
    }

    final temporary = File(
      '${file.path}.encrypting-${DateTime.now().microsecondsSinceEpoch}',
    );
    await _deleteIfExists(temporary);

    sqlite.Database? source;
    sqlite.Database? target;
    try {
      source = sqlite.sqlite3.open(file.path);
      source.execute('PRAGMA busy_timeout = 5000');
      source.execute('PRAGMA wal_checkpoint(TRUNCATE)');
      source.execute('VACUUM INTO ?', [temporary.path]);
      source.close();
      source = null;

      target = sqlite.sqlite3.open(temporary.path);
      final escaped = key.replaceAll("'", "''");
      target.execute("PRAGMA rekey = '$escaped'");
      target.select('SELECT count(*) FROM sqlite_master');
      target.close();
      target = null;

      if (!_canReadEncryptedDatabase(temporary, key)) {
        throw StateError('数据库加密迁移校验失败');
      }

      final safety = File(
        '${file.path}.pre-encryption-${DateTime.now().microsecondsSinceEpoch}',
      );
      await file.copy(safety.path);
      await _deleteIfExists(File('${file.path}-wal'));
      await _deleteIfExists(File('${file.path}-shm'));

      // On Android/iOS this is an atomic rename on the same filesystem. The
      // transient plaintext safety copy is removed only after the encrypted
      // destination has been opened successfully with the device key.
      await temporary.rename(file.path);
      if (!_canReadEncryptedDatabase(file, key)) {
        await _deleteIfExists(file);
        await safety.rename(file.path);
        throw StateError('数据库加密迁移后的文件无法验证');
      }
      await _deleteIfExists(safety);
      await _removeStalePlaintextMigrationCopies(file);
    } finally {
      source?.close();
      target?.close();
      await _deleteIfExists(temporary);
    }
  } finally {
    await lock.unlock();
    await lock.close();
    await _deleteIfExists(lockFile);
  }
}

Future<void> _removeStalePlaintextMigrationCopies(File file) async {
  final directory = file.parent;
  final prefix = '${p.basename(file.path)}.pre-encryption-';
  await for (final entity in directory.list()) {
    if (entity is File && p.basename(entity.path).startsWith(prefix)) {
      await _deleteIfExists(entity);
    }
  }
}

Future<void> _applyPendingDatabaseRestore(File databaseFile) async {
  final pendingFile = File(
    '${databaseFile.path}${AppDatabase.pendingRestoreSuffix}',
  );
  if (!await pendingFile.exists()) return;

  // This method is intentionally NOT called by _openConnection(). Applying a
  // restore is a maintenance operation and is only safe before any Flutter
  // engine opens the live database. The foreground startup performs it before
  // runApp(); background entrypoints never apply pending restores.
  final safetyCopy = File(
    '${databaseFile.path}.pre-restore-on-open-${DateTime.now().microsecondsSinceEpoch}',
  );
  if (await databaseFile.exists()) {
    await databaseFile.copy(safetyCopy.path);
  }
  await _deleteIfExists(File('${databaseFile.path}-wal'));
  await _deleteIfExists(File('${databaseFile.path}-shm'));
  await pendingFile.rename(databaseFile.path);
  final restored = sqlite.sqlite3.open(databaseFile.path);
  try {
    if (restored
        .select("SELECT 1 FROM sqlite_master WHERE name='sync_books'")
        .isNotEmpty) {
      restored.execute(
        'UPDATE sync_books SET access=0, cursor=0, last_error=?',
        ['备份恢复后需要联网验证成员权限'],
      );
    }
  } finally {
    restored.close();
  }
}

Future<void> _deleteIfExists(File file) async {
  if (await file.exists()) await file.delete();
}

@DriftAccessor(tables: [AccountEntries])
class AccountDao extends DatabaseAccessor<AppDatabase> with _$AccountDaoMixin {
  AccountDao(super.attachedDatabase);

  Stream<List<AccountEntity>> watchAll({String? bookId}) =>
      (select(accountEntries)
            ..where(
              (row) => bookId == null
                  ? const Constant(true)
                  : row.bookId.equals(bookId),
            )
            ..orderBy([(row) => OrderingTerm.asc(row.sortOrder)]))
          .watch();

  Future<List<AccountEntity>> getAll({String? bookId}) =>
      (select(accountEntries)
            ..where(
              (row) => bookId == null
                  ? const Constant(true)
                  : row.bookId.equals(bookId),
            )
            ..orderBy([(row) => OrderingTerm.asc(row.sortOrder)]))
          .get();

  Future<void> writeFields(String id, AccountEntriesCompanion fields) async {
    final count = await (update(
      accountEntries,
    )..where((row) => row.id.equals(id))).write(fields);
    if (count != 1) throw StateError('账户不存在');
  }

  Stream<List<AccountEntity>> watchActive({String? bookId}) {
    return (select(accountEntries)
          ..where(
            (row) =>
                row.isArchived.equals(false) &
                (bookId == null
                    ? const Constant(true)
                    : row.bookId.equals(bookId)),
          )
          ..orderBy([(row) => OrderingTerm.asc(row.sortOrder)]))
        .watch();
  }

  Future<List<AccountEntity>> getActive({String? bookId}) {
    return (select(accountEntries)
          ..where(
            (row) =>
                row.isArchived.equals(false) &
                (bookId == null
                    ? const Constant(true)
                    : row.bookId.equals(bookId)),
          )
          ..orderBy([(row) => OrderingTerm.asc(row.sortOrder)]))
        .get();
  }

  Future<AccountEntity?> findById(String id) {
    return (select(
      accountEntries,
    )..where((row) => row.id.equals(id))).getSingleOrNull();
  }

  Future<AccountEntity?> findByIdentifierSuffix({
    required String bookId,
    required String suffix,
    String? excludingId,
  }) {
    return (select(accountEntries)..where(
          (row) =>
              row.bookId.equals(bookId) &
              row.identifierSuffix.equals(suffix) &
              (excludingId == null
                  ? const Constant(true)
                  : row.id.isNotIn([excludingId])),
        ))
        .getSingleOrNull();
  }

  Future<void> insertOne(AccountEntriesCompanion account) async {
    await into(accountEntries).insert(account);
  }

  Future<void> upsert(AccountEntriesCompanion account) async {
    await into(accountEntries).insertOnConflictUpdate(account);
  }

  Future<void> adjustBalance(
    String accountId,
    int deltaInCents,
    DateTime updatedAt,
  ) async {
    final account = await findById(accountId);
    if (account == null) {
      throw StateError('Account $accountId does not exist');
    }
    await (update(
      accountEntries,
    )..where((row) => row.id.equals(accountId))).write(
      AccountEntriesCompanion(
        balanceInCents: Value(account.balanceInCents + deltaInCents),
        updatedAt: Value(updatedAt),
      ),
    );
  }

  Future<void> reorderActive(List<String> ids, {String? bookId}) async {
    final active = await getActive(bookId: bookId);
    final activeIds = active.map((item) => item.id).toSet();
    if (ids.length != active.length || ids.toSet().length != ids.length) {
      throw ArgumentError(
        'Account order must include each active account once',
      );
    }
    if (!ids.every(activeIds.contains)) {
      throw ArgumentError('Account order contains an unknown account');
    }
    final now = DateTime.now();
    await attachedDatabase.transaction(() async {
      for (var index = 0; index < ids.length; index++) {
        await (update(
          accountEntries,
        )..where((row) => row.id.equals(ids[index]))).write(
          AccountEntriesCompanion(
            sortOrder: Value(index),
            updatedAt: Value(now),
          ),
        );
      }
    });
  }
}

@DriftAccessor(tables: [CategoryEntries])
class CategoryDao extends DatabaseAccessor<AppDatabase>
    with _$CategoryDaoMixin {
  CategoryDao(super.attachedDatabase);

  Stream<List<CategoryEntity>> watchActive({String? bookId}) {
    return (select(categoryEntries)
          ..where(
            (row) =>
                row.isArchived.equals(false) &
                (bookId == null
                    ? const Constant(true)
                    : row.bookId.equals(bookId)),
          )
          ..orderBy([(row) => OrderingTerm.asc(row.sortOrder)]))
        .watch();
  }

  Future<List<CategoryEntity>> getActive({String? bookId}) {
    return (select(categoryEntries)
          ..where(
            (row) =>
                row.isArchived.equals(false) &
                (bookId == null
                    ? const Constant(true)
                    : row.bookId.equals(bookId)),
          )
          ..orderBy([(row) => OrderingTerm.asc(row.sortOrder)]))
        .get();
  }

  Future<List<CategoryEntity>> getAll({String? bookId}) {
    return (select(categoryEntries)
          ..where(
            (row) => bookId == null
                ? const Constant(true)
                : row.bookId.equals(bookId),
          )
          ..orderBy([(row) => OrderingTerm.asc(row.sortOrder)]))
        .get();
  }

  Future<void> insertOne(CategoryEntriesCompanion category) async {
    await into(categoryEntries).insert(category);
  }

  Future<CategoryEntity?> findById(String id) {
    return (select(
      categoryEntries,
    )..where((row) => row.id.equals(id))).getSingleOrNull();
  }

  Future<void> upsert(CategoryEntriesCompanion category) async {
    await into(categoryEntries).insertOnConflictUpdate(category);
  }
}

@DriftAccessor(tables: [TransactionEntries])
class TransactionDao extends DatabaseAccessor<AppDatabase>
    with _$TransactionDaoMixin {
  TransactionDao(super.attachedDatabase);

  Stream<List<TransactionEntity>> watchActive({
    String? bookId,
    int? limit,
    bool onlyOccurred = false,
  }) {
    // Evaluate the time cutoff in SQLite on every stream refresh. Capturing
    // DateTime.now() here would hide transactions saved after subscribing.
    final query = select(transactionEntries)
      ..where(
        (row) =>
            row.deletedAt.isNull() &
            CustomExpression<bool>(
              SharedSyncSchema.visibleBooksSql('book_id'),
            ) &
            (bookId == null
                ? const Constant(true)
                : row.bookId.equals(bookId)) &
            (onlyOccurred
                ? row.occurredAt.isSmallerOrEqual(currentDateAndTime)
                : const Constant(true)),
      )
      ..orderBy([
        (row) => OrderingTerm.desc(row.occurredAt),
        (row) => OrderingTerm.desc(row.createdAt),
        (row) => OrderingTerm.desc(row.id),
      ]);
    if (limit != null) query.limit(limit);
    return query.watch();
  }

  Future<List<TransactionEntity>> getActive({
    String? bookId,
    int? limit,
    bool onlyOccurred = false,
  }) {
    final query = select(transactionEntries)
      ..where(
        (row) =>
            row.deletedAt.isNull() &
            CustomExpression<bool>(
              SharedSyncSchema.visibleBooksSql('book_id'),
            ) &
            (bookId == null
                ? const Constant(true)
                : row.bookId.equals(bookId)) &
            (onlyOccurred
                ? row.occurredAt.isSmallerOrEqual(currentDateAndTime)
                : const Constant(true)),
      )
      ..orderBy([
        (row) => OrderingTerm.desc(row.occurredAt),
        (row) => OrderingTerm.desc(row.createdAt),
        (row) => OrderingTerm.desc(row.id),
      ]);
    if (limit != null) query.limit(limit);
    return query.get();
  }

  Future<TransactionEntity?> findById(String id) {
    return (select(
      transactionEntries,
    )..where((row) => row.id.equals(id))).getSingleOrNull();
  }

  Future<TransactionEntity?> findActiveById(String id, {String? bookId}) {
    return (select(transactionEntries)..where(
          (row) =>
              row.id.equals(id) &
              row.deletedAt.isNull() &
              CustomExpression<bool>(
                SharedSyncSchema.visibleBooksSql('book_id'),
              ) &
              (bookId == null
                  ? const Constant(true)
                  : row.bookId.equals(bookId)),
        ))
        .getSingleOrNull();
  }

  Future<void> insertOne(TransactionEntriesCompanion transaction) async {
    await into(transactionEntries).insert(transaction);
  }

  Future<void> replaceOne(TransactionEntriesCompanion transaction) async {
    await into(transactionEntries).insertOnConflictUpdate(transaction);
  }

  Future<void> softDeleteById(String id, DateTime deletedAt) async {
    await (update(transactionEntries)..where((row) => row.id.equals(id))).write(
      TransactionEntriesCompanion(
        deletedAt: Value(deletedAt),
        updatedAt: Value(deletedAt),
      ),
    );
  }
}

@DriftAccessor(tables: [TransactionAttachmentEntries])
class TransactionAttachmentDao extends DatabaseAccessor<AppDatabase>
    with _$TransactionAttachmentDaoMixin {
  TransactionAttachmentDao(super.attachedDatabase);

  Stream<List<TransactionAttachmentEntity>> watchActiveForTransaction(
    String transactionId, {
    required String bookId,
  }) {
    final query = select(transactionAttachmentEntries)
      ..where(
        (row) =>
            row.transactionId.equals(transactionId) &
            row.bookId.equals(bookId) &
            row.deletedAt.isNull() &
            CustomExpression<bool>(SharedSyncSchema.visibleBooksSql('book_id')),
      )
      ..orderBy([
        (row) => OrderingTerm.asc(row.sortOrder),
        (row) => OrderingTerm.asc(row.createdAt),
        (row) => OrderingTerm.asc(row.id),
      ]);
    return query.watch();
  }

  Future<List<TransactionAttachmentEntity>> getForTransaction(
    String transactionId, {
    required String bookId,
    bool includeDeleted = false,
  }) {
    final query = select(transactionAttachmentEntries)
      ..where(
        (row) =>
            row.transactionId.equals(transactionId) &
            row.bookId.equals(bookId) &
            CustomExpression<bool>(
              SharedSyncSchema.visibleBooksSql('book_id'),
            ) &
            (includeDeleted ? const Constant(true) : row.deletedAt.isNull()),
      )
      ..orderBy([
        (row) => OrderingTerm.asc(row.sortOrder),
        (row) => OrderingTerm.asc(row.createdAt),
        (row) => OrderingTerm.asc(row.id),
      ]);
    return query.get();
  }

  Future<void> insertOne(TransactionAttachmentEntriesCompanion attachment) {
    return into(transactionAttachmentEntries).insert(attachment);
  }

  Future<void> replaceOne(TransactionAttachmentEntriesCompanion attachment) {
    return into(transactionAttachmentEntries)
        .insertOnConflictUpdate(attachment);
  }
}

@DriftAccessor(
  tables: [
    InvestmentAssetEntries,
    InvestmentHoldingEntries,
    InvestmentTransactionEntries,
    InvestmentSnapshotEntries,
  ],
)
class InvestmentDao extends DatabaseAccessor<AppDatabase>
    with _$InvestmentDaoMixin {
  InvestmentDao(super.attachedDatabase);

  /// Emits whenever anything the investment module renders changes, so the UI
  /// can refresh after a holding or transaction write.
  Stream<void> watchChanges() => select(investmentHoldingEntries).watch().map(
    (_) {},
  );

  // ---------------------------------------------------------------- assets

  Future<InvestmentAssetEntity?> findAssetBySymbol({
    required String type,
    required String market,
    required String symbol,
  }) {
    return (select(investmentAssetEntries)..where(
          (row) =>
              row.type.equals(type) &
              row.market.equals(market) &
              row.symbol.equals(symbol),
        ))
        .getSingleOrNull();
  }

  Future<InvestmentAssetEntity?> findAssetById(String id) {
    return (select(investmentAssetEntries)
          ..where((row) => row.id.equals(id)))
        .getSingleOrNull();
  }

  Future<List<InvestmentAssetEntity>> getAssetsByIds(List<String> ids) {
    if (ids.isEmpty) return Future.value(const []);
    return (select(investmentAssetEntries)
          ..where((row) => row.id.isIn(ids)))
        .get();
  }

  Future<void> upsertAsset(InvestmentAssetEntriesCompanion asset) {
    return into(investmentAssetEntries).insertOnConflictUpdate(asset);
  }

  Future<void> writeAssetPrice(String id, double? manualPrice) {
    return (update(investmentAssetEntries)..where((row) => row.id.equals(id)))
        .write(
          InvestmentAssetEntriesCompanion(
            manualPrice: Value(manualPrice),
            updatedAt: Value(DateTime.now()),
          ),
        );
  }

  // -------------------------------------------------------------- holdings

  Future<List<InvestmentHoldingEntity>> getHoldings({String? bookId}) {
    final query = select(investmentHoldingEntries)
      ..where(
        (row) => bookId == null
            ? const Constant(true)
            : row.bookId.equals(bookId),
      )
      ..orderBy([(row) => OrderingTerm.desc(row.createdAt)]);
    return query.get();
  }

  Future<InvestmentHoldingEntity?> findHoldingById(String id) {
    return (select(investmentHoldingEntries)
          ..where((row) => row.id.equals(id)))
        .getSingleOrNull();
  }

  Future<void> insertHolding(InvestmentHoldingEntriesCompanion holding) {
    return into(investmentHoldingEntries).insert(holding);
  }

  Future<void> writeHoldingFields(
    String id,
    InvestmentHoldingEntriesCompanion fields,
  ) {
    return (update(
      investmentHoldingEntries,
    )..where((row) => row.id.equals(id))).write(fields);
  }

  Future<void> deleteHolding(String id) {
    return (delete(
      investmentHoldingEntries,
    )..where((row) => row.id.equals(id))).go();
  }

  // ---------------------------------------------------------- transactions

  Future<List<InvestmentTransactionEntity>> getTransactions(
    String holdingId,
  ) {
    final query = select(investmentTransactionEntries)
      ..where((row) => row.holdingId.equals(holdingId))
      ..orderBy([
        (row) => OrderingTerm.desc(row.transactionDate),
        (row) => OrderingTerm.desc(row.createdAt),
      ]);
    return query.get();
  }

  Future<void> insertTransaction(
    InvestmentTransactionEntriesCompanion transaction,
  ) {
    return into(investmentTransactionEntries).insert(transaction);
  }

  Future<void> deleteTransactionsForHolding(String holdingId) {
    return (delete(
      investmentTransactionEntries,
    )..where((row) => row.holdingId.equals(holdingId))).go();
  }

  // ------------------------------------------------------------ snapshots

  Future<List<InvestmentSnapshotEntity>> getSnapshots({
    required String bookId,
    required String fromDate,
  }) {
    final query = select(investmentSnapshotEntries)
      ..where((row) => row.bookId.equals(bookId) & row.date.isBiggerOrEqualValue(fromDate))
      ..orderBy([(row) => OrderingTerm.asc(row.date)]);
    return query.get();
  }

  Future<InvestmentSnapshotEntity?> findSnapshot({
    required String bookId,
    required String date,
  }) {
    return (select(investmentSnapshotEntries)
          ..where((row) => row.bookId.equals(bookId) & row.date.equals(date)))
        .getSingleOrNull();
  }

  Future<void> upsertSnapshot(
    InvestmentSnapshotEntriesCompanion snapshot,
  ) {
    return into(investmentSnapshotEntries).insertOnConflictUpdate(snapshot);
  }
}

@DriftAccessor(
  tables: [GoalEntries, GoalMilestoneEntries, GoalContributionEntries],
)
class GoalDao extends DatabaseAccessor<AppDatabase> with _$GoalDaoMixin {
  GoalDao(super.attachedDatabase);

  Stream<void> watchChanges() {
    final query = select(goalEntries).join([
      leftOuterJoin(
        goalMilestoneEntries,
        goalMilestoneEntries.goalId.equalsExp(goalEntries.id),
      ),
      leftOuterJoin(
        goalContributionEntries,
        goalContributionEntries.goalId.equalsExp(goalEntries.id),
      ),
    ]);
    return query.watch().map((_) {});
  }

  Future<List<GoalEntity>> getAllGoals({String? bookId}) {
    return (select(goalEntries)
          ..where(
            (row) =>
                CustomExpression<bool>(
                  SharedSyncSchema.visibleBooksSql('book_id'),
                ) &
                (bookId == null
                    ? const Constant(true)
                    : row.bookId.equals(bookId)),
          )
          ..orderBy([(row) => OrderingTerm.desc(row.createdAt)]))
        .get();
  }

  Future<void> deleteById(String id) async {
    await (delete(
      goalContributionEntries,
    )..where((row) => row.goalId.equals(id))).go();
    await (delete(
      goalMilestoneEntries,
    )..where((row) => row.goalId.equals(id))).go();
    await (delete(goalEntries)..where((row) => row.id.equals(id))).go();
  }

  Future<GoalEntity?> findGoal(String id) {
    return (select(
      goalEntries,
    )..where((row) => row.id.equals(id))).getSingleOrNull();
  }

  Future<List<GoalMilestoneEntity>> getMilestones(String goalId) {
    return (select(goalMilestoneEntries)
          ..where((row) => row.goalId.equals(goalId))
          ..orderBy([(row) => OrderingTerm.asc(row.sortOrder)]))
        .get();
  }

  Future<List<GoalContributionEntity>> getContributions(String goalId) {
    return (select(goalContributionEntries)
          ..where((row) => row.goalId.equals(goalId))
          ..orderBy([(row) => OrderingTerm.desc(row.createdAt)]))
        .get();
  }

  Future<void> insertGoal(GoalEntriesCompanion goal) async {
    await into(goalEntries).insert(goal);
  }

  Future<void> upsertGoal(GoalEntriesCompanion goal) async {
    await into(goalEntries).insertOnConflictUpdate(goal);
  }

  Future<void> insertMilestone(GoalMilestoneEntriesCompanion milestone) async {
    await into(goalMilestoneEntries).insert(milestone);
  }

  Future<GoalMilestoneEntity?> findMilestone(String id) {
    return (select(
      goalMilestoneEntries,
    )..where((row) => row.id.equals(id))).getSingleOrNull();
  }

  Future<void> upsertMilestone(GoalMilestoneEntriesCompanion milestone) async {
    await into(goalMilestoneEntries).insertOnConflictUpdate(milestone);
  }

  Future<void> deleteMilestone(String id) async {
    await (delete(
      goalMilestoneEntries,
    )..where((row) => row.id.equals(id))).go();
  }

  Future<void> insertContribution(
    GoalContributionEntriesCompanion contribution,
  ) async {
    await into(goalContributionEntries).insert(contribution);
  }
}

@DriftAccessor(tables: [AppSettingEntries])
class AppSettingsDao extends DatabaseAccessor<AppDatabase>
    with _$AppSettingsDaoMixin {
  AppSettingsDao(super.attachedDatabase);

  Future<String?> getValue(String key) async {
    final row = await (select(
      appSettingEntries,
    )..where((row) => row.key.equals(key))).getSingleOrNull();
    return row?.value;
  }

  Future<void> setValue(String key, String value, DateTime updatedAt) async {
    await into(appSettingEntries).insertOnConflictUpdate(
      AppSettingEntriesCompanion.insert(
        key: key,
        value: value,
        updatedAt: updatedAt,
      ),
    );
  }
}

@DriftAccessor(tables: [BudgetEntries])
class BudgetDao extends DatabaseAccessor<AppDatabase> with _$BudgetDaoMixin {
  BudgetDao(super.attachedDatabase);

  Stream<List<BudgetEntity>> watchMonth(String monthKey, {String? bookId}) {
    return (select(budgetEntries)
          ..where(
            (row) =>
                row.monthKey.equals(monthKey) &
                (bookId == null
                    ? const Constant(true)
                    : row.bookId.equals(bookId)),
          )
          ..orderBy([(row) => OrderingTerm.asc(row.categoryId)]))
        .watch();
  }

  Future<List<BudgetEntity>> getMonth(String monthKey, {String? bookId}) {
    return (select(budgetEntries)
          ..where(
            (row) =>
                row.monthKey.equals(monthKey) &
                (bookId == null
                    ? const Constant(true)
                    : row.bookId.equals(bookId)),
          )
          ..orderBy([(row) => OrderingTerm.asc(row.categoryId)]))
        .get();
  }

  Future<void> upsert(BudgetEntriesCompanion budget) async {
    await into(budgetEntries).insertOnConflictUpdate(budget);
  }

  Future<void> deleteById(String id) async {
    await (delete(budgetEntries)..where((row) => row.id.equals(id))).go();
  }
}

@DriftAccessor(tables: [RecurringBillEntries])
class RecurringBillDao extends DatabaseAccessor<AppDatabase>
    with _$RecurringBillDaoMixin {
  RecurringBillDao(super.attachedDatabase);

  Stream<List<RecurringBillEntity>> watchActive({required String bookId}) {
    return (select(recurringBillEntries)
          ..where(
            (row) => row.bookId.equals(bookId) & row.status.equals('active'),
          )
          ..orderBy([(row) => OrderingTerm.asc(row.nextDate)]))
        .watch();
  }

  Future<List<RecurringBillEntity>> getAll({String? bookId}) {
    return (select(recurringBillEntries)
          ..where(
            (row) => bookId == null
                ? const Constant(true)
                : row.bookId.equals(bookId),
          )
          ..orderBy([(row) => OrderingTerm.asc(row.nextDate)]))
        .get();
  }

  Future<void> insertOne(RecurringBillEntriesCompanion bill) async {
    await into(recurringBillEntries).insert(bill);
  }

  Future<void> replaceOne(RecurringBillEntriesCompanion bill) async {
    await into(recurringBillEntries).insertOnConflictUpdate(bill);
  }

  Future<RecurringBillEntity?> findById(String id) {
    return (select(
      recurringBillEntries,
    )..where((row) => row.id.equals(id))).getSingleOrNull();
  }
}

@DriftAccessor(tables: [InstallmentPlanEntries])
class InstallmentPlanDao extends DatabaseAccessor<AppDatabase>
    with _$InstallmentPlanDaoMixin {
  InstallmentPlanDao(super.attachedDatabase);

  Stream<List<InstallmentPlanEntity>> watchActive({required String bookId}) {
    return (select(installmentPlanEntries)
          ..where(
            (row) => row.bookId.equals(bookId) & row.status.equals('active'),
          )
          ..orderBy([(row) => OrderingTerm.asc(row.startDate)]))
        .watch();
  }

  Future<List<InstallmentPlanEntity>> getActive({required String bookId}) {
    return (select(installmentPlanEntries)
          ..where(
            (row) => row.bookId.equals(bookId) & row.status.equals('active'),
          )
          ..orderBy([(row) => OrderingTerm.asc(row.startDate)]))
        .get();
  }

  Future<InstallmentPlanEntity?> findById(String id) {
    return (select(
      installmentPlanEntries,
    )..where((row) => row.id.equals(id))).getSingleOrNull();
  }

  Future<void> insertOne(InstallmentPlanEntriesCompanion plan) async {
    await into(installmentPlanEntries).insert(plan);
  }

  Future<void> replaceOne(InstallmentPlanEntriesCompanion plan) async {
    await into(installmentPlanEntries).insertOnConflictUpdate(plan);
  }
}

@DriftAccessor(
  tables: [
    MerchantRuleEntries,
    EconomicEventEntries,
    EconomicEventRecordEntries,
    InboxItemEntries,
  ],
)
class IntelligenceDao extends DatabaseAccessor<AppDatabase>
    with _$IntelligenceDaoMixin {
  IntelligenceDao(super.attachedDatabase);

  Future<List<MerchantRuleEntity>> getMerchantRules() {
    return (select(
      merchantRuleEntries,
    )..orderBy([(row) => OrderingTerm.desc(row.updatedAt)])).get();
  }

  Future<void> upsertMerchantRule(MerchantRuleEntriesCompanion rule) async {
    await into(merchantRuleEntries).insertOnConflictUpdate(rule);
  }

  Stream<List<InboxItemEntity>> watchPendingInbox() {
    return (select(inboxItemEntries)
          ..where((row) => row.status.equals('pending'))
          ..orderBy([(row) => OrderingTerm.desc(row.createdAt)]))
        .watch();
  }

  Future<List<InboxItemEntity>> getPendingInbox() {
    return (select(inboxItemEntries)
          ..where((row) => row.status.equals('pending'))
          ..orderBy([(row) => OrderingTerm.desc(row.createdAt)]))
        .get();
  }

  Future<void> upsertInboxItem(InboxItemEntriesCompanion item) async {
    await into(inboxItemEntries).insertOnConflictUpdate(item);
  }

  Future<InboxItemEntity?> findInboxItem(String id) {
    return (select(
      inboxItemEntries,
    )..where((row) => row.id.equals(id))).getSingleOrNull();
  }

  Future<void> insertEconomicEvent(EconomicEventEntriesCompanion event) async {
    await into(economicEventEntries).insert(event);
  }

  Future<void> insertEventRecord(
    EconomicEventRecordEntriesCompanion record,
  ) async {
    await into(economicEventRecordEntries).insertOnConflictUpdate(record);
  }

  Future<EconomicEventEntity?> findEconomicEventByTransactionId(
    String transactionId,
  ) async {
    final query = select(economicEventEntries).join([
      innerJoin(
        economicEventRecordEntries,
        economicEventRecordEntries.eventId.equalsExp(economicEventEntries.id),
      ),
    ])..where(economicEventRecordEntries.transactionId.equals(transactionId));
    return query
        .map((row) => row.readTable(economicEventEntries))
        .getSingleOrNull();
  }

  Future<void> updateEconomicEventStatus(
    String eventId,
    String status,
    DateTime updatedAt,
  ) async {
    await (update(
      economicEventEntries,
    )..where((row) => row.id.equals(eventId))).write(
      EconomicEventEntriesCompanion(
        status: Value(status),
        updatedAt: Value(updatedAt),
      ),
    );
  }

  Future<List<EconomicEventRecordEntity>> getEventRecords(String eventId) {
    return (select(
      economicEventRecordEntries,
    )..where((row) => row.eventId.equals(eventId))).get();
  }
}

@DriftAccessor(
  tables: [
    FamilyEntries,
    BookEntries,
    FamilyMemberEntries,
    FamilyInvitationEntries,
    FamilyOperationLogEntries,
    FamilyBudgetEntries,
  ],
)
class FamilyDao extends DatabaseAccessor<AppDatabase> with _$FamilyDaoMixin {
  FamilyDao(super.attachedDatabase);

  Stream<List<BookEntity>> watchBooksForUser(String userId) {
    return (select(bookEntries)
          ..where(
            (row) =>
                row.ownerUserId.equals(userId) & row.isArchived.equals(false),
          )
          ..orderBy([(row) => OrderingTerm.asc(row.createdAt)]))
        .watch();
  }

  Future<List<BookEntity>> getBooksForUser(String userId) {
    return (select(bookEntries)
          ..where(
            (row) =>
                row.ownerUserId.equals(userId) & row.isArchived.equals(false),
          )
          ..orderBy([(row) => OrderingTerm.asc(row.createdAt)]))
        .get();
  }

  Future<void> upsertBook(BookEntriesCompanion book) async {
    await into(bookEntries).insertOnConflictUpdate(book);
  }

  Future<BookEntity?> findBook(String id) {
    return (select(
      bookEntries,
    )..where((row) => row.id.equals(id))).getSingleOrNull();
  }

  Future<void> renameBook(String id, String name, DateTime updatedAt) async {
    final count = await (update(bookEntries)..where((row) => row.id.equals(id)))
        .write(
          BookEntriesCompanion(name: Value(name), updatedAt: Value(updatedAt)),
        );
    if (count != 1) throw StateError('账本不存在');
  }

  Future<void> archiveBook(String id, DateTime updatedAt) async {
    final count = await (update(bookEntries)..where((row) => row.id.equals(id)))
        .write(
          BookEntriesCompanion(
            isArchived: const Value(true),
            updatedAt: Value(updatedAt),
          ),
        );
    if (count != 1) throw StateError('账本不存在');
  }
}

@DriftAccessor(tables: [AdEventEntries])
class AdEventDao extends DatabaseAccessor<AppDatabase> with _$AdEventDaoMixin {
  AdEventDao(super.attachedDatabase);

  Future<void> insertEvent(AdEventEntriesCompanion event) async {
    await into(adEventEntries).insert(event);
  }

  Future<int> countEvents({
    required String placementId,
    required String eventType,
    required DateTime since,
  }) async {
    final count = adEventEntries.id.count();
    final query = selectOnly(adEventEntries)
      ..addColumns([count])
      ..where(
        adEventEntries.placementId.equals(placementId) &
            adEventEntries.eventType.equals(eventType) &
            adEventEntries.occurredAt.isBiggerOrEqualValue(since),
      );
    return (await query.getSingle()).read(count) ?? 0;
  }
}

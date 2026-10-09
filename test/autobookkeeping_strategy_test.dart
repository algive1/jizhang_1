import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jizhang_app/core/models/account.dart';
import 'package:jizhang_app/core/models/category.dart';
import 'package:jizhang_app/features/autobookkeeping/auto_bookkeeping_learning.dart';
import 'package:jizhang_app/features/autobookkeeping/auto_bookkeeping_pending.dart';
import 'package:jizhang_app/features/autobookkeeping/auto_bookkeeping_settings.dart';
import 'package:jizhang_app/features/autobookkeeping/auto_bookkeeping_strategy.dart';
import 'package:jizhang_app/features/settings/data/app_settings_repository.dart';

final now = DateTime(2026, 10, 4);
Account account(
  String id, {
  String? suffix,
  AccountType type = AccountType.wechat,
}) => Account(
  id: id,
  name: id,
  type: type,
  balance: 100,
  currency: 'CNY',
  icon: 'wallet',
  color: 0,
  sortOrder: 0,
  isArchived: false,
  createdAt: now,
  updatedAt: now,
  identifierSuffix: suffix,
);
const category = Category(
  id: 'food',
  name: '餐饮美食',
  icon: 'food',
  type: CategoryType.expense,
  sortOrder: 0,
  isDefault: true,
  isArchived: false,
);
PendingAutoBookkeepingCandidate candidate({
  String type = 'EXPENSE',
  double confidence = 1,
  String? suffix,
  String method = '微信支付',
}) => PendingAutoBookkeepingCandidate(
  fingerprint: 'one',
  amountInCents: 3200,
  merchant: '星巴克',
  paymentMethod: method,
  timestamp: now,
  sourceApp: 'WECHAT',
  scene: 'PAYMENT_SUCCESS',
  transactionType: type,
  identifierSuffix: suffix,
  amountConfidence: confidence,
  merchantConfidence: confidence,
  sceneConfidence: confidence,
);
AutoBookkeepingDecision decide({
  AutoBookkeepingStrategy mode = AutoBookkeepingStrategy.smart,
  PendingAutoBookkeepingCandidate? bill,
  List<Account>? accounts,
  bool healthy = true,
  bool book = true,
  bool refund = false,
  bool transfer = false,
  List<Category>? categories,
}) => decideAutoBookkeeping(
  strategy: mode,
  candidate: bill ?? candidate(),
  recommendation: const AutoBookkeepingRecommendation(
    bookId: 'book-personal',
    categoryId: 'food',
    categoryConfidence: 1,
  ),
  accounts: accounts ?? [account('wallet')],
  categories: categories ?? [category],
  runtimeHealthy: healthy,
  bookAvailable: book,
  refundMatched: refund,
  transferResolved: transfer,
);

void main() {
  test('保守模式从不自动保存；智能模式接受完整高置信度账单', () {
    expect(
      decide(mode: AutoBookkeepingStrategy.conservative).autoRecord,
      isFalse,
    );
    expect(decide().autoRecord, isTrue);
    expect(decide().confidence, closeTo(.9925, .0001));
  });
  test('智能模式低置信度待确认，完全自动允许完整低置信度结果', () {
    expect(decide(bill: candidate(confidence: .2)).autoRecord, isFalse);
    expect(
      decide(
        mode: AutoBookkeepingStrategy.automatic,
        bill: candidate(confidence: .2),
      ).autoRecord,
      isTrue,
    );
  });
  test('完全自动也需要健康权限、有效账本及明确分类', () {
    expect(
      decide(
        mode: AutoBookkeepingStrategy.automatic,
        healthy: false,
      ).autoRecord,
      isFalse,
    );
    expect(
      decide(mode: AutoBookkeepingStrategy.automatic, book: false).autoRecord,
      isFalse,
    );
    expect(
      decide(
        mode: AutoBookkeepingStrategy.automatic,
        categories: [],
      ).autoRecord,
      isFalse,
    );
    expect(decide(bill: candidate(type: 'INCOME')).autoRecord, isFalse);
  });
  test('不猜测账户：同类多个账户、重复尾号和银行卡支付均待确认', () {
    expect(decide(accounts: [account('a'), account('b')]).autoRecord, isFalse);
    expect(
      decide(
        bill: candidate(suffix: '1234'),
        accounts: [
          account('a', suffix: '1234'),
          account('b', suffix: '1234'),
        ],
      ).autoRecord,
      isFalse,
    );
    expect(decide(bill: candidate(method: '微信支付 银行卡')).autoRecord, isFalse);
    expect(
      decide(
        bill: candidate(suffix: '1234'),
        accounts: [
          account('a', suffix: '1234'),
          account('b'),
        ],
      ).account?.id,
      'a',
    );
  });
  test('退款必须匹配原账单，转账必须明确目的账户', () {
    expect(decide(bill: candidate(type: 'REFUND')).autoRecord, isFalse);
    expect(
      decide(bill: candidate(type: 'REFUND'), refund: true).autoRecord,
      isTrue,
    );
    expect(
      decide(
        bill: candidate(type: 'TRANSFER'),
        categories: [],
      ).autoRecord,
      isFalse,
    );
    expect(
      decide(
        bill: candidate(type: 'TRANSFER'),
        categories: [],
        transfer: true,
      ).autoRecord,
      isTrue,
    );
  });
  test('缺失置信度不虚构高分，解析分数限制为0到1', () {
    final parsed = PendingAutoBookkeepingCandidate.fromMap({
      'fingerprint': 'x',
      'amountInCents': 100,
        'timestamp': now.millisecondsSinceEpoch,
      'amountConfidence': double.nan,
      'merchantConfidence': 9,
      'sceneConfidence': -1,
    });
    expect(parsed.amountConfidence, 0);
    expect(parsed.merchantConfidence, 1);
    expect(parsed.sceneConfidence, 0);
  });
  test('策略持久化；未知策略默认保守', () async {
    final settings = MemoryStrategySettings();
    final container = ProviderContainer(
      overrides: [appSettingsRepositoryProvider.overrideWithValue(settings)],
    );
    addTearDown(container.dispose);
    expect(
      await container.read(autoBookkeepingStrategyProvider.future),
      AutoBookkeepingStrategy.conservative,
    );
    await container
        .read(autoBookkeepingStrategyProvider.notifier)
        .select(AutoBookkeepingStrategy.smart);
    expect(settings.values[AutoBookkeepingStrategy.settingKey], 'smart');
    container.invalidate(autoBookkeepingStrategyProvider);
    expect(
      await container.read(autoBookkeepingStrategyProvider.future),
      AutoBookkeepingStrategy.smart,
    );
    expect(
      AutoBookkeepingStrategy.parse('invalid'),
      AutoBookkeepingStrategy.conservative,
    );
  });
  test('未读取、未启用、未连接或后台受限都不能显示健康', () {
    const flags = {
      'enabled': true,
      'accessibilityGranted': true,
      'accessibilityConnected': true,
      'overlayGranted': true,
      'notificationGranted': true,
      'foregroundRunning': true,
      'notificationListenerGranted': true,
      'notificationListenerEnabled': true,
      'notificationListenerConnected': true,
    };
    expect(AutoBookkeepingRuntimeStatus.fromMap(flags).healthy, isTrue);
    for (final key in flags.keys) {
      if (key == 'notificationListenerEnabled') continue;
      expect(
        AutoBookkeepingRuntimeStatus.fromMap({...flags, key: false}).healthy,
        isFalse,
        reason: key,
      );
    }
    expect(
      AutoBookkeepingRuntimeStatus.fromMap({
        ...flags,
        'backgroundRestricted': true,
      }).healthy,
      isFalse,
    );
  });
}

class MemoryStrategySettings implements AppSettingsRepository {
  final values = <String, String>{};
  @override
  Future<String?> get(String key) async => values[key];
  @override
  Future<void> set(String key, String value) async {
    values[key] = value;
  }
}

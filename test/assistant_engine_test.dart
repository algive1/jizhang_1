import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jizhang_app/core/database/database_provider.dart';
import 'package:jizhang_app/core/database/database_seeder.dart';
import 'package:jizhang_app/features/assistant/application/assistant_engine.dart';
import 'package:jizhang_app/features/assistant/application/assistant_conversation.dart';
import 'package:jizhang_app/features/assistant/application/assistant_policy.dart';
import 'package:jizhang_app/features/settings/data/app_settings_repository.dart';
import 'package:jizhang_app/features/transactions/data/transactions_repository.dart';
import 'package:jizhang_app/features/accounts/data/account_repository.dart';

void main() {
  test(
    'local assistant policy rejects code, long input and daily overflow',
    () async {
      final settings = _MemorySettings();
      final policy = LocalAssistantPolicyService(settings);
      expect((await policy.authorize(text: '请帮我写一段 Python 代码')).allowed, false);
      expect(
        (await policy.authorize(text: List.filled(301, 'a').join())).allowed,
        false,
      );
      // The rejected code prompt still consumes one attempt, which prevents
      // probing the boundary indefinitely.
      for (var i = 0; i < LocalAssistantPolicyService.freeDailyLimit - 1; i++) {
        expect((await policy.authorize(text: '本月收支')).allowed, true);
        settings.values.removeWhere(
          (key, _) => key.startsWith('assistant.local.rate.'),
        );
      }
      final exhausted = await policy.authorize(text: '本月收支');
      expect(exhausted.allowed, false);
      expect(exhausted.requiresMembership, true);
    },
  );

  test('rules create real records and account balance effects, queries never write', () async {
    final db = createMemoryDatabase();
    addTearDown(db.close);
    await DatabaseSeeder(db).seedIfNeeded();
    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);
    await container.read(databaseBootstrapProvider.future);
    final engine = container.read(assistantEngineProvider);
    final repository = container.read(transactionRepositoryProvider);
    final initial = (await repository.getAll()).length;
    for (final text in [
      '今天中午吃饭微信支付12元',
      '再帮我记一笔，地铁6元，支付宝',
      '晚饭花了30元现金',
      '打车25元微信',
      '买咖啡18元支付宝',
    ]) {
      final before = await container
          .read(accountRepositoryProvider)
          .getActive();
      final reply = await engine.sendMessage(text);
      expect(reply.transactionId, isNotNull, reason: '$text: ${reply.text}');
      final record = await repository.getById(reply.transactionId!);
      expect(record, isNotNull);
      final after = await container.read(accountRepositoryProvider).getActive();
      expect(
        after.firstWhere((a) => a.id == record!.accountId).balance,
        before.firstWhere((a) => a.id == record!.accountId).balance -
            record!.amount,
      );
    }
    expect((await repository.getAll()).length, initial + 5);
    for (final text in [
      '本月预算',
      '本月收支',
      '导出数据',
      '会员权益',
      '怎么记账',
      '不要记咖啡12元微信',
      '咖啡12.999元微信',
      '咖啡12元还是18元微信',
      '退款12元微信',
      '咖啡12元美元微信',
      '咖啡12元微信支付宝',
      '明天咖啡12元微信',
    ]) {
      expect(
        (await engine.sendMessage(text)).transactionId,
        isNull,
        reason: text,
      );
    }
    expect((await repository.getAll()).length, initial + 5);
  });
  test(
    'conversation persists IDs, unread state and clear does not delete ledger',
    () async {
      final db = createMemoryDatabase();
      addTearDown(db.close);
      await DatabaseSeeder(db).seedIfNeeded();
      final c = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)],
      );
      addTearDown(c.dispose);
      await c.read(assistantConversationProvider.future);
      final notifier = c.read(assistantConversationProvider.notifier);
      await notifier.send('咖啡18元支付宝');
      final messages = await c.read(assistantConversationProvider.future);
      expect(messages.length, 2);
      expect(messages.last.transactionId, isNotNull);
      expect(messages.last.read, false);
      await notifier.markRead();
      expect(
        (await c.read(assistantConversationProvider.future)).last.read,
        true,
      );
      c.invalidate(assistantConversationProvider);
      expect(
        (await c.read(assistantConversationProvider.future)).last.transactionId,
        messages.last.transactionId,
      );
      await c.read(assistantConversationProvider.notifier).clear();
      expect(
        await c
            .read(transactionRepositoryProvider)
            .getById(messages.last.transactionId!),
        isNotNull,
      );
    },
  );
}

class _MemorySettings implements AppSettingsRepository {
  final values = <String, String>{};
  @override
  Future<String?> get(String key) async => values[key];
  @override
  Future<void> set(String key, String value) async => values[key] = value;
}

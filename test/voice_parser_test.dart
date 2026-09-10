import 'package:flutter_test/flutter_test.dart';
import 'package:jizhang_app/core/database/database_seeder.dart';
import 'package:jizhang_app/core/models/transaction_record.dart';
import 'package:jizhang_app/features/voice/domain/transaction_parser.dart';

void main() {
  const rules = RuleBasedTransactionParser();
  final now = DateTime(2026, 8, 31, 14, 30);

  test(
    'complex spoken example becomes two transactions with shared context',
    () async {
      final result = await rules.parse('昨晚十一点跟朋友唱歌680，打车回家38，都是微信。', now: now);

      expect(result.transactions, hasLength(2));
      expect(result.unresolvedFragments, isEmpty);
      expect(result.transactions.first.amount, 680);
      expect(result.transactions.first.categoryId, 'expense-entertainment');
      expect(result.transactions.last.categoryId, 'expense-transport');
      expect(
        result.transactions.every(
          (item) => item.accountId == SeedIds.wechatAccount,
        ),
        isTrue,
      );
      expect(result.transactions.first.occurredAt, DateTime(2026, 8, 30, 23));
      expect(result.transactions.last.occurredAt, DateTime(2026, 8, 30, 23));
    },
  );

  test('simple phrases stay on deterministic rules without AI', () async {
    final lunch = await rules.parse('午饭32支付宝', now: now);
    final taxi = await rules.parse('滴滴28微信', now: now);
    final salary = await rules.parse('工资9800银行卡', now: now);

    expect(lunch.transactions.single.categoryId, 'expense-food');
    expect(lunch.transactions.single.occurredAt.hour, 12);
    expect(taxi.transactions.single.categoryId, 'expense-transport');
    expect(salary.transactions.single.type, TransactionType.income);
    expect(salary.transactions.single.categoryId, 'income-salary');
    expect(lunch.usedAi, isFalse);
  });

  test('relative dates resolve to explicit occurredAt values', () async {
    expect(
      (await rules.parse(
        '前天晚饭50现金',
        now: now,
      )).transactions.single.occurredAt.day,
      29,
    );
    expect(
      (await rules.parse(
        '上周六电影60支付宝',
        now: now,
      )).transactions.single.occurredAt,
      DateTime(2026, 8, 29, 14, 30),
    );
  });

  test('AI decoder enforces the transaction JSON schema', () {
    const decoder = AiTransactionJsonDecoder();
    expect(
      () => decoder.decode('[{"type":"expense","amount":38}]'),
      throwsFormatException,
    );
    final decoded = decoder.decode(
      '[{"type":"expense","amount":38,"category":"交通",'
      '"subcategory":"打车","occurredAt":"2026-08-30T23:00:00",'
      '"account":"微信"}]',
    );
    expect(decoded.single.amount, 38);
    expect(decoded.single.source.name, 'ai');
  });

  test(
    'AI parser retries, caches and does not call the gateway twice',
    () async {
      final gateway = _RetryGateway();
      final parser = CachedRetryingAiTransactionParser(
        gateway: gateway,
        timeout: const Duration(seconds: 1),
      );
      final first = await parser.parse('复杂账单');
      final second = await parser.parse('复杂账单');

      expect(first.transactions, hasLength(1));
      expect(second.transactions, hasLength(1));
      expect(gateway.calls, 2);
    },
  );

  test(
    'hybrid parser does not invoke AI without entitlement and quota',
    () async {
      final gateway = _RetryGateway(alwaysSucceed: true);
      final ai = CachedRetryingAiTransactionParser(gateway: gateway);
      final parser = HybridTransactionParser(
        rules: rules,
        ai: ai,
        canUseAi: () => false,
      );
      final result = await parser.parse('不知道怎么说', now: now);

      expect(result.transactions, isEmpty);
      expect(result.unresolvedFragments, ['不知道怎么说']);
      expect(gateway.calls, 0);
    },
  );
}

class _RetryGateway implements AiParsingGateway {
  _RetryGateway({this.alwaysSucceed = false});

  final bool alwaysSucceed;
  int calls = 0;

  @override
  Future<String> parseToJson({
    required String text,
    required String schemaVersion,
  }) async {
    calls++;
    if (!alwaysSucceed && calls == 1) return '{}';
    return '[{"type":"expense","amount":20,"category":"餐饮",'
        '"occurredAt":"2026-08-31T12:00:00","account":"微信"}]';
  }
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jizhang_app/app/theme/app_theme.dart';
import 'package:jizhang_app/core/database/database_provider.dart';
import 'package:jizhang_app/features/membership/data/membership_repository.dart';
import 'package:jizhang_app/features/membership/data/membership_catalog.dart';
import 'package:jizhang_app/features/membership/data/payment_service.dart';
import 'package:jizhang_app/features/membership/domain/commercial_service_contracts.dart';
import 'package:jizhang_app/features/membership/presentation/membership_page.dart';
import 'package:jizhang_app/features/sharing/data/session_repository.dart';
import 'package:jizhang_app/features/sharing/data/shared_api.dart';

void main() {
  for (final size in [
    const Size(320, 700),
    const Size(360, 780),
    const Size(390, 844),
    const Size(430, 900),
  ]) {
    for (final scale in [1.0, 1.6]) {
      testWidgets('membership page stays usable at $size and scale $scale', (
        tester,
      ) async {
        await tester.binding.setSurfaceSize(size);
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(() async {
          await tester.binding.setSurfaceSize(null);
          tester.platformDispatcher.clearTextScaleFactorTestValue();
        });
        final membership = await LocalOnlyMembershipRepository().getCurrent();
        final catalog = await ConfiguredMembershipCatalogRepository().load();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              membershipProvider.overrideWithValue(AsyncData(membership)),
              membershipCatalogProvider.overrideWithValue(AsyncData(catalog)),
            ],
            child: MaterialApp(
              theme: AppTheme.light(),
              home: const MembershipPage(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('开通会员'), findsOneWidget);
        expect(find.text('购买记录'), findsOneWidget);
        expect(find.text('会员专属权益', skipOffstage: false), findsOneWidget);
        expect(find.text('他们都在用', skipOffstage: false), findsOneWidget);
        expect(find.text('选择支付方式', skipOffstage: false), findsOneWidget);
        final quarterlyPlan = find.byKey(
          const ValueKey('membership-plan-quarterly'),
          skipOffstage: false,
        );
        expect(quarterlyPlan, findsOneWidget);
        expect(tester.takeException(), isNull);

        final defaultAmount = tester.widget<RichText>(
          find.byKey(const ValueKey('membership-pay-amount')),
        );
        expect(defaultAmount.text.toPlainText(), contains('¥22'));
        final monthlyPlan = find.byKey(
          const ValueKey('membership-plan-monthly'),
          skipOffstage: false,
        );
        await tester.ensureVisible(monthlyPlan);
        await tester.tap(monthlyPlan);
        await tester.pumpAndSettle();
        expect(find.text('月度会员'), findsOneWidget);
        final monthlyAmount = tester.widget<RichText>(
          find.byKey(const ValueKey('membership-pay-amount')),
        );
        expect(monthlyAmount.text.toPlainText(), contains('¥8'));
        final yearlyPlan = find.byKey(
          const ValueKey('membership-plan-yearly'),
          skipOffstage: false,
        );
        await tester.ensureVisible(yearlyPlan);
        await tester.tap(yearlyPlan);
        await tester.pumpAndSettle();
        expect(find.text('年度会员'), findsOneWidget);
        final yearlyAmount = tester.widget<RichText>(
          find.byKey(const ValueKey('membership-pay-amount')),
        );
        expect(yearlyAmount.text.toPlainText(), contains('¥68'));
        expect(tester.takeException(), isNull);
      });
    }
  }
  testWidgets('payment uses selected plan and channel once', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final database = createMemoryDatabase();
    addTearDown(database.close);
    final session = SessionRepository(
      SharedApi(),
      database,
      storage: const _EmptySessionStorage(),
    )..user = const SessionUser('test-user', '测试用户');
    addTearDown(session.dispose);
    final payment = _RecordingPaymentService();
    final membership = await LocalOnlyMembershipRepository().getCurrent();
    final catalog = await ConfiguredMembershipCatalogRepository().load();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(database),
          membershipProvider.overrideWithValue(AsyncData(membership)),
          membershipCatalogProvider.overrideWithValue(AsyncData(catalog)),
          sessionRepositoryProvider.overrideWithValue(session),
          paymentServiceProvider.overrideWithValue(payment),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const MembershipPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final alipay = find.byKey(
      const ValueKey('membership-payment-alipay'),
      skipOffstage: false,
    );
    await tester.ensureVisible(alipay);
    await tester.tap(alipay);
    final yearly = find.byKey(
      const ValueKey('membership-plan-yearly'),
      skipOffstage: false,
    );
    await tester.ensureVisible(yearly);
    await tester.tap(yearly);
    await tester.tap(find.byKey(const ValueKey('membership-pay-button')));
    await tester.pump();
    await tester.tap(
      find.byKey(const ValueKey('membership-pay-button')),
      warnIfMissed: false,
    );
    expect(payment.requests, hasLength(1));
    expect(payment.requests.single.productId, 'yearly');
    expect(payment.requests.single.channel, PaymentChannel.alipay);

    payment.completePending();
    await tester.pumpAndSettle();
    expect(find.text('已调起支付'), findsOneWidget);
    await tester.tap(find.text('完成'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 2));
    expect(payment.invokeCount, 1);
  });
}

class _EmptySessionStorage implements SessionStorage {
  const _EmptySessionStorage();

  @override
  Future<String?> read() async => null;

  @override
  Future<void> write(String? value) async {}
}

class _RecordingPaymentService implements PaymentService {
  final requests = <CreatePaymentOrderRequest>[];
  final _pending = Completer<PaymentOrder>();
  int invokeCount = 0;

  @override
  Future<PaymentOrder> createOrder(CreatePaymentOrderRequest request) {
    requests.add(request);
    return _pending.future;
  }

  void completePending() {
    if (_pending.isCompleted) return;
    _pending.complete(
      PaymentOrder(
        id: 'test-order',
        status: PaymentOrderStatus.pending,
        channel: requests.single.channel,
        idempotencyKey: requests.single.idempotencyKey,
        createdAt: DateTime.now(),
        productId: requests.single.productId,
        amountInCents: 6800,
      ),
    );
  }

  @override
  Future<void> invoke(PaymentOrder order) async => invokeCount++;

  @override
  Future<PaymentOrder> refreshOrder(String orderId) async =>
      throw UnimplementedError();

  @override
  Future<List<PaymentOrder>> listOrders() async => const [];
}

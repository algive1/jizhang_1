import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jizhang_app/core/models/account.dart';
import 'package:jizhang_app/core/widgets/payment_brand_icon.dart';
import 'package:jizhang_app/features/accounts/data/account_repository.dart';
import 'package:jizhang_app/features/accounts/presentation/account_management_page.dart';
import 'package:jizhang_app/features/accounts/presentation/asset_dashboard_icons.dart';

void main() {
  test('payment brands resolve to the shared membership assets', () {
    expect(
      PaymentBrand.wechat.asset,
      'assets/images/membership/wechat-pay.png',
    );
    expect(PaymentBrand.alipay.asset, 'assets/images/membership/alipay.png');
    expect(paymentBrandForAccountType(AccountType.wechat), PaymentBrand.wechat);
    expect(paymentBrandForAccountType(AccountType.alipay), PaymentBrand.alipay);
    expect(paymentBrandForAccountType(AccountType.cash), isNull);
    expect(paymentBrandForAccountType(AccountType.debitCard), isNull);
  });

  testWidgets(
    'payment brand marks use the selected shared image without stretching',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Row(
            children: [
              PaymentBrandIcon(brand: PaymentBrand.wechat, size: 24),
              PaymentBrandIcon(brand: PaymentBrand.alipay, size: 31),
            ],
          ),
        ),
      );

      final images = tester.widgetList<Image>(find.byType(Image)).toList();
      expect(images, hasLength(2));
      expect(
        (images[0].image as AssetImage).assetName,
        PaymentBrand.wechat.asset,
      );
      expect(
        (images[1].image as AssetImage).assetName,
        PaymentBrand.alipay.asset,
      );
      expect(images[0].fit, BoxFit.contain);
      expect(images[1].fit, BoxFit.contain);
      expect(
        tester.getSize(find.byType(PaymentBrandIcon).first),
        const Size(24, 24),
      );
      expect(
        tester.getSize(find.byType(PaymentBrandIcon).last),
        const Size(31, 31),
      );
    },
  );

  testWidgets('asset account glyphs render payment brands with shared assets', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Row(
          children: [
            AssetVectorIcon(AssetGlyph.wechat, size: 22),
            AssetVectorIcon(AssetGlyph.alipay, size: 22, tile: true),
          ],
        ),
      ),
    );

    final images = tester.widgetList<Image>(find.byType(Image)).toList();
    expect(images, hasLength(2));
    expect(
      (images[0].image as AssetImage).assetName,
      PaymentBrand.wechat.asset,
    );
    expect(
      (images[1].image as AssetImage).assetName,
      PaymentBrand.alipay.asset,
    );
  });

  testWidgets('account management avatars render shared payment assets', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          accountsProvider.overrideWith(
            (ref) => Stream.value([
              _account(AccountType.wechat, '微信'),
              _account(AccountType.alipay, '支付宝'),
            ]),
          ),
        ],
        child: const MaterialApp(home: AccountManagementPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Image &&
            widget.image is AssetImage &&
            (widget.image as AssetImage).assetName == PaymentBrand.wechat.asset,
      ),
      findsOneWidget,
    );
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Image &&
            widget.image is AssetImage &&
            (widget.image as AssetImage).assetName == PaymentBrand.alipay.asset,
      ),
      findsOneWidget,
    );
  });
}

Account _account(AccountType type, String name) => Account(
  id: name,
  name: name,
  type: type,
  balance: 100,
  currency: 'CNY',
  icon: '',
  color: 0xff63aa8c,
  sortOrder: 0,
  isArchived: false,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jizhang_app/features/legal/presentation/legal_document_page.dart';
import 'package:jizhang_app/features/membership/data/membership_catalog.dart';
import 'package:jizhang_app/features/membership/presentation/membership_visuals.dart';

void main() {
  testWidgets('membership and privacy documents render their real sections', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: LegalDocumentPage(kind: LegalDocumentKind.membership),
      ),
    );
    expect(find.text('会员服务协议'), findsOneWidget);
    expect(find.text('一、服务内容'), findsOneWidget);
    expect(find.textContaining('服务端订单记录'), findsOneWidget);

    await tester.pumpWidget(
      const MaterialApp(
        home: LegalDocumentPage(kind: LegalDocumentKind.privacy),
      ),
    );
    expect(find.text('隐私协议'), findsOneWidget);
    expect(find.text('一、我们处理哪些信息'), findsOneWidget);
    expect(find.textContaining('本地优先'), findsOneWidget);
  });

  testWidgets('service agreement menu opens each document in a dialog', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: LegalDocumentsPage()));
    expect(find.text('服务协议'), findsOneWidget);
    expect(find.text('用户协议'), findsOneWidget);
    expect(find.text('隐私协议'), findsOneWidget);
    expect(find.text('会员服务协议'), findsOneWidget);

    await tester.tap(find.text('用户协议'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('一、账号与设备'), findsOneWidget);
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);

    await tester.tap(find.text('隐私协议'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('一、我们处理哪些信息'), findsOneWidget);
    await tester.tap(find.text('确定'));
  });

  testWidgets('checkout exposes only the membership agreement link', (
    tester,
  ) async {
    final catalog = await ConfiguredMembershipCatalogRepository().load();
    var agreementTapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          bottomNavigationBar: MemberBottomPayBar(
            product: catalog.plans[1],
            isPaying: false,
            onPay: () {},
            onAgreement: () => agreementTapped = true,
          ),
        ),
      ),
    );
    await tester.tap(find.text('《会员服务协议》'));
    expect(agreementTapped, isTrue);
    expect(find.text('《隐私协议》'), findsNothing);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jizhang_app/features/account/presentation/account_login_page.dart';
import 'package:jizhang_app/features/account/presentation/account_register_page.dart';

void main() {
  testWidgets('register form validates identity fields before network access', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: AccountRegisterPage()),
      ),
    );

    await tester.ensureVisible(find.byKey(const ValueKey('account-register-submit')));
    await tester.tap(find.byKey(const ValueKey('account-register-submit')));
    await tester.pump();
    expect(find.text('昵称需为 1–24 个字符'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('account-register-display-name')),
      '小陆',
    );
    await tester.enterText(
      find.byKey(const ValueKey('account-register-username')),
      'phase2_user',
    );
    await tester.enterText(
      find.byKey(const ValueKey('account-register-password')),
      'local-test-password',
    );
    await tester.enterText(
      find.byKey(const ValueKey('account-register-confirm')),
      'local-test-password',
    );
    await tester.ensureVisible(find.byKey(const ValueKey('account-register-submit')));
    await tester.tap(find.byKey(const ValueKey('account-register-submit')));
    await tester.pump();

    expect(find.text('请先阅读并同意用户协议与隐私政策'), findsOneWidget);
  });

  testWidgets('login form rejects malformed account before network access', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: AccountLoginPage()),
      ),
    );

    await tester.enterText(
      find.byKey(const ValueKey('account-login-username')),
      'A',
    );
    await tester.enterText(
      find.byKey(const ValueKey('account-login-password')),
      'local-test-password',
    );
    await tester.tap(find.byKey(const ValueKey('account-login-submit')));
    await tester.pump();

    expect(find.text('账号需为 3–40 位小写字母、数字或下划线'), findsOneWidget);
  });
}

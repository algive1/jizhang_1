import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jizhang_app/core/database/database_provider.dart';
import 'package:jizhang_app/core/database/database_seeder.dart';
import 'package:jizhang_app/features/account/application/account_session_controller.dart';
import 'package:jizhang_app/features/account/data/secure_session_storage.dart';
import 'package:jizhang_app/features/account/presentation/account_login_page.dart';
import 'package:jizhang_app/features/account/presentation/account_register_page.dart';
import 'package:jizhang_app/features/sharing/data/session_repository.dart';
import 'package:jizhang_app/features/sharing/data/shared_api.dart';

import 'support/account_http_stub.dart';

void main() {
  test('registration display name is shared by the canonical and legacy account facade', () async {
    final stub = await AccountHttpStub.start();
    stub.respond = accountRoutes(
      userId: 'phase2-user',
      username: 'phase2_user',
      displayName: '小陆',
      token: 'phase2-token',
    );
    final database = createMemoryDatabase();
    await DatabaseSeeder(database).seedIfNeeded();
    final storage = InMemorySessionStorage();
    final controller = AccountSessionController(storage, baseUrl: stub.baseUrl);
    final api = SharedApi(baseUrl: stub.baseUrl);
    final repository = SessionRepository(
      api,
      database,
      controller: controller,
    );

    addTearDown(() async {
      await repository.dispose();
      await controller.dispose();
      api.close();
      await database.close();
      await stub.stop();
    });

    await repository.authenticate(
      username: 'phase2_user',
      password: 'local-test-password',
      register: true,
      displayName: '小陆',
    );

    expect(controller.user?.id, 'phase2-user');
    expect(controller.user?.preferredName, '小陆');
    expect(repository.accountUser, controller.user);
    expect(repository.user?.username, 'phase2_user');
    expect(repository.userId, 'phase2-user');
    expect(api.sessionToken, 'phase2-token');

    final canonical = storage.canonical! as Map<String, dynamic>;
    final storedUser = (canonical['user'] as Map).cast<String, dynamic>();
    expect(storedUser['displayName'], '小陆');
  });

  testWidgets('register form validates identity fields before network access', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: AccountRegisterPage()),
      ),
    );

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

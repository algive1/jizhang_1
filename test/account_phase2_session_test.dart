import 'package:flutter_test/flutter_test.dart';
import 'package:jizhang_app/core/database/database_provider.dart';
import 'package:jizhang_app/core/database/database_seeder.dart';
import 'package:jizhang_app/features/account/application/account_session_controller.dart';
import 'package:jizhang_app/features/account/data/secure_session_storage.dart';
import 'package:jizhang_app/features/sharing/data/session_repository.dart';
import 'package:jizhang_app/features/sharing/data/shared_api.dart';

import 'support/account_http_stub.dart';

void main() {
  test('registration display name is shared by canonical and legacy account state', () async {
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
    final repository = SessionRepository(api, database, controller: controller);

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

    expect(controller.user?.preferredName, '小陆');
    expect(repository.accountUser, controller.user);
    expect(repository.userId, 'phase2-user');
  });
}

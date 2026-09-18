import 'package:flutter_test/flutter_test.dart';
import 'package:jizhang_app/core/database/app_database.dart';
import 'package:jizhang_app/core/database/database_provider.dart';
import 'package:jizhang_app/core/database/database_seeder.dart';

void main() {
  test('dataset binding is stable and refuses cross-account rebinding', () async {
    final database = createMemoryDatabase();
    addTearDown(database.close);
    await DatabaseSeeder(database).seedIfNeeded();

    final initial = await database.getDeviceDataBinding();
    expect(initial.datasetId, isNotEmpty);
    expect(initial.boundUserId, isNull);
    expect(initial.cloudSyncEnabled, isFalse);

    final ownerBefore = await database
        .customSelect(
          "SELECT owner_user_id FROM books WHERE id='book-personal'",
        )
        .getSingle();
    expect(ownerBefore.read<String>('owner_user_id'), 'user-local');

    final bound = await database.bindDatasetToUser('server-user-a');
    expect(bound.datasetId, initial.datasetId);
    expect(bound.boundUserId, 'server-user-a');

    final repeated = await database.bindDatasetToUser('server-user-a');
    expect(repeated.datasetId, initial.datasetId);
    expect(repeated.boundUserId, 'server-user-a');

    await expectLater(
      database.bindDatasetToUser('server-user-b'),
      throwsA(isA<DatasetBindingConflict>()),
    );

    final ownerAfter = await database
        .customSelect(
          "SELECT owner_user_id FROM books WHERE id='book-personal'",
        )
        .getSingle();
    expect(ownerAfter.read<String>('owner_user_id'), 'user-local');
  });
}

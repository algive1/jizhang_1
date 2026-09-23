import 'package:flutter_test/flutter_test.dart';
import 'package:jizhang_app/features/sharing/data/shared_id_map.dart';

void main() {
  test('account management references round-trip across shared IDs', () {
    const map = SharedIdMap('family-local', 'family-remote');
    final uploaded = map.row(
      'account_management_meta',
      {
        'id': 'account-1',
        'book_id': 'family-local',
        'account_id': 'account-1',
        'fund_category': 'restricted',
      },
      upload: true,
    );

    expect(
      uploaded['id'],
      'family-remote~account_management_meta~account-1',
    );
    expect(uploaded['account_id'], 'family-remote~accounts~account-1');
    expect(uploaded['book_id'], 'family-remote');

    final downloaded = map.row(
      'account_management_meta',
      uploaded,
      upload: false,
    );
    expect(downloaded['id'], 'account-1');
    expect(downloaded['account_id'], 'account-1');
    expect(downloaded['book_id'], 'family-local');
  });

  test('receivable event maps receivable reference independently', () {
    const map = SharedIdMap('family-local', 'family-remote');
    final uploaded = map.row(
      'receivable_events',
      {
        'id': 'event-1',
        'book_id': 'family-local',
        'receivable_id': 'receivable-1',
      },
      upload: true,
    );

    expect(uploaded['id'], 'family-remote~receivable_events~event-1');
    expect(
      uploaded['receivable_id'],
      'family-remote~receivables~receivable-1',
    );
  });
}

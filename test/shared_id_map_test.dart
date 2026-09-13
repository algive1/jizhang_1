import 'package:flutter_test/flutter_test.dart';
import 'package:jizhang_app/features/sharing/data/shared_id_map.dart';

void main() {
  test('maps related transaction and installment account references', () {
    const map = SharedIdMap('book-local', 'book-remote');
    final uploaded = map.row('transactions', {
      'id': 'refund-1',
      'book_id': 'book-local',
      'account_id': 'account-cash',
      'category_id': 'category-income',
      'original_transaction_id': 'expense-1',
      'related_transaction_id': 'expense-1',
    }, upload: true);
    expect(uploaded['id'], 'book-remote~transactions~refund-1');
    expect(uploaded['book_id'], 'book-remote');
    expect(uploaded['account_id'], 'book-remote~accounts~account-cash');
    expect(
      uploaded['original_transaction_id'],
      'book-remote~transactions~expense-1',
    );
    expect(
      uploaded['related_transaction_id'],
      'book-remote~transactions~expense-1',
    );

    final decoded = map.row('installment_plans', {
      'id': 'book-remote~installment_plans~plan-1',
      'book_id': 'book-remote',
      'original_transaction_id': 'book-remote~transactions~expense-1',
      'credit_account_id': 'book-remote~accounts~account-card',
      'repayment_account_id': 'book-remote~accounts~account-cash',
    }, upload: false);
    expect(decoded['id'], 'plan-1');
    expect(decoded['book_id'], 'book-local');
    expect(decoded['original_transaction_id'], 'expense-1');
    expect(decoded['credit_account_id'], 'account-card');
    expect(decoded['repayment_account_id'], 'account-cash');
  });
}

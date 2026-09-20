import 'package:flutter_test/flutter_test.dart';
import 'package:jizhang_app/core/models/category.dart';
import 'package:jizhang_app/core/models/transaction_record.dart';
import 'package:jizhang_app/features/bill_import/application/bill_import_category_mapper.dart';
import 'package:jizhang_app/features/bill_import/application/bill_import_service.dart';

void main() {
  const mapper = BillImportCategoryMapper();

  test('maps MuMu food aliases into existing food children', () {
    final categories = [
      _category('expense-food', '餐饮'),
      _category(
        'expense-food-snacks',
        '零食',
        parentId: 'expense-food',
      ),
      _category(
        'expense-food-meals',
        '正餐',
        parentId: 'expense-food',
      ),
    ];

    final snacks = mapper.resolve(
      _row(category: '零食'),
      categories,
    );
    final meals = mapper.resolve(
      _row(category: '餐饮', subcategory: '三餐'),
      categories,
    );

    expect(snacks.category?.id, 'expense-food');
    expect(snacks.subcategory?.id, 'expense-food-snacks');
    expect(meals.category?.id, 'expense-food');
    expect(meals.subcategory?.id, 'expense-food-meals');
  });

  test('maps semantic child categories even when MuMu root is broad', () {
    final categories = [
      _category('expense-other', '其他'),
      _category('expense-housing', '住房'),
      _category(
        'expense-housing-rent',
        '房租',
        parentId: 'expense-housing',
      ),
      _category('expense-shopping', '购物'),
      _category(
        'expense-shopping-personal-care',
        '个人护理',
        parentId: 'expense-shopping',
      ),
    ];

    final rent = mapper.resolve(
      _row(category: '日常', subcategory: '房租'),
      categories,
    );
    final haircut = mapper.resolve(
      _row(category: '日常', subcategory: '理发'),
      categories,
    );

    expect(rent.category?.id, 'expense-housing');
    expect(rent.subcategory?.id, 'expense-housing-rent');
    expect(haircut.category?.id, 'expense-shopping');
    expect(haircut.subcategory?.id, 'expense-shopping-personal-care');
  });

  test('maps MuMu investment income and living support', () {
    final categories = [
      _category(
        'income-investment',
        '投资收益',
        type: CategoryType.income,
      ),
      _category(
        'income-investment-interest',
        '利息',
        type: CategoryType.income,
        parentId: 'income-investment',
      ),
      _category(
        'income-other',
        '其他收入',
        type: CategoryType.income,
      ),
      _category(
        'income-other-support',
        '生活费/补助',
        type: CategoryType.income,
        parentId: 'income-other',
      ),
    ];

    final investment = mapper.resolve(
      _row(
        type: TransactionType.income,
        category: '理财',
      ),
      categories,
    );
    final support = mapper.resolve(
      _row(
        type: TransactionType.income,
        category: '生活费',
      ),
      categories,
    );

    expect(investment.category?.id, 'income-investment');
    expect(investment.subcategory?.id, 'income-investment-interest');
    expect(support.category?.id, 'income-other');
    expect(support.subcategory?.id, 'income-other-support');
  });

  test('exact user category name wins before default semantic alias', () {
    final categories = [
      _category('custom-daily', '日常'),
      _category('expense-other', '其他'),
    ];

    final result = mapper.resolve(
      _row(category: '日常'),
      categories,
    );

    expect(result.category?.id, 'custom-daily');
  });
}

Category _category(
  String id,
  String name, {
  CategoryType type = CategoryType.expense,
  String? parentId,
}) {
  return Category(
    id: id,
    name: name,
    icon: 'category_outlined',
    type: type,
    sortOrder: 0,
    isDefault: !id.startsWith('custom-'),
    isArchived: false,
    parentId: parentId,
  );
}

ImportedBillRow _row({
  TransactionType type = TransactionType.expense,
  required String category,
  String? subcategory,
}) {
  return ImportedBillRow(
    provider: BillImportProvider.mumu,
    occurredAt: DateTime(2026, 9, 1),
    type: type,
    amount: 10,
    merchant: '',
    note: '',
    externalId: null,
    paymentMethod: null,
    raw: const {},
    sourceCategory: category,
    sourceSubcategory: subcategory,
  );
}

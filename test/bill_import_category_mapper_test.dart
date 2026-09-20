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

  test('maps semantic child categories even when source root is broad', () {
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

  test('maps investment income and living support', () {
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

  test('maps household and tobacco-tea high-frequency categories', () {
    final categories = [
      _category('expense-household', '家居日用'),
      _category(
        'expense-household-cleaning',
        '清洁用品',
        parentId: 'expense-household',
      ),
      _category('expense-tobacco-tea', '烟酒茶'),
      _category(
        'expense-tobacco-tea-tea',
        '茶叶',
        parentId: 'expense-tobacco-tea',
      ),
    ];

    final household = mapper.resolve(
      _row(category: '日常', subcategory: '清洁用品'),
      categories,
    );
    final tea = mapper.resolve(
      _row(category: '烟酒茶', subcategory: '茶叶'),
      categories,
    );

    expect(household.category?.id, 'expense-household');
    expect(household.subcategory?.id, 'expense-household-cleaning');
    expect(tea.category?.id, 'expense-tobacco-tea');
    expect(tea.subcategory?.id, 'expense-tobacco-tea-tea');
  });

  test('maps shopping platforms from subcategory root and merchant context', () {
    final categories = [
      _category('expense-shopping', '购物'),
      _category(
        'expense-shopping-taobao',
        '淘宝',
        parentId: 'expense-shopping',
      ),
      _category(
        'expense-shopping-jd',
        '京东',
        parentId: 'expense-shopping',
      ),
      _category(
        'expense-shopping-pinduoduo',
        '拼多多',
        parentId: 'expense-shopping',
      ),
      _category(
        'expense-shopping-douyin',
        '抖音电商',
        parentId: 'expense-shopping',
      ),
      _category(
        'expense-shopping-xiaohongshu',
        '小红书',
        parentId: 'expense-shopping',
      ),
      _category(
        'expense-shopping-other',
        '其他',
        parentId: 'expense-shopping',
      ),
    ];

    expect(
      mapper.resolve(
        _row(category: '购物', subcategory: '淘宝'),
        categories,
      ).subcategory?.id,
      'expense-shopping-taobao',
    );
    expect(
      mapper.resolve(
        _row(category: '京东'),
        categories,
      ).subcategory?.id,
      'expense-shopping-jd',
    );
    expect(
      mapper.resolve(
        _row(category: '购物', merchant: '拼多多官方旗舰店'),
        categories,
      ).subcategory?.id,
      'expense-shopping-pinduoduo',
    );
    expect(
      mapper.resolve(
        _row(category: '购物', merchant: '抖音商城'),
        categories,
      ).subcategory?.id,
      'expense-shopping-douyin',
    );
    expect(
      mapper.resolve(
        _row(category: '购物', subcategory: '红书'),
        categories,
      ).subcategory?.id,
      'expense-shopping-xiaohongshu',
    );
    expect(
      mapper.resolve(
        _row(category: '购物', subcategory: '其他'),
        categories,
      ).subcategory?.id,
      'expense-shopping-other',
    );
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
  String merchant = '',
  String note = '',
}) {
  return ImportedBillRow(
    provider: BillImportProvider.mumu,
    occurredAt: DateTime(2026, 9, 1),
    type: type,
    amount: 10,
    merchant: merchant,
    note: note,
    externalId: null,
    paymentMethod: null,
    raw: const {},
    sourceCategory: category,
    sourceSubcategory: subcategory,
  );
}

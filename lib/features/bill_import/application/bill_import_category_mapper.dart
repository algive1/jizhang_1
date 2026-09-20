import '../../../core/models/category.dart';
import '../../../core/models/transaction_record.dart';
import 'bill_import_service.dart';

class ImportedCategorySelection {
  const ImportedCategorySelection({
    required this.category,
    required this.subcategory,
  });

  final Category? category;
  final Category? subcategory;
}

/// Maps provider-specific category vocabularies onto the user's current
/// category tree. User-created exact-name matches win before default aliases.
class BillImportCategoryMapper {
  const BillImportCategoryMapper();

  ImportedCategorySelection resolve(
    ImportedBillRow row,
    List<Category> categories,
  ) {
    if (row.type == TransactionType.transfer) {
      return const ImportedCategorySelection(category: null, subcategory: null);
    }

    final type = row.type == TransactionType.expense
        ? CategoryType.expense
        : CategoryType.income;
    final active = categories
        .where((item) => item.type == type && !item.isArchived)
        .toList(growable: false);
    final roots = active
        .where((item) => item.parentId == null)
        .toList(growable: false);

    final sourceCategory = row.sourceCategory?.trim() ?? '';
    final sourceSubcategory = row.sourceSubcategory?.trim() ?? '';

    Category? root = _findByName(roots, sourceCategory);
    root ??= _semanticRoot(
      type: type,
      sourceCategory: sourceCategory,
      sourceSubcategory: sourceSubcategory,
      categories: roots,
    );
    root ??= _fallbackRoot(roots, type);

    if (root == null) {
      return const ImportedCategorySelection(category: null, subcategory: null);
    }

    final children = active
        .where((item) => item.parentId == root!.id)
        .toList(growable: false);
    Category? child = _findByName(children, sourceSubcategory);
    child ??= _semanticChild(
      type: type,
      sourceCategory: sourceCategory,
      sourceSubcategory: sourceSubcategory,
      root: root,
      children: children,
    );

    return ImportedCategorySelection(category: root, subcategory: child);
  }

  Category? _semanticRoot({
    required CategoryType type,
    required String sourceCategory,
    required String sourceSubcategory,
    required List<Category> categories,
  }) {
    final key = type == CategoryType.expense
        ? _expenseRootKey(sourceCategory, sourceSubcategory)
        : _incomeRootKey(sourceCategory);
    return key == null ? null : _findBySeedKey(categories, key);
  }

  String? _expenseRootKey(String category, String subcategory) {
    if (subcategory == '房租') return 'expense-housing';
    if (const {'话费', '通讯', '电费'}.contains(subcategory)) {
      return 'expense-utilities';
    }
    if (subcategory == '数码') return 'expense-digital';

    return switch (category) {
      '餐饮' || '零食' || '水果' => 'expense-food',
      '交通' => 'expense-transport',
      '购物' || '美妆' => 'expense-shopping',
      '娱乐' => 'expense-entertainment',
      '医疗' => 'expense-medical',
      '学习' => 'expense-education',
      '旅游' => 'expense-travel',
      '社交' => 'expense-gift',
      '日常' || '待报销' || '奖赏' || '其他' => 'expense-other',
      _ => null,
    };
  }

  String? _incomeRootKey(String category) => switch (category) {
    '工资' => 'income-salary',
    '奖金' => 'income-bonus',
    '外快兼职' => 'income-part-time',
    '理财' || '利息' => 'income-investment',
    '退款' => 'income-refund',
    '红包' || '礼金' || '生活费' || '报销' || '其他' => 'income-other',
    _ => null,
  };

  Category? _semanticChild({
    required CategoryType type,
    required String sourceCategory,
    required String sourceSubcategory,
    required Category root,
    required List<Category> children,
  }) {
    final seedKey = type == CategoryType.expense
        ? _expenseChildKey(sourceCategory, sourceSubcategory)
        : _incomeChildKey(sourceCategory, sourceSubcategory);
    if (seedKey == null) return null;
    return _findBySeedKey(children, seedKey);
  }

  String? _expenseChildKey(String category, String subcategory) {
    if (category == '零食' && subcategory.isEmpty) {
      return 'expense-food-snacks';
    }
    if (category == '水果' && subcategory.isEmpty) {
      return 'expense-food-fruit';
    }
    if (category == '美妆' && subcategory.isEmpty) {
      return 'expense-shopping-beauty';
    }

    return switch (subcategory) {
      '早餐' => 'expense-food-breakfast',
      '午餐' => 'expense-food-lunch',
      '晚餐' => 'expense-food-dinner',
      '奶茶' => 'expense-food-coffee',
      '买菜' => 'expense-food-grocery',
      '饮料' => 'expense-food-drinks',
      '夜宵' => 'expense-food-late-night',
      '地铁' => 'expense-transport-metro',
      '出租车' || '汽车' => 'expense-transport-taxi',
      '火车' => 'expense-transport-rail',
      '共享单车' => 'expense-transport-bike',
      '日用品' => 'expense-shopping-daily',
      '服饰' => 'expense-shopping-clothes',
      '淘宝' || '拼多多' || '红书' => 'expense-shopping-online',
      '美容仪器' => 'expense-shopping-beauty',
      '付费会员' => 'expense-entertainment-subscription',
      '运动' => 'expense-entertainment-sports',
      '聚会' => 'expense-entertainment-party',
      'KTV' => 'expense-entertainment-ktv',
      '房租' => 'expense-housing-rent',
      '电费' => 'expense-utilities-electricity',
      '话费' || '通讯' => 'expense-utilities-phone',
      '药品' => 'expense-medical-medicine',
      '门诊' => 'expense-medical-clinic',
      '考试' => 'expense-education-exam',
      '文具' => 'expense-education-stationery',
      '酒店住宿' => 'expense-travel-hotel',
      '父母' || '亲友' => 'expense-gift-family',
      '朋友' || '同事' => 'expense-gift-social',
      _ => null,
    };
  }

  String? _incomeChildKey(String category, String subcategory) {
    if (category == '红包') return 'income-other-redpacket';
    if (category == '礼金') return 'income-other-gift';
    if (category == '生活费') return 'income-other-support';
    if (category == '理财' || category == '利息') {
      return 'income-investment-interest';
    }
    return null;
  }

  Category? _fallbackRoot(List<Category> roots, CategoryType type) {
    final preferred = type == CategoryType.expense
        ? const ['其他', '其他支出']
        : const ['其他收入', '其他'];
    for (final name in preferred) {
      final match = _findByName(roots, name);
      if (match != null) return match;
    }
    return roots.firstOrNull;
  }

  Category? _findByName(Iterable<Category> values, String name) {
    if (name.trim().isEmpty) return null;
    final normalized = _normalize(name);
    return values
        .where((item) => _normalize(item.name) == normalized)
        .firstOrNull;
  }

  Category? _findBySeedKey(Iterable<Category> values, String key) {
    return values
        .where(
          (item) => item.id == key || item.id.endsWith('::$key'),
        )
        .firstOrNull;
  }

  String _normalize(String value) => value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[\s_\-·/]+'), '');
}

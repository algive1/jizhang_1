import 'package:flutter_test/flutter_test.dart';
import 'package:jizhang_app/features/membership/data/membership_catalog.dart';

void main() {
  test('版本启停、套餐排序和权益覆盖使用同一份配置', () {
    final catalog = MembershipCatalog.fromJson({
      'versions': [
        {
          'id': 'pro',
          'title': 'Pro',
          'enabled': true,
          'benefitIds': ['cloud', 'export'],
        },
        {'id': 'family', 'title': 'Family', 'enabled': false},
      ],
      'plans': [
        {
          'id': 'monthly',
          'title': '月卡',
          'months': 1,
          'priceInCents': 800,
          'description': '体验',
          'recommended': false,
          'sortOrder': 1,
          'rightOverrides': [
            {'benefitId': 'cloud', 'enabled': false},
            {'benefitId': 'export', 'enabled': true, 'value': '专属导出'},
          ],
        },
        {
          'id': 'yearly',
          'title': '年卡',
          'months': 12,
          'priceInCents': 6800,
          'description': '年付',
          'recommended': true,
          'sortOrder': 0,
        },
        {
          'id': 'family-monthly',
          'versionId': 'family',
          'title': '家庭月卡',
          'months': 1,
          'priceInCents': 1000,
          'description': '家庭',
          'recommended': false,
        },
        {
          'id': 'quarterly',
          'title': '季卡',
          'months': 3,
          'priceInCents': 2200,
          'description': '季付',
          'recommended': false,
          'enabled': false,
        },
      ],
      'benefits': [
        {'id': 'cloud', 'title': '云同步', 'subtitle': '多设备', 'detail': '云端'},
        {'id': 'export', 'title': '导出', 'subtitle': '默认导出', 'detail': 'CSV'},
        {'id': 'books', 'title': '共享', 'subtitle': '共享账本', 'detail': '家庭'},
      ],
      'faqs': [],
    });
    expect(catalog.availablePlans().map((p) => p.id), ['yearly', 'monthly']);
    expect(catalog.availablePlans(versionId: 'family'), isEmpty);
    final benefits = catalog.benefitsFor(catalog.plans.first);
    expect(benefits.map((b) => b.id), ['export']);
    expect(benefits.single.subtitle, '专属导出');
    expect(catalog.plans[2].appleProductId, isNull);
    expect(
      catalog.plans.first.appleProductId,
      'haohaojizhang.membership.monthly',
    );
  });

  test('所有套餐下架后仍能读取配置和历史套餐名称', () {
    final catalog = MembershipCatalog.fromJson({
      'plans': [],
      'benefits': [],
      'faqs': [],
    });
    expect(catalog.availablePlans(), isEmpty);
  });
}

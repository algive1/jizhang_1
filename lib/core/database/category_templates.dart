import '../models/family.dart';

class SeedCategoryTemplate {
  const SeedCategoryTemplate(this.key, this.name, this.icon, this.type);
  final String key, name, icon, type;
}

const _personal = [
  SeedCategoryTemplate('expense-food', '餐饮', 'restaurant_outlined', 'expense'),
  SeedCategoryTemplate(
    'expense-transport',
    '交通',
    'directions_car_outlined',
    'expense',
  ),
  SeedCategoryTemplate(
    'expense-shopping',
    '购物',
    'shopping_bag_outlined',
    'expense',
  ),
  SeedCategoryTemplate(
    'expense-entertainment',
    '娱乐',
    'movie_outlined',
    'expense',
  ),
  SeedCategoryTemplate('expense-housing', '住房', 'home_outlined', 'expense'),
  SeedCategoryTemplate(
    'expense-utilities',
    '生活缴费',
    'receipt_long_outlined',
    'expense',
  ),
  SeedCategoryTemplate(
    'expense-medical',
    '医疗',
    'medical_services_outlined',
    'expense',
  ),
  SeedCategoryTemplate(
    'expense-education',
    '教育培训',
    'school_outlined',
    'expense',
  ),
  SeedCategoryTemplate(
    'expense-travel',
    '旅行',
    'flight_takeoff_outlined',
    'expense',
  ),
  SeedCategoryTemplate('expense-gift', '人情', 'redeem_outlined', 'expense'),
  SeedCategoryTemplate('expense-pet', '宠物', 'pets_outlined', 'expense'),
  SeedCategoryTemplate('expense-digital', '数码', 'devices_outlined', 'expense'),
  SeedCategoryTemplate(
    'expense-car',
    '汽车',
    'directions_car_filled_outlined',
    'expense',
  ),
  SeedCategoryTemplate('expense-other', '其他', 'more_horiz', 'expense'),
  SeedCategoryTemplate('income-salary', '工资', 'work_outline', 'income'),
  SeedCategoryTemplate('income-bonus', '奖金', 'stars_outlined', 'income'),
  SeedCategoryTemplate('income-part-time', '兼职', 'schedule_outlined', 'income'),
  SeedCategoryTemplate('income-investment', '投资收益', 'trending_up', 'income'),
  SeedCategoryTemplate('income-refund', '退款', 'undo', 'income'),
  SeedCategoryTemplate('income-other', '其他收入', 'add_circle_outline', 'income'),
];

const _family = [
  SeedCategoryTemplate(
    'expense-food',
    '家庭采购',
    'shopping_cart_outlined',
    'expense',
  ),
  SeedCategoryTemplate(
    'expense-transport',
    '家庭出行',
    'directions_car_outlined',
    'expense',
  ),
  SeedCategoryTemplate(
    'expense-shopping',
    '家庭购物',
    'shopping_bag_outlined',
    'expense',
  ),
  SeedCategoryTemplate(
    'expense-entertainment',
    '家庭娱乐',
    'movie_outlined',
    'expense',
  ),
  SeedCategoryTemplate('expense-housing', '房屋居住', 'home_outlined', 'expense'),
  SeedCategoryTemplate(
    'expense-utilities',
    '家庭缴费',
    'receipt_long_outlined',
    'expense',
  ),
  SeedCategoryTemplate(
    'expense-medical',
    '家庭医疗',
    'medical_services_outlined',
    'expense',
  ),
  SeedCategoryTemplate(
    'expense-education',
    '子女教育',
    'school_outlined',
    'expense',
  ),
  SeedCategoryTemplate(
    'expense-travel',
    '家庭旅行',
    'flight_takeoff_outlined',
    'expense',
  ),
  SeedCategoryTemplate('expense-gift', '家庭人情', 'redeem_outlined', 'expense'),
  SeedCategoryTemplate('expense-pet', '宠物', 'pets_outlined', 'expense'),
  SeedCategoryTemplate(
    'expense-digital',
    '家庭数码',
    'devices_outlined',
    'expense',
  ),
  SeedCategoryTemplate(
    'expense-car',
    '家庭汽车',
    'directions_car_filled_outlined',
    'expense',
  ),
  SeedCategoryTemplate('expense-other', '其他', 'more_horiz', 'expense'),
  SeedCategoryTemplate('income-salary', '家庭工资', 'work_outline', 'income'),
  SeedCategoryTemplate('income-bonus', '家庭奖金', 'stars_outlined', 'income'),
  SeedCategoryTemplate(
    'income-part-time',
    '家庭兼职',
    'schedule_outlined',
    'income',
  ),
  SeedCategoryTemplate('income-investment', '家庭投资收益', 'trending_up', 'income'),
  SeedCategoryTemplate('income-refund', '家庭退款', 'undo', 'income'),
  SeedCategoryTemplate('income-other', '其他收入', 'add_circle_outline', 'income'),
];

const _enterprise = [
  SeedCategoryTemplate(
    'expense-food',
    '商务餐饮',
    'restaurant_outlined',
    'expense',
  ),
  SeedCategoryTemplate(
    'expense-transport',
    '差旅交通',
    'directions_car_outlined',
    'expense',
  ),
  SeedCategoryTemplate(
    'expense-shopping',
    '采购成本',
    'shopping_bag_outlined',
    'expense',
  ),
  SeedCategoryTemplate(
    'expense-entertainment',
    '营销招待',
    'movie_outlined',
    'expense',
  ),
  SeedCategoryTemplate('expense-housing', '场地租赁', 'home_outlined', 'expense'),
  SeedCategoryTemplate(
    'expense-utilities',
    '办公税费',
    'receipt_long_outlined',
    'expense',
  ),
  SeedCategoryTemplate(
    'expense-medical',
    '员工福利',
    'medical_services_outlined',
    'expense',
  ),
  SeedCategoryTemplate(
    'expense-payroll',
    '工资薪酬',
    'payments_outlined',
    'expense',
  ),
  SeedCategoryTemplate(
    'expense-education',
    '培训会议',
    'school_outlined',
    'expense',
  ),
  SeedCategoryTemplate(
    'expense-travel',
    '商务旅行',
    'flight_takeoff_outlined',
    'expense',
  ),
  SeedCategoryTemplate('expense-gift', '商务礼赠', 'redeem_outlined', 'expense'),
  SeedCategoryTemplate('expense-pet', '营销推广', 'campaign_outlined', 'expense'),
  SeedCategoryTemplate(
    'expense-digital',
    '软件设备',
    'devices_outlined',
    'expense',
  ),
  SeedCategoryTemplate(
    'expense-car',
    '车辆运营',
    'directions_car_filled_outlined',
    'expense',
  ),
  SeedCategoryTemplate('expense-other', '其他支出', 'more_horiz', 'expense'),
  SeedCategoryTemplate('income-salary', '主营业务收入', 'work_outline', 'income'),
  SeedCategoryTemplate('income-bonus', '经营奖励', 'stars_outlined', 'income'),
  SeedCategoryTemplate(
    'income-part-time',
    '其他业务收入',
    'schedule_outlined',
    'income',
  ),
  SeedCategoryTemplate('income-investment', '投资收益', 'trending_up', 'income'),
  SeedCategoryTemplate('income-refund', '采购退款', 'undo', 'income'),
  SeedCategoryTemplate('income-other', '其他收入', 'add_circle_outline', 'income'),
];

List<SeedCategoryTemplate> categoryTemplates(BookType type) => switch (type) {
  BookType.personal => _personal,
  BookType.family => _family,
  BookType.enterprise => _enterprise,
};

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

/// Editable database defaults; the UI always renders repository categories.
const foodSubcategoryTemplates = [
  SeedCategoryTemplate(
    'expense-food-breakfast',
    '早餐',
    'restaurant_outlined',
    'expense',
  ),
  SeedCategoryTemplate(
    'expense-food-lunch',
    '午餐',
    'restaurant_outlined',
    'expense',
  ),
  SeedCategoryTemplate(
    'expense-food-dinner',
    '晚餐',
    'restaurant_outlined',
    'expense',
  ),
  SeedCategoryTemplate(
    'expense-food-coffee',
    '奶茶咖啡',
    'local_cafe_outlined',
    'expense',
  ),
  SeedCategoryTemplate(
    'expense-food-hotpot',
    '火锅',
    'restaurant_outlined',
    'expense',
  ),
  SeedCategoryTemplate(
    'expense-food-snacks',
    '零食',
    'fastfood_outlined',
    'expense',
  ),
  SeedCategoryTemplate(
    'expense-food-grocery',
    '买菜',
    'shopping_cart_outlined',
    'expense',
  ),
  SeedCategoryTemplate(
    'expense-food-fruit',
    '水果',
    'nutrition_outlined',
    'expense',
  ),
  SeedCategoryTemplate(
    'expense-food-delivery',
    '外卖',
    'delivery_dining_outlined',
    'expense',
  ),
];

/// Stable semantic keys survive reorder/rename; labels are editable after seeding.
const _commonChildren = <String, List<(String, String)>>{
  'expense-transport': [
    ('taxi', '打车'),
    ('metro', '地铁公交'),
    ('fuel', '加油'),
    ('parking', '停车'),
    ('rail', '火车高铁'),
    ('flight', '机票'),
    ('bike', '共享单车'),
  ],
  'expense-shopping': [
    ('daily', '日用百货'),
    ('clothes', '服饰鞋包'),
    ('beauty', '美妆护肤'),
    ('furniture', '家居用品'),
    ('online', '网购'),
    ('accessory', '饰品'),
  ],
  'expense-entertainment': [
    ('movie', '电影'),
    ('game', '游戏'),
    ('music', '音乐会员'),
    ('sports', '运动健身'),
    ('party', '聚会'),
    ('ktv', '唱歌'),
    ('show', '演出'),
  ],
  'expense-housing': [
    ('rent', '房租'),
    ('mortgage', '房贷'),
    ('property', '物业'),
    ('repair', '维修'),
    ('renovation', '装修'),
    ('cleaning', '保洁'),
  ],
  'expense-utilities': [
    ('water', '水费'),
    ('electricity', '电费'),
    ('gas', '燃气费'),
    ('phone', '话费'),
    ('internet', '宽带'),
    ('heating', '取暖费'),
  ],
  'expense-medical': [
    ('medicine', '药品'),
    ('clinic', '门诊挂号'),
    ('exam', '体检'),
    ('hospital', '住院'),
    ('dental', '牙科'),
    ('insurance', '医疗保险'),
  ],
  'expense-education': [
    ('books', '书籍'),
    ('tuition', '学费'),
    ('course', '课程培训'),
    ('exam', '考试'),
    ('stationery', '文具'),
    ('interest', '兴趣学习'),
  ],
  'expense-travel': [
    ('hotel', '住宿'),
    ('ticket', '景点门票'),
    ('tour', '旅行团'),
    ('food', '旅行餐饮'),
    ('souvenir', '纪念品'),
    ('transport', '旅途交通'),
  ],
  'expense-gift': [
    ('redpacket', '红包'),
    ('gift', '礼物'),
    ('wedding', '婚庆礼金'),
    ('treat', '请客'),
    ('charity', '公益捐赠'),
  ],
  'expense-pet': [
    ('food', '宠物食品'),
    ('supplies', '宠物用品'),
    ('medical', '宠物医疗'),
    ('grooming', '洗护美容'),
    ('boarding', '寄养'),
  ],
  'expense-digital': [
    ('phone', '手机'),
    ('computer', '电脑'),
    ('appliance', '家用电器'),
    ('accessory', '配件'),
    ('software', '软件订阅'),
    ('repair', '数码维修'),
  ],
  'expense-car': [
    ('fuel', '车辆加油'),
    ('maintenance', '保养'),
    ('repair', '修车'),
    ('insurance', '车险'),
    ('parking', '停车费'),
    ('toll', '过路费'),
  ],
  'expense-other': [('fee', '手续费'), ('loss', '意外损失'), ('misc', '杂项支出')],
  'income-salary': [
    ('base', '基本工资'),
    ('performance', '绩效'),
    ('overtime', '加班费'),
    ('allowance', '津贴补助'),
  ],
  'income-bonus': [('year', '年终奖'), ('quarter', '季度奖金'), ('award', '奖励金')],
  'income-part-time': [
    ('freelance', '自由职业'),
    ('service', '劳务收入'),
    ('side', '副业收入'),
  ],
  'income-investment': [
    ('interest', '利息'),
    ('dividend', '分红'),
    ('fund', '基金收益'),
    ('stock', '股票收益'),
    ('rent', '租金收入'),
  ],
  'income-refund': [
    ('shopping', '购物退款'),
    ('service', '服务退款'),
    ('deposit', '押金退回'),
  ],
  'income-other': [
    ('redpacket', '收到红包'),
    ('gift', '收到礼金'),
    ('used', '闲置出售'),
    ('misc', '其他进账'),
  ],
};

const _familyChildren = <String, List<(String, String)>>{
  'expense-food': [
    ('grocery', '买菜'),
    ('fruit', '水果'),
    ('staple', '米面粮油'),
    ('dairy', '乳品饮料'),
    ('snacks', '家庭零食'),
    ('dining', '家庭聚餐'),
    ('delivery', '外卖'),
  ],
  'expense-shopping': [
    ('daily', '家庭日用品'),
    ('child', '母婴用品'),
    ('clothes', '家人衣物'),
    ('furniture', '家具'),
    ('cleaning', '清洁用品'),
  ],
  'expense-education': [
    ('tuition', '子女学费'),
    ('course', '课外辅导'),
    ('interest', '兴趣班'),
    ('books', '书籍文具'),
    ('care', '托育托管'),
  ],
  'income-salary': [
    ('salary', '家人工资'),
    ('performance', '绩效收入'),
    ('allowance', '家庭补贴'),
  ],
};

const _businessChildren = <String, List<(String, String)>>{
  'expense-food': [
    ('client', '客户用餐'),
    ('team', '团队用餐'),
    ('travel', '出差餐饮'),
    ('coffee', '茶歇饮品'),
  ],
  'expense-transport': [
    ('taxi', '商务打车'),
    ('rail', '高铁火车'),
    ('flight', '商务机票'),
    ('local', '市内交通'),
  ],
  'expense-shopping': [
    ('material', '原材料'),
    ('goods', '商品采购'),
    ('outsourcing', '外包服务'),
    ('shipping', '采购运费'),
    ('packaging', '包装材料'),
  ],
  'expense-entertainment': [
    ('client', '客户招待'),
    ('event', '商务活动'),
    ('team', '团队建设'),
  ],
  'expense-housing': [
    ('office', '办公室租金'),
    ('warehouse', '仓储租金'),
    ('property', '物业费'),
    ('repair', '场地维护'),
  ],
  'expense-utilities': [
    ('office', '办公用品'),
    ('utility', '水电网络'),
    ('tax', '税费'),
    ('bank', '银行手续费'),
    ('professional', '财税服务'),
  ],
  'expense-medical': [
    ('insurance', '员工保险'),
    ('exam', '员工体检'),
    ('festival', '节日福利'),
    ('benefit', '福利补助'),
  ],
  'expense-education': [
    ('training', '员工培训'),
    ('meeting', '会议费'),
    ('certification', '资质认证'),
    ('books', '专业资料'),
  ],
  'expense-travel': [
    ('hotel', '出差住宿'),
    ('allowance', '差旅补贴'),
    ('visa', '签证保险'),
    ('exhibition', '展会费用'),
  ],
  'expense-gift': [
    ('client', '客户礼品'),
    ('festival', '节庆礼赠'),
    ('partner', '合作伙伴礼赠'),
  ],
  'expense-pet': [
    ('ads', '广告投放'),
    ('content', '内容制作'),
    ('platform', '平台推广'),
    ('event', '活动营销'),
  ],
  'expense-digital': [
    ('hardware', '办公设备'),
    ('software', '软件订阅'),
    ('cloud', '云服务'),
    ('maintenance', '设备维护'),
  ],
  'expense-car': [
    ('fuel', '运营燃油'),
    ('maintenance', '车辆维修保养'),
    ('insurance', '商业车险'),
    ('toll', '停车通行'),
  ],
  'expense-other': [('fee', '经营手续费'), ('loss', '经营损失'), ('misc', '其他经营支出')],
  'income-salary': [
    ('product', '产品销售'),
    ('service', '服务收入'),
    ('contract', '合同回款'),
  ],
  'income-bonus': [('subsidy', '经营补贴'), ('award', '经营奖励'), ('rebate', '销售返利')],
  'income-part-time': [
    ('rent', '租赁收入'),
    ('license', '授权收入'),
    ('commission', '佣金收入'),
  ],
  'income-investment': [
    ('interest', '存款利息'),
    ('dividend', '投资分红'),
    ('gain', '投资处置收益'),
  ],
  'income-refund': [
    ('goods', '退货退款'),
    ('service', '服务退款'),
    ('deposit', '保证金退回'),
  ],
  'income-other': [
    ('compensation', '赔偿收入'),
    ('asset', '资产处置'),
    ('misc', '其他经营收入'),
  ],
};

List<SeedCategoryTemplate> subcategoryTemplates(
  BookType type,
  SeedCategoryTemplate parent,
) {
  if (type == BookType.personal && parent.key == 'expense-food')
    return foodSubcategoryTemplates;
  final overrides = switch (type) {
    BookType.personal => const <String, List<(String, String)>>{},
    BookType.family => _familyChildren,
    BookType.enterprise => _businessChildren,
  };
  return [
    for (final child
        in overrides[parent.key] ??
            _commonChildren[parent.key] ??
            const <(String, String)>[])
      SeedCategoryTemplate(
        '${parent.key}-${child.$1}',
        child.$2,
        parent.icon,
        parent.type,
      ),
  ];
}

import 'package:flutter/material.dart';

class CategoryIcon extends StatelessWidget {
  const CategoryIcon({
    required this.category,
    super.key,
    this.size = 46,
    this.vivid = false,
    this.monochrome = false,
    this.iconKey,
    this.illustrated = false,
  });

  final bool illustrated;
  final String category;
  final double size;
  final bool vivid;
  final bool monochrome;

  /// The persisted icon key is used when a category has been renamed or is
  /// custom and therefore cannot be resolved from its display name.
  final String? iconKey;

  @override
  Widget build(BuildContext context) {
    final vividStyle = _styleFor(category, iconKey);
    // Keep the same icon glyph in every surface. The non-vivid variant only
    // softens the container so list rows and the quick-add sheet do not drift.
    final style = vivid
        ? vividStyle
        : (const Color(0xFFF1F4EA), vividStyle.$2, vividStyle.$3);
    final scheme = Theme.of(context).colorScheme;
    final resolvedStyle = monochrome
        ? (
            scheme.primaryContainer.withValues(alpha: .72),
            style.$2,
            scheme.primary,
          )
        : style;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: resolvedStyle.$1,
        borderRadius: BorderRadius.circular(
          illustrated
              ? size / 2
              : vivid
              ? size * .32
              : size / 2,
        ),
      ),
      child: illustrated
          ? Center(
              child: Text(
                _emojiByName[category] ?? _emojiByIcon[iconKey] ?? '🧩',
                style: TextStyle(fontSize: size * .64, height: 1.15),
              ),
            )
          : Icon(resolvedStyle.$2, color: resolvedStyle.$3, size: size * .48),
    );
  }

  static Color accentFor(String category, {String? iconKey}) =>
      _styleFor(category, iconKey).$3;

  static (Color, IconData, Color) _styleFor(String category, String? iconKey) {
    final exact = _vividStyles[category];
    if (exact != null) return exact;
    final inherited =
        _vividStyles[_categoryByIconKey[iconKey]] ?? _vividStyles['其他']!;
    final secondaryIcon = _secondaryIcons[category];
    if (secondaryIcon != null) {
      return (inherited.$1, secondaryIcon, inherited.$3);
    }
    return inherited;
  }

  static const _secondaryIcons = <String, IconData>{
    '早餐': Icons.free_breakfast_rounded,
    '午餐': Icons.lunch_dining_rounded,
    '晚餐': Icons.dinner_dining_rounded,
    '火锅': Icons.soup_kitchen_rounded,
    '买菜': Icons.local_grocery_store_rounded,
    '正餐': Icons.restaurant_rounded,
    '饮料': Icons.local_drink_rounded,
    '夜宵': Icons.nightlife_rounded,
    '甜品烘焙': Icons.bakery_dining_rounded,
    '聚餐': Icons.groups_rounded,
    '打车': Icons.local_taxi_rounded,
    '地铁公交': Icons.directions_subway_rounded,
    '加油': Icons.local_gas_station_rounded,
    '停车': Icons.local_parking_rounded,
    '火车高铁': Icons.train_rounded,
    '机票': Icons.flight_rounded,
    '共享单车': Icons.pedal_bike_rounded,
    '过路费': Icons.toll_rounded,
    '租车': Icons.car_rental_rounded,
    '服饰鞋包': Icons.checkroom_rounded,
    '美妆护肤': Icons.face_retouching_natural_rounded,
    '淘宝': Icons.shopping_bag_rounded,
    '京东': Icons.shopping_cart_checkout_rounded,
    '拼多多': Icons.local_mall_rounded,
    '抖音电商': Icons.shopping_bag_rounded,
    '小红书': Icons.auto_stories_rounded,
    '饰品': Icons.diamond_rounded,
    '个人护理': Icons.spa_rounded,
    '母婴用品': Icons.child_friendly_rounded,
    '礼品': Icons.redeem_rounded,
    '日用品': Icons.inventory_2_rounded,
    '清洁用品': Icons.cleaning_services_rounded,
    '厨房用品': Icons.kitchen_rounded,
    '收纳用品': Icons.inventory_2_rounded,
    '家纺寝具': Icons.bed_rounded,
    '家具': Icons.chair_rounded,
    '小家电': Icons.kitchen_rounded,
    '卫浴用品': Icons.bathtub_rounded,
    '香烟': Icons.smoking_rooms_rounded,
    '酒类': Icons.wine_bar_rounded,
    '茶叶': Icons.emoji_food_beverage_rounded,
    '茶具': Icons.local_cafe_rounded,
    '电影': Icons.movie_rounded,
    '游戏': Icons.sports_esports_rounded,
    '音乐会员': Icons.music_note_rounded,
    '运动健身': Icons.fitness_center_rounded,
    '聚会': Icons.celebration_rounded,
    '唱歌': Icons.mic_rounded,
    '演出': Icons.theater_comedy_rounded,
    '会员订阅': Icons.subscriptions_rounded,
    '房租': Icons.key_rounded,
    '房贷': Icons.account_balance_rounded,
    '物业': Icons.apartment_rounded,
    '维修': Icons.handyman_rounded,
    '装修': Icons.construction_rounded,
    '保洁': Icons.cleaning_services_rounded,
    '水费': Icons.water_drop_rounded,
    '电费': Icons.bolt_rounded,
    '燃气费': Icons.local_fire_department_rounded,
    '话费': Icons.phone_android_rounded,
    '宽带': Icons.wifi_rounded,
    '取暖费': Icons.thermostat_rounded,
    '药品': Icons.medication_rounded,
    '门诊挂号': Icons.local_hospital_rounded,
    '体检': Icons.monitor_heart_rounded,
    '住院': Icons.bed_rounded,
    '牙科': Icons.medical_services_rounded,
    '医疗保险': Icons.health_and_safety_rounded,
    '书籍': Icons.menu_book_rounded,
    '学费': Icons.school_rounded,
    '课程培训': Icons.cast_for_education_rounded,
    '考试': Icons.quiz_rounded,
    '文具': Icons.edit_rounded,
    '兴趣学习': Icons.palette_rounded,
    '住宿': Icons.hotel_rounded,
    '景点门票': Icons.confirmation_number_rounded,
    '旅行团': Icons.tour_rounded,
    '旅行餐饮': Icons.restaurant_rounded,
    '纪念品': Icons.card_giftcard_rounded,
    '旅途交通': Icons.route_rounded,
    '红包': Icons.mark_email_unread_rounded,
    '礼物': Icons.redeem_rounded,
    '婚庆礼金': Icons.favorite_rounded,
    '请客': Icons.restaurant_menu_rounded,
    '公益捐赠': Icons.volunteer_activism_rounded,
    '家人': Icons.family_restroom_rounded,
    '朋友同事': Icons.groups_rounded,
    '宠物食品': Icons.pets_rounded,
    '宠物用品': Icons.shopping_bag_rounded,
    '宠物医疗': Icons.medical_services_rounded,
    '洗护美容': Icons.content_cut_rounded,
    '寄养': Icons.home_rounded,
    '手机': Icons.smartphone_rounded,
    '电脑': Icons.laptop_mac_rounded,
    '家用电器': Icons.kitchen_rounded,
    '配件': Icons.cable_rounded,
    '软件订阅': Icons.apps_rounded,
    '数码维修': Icons.build_rounded,
    '车辆加油': Icons.local_gas_station_rounded,
    '保养': Icons.car_repair_rounded,
    '修车': Icons.build_rounded,
    '车险': Icons.shield_rounded,
    '停车费': Icons.local_parking_rounded,
    '基本工资': Icons.payments_rounded,
    '绩效': Icons.trending_up_rounded,
    '加班费': Icons.more_time_rounded,
    '津贴补助': Icons.account_balance_wallet_rounded,
    '年终奖': Icons.celebration_rounded,
    '季度奖金': Icons.stars_rounded,
    '奖励金': Icons.workspace_premium_rounded,
    '自由职业': Icons.work_outline_rounded,
    '劳务收入': Icons.handshake_rounded,
    '副业收入': Icons.business_center_rounded,
    '利息': Icons.percent_rounded,
    '分红': Icons.pie_chart_rounded,
    '基金收益': Icons.show_chart_rounded,
    '股票收益': Icons.show_chart_rounded,
    '租金收入': Icons.home_work_rounded,
    '购物退款': Icons.shopping_bag_rounded,
    '服务退款': Icons.undo_rounded,
    '押金退回': Icons.savings_rounded,
    '收到红包': Icons.mark_email_unread_rounded,
    '收到礼金': Icons.redeem_rounded,
    '闲置出售': Icons.sell_rounded,
    '生活费/补助': Icons.account_balance_wallet_rounded,
    '其他进账': Icons.add_circle_rounded,
  };

  static const _emojiByName = <String, String>{
    '早餐': '🍜',
    '午餐': '🍱',
    '晚餐': '🍜',
    '奶茶咖啡': '🧋',
    '火锅': '🍲',
    '零食': '🍟',
    '买菜': '🥬',
    '水果': '🍎',
    '外卖': '🛵',
  };
  static const _emojiByIcon = <String, String>{
    'restaurant_outlined': '🍜',
    'shopping_bag_outlined': '🛍️',
    'directions_car_outlined': '🚙',
    'home_outlined': '🏠',
    'movie_outlined': '🎮',
    'school_outlined': '📖',
    'medical_services_outlined': '💊',
    'redeem_outlined': '🎁',
    'trending_up': '🪙',
    'pets_outlined': '🐾',
    'devices_outlined': '📷',
    'work_outline': '💼',
    'flight_takeoff_outlined': '🏝️',
    'more_horiz': '🟩',
    'category_outlined': '🧩',
    'receipt_long_outlined': '🧾',
    'directions_car_filled_outlined': '🚗',
    'local_cafe_outlined': '🧋',
    'fastfood_outlined': '🍟',
    'shopping_cart_outlined': '🧺',
    'nutrition_outlined': '🍎',
    'delivery_dining_outlined': '🛵',
    'payments_outlined': '💰',
    'stars_outlined': '🌟',
    'schedule_outlined': '⏰',
    'undo': '💸',
    'add_circle_outline': '💵',
    'campaign_outlined': '📣',
  };

  static const _categoryByIconKey = <String, String>{
    'restaurant_outlined': '餐饮',
    'local_cafe_outlined': '奶茶咖啡',
    'fastfood_outlined': '零食',
    'shopping_cart_outlined': '日用',
    'nutrition_outlined': '水果',
    'delivery_dining_outlined': '外卖',
    'directions_car_outlined': '交通',
    'shopping_bag_outlined': '购物',
    'movie_outlined': '娱乐',
    'home_outlined': '住房',
    'receipt_long_outlined': '生活缴费',
    'medical_services_outlined': '医疗',
    'school_outlined': '教育培训',
    'flight_takeoff_outlined': '旅行',
    'redeem_outlined': '人情',
    'pets_outlined': '宠物',
    'devices_outlined': '数码',
    'directions_car_filled_outlined': '汽车',
    'work_outline': '工资',
    'stars_outlined': '奖金',
    'schedule_outlined': '兼职',
    'trending_up': '投资收益',
    'undo': '退款',
    'add_circle_outline': '其他收入',
    'payments_outlined': '工资薪酬',
    'campaign_outlined': '营销推广',
    'more_horiz': '其他',
    'category_outlined': '其他',
  };
  static const _vividStyles = <String, (Color, IconData, Color)>{
    '转账': (Color(0xFFE7F2FF), Icons.swap_horiz_rounded, Color(0xFF398FF2)),
    '余额校准': (Color(0xFFF0F3F7), Icons.tune_rounded, Color(0xFF8799B0)),
    '奶茶咖啡': (Color(0xFFFFF0DF), Icons.local_cafe_rounded, Color(0xFFB78450)),
    '零食': (Color(0xFFFFF0DF), Icons.fastfood_rounded, Color(0xFFFF973F)),
    '水果': (Color(0xFFE0F8EF), Icons.eco_rounded, Color(0xFF12B992)),
    '外卖': (Color(0xFFE7F2FF), Icons.delivery_dining_rounded, Color(0xFF398FF2)),
    '餐饮': (Color(0xFFFFF0DF), Icons.restaurant_rounded, Color(0xFFFF973F)),
    '购物': (Color(0xFFFFEAF2), Icons.shopping_bag_rounded, Color(0xFFF75C9A)),
    '交通': (Color(0xFFE7F2FF), Icons.directions_car_rounded, Color(0xFF398FF2)),
    '居家': (Color(0xFFE0F8EF), Icons.home_rounded, Color(0xFF12B992)),
    '住房': (Color(0xFFE0F8EF), Icons.home_rounded, Color(0xFF12B992)),
    '商务餐饮': (Color(0xFFFFF0DF), Icons.restaurant_rounded, Color(0xFFFF973F)),
    '娱乐': (Color(0xFFF0EAFE), Icons.sports_esports_rounded, Color(0xFF9D77EE)),
    '日用': (Color(0xFFEAF2FF), Icons.shopping_cart_rounded, Color(0xFF539AF2)),
    '医疗': (Color(0xFFE3F8F1), Icons.local_hospital_rounded, Color(0xFF19B798)),
    '教育': (Color(0xFFE9F2FF), Icons.school_rounded, Color(0xFF408FE6)),
    '人情': (Color(0xFFFFEDF2), Icons.favorite_rounded, Color(0xFFEF789E)),
    '工资': (Color(0xFFE1F8EF), Icons.work_rounded, Color(0xFF11B690)),
    '收入': (
      Color(0xFFE1F8EF),
      Icons.account_balance_wallet_rounded,
      Color(0xFF11B690),
    ),
    '生活缴费': (Color(0xFFEAF2FF), Icons.receipt_long_rounded, Color(0xFF539AF2)),
    '教育培训': (Color(0xFFE9F2FF), Icons.school_rounded, Color(0xFF408FE6)),
    '家庭娱乐': (
      Color(0xFFF0EAFE),
      Icons.sports_esports_rounded,
      Color(0xFF9D77EE),
    ),
    '家庭缴费': (Color(0xFFEAF2FF), Icons.receipt_long_rounded, Color(0xFF539AF2)),
    '家庭医疗': (
      Color(0xFFE3F8F1),
      Icons.local_hospital_rounded,
      Color(0xFF19B798),
    ),
    '家庭旅行': (
      Color(0xFFE5F5FC),
      Icons.flight_takeoff_rounded,
      Color(0xFF38A2C8),
    ),
    '家庭人情': (Color(0xFFFFEDF2), Icons.favorite_rounded, Color(0xFFEF789E)),
    '家庭数码': (Color(0xFFEAF0FF), Icons.devices_rounded, Color(0xFF718EDD)),
    '家庭汽车': (
      Color(0xFFE7F2FF),
      Icons.directions_car_rounded,
      Color(0xFF398FF2),
    ),
    '家庭工资': (Color(0xFFE1F8EF), Icons.work_rounded, Color(0xFF11B690)),
    '家庭奖金': (Color(0xFFFFF3D9), Icons.stars_rounded, Color(0xFFE4B345)),
    '家庭兼职': (Color(0xFFE5F6F6), Icons.schedule_rounded, Color(0xFF30AFA6)),
    '家庭投资收益': (Color(0xFFE1F8EF), Icons.trending_up_rounded, Color(0xFF11B690)),
    '家庭退款': (Color(0xFFE9F2FF), Icons.undo_rounded, Color(0xFF408FE6)),
    '旅行': (Color(0xFFE5F5FC), Icons.flight_takeoff_rounded, Color(0xFF38A2C8)),
    '宠物': (Color(0xFFFFEFDE), Icons.pets_rounded, Color(0xFFD29B50)),
    '数码': (Color(0xFFEAF0FF), Icons.devices_rounded, Color(0xFF718EDD)),
    '汽车': (Color(0xFFE7F2FF), Icons.directions_car_rounded, Color(0xFF398FF2)),
    '奖金': (Color(0xFFFFF3D9), Icons.stars_rounded, Color(0xFFE4B345)),
    '兼职': (Color(0xFFE5F6F6), Icons.schedule_rounded, Color(0xFF30AFA6)),
    '投资收益': (Color(0xFFE1F8EF), Icons.trending_up_rounded, Color(0xFF11B690)),
    '退款': (Color(0xFFE9F2FF), Icons.undo_rounded, Color(0xFF408FE6)),
    '其他收入': (Color(0xFFE1F8EF), Icons.add_circle_outline, Color(0xFF11B690)),
    '家庭采购': (Color(0xFFEAF2FF), Icons.shopping_cart_rounded, Color(0xFF539AF2)),
    '家庭出行': (
      Color(0xFFE7F2FF),
      Icons.directions_car_rounded,
      Color(0xFF398FF2),
    ),
    '家庭购物': (Color(0xFFFFEAF2), Icons.shopping_bag_rounded, Color(0xFFF75C9A)),
    '房屋居住': (Color(0xFFE0F8EF), Icons.home_rounded, Color(0xFF12B992)),
    '子女教育': (Color(0xFFE9F2FF), Icons.school_rounded, Color(0xFF408FE6)),
    '采购成本': (Color(0xFFEAF2FF), Icons.shopping_cart_rounded, Color(0xFF539AF2)),
    '差旅交通': (
      Color(0xFFE7F2FF),
      Icons.directions_car_rounded,
      Color(0xFF398FF2),
    ),
    '场地租赁': (Color(0xFFE0F8EF), Icons.home_rounded, Color(0xFF12B992)),
    '培训会议': (Color(0xFFE9F2FF), Icons.school_rounded, Color(0xFF408FE6)),
    '商务旅行': (
      Color(0xFFE5F5FC),
      Icons.flight_takeoff_rounded,
      Color(0xFF38A2C8),
    ),
    '商务礼赠': (Color(0xFFFFEDF2), Icons.favorite_rounded, Color(0xFFEF789E)),
    '营销推广': (Color(0xFFFFF0E0), Icons.campaign_rounded, Color(0xFFE28A30)),
    '主营业务收入': (Color(0xFFE1F8EF), Icons.work_rounded, Color(0xFF11B690)),
    '经营奖励': (Color(0xFFFFF3D9), Icons.stars_rounded, Color(0xFFE4B345)),
    '其他业务收入': (Color(0xFFE5F6F6), Icons.schedule_rounded, Color(0xFF30AFA6)),
    '其他支出': (Color(0xFFF0F3F7), Icons.more_horiz_rounded, Color(0xFF8799B0)),
    '营销招待': (Color(0xFFFFF0E0), Icons.campaign_rounded, Color(0xFFE28A30)),
    '办公税费': (Color(0xFFEAF2FF), Icons.receipt_long_rounded, Color(0xFF539AF2)),
    '员工福利': (
      Color(0xFFE3F8F1),
      Icons.health_and_safety_rounded,
      Color(0xFF19B798),
    ),
    '软件设备': (Color(0xFFEAF0FF), Icons.devices_rounded, Color(0xFF718EDD)),
    '车辆运营': (
      Color(0xFFE7F2FF),
      Icons.directions_car_rounded,
      Color(0xFF398FF2),
    ),
    '工资薪酬': (Color(0xFFE1F8EF), Icons.work_rounded, Color(0xFF11B690)),
    '采购退款': (Color(0xFFE9F2FF), Icons.undo_rounded, Color(0xFF408FE6)),
    '其他': (Color(0xFFF0F3F7), Icons.more_horiz_rounded, Color(0xFF8799B0)),
  };
}

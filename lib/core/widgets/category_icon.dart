import 'package:flutter/material.dart';

import '../../app/theme/app_theme_tokens.dart';

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
        : (context.appSurfaceSoft, vividStyle.$2, vividStyle.$3);
    final resolvedStyle = monochrome
        ? (context.appPrimarySoft, style.$2, context.appPrimary)
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
    final base =
        _vividStyles[category] ??
        _vividStyles[_categoryByIconKey[iconKey]] ??
        _vividStyles['其他']!;
    final icon =
        _semanticIconForName(category) ?? _iconByKey[iconKey] ?? base.$2;
    return (base.$1, icon, base.$3);
  }

  static IconData? _semanticIconForName(String name) {
    if (RegExp('早餐|午餐|晚餐|正餐|聚餐|客户用餐|团队用餐|出差餐饮|旅行餐饮').hasMatch(name)) {
      return Icons.restaurant_rounded;
    }
    if (RegExp('奶茶|咖啡|茶歇|饮料|乳品').hasMatch(name)) {
      return Icons.local_cafe_rounded;
    }
    if (RegExp('火锅').hasMatch(name)) return Icons.soup_kitchen_rounded;
    if (RegExp('零食|夜宵').hasMatch(name)) return Icons.fastfood_rounded;
    if (RegExp('买菜|米面粮油|家庭采购').hasMatch(name)) {
      return Icons.shopping_cart_rounded;
    }
    if (RegExp('水果').hasMatch(name)) return Icons.eco_rounded;
    if (RegExp('外卖').hasMatch(name)) return Icons.delivery_dining_rounded;
    if (RegExp('甜品|烘焙').hasMatch(name)) return Icons.cake_rounded;

    if (RegExp('打车|出租').hasMatch(name)) return Icons.local_taxi_rounded;
    if (RegExp('地铁|公交|市内交通').hasMatch(name)) return Icons.directions_bus_rounded;
    if (RegExp('加油|燃油').hasMatch(name)) return Icons.local_gas_station_rounded;
    if (RegExp('停车').hasMatch(name)) return Icons.local_parking_rounded;
    if (RegExp('火车|高铁').hasMatch(name)) return Icons.train_rounded;
    if (RegExp('机票|航班').hasMatch(name)) return Icons.flight_rounded;
    if (RegExp('单车').hasMatch(name)) return Icons.pedal_bike_rounded;
    if (RegExp('过路费|通行').hasMatch(name)) return Icons.toll_rounded;
    if (RegExp('租车').hasMatch(name)) return Icons.car_rental_rounded;

    if (RegExp('服饰|衣物|鞋包').hasMatch(name)) return Icons.checkroom_rounded;
    if (RegExp('美妆|美容|护理').hasMatch(name)) return Icons.face_retouching_natural_rounded;
    if (RegExp('淘宝|京东|拼多多|抖音|小红书|商品采购|原材料').hasMatch(name)) {
      return Icons.storefront_rounded;
    }
    if (RegExp('饰品|礼品|礼物|礼赠').hasMatch(name)) return Icons.card_giftcard_rounded;
    if (RegExp('母婴|托育').hasMatch(name)) return Icons.child_friendly_rounded;

    if (RegExp('日用品|办公用品').hasMatch(name)) return Icons.shopping_basket_rounded;
    if (RegExp('清洁|保洁').hasMatch(name)) return Icons.cleaning_services_rounded;
    if (RegExp('厨房').hasMatch(name)) return Icons.kitchen_rounded;
    if (RegExp('收纳|仓储').hasMatch(name)) return Icons.inventory_2_rounded;
    if (RegExp('家纺|寝具').hasMatch(name)) return Icons.bed_rounded;
    if (RegExp('家具').hasMatch(name)) return Icons.chair_rounded;
    if (RegExp('家电|设备|硬件').hasMatch(name)) return Icons.devices_other_rounded;
    if (RegExp('卫浴').hasMatch(name)) return Icons.bathtub_rounded;

    if (RegExp('香烟').hasMatch(name)) return Icons.smoking_rooms_rounded;
    if (RegExp('酒').hasMatch(name)) return Icons.local_bar_rounded;
    if (RegExp('茶叶|茶具').hasMatch(name)) return Icons.emoji_food_beverage_rounded;

    if (RegExp('电影').hasMatch(name)) return Icons.movie_rounded;
    if (RegExp('游戏').hasMatch(name)) return Icons.sports_esports_rounded;
    if (RegExp('音乐').hasMatch(name)) return Icons.music_note_rounded;
    if (RegExp('运动|健身').hasMatch(name)) return Icons.fitness_center_rounded;
    if (RegExp('聚会|团队建设').hasMatch(name)) return Icons.groups_rounded;
    if (RegExp('唱歌').hasMatch(name)) return Icons.mic_rounded;
    if (RegExp('演出|商务活动').hasMatch(name)) return Icons.theater_comedy_rounded;
    if (RegExp('会员订阅|软件订阅|云服务').hasMatch(name)) return Icons.subscriptions_rounded;

    if (RegExp('房租|租金|办公室租金|仓储租金').hasMatch(name)) return Icons.home_rounded;
    if (RegExp('房贷').hasMatch(name)) return Icons.account_balance_rounded;
    if (RegExp('物业').hasMatch(name)) return Icons.apartment_rounded;
    if (RegExp('维修|维护|修车|保养').hasMatch(name)) return Icons.build_rounded;
    if (RegExp('装修').hasMatch(name)) return Icons.construction_rounded;

    if (RegExp('水费').hasMatch(name)) return Icons.water_drop_rounded;
    if (RegExp('电费').hasMatch(name)) return Icons.bolt_rounded;
    if (RegExp('燃气').hasMatch(name)) return Icons.local_fire_department_rounded;
    if (RegExp('话费').hasMatch(name)) return Icons.phone_android_rounded;
    if (RegExp('宽带|网络').hasMatch(name)) return Icons.router_rounded;
    if (RegExp('取暖').hasMatch(name)) return Icons.thermostat_rounded;
    if (RegExp('税费').hasMatch(name)) return Icons.receipt_long_rounded;
    if (RegExp('手续费').hasMatch(name)) return Icons.account_balance_wallet_rounded;

    if (RegExp('药品').hasMatch(name)) return Icons.medication_rounded;
    if (RegExp('门诊|挂号|住院|体检|医疗').hasMatch(name)) return Icons.local_hospital_rounded;
    if (RegExp('牙科').hasMatch(name)) return Icons.medical_services_rounded;
    if (RegExp('保险|车险').hasMatch(name)) return Icons.shield_rounded;

    if (RegExp('书籍|资料').hasMatch(name)) return Icons.menu_book_rounded;
    if (RegExp('学费|课程|培训|辅导|兴趣班').hasMatch(name)) return Icons.school_rounded;
    if (RegExp('考试|认证').hasMatch(name)) return Icons.assignment_rounded;
    if (RegExp('文具').hasMatch(name)) return Icons.edit_rounded;

    if (RegExp('住宿|酒店').hasMatch(name)) return Icons.hotel_rounded;
    if (RegExp('门票|展会').hasMatch(name)) return Icons.confirmation_number_rounded;
    if (RegExp('旅行团|旅途').hasMatch(name)) return Icons.tour_rounded;

    if (RegExp('红包|礼金').hasMatch(name)) return Icons.redeem_rounded;
    if (RegExp('婚庆').hasMatch(name)) return Icons.favorite_rounded;
    if (RegExp('请客').hasMatch(name)) return Icons.restaurant_rounded;
    if (RegExp('公益|捐赠').hasMatch(name)) return Icons.volunteer_activism_rounded;
    if (RegExp('家人|家庭补贴|生活费').hasMatch(name)) return Icons.family_restroom_rounded;
    if (RegExp('朋友|同事|客户|合作伙伴').hasMatch(name)) return Icons.groups_rounded;

    if (RegExp('宠物').hasMatch(name)) return Icons.pets_rounded;
    if (RegExp('手机').hasMatch(name)) return Icons.phone_android_rounded;
    if (RegExp('电脑').hasMatch(name)) return Icons.computer_rounded;
    if (RegExp('配件|包装').hasMatch(name)) return Icons.cable_rounded;

    if (RegExp('工资|绩效|加班|津贴|补助|产品销售|服务收入|合同回款').hasMatch(name)) {
      return Icons.payments_rounded;
    }
    if (RegExp('奖金|奖励|返利').hasMatch(name)) return Icons.stars_rounded;
    if (RegExp('自由职业|劳务|副业|佣金').hasMatch(name)) return Icons.work_outline_rounded;
    if (RegExp('利息|分红|基金|股票|投资').hasMatch(name)) return Icons.trending_up_rounded;
    if (RegExp('退款|退回').hasMatch(name)) return Icons.undo_rounded;
    if (RegExp('闲置出售|资产处置').hasMatch(name)) return Icons.sell_rounded;
    if (RegExp('广告|推广|营销|内容制作').hasMatch(name)) return Icons.campaign_rounded;

    return null;
  }

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

  static const _iconByKey = <String, IconData>{
    'home_work_outlined': Icons.home_work_outlined,
    'local_bar_outlined': Icons.local_bar_outlined,
    'local_drink_outlined': Icons.local_drink_outlined,
    'nightlife_outlined': Icons.nightlife_outlined,
    'bakery_dining_outlined': Icons.bakery_dining_outlined,
    'dinner_dining_outlined': Icons.dinner_dining_outlined,
    'health_and_safety_outlined': Icons.health_and_safety_outlined,
    'campaign_outlined': Icons.campaign_outlined,
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
    'home_work_outlined': '居家',
    'local_bar_outlined': '其他',
    'local_drink_outlined': '餐饮',
    'nightlife_outlined': '娱乐',
    'bakery_dining_outlined': '餐饮',
    'dinner_dining_outlined': '餐饮',
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

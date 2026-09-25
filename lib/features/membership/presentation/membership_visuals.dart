import 'package:flutter/material.dart';

import '../../../app/theme/app_theme_tokens.dart';

import '../../../core/widgets/payment_brand_icon.dart';
import '../data/membership_catalog.dart';
import '../domain/commercial_service_contracts.dart';

const memberGreen = Color(0xFF456A25);
const memberAccent = Color(0xFF7CA33F);
const memberInk = Color(0xFF20221F);
const memberMuted = Color(0xFF7E847C);
const memberSurface = Color(0xFFFAFAF5);
const memberBackground = Color(0xFFF7F8F3);
const memberAssets = 'assets/images/membership/';
const memberCardBorder = Color(0xFFDCE8D3);
const memberCardShadows = <BoxShadow>[
  BoxShadow(color: Color(0x14283D27), blurRadius: 4, offset: Offset(0, 2)),
  BoxShadow(
    color: Color(0x0D6E8C51),
    blurRadius: 20,
    spreadRadius: 1,
    offset: Offset(0, 8),
  ),
];

Color memberGreenFor(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFFA8CF7B)
        : memberGreen;

Color memberAccentFor(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFFC3DEA0)
        : memberAccent;

Color memberInkFor(BuildContext context) => context.appPrimaryText;
Color memberMutedFor(BuildContext context) => context.appSecondaryText;
Color memberSurfaceFor(BuildContext context) => context.appSurface;
Color memberBackgroundFor(BuildContext context) => context.appBackground;
Color memberCardBorderFor(BuildContext context) => context.appDivider;

List<BoxShadow> memberCardShadowsFor(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
        ? const [
            BoxShadow(
              color: Color(0x52000000),
              blurRadius: 18,
              offset: Offset(0, 8),
            ),
          ]
        : memberCardShadows;


/// Brand assets are kept in the membership asset folder so the same payment
/// marks can be reused by order history and other checkout surfaces.
const memberWechatPayAsset = paymentWechatAsset;
const memberAlipayAsset = paymentAlipayAsset;

class MembershipHero extends StatelessWidget {
  const MembershipHero({super.key});

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final width = constraints.maxWidth;
      final scale = MediaQuery.textScalerOf(context).scale(1);
      final height = 120.0 + (scale - 1) * 90;
      return SizedBox(
        key: const ValueKey('membership-hero'),
        height: height,
        child: Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            Positioned(
              right: width * .10,
              bottom: -26,
              width: width * .37,
              height: 153,
              child: Image.asset(
                '${memberAssets}hero-mascot.png',
                fit: BoxFit.contain,
                alignment: Alignment.bottomCenter,
              ),
            ),
            Positioned(
              right: -12,
              bottom: 0,
              width: 85,
              height: 65,
              child: IgnorePointer(
                child: Image.asset(
                  '${memberAssets}hero-leaves.png',
                  fit: BoxFit.contain,
                ),
              ),
            ),
            Positioned(
              left: width * .18,
              top: -7,
              width: 24,
              height: 25,
              child: IgnorePointer(
                child: Image.asset(
                  '${memberAssets}hero-leaves.png',
                  fit: BoxFit.contain,
                ),
              ),
            ),
            Positioned(
              left: 24,
              right: 8,
              top: 10,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '成为会员',
                    style: TextStyle(
                      color: memberGreenFor(context),
                      fontSize: width < 350 ? 29 : 33,
                      fontWeight: FontWeight.w900,
                      height: 1.12,
                    ),
                  ),
                  const SizedBox(height: 5),
                  SizedBox(
                    width: width * .63,
                    child: Text(
                      '解锁更完整的记账体验',
                      style: TextStyle(
                        color: memberInkFor(context),
                        fontSize: width < 350 ? 13 : 15,
                        fontWeight: FontWeight.w800,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              left: 24,
              bottom: 15,
              width: width * .65,
              child: const Row(
                children: [
                  Expanded(
                    child: _HeroSellingPoint(
                      icon: Icons.workspace_premium_rounded,
                      text: '更强大的功能',
                    ),
                  ),
                  Expanded(
                    child: _HeroSellingPoint(
                      icon: Icons.favorite_rounded,
                      text: '更贴心的陪伴',
                    ),
                  ),
                  Expanded(
                    child: _HeroSellingPoint(
                      icon: Icons.eco_rounded,
                      text: '更好的生活',
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              right: 11,
              top: 9,
              width: 63,
              child: Transform.rotate(
                angle: -.16,
                child: Text(
                  '好好记账\n陪你把生活\n过得更好',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: memberGreenFor(context),
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    height: 1.65,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}

class _HeroSellingPoint extends StatelessWidget {
  const _HeroSellingPoint({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 12, color: memberGreenFor(context)),
      const SizedBox(width: 3),
      Flexible(
        child: Text(
          text,
          style: TextStyle(color: memberGreenFor(context), fontSize: 8, height: 1.25),
        ),
      ),
    ],
  );
}

class MemberPlanSection extends StatelessWidget {
  const MemberPlanSection({
    super.key,
    required this.plans,
    required this.selectedPlanId,
    required this.onSelect,
    required this.renewal,
  });

  final List<MembershipProduct> plans;
  final String selectedPlanId;
  final ValueChanged<MembershipProduct> onSelect;
  final bool renewal;

  @override
  Widget build(BuildContext context) {
    final monthly = plans.firstWhere(
      (plan) => plan.months == 1,
      orElse: () => plans.first,
    );
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(10, 7, 10, 6),
      decoration: BoxDecoration(
        color: memberSurfaceFor(context),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: memberCardBorderFor(context)),
        boxShadow: memberCardShadowsFor(context),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var index = 0; index < plans.length; index++)
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  right: index == plans.length - 1 ? 0 : 6,
                ),
                child: MembershipPlanCard(
                  product: plans[index],
                  monthlyPrice: monthly.priceInCents,
                  selected: plans[index].id == selectedPlanId,
                  renewal: renewal,
                  onSelect: () => onSelect(plans[index]),
                  onPurchase: () => onSelect(plans[index]),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class MembershipPlanCard extends StatelessWidget {
  const MembershipPlanCard({
    super.key,
    required this.product,
    required this.monthlyPrice,
    required this.selected,
    required this.renewal,
    required this.onSelect,
    required this.onPurchase,
  });

  final MembershipProduct product;
  final int monthlyPrice;
  final bool selected;
  final bool renewal;
  final VoidCallback onSelect;
  final VoidCallback onPurchase;

  @override
  Widget build(BuildContext context) {
    final saving = monthlyPrice * product.months - product.priceInCents;
    final dailyPrice = product.priceInCents / product.months / 30 / 100;
    return Semantics(
      selected: selected,
      button: true,
      label:
          '${product.title}，${MembershipProduct.money(product.priceInCents)}元',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: ValueKey('membership-plan-${product.id}'),
          borderRadius: BorderRadius.circular(18),
          onTap: onSelect,
          child: Ink(
            padding: const EdgeInsets.fromLTRB(4, 4, 4, 5),
            decoration: BoxDecoration(
              color: selected ? Color.alphaBlend(memberGreenFor(context).withValues(alpha: .14), memberSurfaceFor(context)) : memberSurfaceFor(context),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: selected ? memberAccentFor(context) : memberCardBorderFor(context),
                width: selected ? 1.5 : 1,
              ),
              boxShadow: selected
                  ? const [
                      BoxShadow(
                        color: Color(0x147CA33F),
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Column(
                  children: [
                    const SizedBox(height: 0),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        product.title,
                        maxLines: 1,
                        style: TextStyle(
                          color: memberInkFor(context),
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    SizedBox(
                      height: 23,
                      child: Text(
                        product.description,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: memberMutedFor(context),
                          fontSize: 10,
                          height: 1.25,
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text.rich(
                        TextSpan(
                          children: [
                            const TextSpan(
                              text: '¥',
                              style: TextStyle(fontSize: 13),
                            ),
                            TextSpan(
                              text: MembershipProduct.money(
                                product.priceInCents,
                              ),
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                        style: TextStyle(color: memberInkFor(context)),
                      ),
                    ),
                    const SizedBox(height: 0),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        '¥${dailyPrice.toStringAsFixed(2)} / 天',
                        style: TextStyle(
                          color: memberMutedFor(context),
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    SizedBox(
                      height: 17,
                      child: saving > 0
                          ? FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                '立省 ¥${MembershipProduct.money(saving)}',
                                style: TextStyle(
                                  color: memberAccentFor(context),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(height: 2),
                    SizedBox(
                      width: double.infinity,
                      height: 28,
                      child: OutlinedButton(
                        onPressed: onPurchase,
                        style: OutlinedButton.styleFrom(
                          backgroundColor: selected
                              ? memberGreenFor(context)
                              : Colors.transparent,
                          foregroundColor: selected
                              ? Colors.white
                              : memberGreenFor(context),
                          side: BorderSide(
                            color: selected
                                ? memberGreenFor(context)
                                : memberGreenFor(context).withValues(alpha: .45),
                          ),
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                        ),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            renewal ? '立即续费' : '立即开通',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                if (product.recommended)
                  Positioned(
                    top: -12,
                    right: 5,
                    child: Container(
                      height: 22,
                      padding: const EdgeInsets.symmetric(horizontal: 9),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: memberAccentFor(context),
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: Text(
                        '推荐',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class MemberBenefits extends StatelessWidget {
  const MemberBenefits({
    super.key,
    required this.benefits,
    required this.onMore,
  });

  final List<MembershipBenefit> benefits;
  final VoidCallback onMore;

  static const _icons = <String, IconData>{
    'automatic': Icons.auto_awesome_rounded,
    'statistics': Icons.analytics_outlined,
    'books': Icons.menu_book_outlined,
    'cloud': Icons.cloud_sync_outlined,
    'categories': Icons.category_outlined,
    'export': Icons.file_download_outlined,
    'adfree': Icons.block_rounded,
    'support': Icons.headset_mic_outlined,
  };
  static const _iconColors = <String, Color>{
    'automatic': Color(0xFF72B84B),
    'statistics': Color(0xFFF3A044),
    'books': Color(0xFF4FA8D8),
    'cloud': Color(0xFF8368DB),
    'categories': Color(0xFFF07C99),
    'export': Color(0xFF68A847),
    'adfree': Color(0xFFE79743),
    'support': Color(0xFF5B95D9),
  };

  @override
  Widget build(BuildContext context) {
    final largeText = MediaQuery.textScalerOf(context).scale(1) > 1.2;
    return MemberSectionCard(
      title: '会员专属权益',
      action: '更多权益',
      onAction: onMore,
      leading: Icon(
        Icons.workspace_premium_rounded,
        color: Color(0xFFF0B43C),
        size: 22,
      ),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      headerMinHeight: 24,
      childSpacing: 4,
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: benefits.length,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          mainAxisSpacing: 3,
          crossAxisSpacing: 4,
          mainAxisExtent: largeText ? 132 : 76,
        ),
        itemBuilder: (context, index) {
          final benefit = benefits[index];
          final iconColor = _iconColors[benefit.id] ?? memberGreenFor(context);
          return Column(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: .12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _icons[benefit.id] ?? Icons.check_rounded,
                  color: iconColor,
                  size: 22,
                ),
              ),
              const SizedBox(height: 5),
              SizedBox(
                height: largeText ? 38 : 15,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    benefit.title,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    style: TextStyle(
                      color: memberInkFor(context),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 2),
              SizedBox(
                height: largeText ? 38 : 15,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    benefit.subtitle,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    style: TextStyle(
                      color: memberMutedFor(context),
                      fontSize: 9,
                      height: 1.2,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class MemberTestimonials extends StatelessWidget {
  const MemberTestimonials({super.key, required this.onMore});

  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) => MemberSectionCard(
    title: '他们都在用',
    action: '查看全部',
    onAction: onMore,
    leading: Icon(
      Icons.groups_rounded,
      color: Color(0xFF6F954B),
      size: 22,
    ),
    padding: const EdgeInsets.fromLTRB(14, 6, 14, 6),
    headerMinHeight: 24,
    childSpacing: 2,
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _TestimonialCard(
            image: '${memberAssets}testimonial-user-female.webp',
            name: '小橙子',
            quote: '会员的自动记账太好用了！帮我省下很多时间，消费分析也很准，现在花钱更有计划了～',
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _TestimonialCard(
            image: '${memberAssets}testimonial-user-male.webp',
            name: '阿凯',
            quote: '用了半年，真的改变了我的消费习惯。无广告、数据同步、导出功能都很实用，强烈推荐！',
          ),
        ),
      ],
    ),
  );
}

class _TestimonialCard extends StatelessWidget {
  const _TestimonialCard({
    required this.image,
    required this.name,
    required this.quote,
  });

  final String image;
  final String name;
  final String quote;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: 94),
    padding: const EdgeInsets.all(6),
    decoration: BoxDecoration(
      color: memberSurfaceFor(context),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: memberCardBorderFor(context)),
      boxShadow: const [
        BoxShadow(
          color: Color(0x0A547341),
          blurRadius: 5,
          offset: Offset(0, 2),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            ClipOval(
              child: Image.asset(
                image,
                width: 26,
                height: 26,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const ColoredBox(
                  color: Color(0xFFDCEACB),
                  child: SizedBox(width: 26, height: 26),
                ),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                name,
                style: TextStyle(
                  color: memberInkFor(context),
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Icon(
              Icons.workspace_premium_rounded,
              color: Color(0xFFF0B43C),
              size: 16,
            ),
          ],
        ),
        const SizedBox(height: 3),
        Text(
          quote,
          style: TextStyle(color: memberInkFor(context), fontSize: 9, height: 1.34),
        ),
        const SizedBox(height: 1),
        Text(
          '★★★★★',
          style: TextStyle(
            color: Color(0xFFF0B43C),
            fontSize: 11,
            letterSpacing: 1,
          ),
        ),
      ],
    ),
  );
}

class PaymentMethodSection extends StatelessWidget {
  const PaymentMethodSection({
    super.key,
    required this.selected,
    required this.onSelect,
  });

  final PaymentChannel selected;
  final ValueChanged<PaymentChannel> onSelect;

  @override
  Widget build(BuildContext context) => MemberSectionCard(
    title: '选择支付方式',
    action: '支付安全有保障',
    onAction: null,
    actionLeading: Icon(
      Icons.verified_user_rounded,
      color: Color(0xFF70964F),
      size: 15,
    ),
    padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
    headerMinHeight: 24,
    childSpacing: 2,
    child: Row(
      children: [
        Expanded(
          child: _PaymentMethodCard(
            title: '微信支付',
            asset: memberWechatPayAsset,
            color: const Color(0xFF20B65A),
            selected: selected == PaymentChannel.wechatPay,
            onTap: () => onSelect(PaymentChannel.wechatPay),
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: _PaymentMethodCard(
            title: '支付宝支付',
            asset: memberAlipayAsset,
            color: const Color(0xFF1677FF),
            selected: selected == PaymentChannel.alipay,
            onTap: () => onSelect(PaymentChannel.alipay),
          ),
        ),
      ],
    ),
  );
}

class _PaymentMethodCard extends StatelessWidget {
  const _PaymentMethodCard({
    required this.title,
    required this.asset,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String asset;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    selected: selected,
    button: true,
    label: title,
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        key: ValueKey(
          'membership-payment-${title == '微信支付' ? 'wechat' : 'alipay'}',
        ),
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? Color.alphaBlend(memberGreenFor(context).withValues(alpha: .14), memberSurfaceFor(context)) : memberSurfaceFor(context),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? memberGreenFor(context) : memberCardBorderFor(context),
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 29,
                height: 29,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: PaymentBrandIcon(
                  brand: asset == memberWechatPayAsset
                      ? PaymentBrand.wechat
                      : PaymentBrand.alipay,
                  size: 29,
                  fallbackColor: color,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    title,
                    style: TextStyle(
                      color: memberInkFor(context),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              Icon(
                selected ? Icons.check_circle_rounded : Icons.circle_outlined,
                color: selected ? memberGreenFor(context) : memberMutedFor(context),
                size: 18,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class MemberBottomPayBar extends StatelessWidget {
  const MemberBottomPayBar({
    super.key,
    required this.product,
    required this.isPaying,
    required this.onPay,
    required this.onAgreement,
  });

  final MembershipProduct? product;
  final bool isPaying;
  final VoidCallback onPay;
  final VoidCallback onAgreement;

  @override
  Widget build(BuildContext context) {
    final price = product == null
        ? '--'
        : MembershipProduct.money(product!.priceInCents);
    return Material(
      color: Colors.white,
      elevation: 10,
      shadowColor: const Color(0x1A20221F),
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  RichText(
                    key: const ValueKey('membership-pay-amount'),
                    text: TextSpan(
                      style: DefaultTextStyle.of(context).style,
                      children: [
                        const TextSpan(
                          text: '实付金额  ',
                          style: TextStyle(
                            color: memberInkFor(context),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const TextSpan(
                          text: '¥',
                          style: TextStyle(fontSize: 15),
                        ),
                        TextSpan(
                          text: price,
                          style: TextStyle(
                            color: memberGreenFor(context),
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        '开通即表示同意',
                        style: TextStyle(color: memberMutedFor(context), fontSize: 9),
                      ),
                      InkWell(
                        onTap: onAgreement,
                        child: Text(
                          '《会员服务协议》',
                          style: TextStyle(
                            color: memberGreenFor(context),
                            fontSize: 9,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 132,
              height: 46,
              child: FilledButton(
                key: const ValueKey('membership-pay-button'),
                onPressed: product == null || isPaying ? null : onPay,
                style: FilledButton.styleFrom(
                  backgroundColor: memberGreenFor(context),
                  disabledBackgroundColor: context.appDivider,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                child: isPaying
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        '立即支付',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MemberSectionCard extends StatelessWidget {
  const MemberSectionCard({
    super.key,
    required this.title,
    required this.action,
    required this.onAction,
    required this.child,
    this.leading,
    this.actionLeading,
    this.padding = const EdgeInsets.fromLTRB(14, 13, 14, 14),
    this.headerMinHeight = 32,
    this.childSpacing = 8,
  });

  final String title;
  final String action;
  final VoidCallback? onAction;
  final Widget child;
  final Widget? leading;
  final Widget? actionLeading;
  final EdgeInsetsGeometry padding;
  final double headerMinHeight;
  final double childSpacing;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: padding,
    decoration: BoxDecoration(
      color: memberSurfaceFor(context),
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: memberCardBorderFor(context)),
      boxShadow: memberCardShadowsFor(context),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ConstrainedBox(
          constraints: BoxConstraints(minHeight: headerMinHeight),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (leading != null) ...[leading!, const SizedBox(width: 7)],
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: memberInkFor(context),
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              if (onAction != null)
                TextButton(
                  onPressed: onAction,
                  style: TextButton.styleFrom(
                    foregroundColor: memberGreenFor(context),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    minimumSize: Size(0, headerMinHeight),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(action, style: TextStyle(fontSize: 11)),
                      Icon(Icons.chevron_right_rounded, size: 17),
                    ],
                  ),
                ),
              if (onAction == null)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (actionLeading != null) ...[
                      actionLeading!,
                      const SizedBox(width: 4),
                    ],
                    Text(
                      action,
                      style: TextStyle(color: memberMutedFor(context), fontSize: 10),
                    ),
                  ],
                ),
            ],
          ),
        ),
        SizedBox(height: childSpacing),
        child,
      ],
    ),
  );
}

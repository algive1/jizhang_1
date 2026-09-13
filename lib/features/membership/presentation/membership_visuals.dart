import 'package:flutter/material.dart';

import '../data/membership_catalog.dart';

const memberGreen = Color(0xFF557D2D);
const memberInk = Color(0xFF101820);
const memberMuted = Color(0xFF85878D);
const memberAssets = 'assets/images/membership/';

class MembershipHero extends StatelessWidget {
  const MembershipHero({super.key});
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final width = box.maxWidth;
      final scale = MediaQuery.textScalerOf(context).scale(1);
      final height = width * .44 + (scale > 1.2 ? 65 : 20);
      return Container(
        height: height,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: const Color(0xFFF6F6EB),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Stack(
          children: [
            Positioned(
              right: -8,
              bottom: -2,
              width: width * .9,
              height: height + 25,
              child: IgnorePointer(
                child: Image.asset(
                  '${memberAssets}membership-hero-scene.webp',
                  fit: BoxFit.fill,
                ),
              ),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFFF8F8EE),
                      const Color(0xFFF8F8EE).withValues(alpha: 0),
                    ],
                    stops: const [.30, .72],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 10, 0, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '好好记账\n让生活更从容',
                    style: TextStyle(
                      color: const Color(0xFF244811),
                      fontSize: width * .064,
                      height: 1.14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '成为会员，解锁更多高级功能',
                    style: TextStyle(
                      color: const Color(0xFF777E70),
                      fontSize: width * .031,
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: width * .59,
                    child: Row(
                      children: [
                        _value(Icons.workspace_premium, '更完整\n的记账体验', width),
                        _value(Icons.favorite, '数据更安全\n更放心', width),
                        _value(Icons.bar_chart_rounded, '让生活\n更清晰', width),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              right: width * .047,
              bottom: height * .14,
              width: width * .21,
              child: Transform.rotate(
                angle: -.05,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '记录生活',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: const Color(0xFF50543C),
                        fontSize: width * .022,
                        height: 1.4,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    Text(
                      '遇见更好的自己',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: const Color(0xFF50543C),
                        fontSize: width * .019,
                        height: 1.4,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    Icon(
                      Icons.favorite_border,
                      size: width * .026,
                      color: const Color(0xFF50543C),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
  Widget _value(IconData icon, String label, double width) => Expanded(
    child: Row(
      children: [
        Container(
          width: width * .061,
          height: width * .061,
          decoration: const BoxDecoration(
            color: Color(0xFFFFFBEE),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: const Color(0xFFBD8A3B), size: width * .04),
        ),
        const SizedBox(width: 3),
        Flexible(
          child: Text(
            label,
            style: TextStyle(
              fontSize: width * .019,
              color: memberInk,
              height: 1.3,
            ),
          ),
        ),
      ],
    ),
  );
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
  final bool selected, renewal;
  final VoidCallback onSelect, onPurchase;
  @override
  Widget build(BuildContext context) {
    final saving = monthlyPrice * product.months - product.priceInCents;
    final roundedMonthlyCents =
        (product.priceInCents / product.months / 100).round() * 100;
    return Semantics(
      selected: selected,
      child: GestureDetector(
        key: ValueKey('membership-plan-${product.id}'),
        onTap: onSelect,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 6),
              padding: const EdgeInsets.fromLTRB(7, 7, 7, 8),
              decoration: BoxDecoration(
                color: selected
                    ? const Color(0xFFF3F8EB)
                    : const Color(0xFFFEF8ED),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: selected
                      ? const Color(0xFF88A960)
                      : Colors.transparent,
                ),
              ),
              child: Column(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: product.months == 12
                          ? const Color(0xFFF9E5C1)
                          : const Color(0xFFE5EED2),
                    ),
                    child: Icon(
                      product.months == 1 ? Icons.eco : Icons.workspace_premium,
                      color: product.months == 12
                          ? const Color(0xFFB38A3F)
                          : memberGreen,
                      size: 25,
                    ),
                  ),
                  const SizedBox(height: 4),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      product.title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: memberInk,
                      ),
                    ),
                  ),
                  const SizedBox(height: 3),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      product.description,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 10,
                        height: 1.35,
                        color: Color(0xFF66675F),
                      ),
                    ),
                  ),
                  const SizedBox(height: 7),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text.rich(
                      TextSpan(
                        children: [
                          const TextSpan(
                            text: '¥',
                            style: TextStyle(fontSize: 15),
                          ),
                          TextSpan(
                            text: MembershipProduct.money(product.priceInCents),
                            style: const TextStyle(
                              fontSize: 29,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          TextSpan(
                            text: ' /${product.unit}',
                            style: const TextStyle(fontSize: 13),
                          ),
                        ],
                      ),
                      style: const TextStyle(color: memberInk),
                    ),
                  ),
                  const SizedBox(height: 2),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text:
                                '¥${MembershipProduct.money(roundedMonthlyCents)}/月',
                          ),
                          if (saving > 0)
                            TextSpan(
                              text: ' 立省 ¥${MembershipProduct.money(saving)}',
                              style: TextStyle(
                                color: selected ? memberGreen : memberMuted,
                              ),
                            ),
                        ],
                      ),
                      style: const TextStyle(
                        fontSize: 10,
                        color: Color(0xFF777B7B),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    height: 30,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: selected
                            ? memberGreen
                            : const Color(0xFFF9E2BC),
                        foregroundColor: selected
                            ? Colors.white
                            : const Color(0xFF613D11),
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: onPurchase,
                      child: FittedBox(
                        child: Text(
                          renewal ? '立即续费' : '立即开通',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (product.recommended)
              Positioned(
                top: 0,
                right: 9,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: memberGreen,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: const Text(
                    '推荐',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
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

class MembershipSection extends StatelessWidget {
  const MembershipSection({
    super.key,
    required this.title,
    required this.action,
    required this.onAction,
    required this.child,
  });
  final String title, action;
  final VoidCallback onAction;
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(top: 7),
    padding: const EdgeInsets.fromLTRB(11, 5, 11, 9),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: .92),
      borderRadius: BorderRadius.circular(15),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  color: memberInk,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            TextButton(
              style: TextButton.styleFrom(
                padding: const EdgeInsets.only(left: 4),
                minimumSize: const Size(0, 34),
                foregroundColor: memberMuted,
              ),
              onPressed: onAction,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(action, style: const TextStyle(fontSize: 10)),
                  const Icon(Icons.chevron_right, size: 15),
                ],
              ),
            ),
          ],
        ),
        child,
      ],
    ),
  );
}

import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../auto_bookkeeping_strategy.dart';

const autoInk = Color(0xFF0D1429);
const autoMuted = Color(0xFF74808F);
const autoGreen = Color(0xFF00C980);
const autoGold = Color(0xFF9A5A1C);
TextStyle autoText(
  double size, {
  FontWeight weight = FontWeight.w400,
  Color color = autoInk,
}) => TextStyle(
  fontSize: size,
  height: 1.25,
  fontWeight: weight,
  color: color,
  letterSpacing: 0,
  fontFeatures: const [ui.FontFeature.tabularFigures()],
);

class AutoBookkeepingBackground extends StatelessWidget {
  const AutoBookkeepingBackground({super.key});
  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: Stack(
      fit: StackFit.expand,
      children: [
        ImageFiltered(
          imageFilter: ui.ImageFilter.blur(sigmaX: 3.5, sigmaY: 3.5),
          child: Image.asset(
            'assets/images/liquid_glass_profile_background.webp',
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
            cacheWidth:
                (MediaQuery.sizeOf(context).width *
                        MediaQuery.devicePixelRatioOf(context))
                    .ceil(),
          ),
        ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0x00FFF4E6), Color(0x35FFF4E6), Color(0xC5F5DABB)],
              stops: [0, .3, 1],
            ),
          ),
        ),
      ],
    ),
  );
}

class AutoSurface extends StatelessWidget {
  const AutoSurface({
    required this.child,
    super.key,
    this.radius = 13,
    this.opacity = .86,
    this.padding = EdgeInsets.zero,
    this.borderColor,
    this.gradient,
    this.blur = true,
  });
  final Widget child;
  final double radius, opacity;
  final EdgeInsetsGeometry padding;
  final Color? borderColor;
  final Gradient? gradient;
  final bool blur;
  @override
  Widget build(BuildContext context) {
    final panel = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: gradient == null
            ? Colors.white.withValues(alpha: opacity)
            : null,
        gradient: gradient,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: borderColor ?? Colors.white.withValues(alpha: .9),
          width: .8,
        ),
      ),
      child: child,
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: blur
            ? const [
                BoxShadow(
                  color: Color(0x125D3921),
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: blur
            ? BackdropFilter.grouped(
                filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: panel,
              )
            : panel,
      ),
    );
  }
}

class AutoSection extends StatelessWidget {
  const AutoSection({
    required this.title,
    required this.child,
    super.key,
    this.more,
    this.onMore,
    this.headerPadding = 6,
    this.bottomPadding = 6,
  });
  final String title;
  final Widget child;
  final String? more;
  final VoidCallback? onMore;
  final double headerPadding, bottomPadding;
  @override
  Widget build(BuildContext context) => AutoSurface(
    padding: EdgeInsets.fromLTRB(6, 0, 6, bottomPadding),
    child: Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, right: 2),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 27),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: autoText(14, weight: FontWeight.w800),
                  ),
                ),
                if (more != null)
                  InkWell(
                    onTap: onMore,
                    borderRadius: BorderRadius.circular(10),
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: headerPadding),
                      child: Row(
                        children: [
                          Text(
                            more!,
                            style: autoText(
                              9.5,
                              weight: FontWeight.w600,
                              color: autoMuted,
                            ),
                          ),
                          const SizedBox(width: 3),
                          const Icon(
                            Icons.chevron_right_rounded,
                            size: 16,
                            color: autoMuted,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        child,
      ],
    ),
  );
}

class AutoBookkeepingHero extends StatelessWidget {
  const AutoBookkeepingHero({
    required this.enabled,
    required this.healthy,
    required this.onChanged,
    this.busy = false,
    this.connecting = false,
    this.statusMessage,
    super.key,
  });
  final bool enabled, healthy;
  final bool busy, connecting;
  final String? statusMessage;
  final ValueChanged<bool>? onChanged;
  @override
  Widget build(BuildContext context) => Stack(
    clipBehavior: Clip.none,
    children: [
      AutoSurface(
        radius: 18,
        opacity: .73,
        padding: const EdgeInsets.fromLTRB(14, 15, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  label: '自动记账开关',
                  toggled: enabled,
                  enabled: onChanged != null,
                  child: GestureDetector(
                    key: const ValueKey('autobookkeeping-toggle'),
                    onTap: onChanged == null
                        ? null
                        : () => onChanged!(!enabled),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: 54,
                      height: 32,
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: enabled ? autoGreen : const Color(0xFFA9B3BA),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white, width: 1.1),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x185C431E),
                            blurRadius: 6,
                            offset: Offset(0, 3),
                          ),
                        ],
                      ),
                      child: AnimatedAlign(
                        duration: const Duration(milliseconds: 180),
                        alignment: enabled
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: DecoratedBox(
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                          ),
                          child: SizedBox(
                            width: 25,
                            height: 25,
                            child: busy
                                ? const Padding(
                                    padding: EdgeInsets.all(5),
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: autoGreen,
                                    ),
                                  )
                                : null,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          busy
                              ? '正在保存设置…'
                              : enabled
                              ? '自动记账已开启'
                              : '自动记账未开启',
                          style: autoText(16, weight: FontWeight.w800),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          connecting
                              ? '正在连接服务，可随时关闭'
                              : statusMessage ??
                                    (enabled && !healthy
                                        ? '权限待检测，点击一键检测'
                                        : '检测支付通知并自动生成待确认账单'),
                          style: autoText(9.5, color: const Color(0xFF7E6954)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                for (final item in [
                  (Icons.verified_user_outlined, '安全稳定'),
                  (Icons.bolt_rounded, '实时识别'),
                  (Icons.workspace_premium_rounded, '让记账更轻松'),
                ]) ...[
                  if (item.$1 == Icons.workspace_premium_rounded)
                    const _CrownGlyph(size: 14, color: Color(0xFFD18B28))
                  else
                    Icon(item.$1, size: 14, color: const Color(0xFFD18B28)),
                  const SizedBox(width: 5),
                  Text(
                    item.$2,
                    style: autoText(9, color: const Color(0xFF8B6640)),
                  ),
                  if (item.$2 != '让记账更轻松')
                    Container(
                      width: .5,
                      height: 12,
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      color: const Color(0xFFCFC4B4),
                    ),
                ],
              ],
            ),
          ],
        ),
      ),
      Positioned(
        right: -8,
        top: -16,
        bottom: 0,
        width: 160,
        child: IgnorePointer(
          child: Image.asset(
            'assets/images/autobookkeeping/hero-robot.png',
            fit: BoxFit.contain,
            alignment: Alignment.bottomRight,
            cacheWidth: (160 * MediaQuery.devicePixelRatioOf(context)).ceil(),
          ),
        ),
      ),
    ],
  );
}

const autoSources = [
  ('微信', 'assets/images/membership/wechat-pay.png'),
  ('支付宝', 'assets/images/membership/alipay.png'),
  ('美团', 'assets/images/autobookkeeping/meituan.png'),
  ('抖音', 'assets/images/autobookkeeping/douyin.png'),
  ('拼多多', 'assets/images/autobookkeeping/pinduoduo.png'),
  ('京东', 'assets/images/autobookkeeping/jd.png'),
];

class AutoSourceIcon extends StatelessWidget {
  const AutoSourceIcon(this.path, {super.key, this.size = 32});
  final String path;
  final double size;
  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(size * .29),
      boxShadow: const [
        BoxShadow(
          color: Color(0x1800C980),
          blurRadius: 5,
          offset: Offset(0, 2),
        ),
      ],
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(size * .29),
      child: OverflowBox(
        maxWidth: size * (path.contains('/membership/') ? 1.32 : 1),
        maxHeight: size * (path.contains('/membership/') ? 1.32 : 1),
        child: Image.asset(
          path,
          width: size * (path.contains('/membership/') ? 1.32 : 1),
          height: size * (path.contains('/membership/') ? 1.32 : 1),
          fit: BoxFit.cover,
        ),
      ),
    ),
  );
}

class RecognitionSources extends StatelessWidget {
  const RecognitionSources({
    required this.healthy,
    required this.onCheck,
    super.key,
  });
  final bool healthy;
  final VoidCallback onCheck;
  @override
  Widget build(BuildContext context) => AutoSection(
    title: '识别来源',
    more: '管理授权',
    onMore: onCheck,
    child: SingleChildScrollView(
      key: const ValueKey('autobookkeeping-sources'),
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var i = 0; i < autoSources.length; i++)
            Padding(
              padding: EdgeInsets.only(
                right: i == autoSources.length - 1 ? 0 : 6,
              ),
              child: SizedBox(
                width: 84,
                child: AutoSurface(
                  radius: 15,
                  blur: false,
                  opacity: .86,
                  child: InkWell(
                    onTap: onCheck,
                    borderRadius: BorderRadius.circular(15),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Column(
                        children: [
                          AutoSourceIcon(autoSources[i].$2),
                          const SizedBox(height: 5),
                          Text(
                            autoSources[i].$1,
                            style: autoText(11, weight: FontWeight.w700),
                          ),
                          const SizedBox(height: 3),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (healthy) ...[
                                const Icon(
                                  Icons.check_circle_rounded,
                                  size: 12,
                                  color: autoGreen,
                                ),
                                const SizedBox(width: 4),
                              ],
                              Text(
                                healthy ? '已开启' : '已关闭',
                                style: autoText(
                                  9.5,
                                  weight: FontWeight.w600,
                                  color: healthy ? autoGreen : autoMuted,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

class RecognitionRules extends StatelessWidget {
  const RecognitionRules({
    required this.healthy,
    required this.onCheck,
    super.key,
  });
  final bool healthy;
  final VoidCallback onCheck;
  @override
  Widget build(BuildContext context) => AutoSection(
    title: '智能识别规则',
    more: '更多设置',
    onMore: onCheck,
    child: AutoSurface(
      radius: 15,
      blur: false,
      opacity: .83,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Column(
        children: [
          for (final (i, item) in [
            (
              Icons.storage_rounded,
              '自动分类',
              '根据商户和金额智能分类',
              const Color(0xFF02D08A),
            ),
            (
              Icons.storefront_rounded,
              '商户识别',
              '识别商户名称，匹配常用商家',
              const Color(0xFFFF8825),
            ),
            (
              Icons.currency_yen_rounded,
              '金额提取',
              '自动提取交易金额',
              const Color(0xFF359BFF),
            ),
            (
              Icons.link_rounded,
              '支付方式识别',
              '识别微信、支付宝、银行卡等',
              const Color(0xFF9656FF),
            ),
          ].indexed)
            InkWell(
              onTap: onCheck,
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color.lerp(item.$4, Colors.white, .28)!,
                          item.$4,
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: item.$4.withValues(alpha: .13),
                          blurRadius: 5,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: item.$1 == Icons.storage_rounded
                        ? const Center(
                            child: SizedBox(
                              width: 23,
                              height: 23,
                              child: CustomPaint(painter: _DatabasePainter()),
                            ),
                          )
                        : item.$1 == Icons.link_rounded
                        ? Transform.rotate(
                            angle: -.785398,
                            child: Icon(item.$1, size: 23, color: Colors.white),
                          )
                        : Icon(item.$1, size: 23, color: Colors.white),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 42),
                      decoration: BoxDecoration(
                        border: i < 3
                            ? const Border(
                                bottom: BorderSide(
                                  color: Color(0xFFECECF0),
                                  width: .5,
                                ),
                              )
                            : null,
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 5.5),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.$2,
                                  style: autoText(12, weight: FontWeight.w700),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  item.$3,
                                  style: autoText(9.5, color: autoMuted),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            healthy ? '已开启' : '已关闭',
                            style: autoText(
                              10,
                              weight: FontWeight.w600,
                              color: healthy ? autoGreen : autoMuted,
                            ),
                          ),
                          const SizedBox(width: 7),
                          const Icon(
                            Icons.chevron_right_rounded,
                            size: 17,
                            color: autoMuted,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    ),
  );
}

class AutoConfirmationStrategies extends StatelessWidget {
  const AutoConfirmationStrategies({
    required this.value,
    required this.onSelected,
    super.key,
  });
  final AutoBookkeepingStrategy value;
  final ValueChanged<AutoBookkeepingStrategy>? onSelected;
  @override
  Widget build(BuildContext context) => AutoSection(
    title: '自动确认策略',
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (i, strategy) in AutoBookkeepingStrategy.values.indexed) ...[
          if (i > 0) const SizedBox(width: 6),
          Expanded(
            child: AutoSurface(
              radius: 11,
              blur: false,
              opacity: .84,
              borderColor: value == strategy ? const Color(0xFFFFBD39) : null,
              gradient: value == strategy
                  ? const LinearGradient(
                      colors: [Color(0xFFFFFDEA), Color(0xFFFFF5D9)],
                    )
                  : null,
              child: InkWell(
                onTap: onSelected == null ? null : () => onSelected!(strategy),
                borderRadius: BorderRadius.circular(11),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(7, 8, 6, 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (i == 1)
                        const _CrownGlyph(size: 23, color: Color(0xFFE79E2C))
                      else
                        Icon(
                          [
                            Icons.eco_rounded,
                            Icons.workspace_premium_rounded,
                            Icons.bolt_rounded,
                          ][i],
                          size: 23,
                          color: [
                            autoGreen,
                            const Color(0xFFE79E2C),
                            const Color(0xFF379BFF),
                          ][i],
                        ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    strategy.label,
                                    style: autoText(
                                      10.5,
                                      weight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                Icon(
                                  value == strategy
                                      ? Icons.radio_button_checked
                                      : Icons.radio_button_unchecked,
                                  size: 13,
                                  color: value == strategy
                                      ? const Color(0xFFB97B23)
                                      : const Color(0xFF9BA4B0),
                                ),
                              ],
                            ),
                            const SizedBox(height: 5),
                            Text(
                              strategy.description,
                              style: autoText(8.5, color: autoMuted),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    ),
  );
}

class RecognitionExample extends StatelessWidget {
  const RecognitionExample({required this.onMore, super.key});
  final VoidCallback onMore;
  @override
  Widget build(BuildContext context) => AutoSection(
    title: '识别示例',
    more: '查看更多示例',
    onMore: onMore,
    child: Row(
      children: [
        Expanded(
          child: AutoSurface(
            radius: 11,
            blur: false,
            opacity: .85,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            child: Row(
              children: [
                const AutoSourceIcon('assets/images/membership/wechat-pay.png'),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '微信支付',
                        style: autoText(10.5, weight: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      Text('星巴克咖啡', style: autoText(9.5, color: autoMuted)),
                      Text(
                        '¥ 32.00',
                        style: autoText(11, weight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 6),
          child: Icon(
            Icons.arrow_forward_rounded,
            size: 14,
            color: Color(0xFF999DA3),
          ),
        ),
        Expanded(
          child: AutoSurface(
            radius: 11,
            blur: false,
            opacity: .85,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact =
                    constraints.maxWidth <
                    130 * MediaQuery.textScalerOf(context).scale(1);
                return Row(
                  children: [
                    Container(
                      width: 31,
                      height: 31,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF6DE),
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: const Icon(
                        Icons.coffee_rounded,
                        color: Color(0xFFCA8122),
                        size: 23,
                      ),
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '餐饮美食',
                            style: autoText(10, weight: FontWeight.w700),
                          ),
                          const SizedBox(height: 4),
                          Text('星巴克', style: autoText(9.5, color: autoMuted)),
                          if (compact)
                            Text(
                              '¥ 32.00',
                              style: autoText(11, weight: FontWeight.w700),
                            ),
                        ],
                      ),
                    ),
                    if (!compact)
                      Text(
                        '¥ 32.00',
                        style: autoText(11, weight: FontWeight.w700),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    ),
  );
}

class _CrownGlyph extends StatelessWidget {
  const _CrownGlyph({required this.size, required this.color});
  final double size;
  final Color color;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: size,
    height: size,
    child: CustomPaint(painter: _CrownPainter(color)),
  );
}

class _CrownPainter extends CustomPainter {
  const _CrownPainter(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height, paint = Paint()..color = color;
    final path = Path()
      ..moveTo(w * .06, h * .32)
      ..lineTo(w * .27, h * .58)
      ..lineTo(w * .5, h * .16)
      ..lineTo(w * .73, h * .58)
      ..lineTo(w * .94, h * .32)
      ..lineTo(w * .8, h * .83)
      ..lineTo(w * .2, h * .83)
      ..close();
    canvas.drawPath(path, paint);
    for (final point in [
      Offset(w * .06, h * .29),
      Offset(w * .5, h * .12),
      Offset(w * .94, h * .29),
    ]) {
      canvas.drawCircle(point, w * .06, paint);
    }
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * .2, h * .9, w * .6, h * .07),
        Radius.circular(w * .035),
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(_CrownPainter oldDelegate) => oldDelegate.color != color;
}

class _DatabasePainter extends CustomPainter {
  const _DatabasePainter();
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white;
    final w = size.width, h = size.height;
    for (final y in [.37, .65]) {
      final path = Path()
        ..moveTo(w * .16, h * y)
        ..quadraticBezierTo(w * .5, h * (y + .2), w * .84, h * y)
        ..lineTo(w * .84, h * (y + .15))
        ..quadraticBezierTo(w * .5, h * (y + .38), w * .16, h * (y + .15))
        ..close();
      canvas.drawPath(path, paint);
    }
    canvas.drawOval(Rect.fromLTWH(w * .16, h * .1, w * .68, h * .3), paint);
  }

  @override
  bool shouldRepaint(_DatabasePainter oldDelegate) => false;
}

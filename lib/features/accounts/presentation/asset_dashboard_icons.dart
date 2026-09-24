import 'package:flutter/material.dart';

import '../../../core/models/account.dart';
import '../../../core/widgets/payment_brand_icon.dart';

enum AssetGlyph {
  wallet,
  bank,
  wechat,
  alipay,
  house,
  card,
  tag,
  transfer,
  pie,
  growth,
}

AssetGlyph accountGlyph(Account account) => switch (account.type) {
  AccountType.cash => AssetGlyph.wallet,
  AccountType.wechat => AssetGlyph.wechat,
  AccountType.debitCard || AccountType.liability => AssetGlyph.bank,
  AccountType.creditCard => AssetGlyph.card,
  AccountType.alipay => AssetGlyph.alipay,
  AccountType.other => AssetGlyph.house,
};

class AssetVectorIcon extends StatelessWidget {
  const AssetVectorIcon(
    this.glyph, {
    this.size = 22,
    this.color = const Color(0xff436b28),
    this.tile = false,
    super.key,
  });
  final AssetGlyph glyph;
  final double size;
  final Color color;
  final bool tile;
  @override
  Widget build(BuildContext context) {
    final brand = switch (glyph) {
      AssetGlyph.wechat => PaymentBrand.wechat,
      AssetGlyph.alipay => PaymentBrand.alipay,
      _ => null,
    };
    final base = switch (glyph) {
      AssetGlyph.bank || AssetGlyph.card => const Color(0xffff8073),
      AssetGlyph.wechat => const Color(0xff63aa8c),
      AssetGlyph.alipay => const Color(0xff289eff),
      AssetGlyph.house => const Color(0xffffa05f),
      _ => const Color(0xff63aa8c),
    };
    if (brand != null) {
      if (!tile) return PaymentBrandIcon(brand: brand, size: size);
      return Container(
        width: size,
        height: size,
        padding: EdgeInsets.all(size * .18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(size * .25),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color.lerp(base, Colors.white, .18)!, base],
          ),
          border: Border.all(
            color: Colors.white.withValues(alpha: .6),
            width: .6,
          ),
        ),
        child: PaymentBrandIcon(brand: brand, size: size * .64),
      );
    }
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(tile ? size * .18 : 0),
      decoration: tile
          ? BoxDecoration(
              borderRadius: BorderRadius.circular(size * .25),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color.lerp(base, Colors.white, .18)!, base],
              ),
              border: Border.all(
                color: Colors.white.withValues(alpha: .6),
                width: .6,
              ),
            )
          : null,
      child: CustomPaint(
        painter: _GlyphPainter(glyph, tile ? Colors.white : color),
      ),
    );
  }
}

class _GlyphPainter extends CustomPainter {
  _GlyphPainter(this.glyph, this.color);
  final AssetGlyph glyph;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 24, size.height / 24);
    final pen = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    void path(List<Offset> points, {bool close = false}) {
      final p = Path()..addPolygon(points, close);
      canvas.drawPath(p, pen);
    }

    void line(double x, double y, double xx, double yy) =>
        canvas.drawLine(Offset(x, y), Offset(xx, yy), pen);
    switch (glyph) {
      case AssetGlyph.wallet || AssetGlyph.wechat:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(3, 6, 18, 15),
            const Radius.circular(3),
          ),
          pen,
        );
        path(const [Offset(5, 6), Offset(17, 3), Offset(19, 6)]);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(15, 11, 7, 6),
            const Radius.circular(2),
          ),
          pen,
        );
        canvas.drawCircle(const Offset(18, 14), .7, Paint()..color = color);
      case AssetGlyph.bank:
        path(const [Offset(2, 8), Offset(12, 2), Offset(22, 8)], close: true);
        for (final x in [5.0, 12.0, 19.0]) {
          line(x, 11, x, 19);
        }
        line(3, 21, 21, 21);
        line(2, 23, 22, 23);
      case AssetGlyph.house:
        path(const [Offset(2, 11), Offset(12, 2), Offset(22, 11)]);
        path(const [
          Offset(5, 10),
          Offset(5, 22),
          Offset(10, 22),
          Offset(10, 15),
          Offset(14, 15),
          Offset(14, 22),
          Offset(19, 22),
          Offset(19, 10),
        ]);
      case AssetGlyph.card:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(2, 5, 20, 15),
            const Radius.circular(3),
          ),
          pen,
        );
        line(2, 10, 22, 10);
        line(5, 15, 9, 15);
        line(12, 15, 14, 15);
      case AssetGlyph.alipay:
        line(5, 5, 20, 5);
        line(12, 2, 12, 10);
        line(4, 10, 18, 10);
        canvas.drawPath(
          Path()
            ..moveTo(17, 10)
            ..cubicTo(14, 21, 3, 24, 2, 17)
            ..cubicTo(1, 9, 16, 16, 23, 19),
          pen,
        );
      case AssetGlyph.tag:
        path(const [
          Offset(3, 3),
          Offset(12, 3),
          Offset(22, 13),
          Offset(13, 22),
          Offset(3, 12),
        ], close: true);
        canvas.drawCircle(const Offset(7, 7), 1, pen);
      case AssetGlyph.transfer:
        path(const [Offset(3, 8), Offset(21, 8), Offset(16, 3)]);
        path(const [Offset(21, 16), Offset(3, 16), Offset(8, 21)]);
      case AssetGlyph.pie:
        canvas.drawArc(const Rect.fromLTWH(2, 2, 20, 20), 0, 4.71, false, pen);
        path(const [Offset(12, 2), Offset(12, 12), Offset(22, 12)]);
        canvas.drawArc(
          const Rect.fromLTWH(2, 2, 20, 20),
          -1.57,
          1.57,
          true,
          pen,
        );
      case AssetGlyph.growth:
        // A rising trend line with three markers. Deliberately not a K-line /
        // candlestick: 投资管理 is a personal-asset view, not a trading app.
        path(const [
          Offset(3, 18),
          Offset(9, 12),
          Offset(14, 15),
          Offset(21, 6),
        ]);
        line(21, 6, 15.5, 6);
        line(21, 6, 21, 11.5);
        for (final point in const [
          Offset(3, 18),
          Offset(9, 12),
          Offset(14, 15),
          Offset(21, 6),
        ])
          canvas.drawCircle(point, 1.1, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(covariant _GlyphPainter old) =>
      old.glyph != glyph || old.color != color;
}

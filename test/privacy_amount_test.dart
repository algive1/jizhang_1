import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jizhang_app/core/widgets/privacy_amount.dart';

void main() {
  testWidgets(
    'hidden amount uses a small fixed mask and keeps its line height',
    (tester) async {
      const amountStyle = TextStyle(
        color: Colors.green,
        fontSize: 48,
        fontWeight: FontWeight.w700,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PrivacyAmount(
                  text: '¥12,680.00',
                  style: amountStyle,
                  hidden: false,
                ),
                PrivacyAmount(
                  text: '¥12,680.00',
                  style: amountStyle,
                  hidden: true,
                ),
              ],
            ),
          ),
        ),
      );

      final visible = tester.getRect(find.text('¥12,680.00'));
      final maskFinder = find.text(privacyAmountMask);
      final mask = tester.widget<Text>(maskFinder);
      expect(mask.style?.fontSize, 13);
      expect(mask.style?.letterSpacing, 3);
      expect(mask.textScaler, TextScaler.noScaling);
      expect(tester.getRect(maskFinder).height, lessThan(visible.height));
      expect(
        tester.getSize(find.byType(PrivacyAmount).at(1)).height,
        visible.height,
      );
    },
  );
}

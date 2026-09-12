import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jizhang_app/core/widgets/money_text.dart';

void main() {
  testWidgets('money text renders cents at half the whole amount size', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: MoneyText(123.45, style: TextStyle(fontSize: 20))),
      ),
    );

    final richText = tester.widget<RichText>(find.byType(RichText));
    final root = richText.text as TextSpan;
    final fraction = _findSpan(root, '45');
    expect(root.toPlainText(), '¥123.45');
    expect(fraction, isNotNull);
    expect(fraction!.style?.fontSize, 10);
  });
}

TextSpan? _findSpan(InlineSpan span, String text) {
  if (span is TextSpan && span.text == text) return span;
  if (span is! TextSpan) return null;
  for (final child in span.children ?? const <InlineSpan>[]) {
    final match = _findSpan(child, text);
    if (match != null) return match;
  }
  return null;
}

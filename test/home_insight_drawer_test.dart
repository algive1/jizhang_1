import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jizhang_app/features/home/presentation/home_insight_drawer.dart';

void main() {
  testWidgets(
    'home insight drawer stays collapsed while insight is unavailable',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: HomeInsightDrawer(
                bookId: 'book-1',
                day: DateTime(2026, 9, 20),
                insight: null,
                available: true,
                onTap: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.byType(ErrorWidget), findsNothing);
      expect(find.text('值得关注'), findsNothing);
    },
  );
}

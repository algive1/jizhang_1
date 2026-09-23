import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jizhang_app/app/theme/app_theme.dart';
import 'package:jizhang_app/app/theme/app_theme_definition.dart';
import 'package:jizhang_app/core/widgets/app_card.dart';

void main() {
  testWidgets('content AppCard is opaque and does not blur its backdrop', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(BuiltInThemes.liquidGlass),
        home: const Scaffold(body: AppCard(child: Text('content'))),
      ),
    );
    await tester.pump();

    expect(find.byType(BackdropFilter), findsNothing);
  });

  testWidgets('frosted AppCard keeps the shared glass surface', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(BuiltInThemes.liquidGlass),
        home: const Scaffold(
          body: AppCard(
            material: AppCardMaterial.frosted,
            child: Text('frosted'),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(BackdropFilter), findsOneWidget);
  });
}

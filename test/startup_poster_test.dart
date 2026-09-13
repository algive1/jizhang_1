import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jizhang_app/core/constants/app_assets.dart';
import 'package:jizhang_app/core/widgets/startup_poster.dart';

void main() {
  testWidgets('fills narrow phone layouts without distorting the poster', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const MaterialApp(home: StartupPoster()));

    final image = tester.widget<Image>(find.byType(Image));
    expect(image.image, const AssetImage(AppAssets.startupPoster));
    expect(image.fit, BoxFit.cover);
    expect(tester.takeException(), isNull);
  });
}

import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:jizhang_app/app/theme/app_theme.dart';

/// Android parity for the reference app's iOS-style back swipe.
///
/// The gesture is not a separate widget: it is built into
/// `CupertinoRouteTransitionMixin.buildPageTransitions`, which
/// `CupertinoPageTransitionsBuilder` delegates to. So the theme switch below
/// is the whole feature, and these tests pin both halves of it — the builder
/// mapping and the behaviour a user actually performs.
///
/// The widget tests pin `ThemeData.platform` to Android (rather than flipping
/// the global `debugDefaultTargetPlatformOverride`) because the transitions
/// theme reads `ThemeData.platform`; the debug variable may not survive a test
/// body either way.
void main() {
  ThemeData androidTheme() =>
      AppTheme.light().copyWith(platform: TargetPlatform.android);

  test('android maps to the cupertino page transition', () {
    final builders = AppTheme.light().pageTransitionsTheme.builders;

    expect(
      builders[TargetPlatform.android],
      isA<CupertinoPageTransitionsBuilder>(),
    );
    // Everything else keeps Flutter's own default for that platform.
    expect(
      builders[TargetPlatform.iOS],
      isA<CupertinoPageTransitionsBuilder>(),
    );
    expect(
      builders[TargetPlatform.linux],
      isNot(isA<CupertinoPageTransitionsBuilder>()),
    );
  });

  testWidgets('edge swipe tracks the finger and pops the route', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(theme: androidTheme(), home: const _Launcher()),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('detail'), findsOneWidget);

    final restingLeft = tester.getTopLeft(find.text('detail'));

    // Starts inside the left edge strip (max(safe area, 20 logic pixels)).
    final gesture = await tester.startGesture(const Offset(4, 300));
    await gesture.moveBy(const Offset(180, 0));
    await tester.pump();

    final draggedLeft = tester.getTopLeft(find.text('detail'));
    expect(
      draggedLeft.dx - restingLeft.dx,
      greaterThan(100),
      reason: 'the page should follow the finger, not wait for the release',
    );

    await gesture.moveBy(const Offset(320, 0));
    await gesture.up();
    await tester.pumpAndSettle();

    expect(find.text('detail'), findsNothing);
    expect(find.text('open'), findsOneWidget);
  });

  testWidgets('a drag that starts mid-screen leaves the route alone', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(theme: androidTheme(), home: const _Launcher()),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.dragFrom(const Offset(200, 300), const Offset(600, 0));
    await tester.pumpAndSettle();

    expect(find.text('detail'), findsOneWidget);
  });

  testWidgets('fullscreen dialogs stay modal (no edge swipe)', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: androidTheme(),
        home: Scaffold(
          body: Center(
            child: Builder(
              builder: (context) => TextButton(
                onPressed: () => Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    fullscreenDialog: true,
                    builder: (_) =>
                        const Scaffold(body: Center(child: Text('quick-add'))),
                  ),
                ),
                child: const Text('open-dialog'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open-dialog'));
    await tester.pumpAndSettle();

    await tester.dragFrom(const Offset(4, 300), const Offset(600, 0));
    await tester.pumpAndSettle();

    expect(find.text('quick-add'), findsOneWidget);
  });

  testWidgets('go_router pages inherit the edge swipe', (tester) async {
    final router = GoRouter(
      initialLocation: '/a',
      routes: [
        GoRoute(
          path: '/a',
          builder: (context, state) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => context.push('/b'),
                child: const Text('page-a'),
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/b',
          builder: (context, state) =>
              const Scaffold(body: Center(child: Text('page-b'))),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      MaterialApp.router(routerConfig: router, theme: androidTheme()),
    );

    await tester.tap(find.text('page-a'));
    await tester.pumpAndSettle();
    expect(find.text('page-b'), findsOneWidget);

    await tester.dragFrom(const Offset(4, 300), const Offset(600, 0));
    await tester.pumpAndSettle();

    expect(find.text('page-b'), findsNothing);
    expect(find.text('page-a'), findsOneWidget);
  });
}

class _Launcher extends StatelessWidget {
  const _Launcher();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: TextButton(
          onPressed: () => Navigator.of(context).push<void>(
            MaterialPageRoute<void>(
              builder: (_) =>
                  const Scaffold(body: Center(child: Text('detail'))),
            ),
          ),
          child: const Text('open'),
        ),
      ),
    );
  }
}

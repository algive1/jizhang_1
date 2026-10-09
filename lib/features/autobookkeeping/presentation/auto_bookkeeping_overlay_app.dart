import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/platform/app_notice_theme.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/platform/bookkeeping_refresh.dart';
import '../../settings/application/theme_controller.dart';
import '../auto_bookkeeping_pending.dart';
import 'auto_bookkeeping_confirm_page.dart';

/// Prepares the same confirmation component without starting the main app's maintenance work.
class AutoBookkeepingOverlayApp extends ConsumerStatefulWidget {
  const AutoBookkeepingOverlayApp({super.key});
  @override
  ConsumerState<AutoBookkeepingOverlayApp> createState() => _OverlayAppState();
}

class _OverlayAppState extends ConsumerState<AutoBookkeepingOverlayApp> {
  static const _channel = MethodChannel('jizhang/autobookkeeping_overlay');
  PendingAutoBookkeepingCandidate? _candidate;
  int _generation = 0;
  bool _prepared = false;
  late final BookkeepingRefreshBridge _refresh;

  @override
  void initState() {
    super.initState();
    _refresh = BookkeepingRefreshBridge(() async {
      await ref.read(databaseBootstrapProvider.future);
      refreshExternalBookkeepingData(ref.read(databaseProvider));
    })..start();
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'show' && call.arguments is Map) {
        if (!mounted) return;
        setState(() {
          _candidate = PendingAutoBookkeepingCandidate.fromMap(
            call.arguments as Map,
          );
          _generation++;
          _prepared = false;
        });
        unawaited(_refreshAppearance());
      } else if (call.method == 'hide' && mounted) {
        setState(() => _candidate = null);
      }
    });
    unawaited(_warmUp());
  }

  Future<void> _warmUp() async {
    // Readiness means the show handler is installed, not that every query finished.
    await _channel.invokeMethod<void>('engineReady');
    try {
      await ref.read(databaseBootstrapProvider.future);
      await Future.wait([
        ref.read(preferredThemeProvider.future),
        ref.read(brightnessModeProvider.future),
      ]);
    } on Object {
      // Let the review report its own loading error; keep the candidate in the durable inbox.
    }
  }

  Future<void> _refreshAppearance() async {
    try {
      await _refresh.check().timeout(const Duration(seconds: 2));
    } on Object {
      // An unavailable refresh channel must not block opening the review.
    }
    if (!mounted) return;
    ref.invalidate(preferredThemeProvider);
    ref.invalidate(brightnessModeProvider);
  }

  @override
  void dispose() {
    _channel.setMethodCallHandler(null);
    _refresh.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final candidate = _candidate;
    final appearance = ref.watch(effectiveThemeProvider);
    final dark =
        ref.watch(brightnessModeProvider).value == AppBrightnessPreference.dark;
    final theme = dark ? AppTheme.dark(appearance) : AppTheme.light(appearance);
    AppNoticeTheme.sync(theme);
    return MaterialApp(
      title: '好好记账',
      color: Colors.transparent,
      theme: theme.copyWith(
        scaffoldBackgroundColor: Colors.transparent,
        canvasColor: Colors.transparent,
      ),
      locale: const Locale('zh', 'CN'),
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      supportedLocales: const [Locale('zh', 'CN')],
      debugShowCheckedModeBanner: false,
      home: candidate == null
          ? const SizedBox.shrink()
          : AutoBookkeepingConfirmPage(
              key: ValueKey(_generation),
              overlayMode: true,
              initialCandidate: candidate,
              allowAutomaticSave: true,
              onReady: () {
                if (!mounted ||
                    _prepared ||
                    _candidate?.fingerprint != candidate.fingerprint)
                  return;
                setState(() => _prepared = true);
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted &&
                      _candidate?.fingerprint == candidate.fingerprint) {
                    unawaited(
                      _channel.invokeMethod<void>('prepared', {
                        'fingerprint': candidate.fingerprint,
                      }),
                    );
                  }
                });
              },
            ),
    );
  }
}

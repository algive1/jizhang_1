import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

import 'router/app_router.dart';
import 'theme/app_theme.dart';
import '../core/database/database_provider.dart';
import '../core/widgets/startup_poster.dart';
import '../features/sharing/application/shared_book_sync_service.dart';
import '../features/notifications/application/payment_notification_service.dart';
import '../features/recurring/application/recurring_bill_notification_service.dart';
import '../features/recurring/data/recurring_bill_repository.dart';
import '../features/scheduling/finance_scheduler_bridge.dart';
import '../core/diagnostics/operation_log.dart';
import '../core/installation/installation_age_repository.dart';
import '../core/analytics/product_analytics.dart';
import '../features/sharing/data/session_repository.dart';
import '../features/account/application/personal_cloud_auto_backup_service.dart';
import '../features/account/application/personal_cloud_remote_change_service.dart';
import '../features/update/application/app_update_service.dart';
import '../features/push/application/push_registration_service.dart';
import '../features/security/presentation/app_lock_gate.dart';
import '../features/budgets/application/budget_alert_notification_service.dart';
import '../features/budgets/data/budget_repository.dart';
import '../features/settings/application/theme_controller.dart';

final startupVisualWarmupProvider = FutureProvider<void>((ref) async {
  try {
    await LiquidGlassShaders.ensureLoaded();
  } on Object {
    // Liquid glass has a frosted fallback. Shader warm-up must never prevent
    // startup, but doing it behind the Flutter poster avoids extending the
    // Android/iOS native launch screen while still preparing the first lens.
  }
});

class JizhangApp extends ConsumerStatefulWidget {
  const JizhangApp({super.key});

  @override
  ConsumerState<JizhangApp> createState() => _JizhangAppState();
}

class _JizhangAppState extends ConsumerState<JizhangApp>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  static const _startupPosterDuration = Duration(milliseconds: 450);
  late final AnimationController _startupPosterController;
  bool _startupPosterElapsed = false;
  static const _navigationChannel = MethodChannel('jizhang/navigation');
  late final void Function(FlutterErrorDetails)? _previousFlutterErrorHandler;
  late final bool Function(Object, StackTrace)? _previousPlatformErrorHandler;
  late final OperationLogService _diagnostics;
  late final SessionRepository _sessionRepository;
  bool _updateDialogVisible = false;
  bool _initialUpdateCheckScheduled = false;

  @override
  void initState() {
    super.initState();
    _diagnostics = ref.read(operationLogServiceProvider);
    _sessionRepository = ref.read(sessionRepositoryProvider);
    _installDiagnosticHandlers();
    WidgetsBinding.instance.addObserver(this);
    _navigationChannel.setMethodCallHandler(_handleNavigationCall);
    _startupPosterController =
        AnimationController(vsync: this, duration: _startupPosterDuration)
          ..addStatusListener((status) {
            if (status == AnimationStatus.completed && mounted) {
              setState(() => _startupPosterElapsed = true);
            }
          })
          ..forward();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(() async {
        try {
          await ref.read(installationAgeRepositoryProvider).createdAt();
        } on Object {
          // Install-age tracking is conservative metadata and must never
          // block startup when local storage is unavailable.
        }
      }());
      unawaited(ref.read(productAnalyticsProvider).track('app_open'));
      _processNotifications();
      _processRecurringAutoRecords();
      _syncRecurringBillNotifications();
      _syncBudgetAlerts();
      unawaited(_flushDiagnosticsAfterSessionRestore());
      _syncPersonalCloudForeground();
      _registerPushIfAvailable();
      unawaited(const FinanceSchedulerBridge().scheduleDaily());
      final sync = ref.read(sharedBookSyncProvider);
      unawaited(
        sync
            .start()
            .then(
              (_) => sync.setForeground(
                WidgetsBinding.instance.lifecycleState ==
                    AppLifecycleState.resumed,
              ),
            )
            .catchError((Object error) {
              sync.lastError = '共享服务初始化失败：$error';
            }),
      );
    });
  }

  void _installDiagnosticHandlers() {
    _previousFlutterErrorHandler = FlutterError.onError;
    FlutterError.onError = (details) {
      _previousFlutterErrorHandler?.call(details);
      unawaited(
        _diagnostics.record(
          kind: 'flutter_error',
          level: 'error',
          message: details.exception.runtimeType.toString(),
          data: {'fatal': false},
        ),
      );
    };
    _previousPlatformErrorHandler = PlatformDispatcher.instance.onError;
    PlatformDispatcher.instance.onError = (error, stack) {
      unawaited(
        _diagnostics.record(
          kind: 'platform_error',
          level: 'error',
          message: error.runtimeType.toString(),
          data: {'fatal': true},
        ),
      );
      return _previousPlatformErrorHandler?.call(error, stack) ?? false;
    };
    unawaited(_diagnostics.record(kind: 'app_started', screen: '/'));
  }

  Future<void> _flushDiagnosticsAfterSessionRestore() async {
    try {
      await _sessionRepository.initialize();
      await _diagnostics.flush();
    } on Object {
      // Diagnostics must never block the app when secure storage/network is unavailable.
    }
  }

  Future<void> _handleNavigationCall(MethodCall call) async {
    if (call.method != 'openRoute') return;
    final route = call.arguments;
    if (route is String && route.isNotEmpty && mounted) {
      ref.read(appRouterProvider).go(route);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    unawaited(
      _diagnostics.record(kind: 'app_lifecycle', data: {'state': state.name}),
    );
    if (state == AppLifecycleState.resumed) {
      unawaited(ref.read(productAnalyticsProvider).track('app_foreground'));
      _processNotifications();
      _processRecurringAutoRecords();
      _syncRecurringBillNotifications();
      _syncBudgetAlerts();
      unawaited(_flushDiagnosticsAfterSessionRestore());
      _syncPersonalCloudForeground();
      _registerPushIfAvailable();
      _checkForAppUpdate();
    }
    ref
        .read(sharedBookSyncProvider)
        .setForeground(state == AppLifecycleState.resumed);
  }

  void _registerPushIfAvailable() {
    unawaited(
      ref
          .read(pushRegistrationServiceProvider)
          .registerIfAvailable()
          .then((result) {
            if (result == PushRegistrationResult.failed) {
              return _diagnostics.record(
                kind: 'push_registration',
                level: 'warn',
                data: {'result': result.name},
              );
            }
            return Future<void>.value();
          }),
    );
  }

  void _checkForAppUpdate() {
    if (_updateDialogVisible) return;
    unawaited(() async {
      try {
        final decision = await ref
            .read(appUpdateServiceProvider)
            .checkIfDue();
        if (!mounted || decision == null) return;
        final dialogContext = rootNavigatorKey.currentContext;
        if (dialogContext == null || !dialogContext.mounted) return;

        _updateDialogVisible = true;
        await showDialog<void>(
          context: dialogContext,
          barrierDismissible: decision.kind != AppUpdateKind.required,
          builder: (context) {
            final required = decision.kind == AppUpdateKind.required;
            return PopScope(
              canPop: !required,
              child: AlertDialog(
                title: Text(required ? '需要更新后继续使用' : '发现新版本'),
                content: Text(
                  '${decision.message ?? '新版本已经可以更新。'}\n\n'
                  '当前版本：${decision.currentVersion}\n'
                  '最新版本：${decision.latestVersion}',
                ),
                actions: [
                  if (!required)
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('稍后'),
                    ),
                  FilledButton(
                    onPressed: () async {
                      final opened = await ref
                          .read(appUpdateServiceProvider)
                          .openStore(decision);
                      if (!context.mounted) return;
                      if (opened && !required) {
                        Navigator.pop(context);
                      } else if (!opened) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('暂时无法打开更新地址')),
                        );
                      }
                    },
                    child: Text(required ? '立即更新' : '去更新'),
                  ),
                ],
              ),
            );
          },
        );
      } on Object catch (error) {
        await _diagnostics.record(
          kind: 'app_update_check',
          level: 'warn',
          message: error.runtimeType.toString(),
        );
      } finally {
        _updateDialogVisible = false;
      }
    }());
  }

  void _syncPersonalCloudForeground() {
    unawaited(() async {
      final remote = await ref
          .read(personalCloudRemoteChangeServiceProvider)
          .checkIfDue();
      if (remote == PersonalCloudRemoteCheckResult.updateAvailable ||
          remote == PersonalCloudRemoteCheckResult.datasetConflict) {
        await _diagnostics.record(
          kind: 'personal_cloud_remote_check',
          data: {'result': remote.name},
        );
        return;
      }

      final backup = await ref
          .read(personalCloudAutoBackupServiceProvider)
          .backupIfDue();
      if (backup == PersonalCloudAutoBackupResult.backedUp ||
          backup == PersonalCloudAutoBackupResult.conflict) {
        await _diagnostics.record(
          kind: 'personal_cloud_auto_backup',
          data: {'result': backup.name},
        );
      }
    }());
  }

  void _processRecurringAutoRecords() {
    unawaited(
      ref
          .read(databaseBootstrapProvider.future)
          .then((_) async {
            if (!mounted) return;
            await ref
                .read(recurringBillExecutionServiceProvider)
                .processDueAutoRecords();
            if (mounted) {
              ref
                  .read(recurringAutoRecordErrorProvider.notifier)
                  .setError(null);
            }
          })
          .catchError((Object error) {
            if (mounted) {
              ref
                  .read(recurringAutoRecordErrorProvider.notifier)
                  .setError('周期账单自动记账失败：$error');
            }
          }),
    );
  }

  void _syncRecurringBillNotifications() {
    unawaited(
      ref
          .read(databaseBootstrapProvider.future)
          .then((_) async {
            if (!mounted) return;
            final repository = ref.read(recurringBillRepositoryProvider);
            final bills = await repository.getAllForNotification();
            await ref
                .read(recurringBillNotificationSchedulerProvider)
                .syncBills(bills);
          })
          .catchError((Object _) {
            // Notification delivery is best effort and must not block app
            // startup or hide a successful bookkeeping operation.
          }),
    );
  }

  void _syncBudgetAlerts() {
    unawaited(
      ref
          .read(databaseBootstrapProvider.future)
          .then((_) async {
            if (!mounted) return;
            await ref
                .read(budgetAlertNotificationServiceProvider)
                .sync(ref.read(budgetOverviewProvider));
          })
          .catchError((Object _) {
            // Budget warnings are best effort and must never block startup.
          }),
    );
  }

  void _processNotifications() {
    unawaited(
      ref
          .read(databaseBootstrapProvider.future)
          .then((_) async {
            if (!mounted) return;
            await ref
                .read(paymentNotificationAutoBookkeepingProvider)
                .processPending();
            unawaited(
              _diagnostics.record(
                kind: 'payment_notifications_processed',
                data: {'status': 'completed'},
              ),
            );
            if (mounted)
              ref
                  .read(notificationProcessingErrorProvider.notifier)
                  .setError(null);
          })
          .catchError((Object error) {
            unawaited(
              _diagnostics.record(
                kind: 'payment_notifications_processed',
                level: 'error',
                message: error.runtimeType.toString(),
                data: {'status': 'failed'},
              ),
            );
            if (mounted)
              ref
                  .read(notificationProcessingErrorProvider.notifier)
                  .setError('支付通知仍待处理：$error');
          }),
    );
  }

  @override
  void dispose() {
    _navigationChannel.setMethodCallHandler(null);
    _startupPosterController.dispose();
    FlutterError.onError = _previousFlutterErrorHandler;
    PlatformDispatcher.instance.onError = _previousPlatformErrorHandler;
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ref = this.ref;
    final databaseBootstrap = ref.watch(databaseBootstrapProvider);
    final visualWarmup = ref.watch(startupVisualWarmupProvider);
    if (databaseBootstrap.isLoading ||
        visualWarmup.isLoading ||
        !_startupPosterElapsed) {
      return const MaterialApp(
        title: '好好记账',
        debugShowCheckedModeBanner: false,
        home: StartupPoster(),
      );
    }
    if (databaseBootstrap.hasError) {
      return MaterialApp(
        title: '好好记账',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        home: Scaffold(
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 360),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.storage_rounded, size: 42),
                      const SizedBox(height: 14),
                      const Text(
                        '本地账本初始化失败',
                        style: TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '没有加载完成前不会进入一个空白或灰色首页。可以直接重试，本地账单不会因为重试被清空。',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 18),
                      FilledButton.icon(
                        onPressed: () =>
                            ref.invalidate(databaseBootstrapProvider),
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('重新加载'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    ref.listen(budgetOverviewProvider, (previous, next) {
      unawaited(
        ref
            .read(budgetAlertNotificationServiceProvider)
            .sync(next)
            .catchError((Object _) {
              // A notification failure must not affect budgeting or app UI.
            }),
      );
    });

    if (!_initialUpdateCheckScheduled) {
      _initialUpdateCheckScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _checkForAppUpdate();
      });
    }

    final appearance = ref.watch(effectiveThemeProvider);
    final disableThemeAnimations =
        MediaQueryData.fromView(View.of(context)).disableAnimations;
    final brightnessPreference =
        ref.watch(brightnessModeProvider).value ??
        AppBrightnessPreference.light;
    return MaterialApp.router(
      title: '好好记账',
      theme: AppTheme.light(appearance),
      darkTheme: AppTheme.dark(appearance),
      themeMode: brightnessPreference == AppBrightnessPreference.dark
          ? ThemeMode.dark
          : ThemeMode.light,
      themeAnimationDuration: disableThemeAnimations
          ? Duration.zero
          : const Duration(milliseconds: 260),
      themeAnimationCurve: Curves.easeOutCubic,
      routerConfig: ref.watch(appRouterProvider),
      locale: const Locale('zh', 'CN'),
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      supportedLocales: const [Locale('zh', 'CN')],
      debugShowCheckedModeBanner: false,
      builder: (context, child) {
        final content = AppLockGate(
          child: child ?? const SizedBox.shrink(),
        );
        // Every theme gets a translucent wash behind the app, so pages that
        // do not draw their own background still sit on something with a
        // little variation. `AppScaffold` layers its mesh gradient on top of
        // this for the shell routes.
        final scheme = Theme.of(context).colorScheme;
        final background = Theme.of(context).scaffoldBackgroundColor;
        return DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                background,
                Color.alphaBlend(
                  scheme.primary.withValues(alpha: .08),
                  scheme.surface,
                ),
                scheme.surface,
              ],
              stops: const [0, .52, 1],
            ),
          ),
          child: content,
        );
      },
    );
  }
}

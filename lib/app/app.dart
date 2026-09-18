import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
import '../features/sharing/data/session_repository.dart';

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
      _processNotifications();
      _processRecurringAutoRecords();
      _syncRecurringBillNotifications();
      unawaited(_flushDiagnosticsAfterSessionRestore());
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
      _processNotifications();
      _processRecurringAutoRecords();
      _syncRecurringBillNotifications();
      unawaited(_flushDiagnosticsAfterSessionRestore());
    }
    ref
        .read(sharedBookSyncProvider)
        .setForeground(state == AppLifecycleState.resumed);
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
    if (databaseBootstrap.isLoading || !_startupPosterElapsed) {
      return const MaterialApp(
        title: '好好记账',
        debugShowCheckedModeBanner: false,
        home: StartupPoster(),
      );
    }

    return MaterialApp.router(
      title: '好好记账',
      theme: AppTheme.light(),
      routerConfig: ref.watch(appRouterProvider),
      locale: const Locale('zh', 'CN'),
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      supportedLocales: const [Locale('zh', 'CN')],
      debugShowCheckedModeBanner: false,
    );
  }
}

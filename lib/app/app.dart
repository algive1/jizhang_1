import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'router/app_router.dart';
import 'theme/app_theme.dart';
import '../core/database/database_provider.dart';
import '../features/sharing/application/shared_book_sync_service.dart';
import '../features/notifications/application/payment_notification_service.dart';

class JizhangApp extends ConsumerStatefulWidget {
  const JizhangApp({super.key});

  @override
  ConsumerState<JizhangApp> createState() => _JizhangAppState();
}

class _JizhangAppState extends ConsumerState<JizhangApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _processNotifications();
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

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _processNotifications();
    ref
        .read(sharedBookSyncProvider)
        .setForeground(state == AppLifecycleState.resumed);
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
            if (mounted)
              ref
                  .read(notificationProcessingErrorProvider.notifier)
                  .setError(null);
          })
          .catchError((Object error) {
            if (mounted)
              ref
                  .read(notificationProcessingErrorProvider.notifier)
                  .setError('支付通知仍待处理：$error');
          }),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ref = this.ref;
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

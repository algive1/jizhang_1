import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/formatters/money_formatter.dart';
import '../../../core/models/budget.dart';
import '../../settings/data/app_settings_repository.dart';

abstract interface class BudgetNotificationBridge {
  Future<bool> isGranted();
  Future<void> requestPermission();
  Future<void> show({
    required String id,
    required String title,
    required String body,
    required String route,
  });
}

class MethodChannelBudgetNotificationBridge
    implements BudgetNotificationBridge {
  const MethodChannelBudgetNotificationBridge();

  static const _channel = MethodChannel('jizhang/budget_notifications');

  @override
  Future<bool> isGranted() async {
    try {
      return await _channel.invokeMethod<bool>('isGranted') ?? false;
    } on MissingPluginException {
      return false;
    }
  }

  @override
  Future<void> requestPermission() async {
    try {
      await _channel.invokeMethod<void>('requestPermission');
    } on MissingPluginException {
      // Desktop and tests do not expose native notification APIs.
    }
  }

  @override
  Future<void> show({
    required String id,
    required String title,
    required String body,
    required String route,
  }) async {
    try {
      await _channel.invokeMethod<void>('show', {
        'id': id,
        'title': title,
        'body': body,
        'route': route,
      });
    } on MissingPluginException {
      // Desktop and tests do not expose native notification APIs.
    }
  }
}

class BudgetAlertNotificationService {
  BudgetAlertNotificationService(this._settings, this._bridge);

  static const route = '/profile/budgets';
  static const _settingPrefix = 'budget_alert_status';

  final AppSettingsRepository _settings;
  final BudgetNotificationBridge _bridge;

  Future<void> requestPermission() => _bridge.requestPermission();

  Future<void> sync(BudgetOverview overview) async {
    final progresses = <BudgetProgress>[
      if (overview.total != null) overview.total!,
      ...overview.categories,
    ];
    if (!progresses.any((item) => item.status != BudgetAlertStatus.normal)) {
      for (final item in progresses) {
        await _recordState(item, BudgetAlertStatus.normal);
      }
      return;
    }
    if (!await _bridge.isGranted()) return;
    for (final progress in progresses) {
      await _syncProgress(progress);
    }
  }

  Future<void> _syncProgress(BudgetProgress progress) async {
    final previous = _parseStatus(await _settings.get(_stateKey(progress)));
    final current = progress.status;

    if (current == BudgetAlertStatus.normal) {
      if (previous != BudgetAlertStatus.normal) {
        await _recordState(progress, current);
      }
      return;
    }

    final shouldNotify = previous == null || _rank(current) > _rank(previous);
    if (shouldNotify) {
      final categoryName = progress.category?.name;
      final scope = categoryName == null ? '本月总预算' : '${categoryName}预算';
      final percent = (progress.percentage * 100).round();
      final title = current == BudgetAlertStatus.exceeded
          ? '${scope}已超额'
          : '${scope}已使用 ${percent}%';
      final body = current == BudgetAlertStatus.exceeded
          ? '已支出 ¥${MoneyFormatter.decimal(progress.used)}，'
                '超出 ¥${MoneyFormatter.decimal(progress.remaining.abs())}。点击查看预算。'
          : '已支出 ¥${MoneyFormatter.decimal(progress.used)} / '
                '¥${MoneyFormatter.decimal(progress.budget.amount)}，'
                '还可使用 ¥${MoneyFormatter.decimal(progress.remaining.clamp(0, double.infinity))}。';
      await _bridge.show(
        id: _notificationId(progress, current),
        title: title,
        body: body,
        route: route,
      );
    }

    if (previous != current) {
      await _recordState(progress, current);
    }
  }

  Future<void> _recordState(
    BudgetProgress progress,
    BudgetAlertStatus status,
  ) {
    return _settings.set(_stateKey(progress), status.name);
  }

  String _stateKey(BudgetProgress progress) {
    final category = progress.budget.categoryId ?? 'total';
    return '$_settingPrefix:${progress.budget.bookId}:'
        '${progress.budget.monthKey}:$category';
  }

  String _notificationId(
    BudgetProgress progress,
    BudgetAlertStatus status,
  ) {
    final category = progress.budget.categoryId ?? 'total';
    return 'budget-alert-${progress.budget.bookId}-'
        '${progress.budget.monthKey}-$category-${status.name}';
  }

  BudgetAlertStatus? _parseStatus(String? value) {
    if (value == null) return null;
    for (final status in BudgetAlertStatus.values) {
      if (status.name == value) return status;
    }
    return null;
  }

  int _rank(BudgetAlertStatus status) => switch (status) {
    BudgetAlertStatus.normal => 0,
    BudgetAlertStatus.nearLimit => 1,
    BudgetAlertStatus.exceeded => 2,
  };
}

final budgetNotificationBridgeProvider = Provider<BudgetNotificationBridge>(
  (ref) => const MethodChannelBudgetNotificationBridge(),
);

final budgetAlertNotificationServiceProvider =
    Provider<BudgetAlertNotificationService>(
      (ref) => BudgetAlertNotificationService(
        ref.watch(appSettingsRepositoryProvider),
        ref.watch(budgetNotificationBridgeProvider),
      ),
    );

import 'package:flutter_test/flutter_test.dart';
import 'package:jizhang_app/core/models/budget.dart';
import 'package:jizhang_app/features/budgets/application/budget_alert_notification_service.dart';
import 'package:jizhang_app/features/settings/data/app_settings_repository.dart';

void main() {
  test('budget alert notifies once per level and escalates at exceeded', () async {
    final settings = _MemorySettings();
    final bridge = _FakeBridge();
    final service = BudgetAlertNotificationService(settings, bridge);

    await service.sync(BudgetOverview(total: _progress(.85), categories: const []));
    await service.sync(BudgetOverview(total: _progress(.90), categories: const []));
    expect(bridge.notifications, hasLength(1));
    expect(bridge.notifications.single.title, contains('已使用'));

    await service.sync(BudgetOverview(total: _progress(1.08), categories: const []));
    expect(bridge.notifications, hasLength(2));
    expect(bridge.notifications.last.title, contains('已超额'));
    expect(bridge.notifications.last.route, BudgetAlertNotificationService.route);
  });

  test('normal status resets the alert level for a later threshold crossing', () async {
    final settings = _MemorySettings();
    final bridge = _FakeBridge();
    final service = BudgetAlertNotificationService(settings, bridge);

    await service.sync(BudgetOverview(total: _progress(.82), categories: const []));
    await service.sync(BudgetOverview(total: _progress(.60), categories: const []));
    await service.sync(BudgetOverview(total: _progress(.81), categories: const []));

    expect(bridge.notifications, hasLength(2));
  });

  test('denied notification permission does not consume the alert state', () async {
    final settings = _MemorySettings();
    final bridge = _FakeBridge()..granted = false;
    final service = BudgetAlertNotificationService(settings, bridge);

    await service.sync(BudgetOverview(total: _progress(.9), categories: const []));
    expect(bridge.notifications, isEmpty);

    bridge.granted = true;
    await service.sync(BudgetOverview(total: _progress(.9), categories: const []));
    expect(bridge.notifications, hasLength(1));
  });
}

BudgetProgress _progress(double percentage) {
  final amount = 1000.0;
  final used = amount * percentage;
  final now = DateTime(2026, 9, 19);
  return BudgetProgress(
    budget: Budget(
      id: 'budget-total',
      bookId: 'book-personal',
      monthKey: '2026-09',
      amount: amount,
      createdAt: now,
      updatedAt: now,
    ),
    used: used,
    remaining: amount - used,
    percentage: percentage,
    remainingDays: 12,
    dailyAvailable: 10,
    status: percentage > 1
        ? BudgetAlertStatus.exceeded
        : percentage >= .8
        ? BudgetAlertStatus.nearLimit
        : BudgetAlertStatus.normal,
  );
}

class _MemorySettings implements AppSettingsRepository {
  final values = <String, String>{};

  @override
  Future<String?> get(String key) async => values[key];

  @override
  Future<void> set(String key, String value) async {
    values[key] = value;
  }
}

class _Notification {
  const _Notification(this.id, this.title, this.body, this.route);
  final String id;
  final String title;
  final String body;
  final String route;
}

class _FakeBridge implements BudgetNotificationBridge {
  bool granted = true;
  int permissionRequests = 0;
  final notifications = <_Notification>[];

  @override
  Future<bool> isGranted() async => granted;

  @override
  Future<void> requestPermission() async {
    permissionRequests++;
  }

  @override
  Future<void> show({
    required String id,
    required String title,
    required String body,
    required String route,
  }) async {
    notifications.add(_Notification(id, title, body, route));
  }
}

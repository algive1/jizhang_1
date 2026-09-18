import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../sharing/data/session_repository.dart';

class DatasetBindingService {
  const DatasetBindingService(this.database, this.session);

  final AppDatabase database;
  final SessionRepository session;

  Future<DeviceDataBinding> status() => database.getDeviceDataBinding();

  Future<DeviceDataBinding> bindCurrentAccount() async {
    await session.initialize();
    final userId = session.userId;
    if (userId == null) throw StateError('请先登录');
    return database.bindDatasetToUser(userId);
  }
}

final datasetBindingServiceProvider = Provider<DatasetBindingService>((ref) {
  return DatasetBindingService(
    ref.watch(databaseProvider),
    ref.watch(sessionRepositoryProvider),
  );
});

final datasetBindingProvider = FutureProvider<DeviceDataBinding>((ref) {
  return ref.watch(datasetBindingServiceProvider).status();
});

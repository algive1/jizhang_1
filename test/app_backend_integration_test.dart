import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;
import 'package:jizhang_app/core/config/testing_access.dart';
import 'package:jizhang_app/core/database/app_database.dart';
import 'package:jizhang_app/core/database/database_seeder.dart';
import 'package:jizhang_app/core/installation/installation_identity.dart';
import 'package:jizhang_app/core/models/membership.dart';
import 'package:jizhang_app/features/account/application/personal_cloud_backup_service.dart';
import 'package:jizhang_app/features/account/application/personal_cloud_bootstrap_service.dart';
import 'package:jizhang_app/features/app_runtime/application/device_heartbeat_service.dart';
import 'package:jizhang_app/features/app_runtime/data/app_runtime_repository.dart';
import 'package:jizhang_app/features/data_export/application/local_backup_service.dart';
import 'package:jizhang_app/features/investments/data/http_market_data_provider.dart';
import 'package:jizhang_app/features/investments/domain/investment_asset.dart';
import 'package:jizhang_app/features/investments/domain/investment_quote.dart';
import 'package:jizhang_app/features/membership/application/membership_feature_guard.dart';
import 'package:jizhang_app/features/membership/data/membership_repository.dart';
import 'package:jizhang_app/features/settings/data/app_settings_repository.dart';
import 'package:jizhang_app/features/sharing/data/session_repository.dart';
import 'package:jizhang_app/features/sharing/data/shared_api.dart';
import 'package:jizhang_app/features/support/application/support_ticket_service.dart';
import 'package:jizhang_app/features/update/application/app_update_service.dart';

class _Credentials implements SessionStorage {
  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String? value) async {
    this.value = value;
  }
}

class _BuildInfo implements AppUpdatePlatform {
  @override
  Future<AppBuildInfo> appInfo() async =>
      const AppBuildInfo(platform: 'android', version: '1.0.0', build: 1);
  @override
  Future<bool> openStore(String url) async => false;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = null;
  test('APP and console share real HTTP, membership, content, device, cloud and market contracts', () async {
    expect(
      kAllFeaturesFreeForTesting,
      isFalse,
      reason: 'Run with --dart-define=ALL_FEATURES_FREE_FOR_TESTING=false to test production permission enforcement',
    );
    final directory = await Directory.systemTemp.createTemp(
      'app-console-integration-',
    );
    final server = await Process.start(
      'node',
      [
        '--import',
        './server/node_modules/tsx/dist/loader.mjs',
        'server/test/fixtures/flutter_integration_server.ts',
      ],
      environment: {
        'NODE_ENV': 'test',
        'ALL_FEATURES_FREE_FOR_TESTING': 'false',
        'LEDGER_DB_PATH': '${directory.path}/server.sqlite',
      },
    );
    final address = Completer<String>(), errors = <String>[];
    final out = server.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) {
          if (line.startsWith('Shared ledger listening at ') &&
              !address.isCompleted) {
            address.complete(
              line.substring('Shared ledger listening at '.length),
            );
          }
        });
    final err = server.stderr.transform(utf8.decoder).listen(errors.add);
    addTearDown(() async {
      server.kill();
      await server.exitCode.timeout(const Duration(seconds: 10));
      await out.cancel();
      await err.cancel();
      await directory.delete(recursive: true);
    });
    final base = await address.future.timeout(
      const Duration(seconds: 20),
      onTimeout: () =>
          throw StateError('Backend startup failed: ${errors.join()}'),
    );
    final documents = await Directory('${directory.path}/client').create();
    final database = AppDatabase.forTesting(
      NativeDatabase(
        File('${documents.path}/${LocalBackupService.databaseFileName}'),
      ),
    );
    addTearDown(database.close);
    await DatabaseSeeder(database).seedIfNeeded();
    final api = SharedApi(baseUrl: base), admin = SharedApi(baseUrl: base);
    addTearDown(api.close);
    addTearDown(admin.close);
    final session = SessionRepository(api, database, storage: _Credentials());
    addTearDown(session.dispose);
    final settings = DriftAppSettingsRepository(database);
    final runtime = AppRuntimeRepository(api, settings);
    addTearDown(runtime.dispose);
    final login = await admin.request(
      '/console/auth/login',
      method: 'POST',
      body: {
        'username': 'flutter_test_admin',
        'password': 'isolated-console-password',
      },
    );
    admin.sessionToken = (login['data'] as Map)['token'];
    Future<Map<String, dynamic>> manage(
      String path, {
      String method = 'GET',
      Object? body,
    }) async {
      final response = await admin.request(
        '/console$path',
        method: method,
        body: body,
      );
      return Map<String, dynamic>.from(response['data'] as Map);
    }

    Future<int> config(Map<String, Object> flags, int baseVersion) async {
      final doc = await manage(
        '/documents/config',
        method: 'POST',
        body: {
          'key': 'runtime',
          'payload': flags,
          'note': '联调验证',
          'baseVersion': baseVersion,
        },
      );
      final version = doc['version'] as int;
      await manage(
        '/documents/config/runtime/publish',
        method: 'POST',
        body: {'version': version, 'rollout': 100},
      );
      await runtime.refreshConfiguration(force: true);
      return version;
    }

    // Public content works before login; publication, rollback and offline
    // defaults use the same installation cohort as execution requests.
    await config({'voiceEnabled': false, 'cloudBackupEnabled': false}, 0);
    await expectLater(
      runtime.require(AppCapability.voice),
      throwsA(isA<AppCapabilityUnavailable>()),
    );
    expect(api.installationId, await installationIdentity(settings));
    final created = await manage(
      '/operations',
      method: 'POST',
      body: {
        'kind': 'faq',
        'title': '如何开启云备份？',
        'body': '登录并绑定数据后，主动创建首次备份。',
        'enabled': true,
      },
    );
    expect((await runtime.operations('faq')).items.single.title, '如何开启云备份？');
    await manage(
      '/operations/${created['id']}',
      method: 'PUT',
      body: {
        'kind': 'faq',
        'title': '如何开启云备份？',
        'body': '登录并绑定数据后，主动创建首次备份。',
        'enabled': false,
      },
    );
    expect((await runtime.operations('faq', force: true)).items, isEmpty);
    await config({'voiceEnabled': true, 'cloudBackupEnabled': true}, 1);

    await session.authenticate(
      username: 'flutter_integrated_user',
      password: 'isolated-app-password',
      register: true,
    );
    final userId = session.userId!;
    final membership = RemoteMembershipRepository(api, session);
    final access = SnapshotMembershipFeatureAccessService(membership);
    expect(
      (await membership.getCurrent())
          .policyFor(MembershipFeature.automaticBookkeeping)
          .requiresMembership,
      isTrue,
    );
    await expectLater(
      requireMembershipFeature(access, MembershipFeature.automaticBookkeeping),
      throwsA(isA<MembershipFeatureDenied>()),
    );

    final heartbeat = DeviceHeartbeatService(
      api,
      session,
      settings,
      _BuildInfo(),
      readState: (_, _) async => const DeviceHeartbeatState(
        automaticBookkeeping: false,
        autoBackup: false,
      ),
    );
    expect(await heartbeat.sendIfDue(), DeviceHeartbeatResult.sent);
    expect(await heartbeat.sendIfDue(), DeviceHeartbeatResult.skipped);
    final devices = (await manage('/devices?userId=$userId'))['items'] as List;
    expect(devices.length, 1);
    expect((devices.single as Map)['appVersion'], '1.0.0');
    expect((devices.single as Map)['installationId'], api.installationId);
    expect((devices.single as Map)['brand'], isNull);
    expect((devices.single as Map)['model'], isNull);

    final support = SupportTicketService(api, settings, session);
    final ticket = await support.submit(
      subject: '联调测试问题',
      message: '验证后台回复回到 APP',
    );
    expect((await support.listMine()).single.id, ticket);
    await manage(
      '/feedback/$ticket/messages',
      method: 'POST',
      body: {'body': '后台回复已送达'},
    );
    expect((await support.detail(ticket)).messages.last.body, '后台回复已送达');

    await manage(
      '/membership/users/$userId',
      method: 'PUT',
      body: {'productId': 'monthly', 'durationDays': 30, 'reason': '隔离环境联调'},
    );
    expect((await membership.getCurrent()).membership.plan, MembershipPlan.pro);
    await requireMembershipFeature(
      access,
      MembershipFeature.automaticBookkeeping,
    );
    await database.bindDatasetToUser(userId);
    final bootstrap = PersonalCloudBootstrapService(
      database,
      session,
      api,
      membership,
      beforeCloudOperation: () => runtime.require(AppCapability.cloudBackup),
    );
    expect((await bootstrap.bootstrap()).datasetMatches, isTrue);
    final local = LocalBackupService(
      database,
      documentsDirectory: () async => documents,
    );
    final cloud = PersonalCloudBackupService(
      database,
      session,
      api,
      membership,
      local,
      beforeCloudOperation: () => runtime.require(AppCapability.cloudBackup),
    );
    await settings.set('integration.payload', '已上传的本地数据');
    final uploaded = await cloud.uploadSnapshot();
    expect(uploaded.hasSnapshot, isTrue);
    expect(uploaded.revision, 1);
    final backups = (await manage('/backups?userId=$userId'))['items'] as List;
    expect(backups.length, 1);
    expect((backups.single as Map).containsKey('snapshot'), isFalse);
    await settings.set('integration.payload', '上传后的本地变更');
    final restored = await cloud.downloadAndPrepareRestore();
    expect(restored.revision, 1);
    final pending = File(
      '${documents.path}/${LocalBackupService.databaseFileName}${LocalBackupService.pendingRestoreSuffix}',
    );
    expect(await pending.exists(), isTrue);
    final snapshot = sqlite.sqlite3.open(pending.path);
    try {
      expect(
        snapshot
            .select(
              "SELECT value FROM app_settings WHERE key='integration.payload'",
            )
            .single['value'],
        '已上传的本地数据',
      );
    } finally {
      snapshot.close();
    }
    expect(await settings.get('integration.payload'), '上传后的本地变更');

    await config({'cloudBackupEnabled': false}, 2);
    await expectLater(
      cloud.uploadSnapshot(),
      throwsA(isA<AppCapabilityUnavailable>()),
    );
    await expectLater(
      api.request(
        '/sync/bootstrap',
        method: 'POST',
        body: {'datasetId': (await database.getDeviceDataBinding()).datasetId},
      ),
      throwsA(isA<SharedApiException>().having((e) => e.status, 'status', 503)),
    );
    await manage(
      '/documents/config/runtime/publish',
      method: 'POST',
      body: {'version': 2, 'rollout': 100},
    );
    expect(
      (await runtime.refreshConfiguration(force: true))
          .allows(AppCapability.cloudBackup),
      isTrue,
    );
    await manage('/documents/config/runtime/publication', method: 'DELETE');
    expect((await runtime.refreshConfiguration(force: true)).versions, isEmpty);

    // Real proxy contract, with an explicitly isolated external vendor fixture.
    final market = HttpMarketDataProvider(api);
    expect(
      (await market.search(
        '600000',
        type: InvestmentAssetType.stock,
      )).single.currency,
      'CNY',
    );
    expect(
      (await market.search(
        '000001',
        type: InvestmentAssetType.fund,
      )).single.type,
      InvestmentAssetType.fund,
    );
    expect(
      (await market.getQuote('000001', InvestmentAssetType.fund))!.price,
      1.25,
    );
    expect(
      (await market.getHistory(
        '600000',
        InvestmentAssetType.stock,
        InvestmentRange.month,
      )).single.value,
      10,
    );

    await manage(
      '/membership/users/$userId',
      method: 'PUT',
      body: {'productId': null, 'durationDays': 0, 'reason': '取消会员后验证限制'},
    );
    await expectLater(
      requireMembershipFeature(access, MembershipFeature.dataExport),
      throwsA(isA<MembershipFeatureDenied>()),
    );
    await expectLater(
      cloud.uploadSnapshot(),
      throwsA(isA<CloudSyncMembershipRequired>()),
    );
    final interrupted = PersonalCloudBootstrapService(
      database,
      session,
      api,
      membership,
      beforeCloudOperation: session.logout,
    );
    await expectLater(interrupted.bootstrap(), throwsStateError);
    expect(
      await heartbeat.sendIfDue(force: true),
      DeviceHeartbeatResult.skipped,
    );
    await session.authenticate(
      username: 'flutter_second_user',
      password: 'isolated-app-password',
      register: true,
    );
    final secondUser = session.userId!;
    expect(await heartbeat.sendIfDue(), DeviceHeartbeatResult.sent);
    final secondDevices =
        (await manage('/devices?userId=$secondUser'))['items'] as List;
    expect(secondDevices.length, 1);
    expect((secondDevices.single as Map)['installationId'], api.installationId);
    final interruptedHeartbeat = DeviceHeartbeatService(
      api,
      session,
      settings,
      _BuildInfo(),
      readState: (_, _) async {
        await session.logout();
        return const DeviceHeartbeatState(autoBackup: false);
      },
    );
    expect(
      await interruptedHeartbeat.sendIfDue(force: true),
      DeviceHeartbeatResult.skipped,
    );
  }, timeout: const Timeout(Duration(minutes: 2)));
}

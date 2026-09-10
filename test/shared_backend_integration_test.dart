import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:jizhang_app/core/database/database_provider.dart';
import 'package:jizhang_app/core/database/database_seeder.dart';
import 'package:jizhang_app/core/models/family.dart';
import 'package:jizhang_app/core/models/goal.dart';
import 'package:jizhang_app/features/goals/data/goal_repository.dart';
import 'package:jizhang_app/features/budgets/data/budget_repository.dart';
import 'package:jizhang_app/features/budgets/domain/safe_to_spend_service.dart';
import 'package:jizhang_app/core/models/transaction_record.dart';
import 'package:jizhang_app/features/accounts/data/account_repository.dart';
import 'package:jizhang_app/features/books/data/book_repository.dart';
import 'package:jizhang_app/features/membership/data/membership_repository.dart';
import 'package:jizhang_app/features/sharing/data/session_repository.dart';
import 'package:jizhang_app/features/sharing/data/shared_api.dart';
import 'package:jizhang_app/features/sharing/application/shared_book_sync_service.dart';
import 'package:jizhang_app/features/family/data/shared_family_service.dart';
import 'package:jizhang_app/features/transactions/data/transactions_repository.dart';

// Only credential persistence is in-memory. Authentication, HTTP, server SQLite,
// both client SQLite databases and every repository below are real.
class VolatileSessionStorage implements SessionStorage {
  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String? value) async {
    this.value = value;
  }
}

void main() {
  test(
    'two real Flutter databases synchronize via localhost backend',
    () async {
      driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
      final temp = await Directory.systemTemp.createTemp('ledger-two-clients-');
      final server = await Process.start(
        '/Users/algive/.local/node/node-v22.14.0-darwin-x64/bin/node',
        ['server/node_modules/tsx/dist/cli.mjs', 'server/src/main.ts'],
        environment: {
          'PORT': '0',
          'LEDGER_DB_PATH': '${temp.path}/server.sqlite',
        },
      );
      final address = Completer<String>();
      final out = server.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) {
            if (line.startsWith('Shared ledger listening at '))
              address.complete(
                line.substring('Shared ledger listening at '.length),
              );
          });
      final errors = <String>[];
      final err = server.stderr.transform(utf8.decoder).listen(errors.add);
      addTearDown(() async {
        server.kill();
        await server.exitCode;
        await out.cancel();
        await err.cancel();
        await temp.delete(recursive: true);
      });
      final base = await address.future.timeout(
        const Duration(seconds: 20),
        onTimeout: () =>
            throw StateError('Local server did not start: ${errors.join()}'),
      );
      final a = createMemoryDatabase(), b = createMemoryDatabase();
      for (final db in [a, b]) {
        await DatabaseSeeder(db).seedIfNeeded();
        addTearDown(db.close);
      }
      final proxy = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final transport = HttpClient();
      Future<void> Function()? duringPromotion;
      var dropPromotionResponse = false;
      proxy.listen((incoming) async {
        final outgoing = await transport.openUrl(
          incoming.method,
          Uri.parse('$base${incoming.uri}'),
        );
        if (incoming.headers.value(HttpHeaders.authorizationHeader) != null)
          outgoing.headers.set(
            HttpHeaders.authorizationHeader,
            incoming.headers.value(HttpHeaders.authorizationHeader)!,
          );
        if (incoming.headers.contentType != null)
          outgoing.headers.contentType = incoming.headers.contentType;
        final requestBytes = await incoming.fold<List<int>>(
          [],
          (all, part) => all..addAll(part),
        );
        outgoing.contentLength = requestBytes.length;
        if (requestBytes.isNotEmpty) outgoing.add(requestBytes);
        final result = await outgoing.close();
        final bytes = await result.fold<List<int>>(
          [],
          (all, part) => all..addAll(part),
        );
        if (dropPromotionResponse &&
            incoming.method == 'POST' &&
            incoming.uri.path == '/api/v1/books') {
          dropPromotionResponse = false;
          await duringPromotion!();
          (await incoming.response.detachSocket(writeHeaders: false)).destroy();
          return;
        }
        incoming.response.statusCode = result.statusCode;
        incoming.response.headers.contentType = ContentType.json;
        incoming.response.add(bytes);
        await incoming.response.close();
      });
      addTearDown(() async {
        transport.close(force: true);
        await proxy.close(force: true);
      });
      final apiA = SharedApi(baseUrl: 'http://127.0.0.1:${proxy.port}'),
          apiB = SharedApi(baseUrl: base);
      addTearDown(apiA.close);
      addTearDown(apiB.close);
      final sessionA = SessionRepository(
            apiA,
            a,
            storage: VolatileSessionStorage(),
          ),
          sessionB = SessionRepository(
            apiB,
            b,
            storage: VolatileSessionStorage(),
          );
      addTearDown(sessionA.dispose);
      addTearDown(sessionB.dispose);
      final syncA = SharedBookSyncService(a, sessionA),
          syncB = SharedBookSyncService(b, sessionB);
      addTearDown(syncA.dispose);
      addTearDown(syncB.dispose);
      await sessionA.authenticate(
        username: 'flutter_owner',
        password: 'local-test-password-a',
        register: true,
      );
      await sessionB.authenticate(
        username: 'flutter_member',
        password: 'local-test-password-b',
        register: true,
      );
      final booksA = DriftBookRepository(a, LocalOnlyMembershipRepository()),
          booksB = DriftBookRepository(b, LocalOnlyMembershipRepository());
      final family = await booksA.create(name: '双端家庭', type: BookType.family);
      final accountA = DriftAccountRepository(a, bookId: family.id),
          txA = DriftTransactionRepository(a),
          txB = DriftTransactionRepository(b);
      final cashA = (await accountA.getActive()).single.id;
      await accountA.reconcileBalance(cashA, 100);
      dropPromotionResponse = true;
      duringPromotion = () async {
        final now = DateTime.now();
        await txA.create(
          TransactionRecord(
            id: 'during-promotion',
            bookId: family.id,
            type: TransactionType.expense,
            amount: 3,
            accountId: cashA,
            occurredAt: now,
            createdAt: now,
            updatedAt: now,
          ),
        );
      };
      await expectLater(syncA.enableSharing(family.id), throwsStateError);
      expect((await syncA.pending(family.id)).length, 1);
      await syncA.enableSharing(family.id);
      expect((await syncA.states()).length, 1);
      expect(await syncA.pending(family.id), isEmpty);
      final shared = (await booksA.getForUser(SeedIds.localUser))
          .firstWhere((book) => book.id == family.id);
      expect(shared.isShared, isTrue);
      final remote = shared.sharedId!;
      final invitation = await SharedFamilyService(syncA)
          .createInvitation(familyId: remote);
      await SharedFamilyService(syncB).acceptInvitation(invitation.code);
      expect(syncB.lastError, isNull);
      final visible = await booksB.getForUser(SeedIds.localUser);
      expect(visible.length, 2);
      expect(visible.any((book) => book.id == family.id), isFalse);
      final bookB = visible.firstWhere((b) => b.isShared).id;
      final cashB = (await DriftAccountRepository(
        b,
        bookId: bookB,
      ).getActive()).single.id;
      expect(
        (await DriftAccountRepository(
          b,
          bookId: bookB,
        ).getActive()).single.balance,
        97,
      );
      TransactionRecord record(
        String id,
        String book,
        String cash,
        double amount,
      ) {
        final now = DateTime.now();
        return TransactionRecord(
          id: id,
          bookId: book,
          type: TransactionType.expense,
          amount: amount,
          currency: 'CNY',
          accountId: cash,
          occurredAt: now,
          createdAt: now,
          updatedAt: now,
        );
      }

      // No synchronizer runs while these writes are made: the outbox commits offline.
      await txB.create(record('offline-b', bookB, cashB, 12));
      expect((await syncB.pending(bookB)).length, 1);
      expect((await accountA.getActive()).single.balance, 97);
      await syncB.sync();
      expect(syncB.lastError, isNull);
      expect(await syncB.pending(bookB), isEmpty);
      await syncA.sync();
      expect(syncA.lastError, isNull);
      expect((await accountA.getActive()).single.balance, 85);
      await syncA.sync();
      await syncB.sync();
      expect((await accountA.getActive()).single.balance, 85);
      final onA = (await txA.getAll()).firstWhere((t) => t.id == 'offline-b');
      final onB = (await txB.getAll()).firstWhere((t) => t.id == 'offline-b');
      await txA.update(onA.copyWith(amount: 15));
      await txB.update(onB.copyWith(amount: 20));
      await syncA.sync();
      await syncB.sync();
      expect((await syncB.pending(bookB)).first['status'], 'conflict');
      await syncB.resolve(bookB, useServer: true);
      expect(await syncB.pending(bookB), isEmpty);
      expect(
        (await DriftAccountRepository(
          b,
          bookId: bookB,
        ).getActive()).single.balance,
        82,
      );
      await expectLater(
        DriftAccountRepository(b, bookId: bookB).reconcileBalance(cashB, 500),
        throwsA(isA<Exception>()),
      );
      expect(
        (await DriftAccountRepository(
          b,
          bookId: bookB,
        ).getActive()).single.balance,
        82,
      );
      final budgetA = DriftBudgetRepository(
        a,
        const SafeToSpendService(),
        bookId: family.id,
      );
      await budgetA.setBudget(monthKey: '2026-09', amount: 700);
      final goalA = DriftGoalRepository(a), goalB = DriftGoalRepository(b);
      final now = DateTime.now();
      final goal = await goalA.create(
        goal: Goal(
          id: 'shared-goal',
          bookId: family.id,
          name: '共同旅行',
          icon: 'travel',
          targetAmount: 100,
          currentAmount: 0,
          targetDate: now.add(const Duration(days: 60)),
          status: GoalStatus.active,
          createdAt: now,
          milestones: [],
        ),
        milestoneAmounts: [25, 50, 100],
        initialAmount: 10,
      );
      await syncA.sync();
      expect(await syncA.pending(family.id), isEmpty);
      await syncB.sync();
      final joinedGoal = (await goalB.getAll()).single;
      expect(joinedGoal.currentAmount, 10);
      expect(
        (await DriftBudgetRepository(
          b,
          const SafeToSpendService(),
          bookId: bookB,
        ).getMonth('2026-09')).single.amount,
        700,
      );
      await SharedFamilyService(syncA)
          .changeRole(remote, sessionB.user!.id, FamilyRole.admin);
      await syncB.sync();
      await goalB.contribute(
        goalId: joinedGoal.id,
        amount: 20,
        type: GoalContributionType.deposit,
      );
      await syncB.sync();
      expect(await syncB.pending(bookB), isEmpty);
      await syncA.sync();
      final contributed = (await goalA.getById(goal.id))!;
      expect(contributed.currentAmount, 30);
      expect(
        contributed.contributions
            .singleWhere((c) => c.amount == 20)
            .contributorUserId,
        sessionB.user!.id,
      );
      await goalA.replaceMilestones(goal.id, [20, 50, 100]);
      await syncA.sync();
      expect(await syncA.pending(family.id), isEmpty);
      await syncB.sync();
      expect(
        (await goalB.getById(joinedGoal.id))!.milestones.map((m) => m.amount),
        [20, 50, 100],
      );
      final oldBudget = (await budgetA.getMonth('2026-09')).single;
      await budgetA.removeBudget(oldBudget.id);
      await syncA.sync();
      await budgetA.setBudget(monthKey: '2026-09', amount: 800);
      await syncA.sync();
      expect(await syncA.pending(family.id), isEmpty);
      await syncB.sync();
      expect(
        (await DriftBudgetRepository(
          b,
          const SafeToSpendService(),
          bookId: bookB,
        ).getMonth('2026-09')).single.amount,
        800,
      );
      await SharedFamilyService(syncA).removeMember(remote, sessionB.user!.id);
      await txB.create(
        record('draft-after-revocation', bookB, cashB, 1),
      ); // permission not yet known offline
      await syncB.sync();
      expect((await booksB.getForUser(SeedIds.localUser)).length, 1);
      expect((await syncB.pending(bookB)).length, 1);
      expect((await accountA.getActive()).single.balance, 82);
      await expectLater(
        txB.create(record('blocked', bookB, cashB, 1)),
        throwsA(isA<Exception>()),
      );
      await sessionA.logout();
      expect((await booksA.getForUser(SeedIds.localUser)).map((b) => b.id), [
        SeedIds.personalBook,
      ]);
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}

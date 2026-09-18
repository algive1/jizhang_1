import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_provider.dart';
import '../../../core/database/database_seeder.dart';
import '../../../core/widgets/app_card.dart';
import '../../books/data/book_repository.dart';
import '../../settings/data/app_settings_repository.dart';
import '../application/payment_notification_service.dart';

final _targetSettingsProvider = FutureProvider<Map<String, String>>((
  ref,
) async {
  await ref.watch(databaseBootstrapProvider.future);
  final settings = ref.watch(appSettingsRepositoryProvider);
  final book =
      await settings.get(notificationTargetBookKey) ?? SeedIds.personalBook;
  final result = {'book': book};
  for (final channel in _channels.keys) {
    final id = await settings.get(notificationAccountKey(book, channel));
    if (id != null) {
      result[channel] = id;
    } else if (book == SeedIds.personalBook) {
      result[channel] = channel;
    }
  }
  return result;
});
const _channels = {
  SeedIds.wechatAccount: '微信',
  SeedIds.alipayAccount: '支付宝',
  SeedIds.bankAccount: '云闪付',
  'meituan': '美团',
};

class NotificationTargetCard extends ConsumerWidget {
  const NotificationTargetCard({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(_targetSettingsProvider),
        books = ref.watch(booksProvider).value ?? [];
    return AppCard(
      child: state.when(
        data: (settings) {
          final target = settings['book']!;
          final available = books.any((b) => b.id == target);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                '固定写入账本',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              const Text('浏览时切换账本不会改变通知目的地。账户未设置或账本不可用时，通知保留待处理。'),
              DropdownButton<String>(
                isExpanded: true,
                value: available ? target : null,
                hint: const Text('目标账本当前不可用'),
                items: [
                  for (final b in books)
                    DropdownMenuItem(
                      value: b.id,
                      child: Text(b.name, overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: (id) async {
                  if (id == null) return;
                  await ref
                      .read(appSettingsRepositoryProvider)
                      .set(notificationTargetBookKey, id);
                  ref.invalidate(_targetSettingsProvider);
                },
              ),
              if (available)
                FutureBuilder(
                  future: ref
                      .read(databaseProvider)
                      .accountDao
                      .getActive(bookId: target),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) return const Text('账户读取失败，请重新进入');
                    if (!snapshot.hasData)
                      return const LinearProgressIndicator();
                    final accounts = snapshot.data!;
                    return Column(
                      children: [
                        for (final channel in _channels.entries)
                          Row(
                            children: [
                              SizedBox(width: 70, child: Text(channel.value)),
                              Expanded(
                                child: DropdownButton<String>(
                                  isExpanded: true,
                                  value:
                                      accounts.any(
                                        (a) => a.id == settings[channel.key],
                                      )
                                      ? settings[channel.key]
                                      : null,
                                  hint: const Text('请选择账户'),
                                  items: [
                                    for (final a in accounts)
                                      DropdownMenuItem(
                                        value: a.id,
                                        child: Text(
                                          '${a.name}${a.identifierSuffix == null ? '' : '-${a.identifierSuffix}'}',
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                  ],
                                  onChanged: (id) async {
                                    if (id == null) return;
                                    await ref
                                        .read(appSettingsRepositoryProvider)
                                        .set(
                                          notificationAccountKey(
                                            target,
                                            channel.key,
                                          ),
                                          id,
                                        );
                                    ref.invalidate(_targetSettingsProvider);
                                  },
                                ),
                              ),
                            ],
                          ),
                      ],
                    );
                  },
                ),
            ],
          );
        },
        error: (_, _) => TextButton(
          onPressed: () => ref.invalidate(_targetSettingsProvider),
          child: const Text('设置读取失败，点此重试'),
        ),
        loading: () => const LinearProgressIndicator(),
      ),
    );
  }
}

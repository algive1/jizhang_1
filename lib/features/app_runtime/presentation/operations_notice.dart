import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/app_runtime_repository.dart';

/// Published text only; remote content cannot introduce navigation or web code.
class OperationsNotice extends ConsumerWidget {
  const OperationsNotice({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final banners =
        ref.watch(appOperationsProvider('banner')).value?.items ??
        const <AppOperation>[];
    final activities =
        ref.watch(appOperationsProvider('activity')).value?.items ??
        const <AppOperation>[];
    final items = [...banners, ...activities].take(3).toList();
    if (items.isEmpty) return const SizedBox.shrink();
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: [
          for (final item in items)
            ListTile(
              leading: const Icon(Icons.campaign_outlined),
              title: Text(
                item.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                item.body,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => showModalBottomSheet<void>(
                context: context,
                useSafeArea: true,
                showDragHandle: true,
                isScrollControlled: true,
                builder: (context) => ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.sizeOf(context).height * .7,
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          item.title,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 16),
                        Text(item.body, style: const TextStyle(height: 1.6)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

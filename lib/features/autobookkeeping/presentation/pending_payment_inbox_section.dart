import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_theme_tokens.dart';
import '../../../core/widgets/app_card.dart';
import '../auto_bookkeeping_inbox.dart';
import 'auto_bookkeeping_confirm_page.dart';

class PendingPaymentInboxSection extends ConsumerStatefulWidget {
  const PendingPaymentInboxSection({super.key});
  @override
  ConsumerState<PendingPaymentInboxSection> createState() =>
      _PendingPaymentInboxState();
}

class _PendingPaymentInboxState
    extends ConsumerState<PendingPaymentInboxSection> {
  bool _ignored = false;
  String? _busy;

  Future<void> _act(PendingPaymentReview item, {required bool ignore}) async {
    if (_busy != null) return;
    setState(() => _busy = item.candidate.fingerprint);
    final bridge = ref.read(autoBookkeepingInboxBridgeProvider);
    try {
      if (ignore) {
        await bridge.ignore(item.candidate.fingerprint);
      } else {
        if (!await bridge.select(item.candidate.fingerprint))
          throw StateError('请先处理当前确认浮层，再重试');
        if (!mounted) return;
        await showDialog<void>(
          context: context,
          barrierColor: Colors.transparent,
          barrierDismissible: false,
          builder: (_) => const AutoBookkeepingConfirmPage(
            overlayMode: true,
            embedded: true,
          ),
        );
      }
    } on Object catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('处理失败：$error')));
    } finally {
      if (mounted) {
        ref.invalidate(pendingPaymentInboxProvider);
        setState(() => _busy = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) => ref
      .watch(pendingPaymentInboxProvider)
      .when(
        loading: () => const Padding(
          padding: EdgeInsets.all(16),
          child: LinearProgressIndicator(),
        ),
        error: (error, _) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('待确认付款读取失败'),
                TextButton(
                  onPressed: () => ref.invalidate(pendingPaymentInboxProvider),
                  child: const Text('重试'),
                ),
              ],
            ),
          ),
        ),
        data: (items) {
          if (items.isEmpty) return const SizedBox.shrink();
          final pending = items.where((item) => !item.ignored).length;
          final ignored = items.length - pending;
          final visible = items.where((item) => item.ignored == _ignored);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(
                    label: Text('待确认 $pending'),
                    selected: !_ignored,
                    onSelected: (_) => setState(() => _ignored = false),
                  ),
                  ChoiceChip(
                    label: Text('已忽略 $ignored'),
                    selected: _ignored,
                    onSelected: (_) => setState(() => _ignored = true),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (visible.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(_ignored ? '暂无已忽略的付款记录' : '暂无待确认的付款记录'),
                ),
              for (final item in visible)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                item.candidate.merchant,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              '¥${(item.candidate.amountInCents / 100).toStringAsFixed(2)}',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${DateFormat('yyyy-MM-dd HH:mm:ss').format(item.candidate.timestamp)} · ${item.candidate.paymentMethod}',
                          style: TextStyle(color: context.appSecondaryText),
                        ),
                        if (item.candidate.note case final note?)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text('备注：$note'),
                          ),
                        if (item.candidate.orderId case final order?)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: SelectableText('订单号：$order'),
                          ),
                        if (item.candidate.identifierSuffix case final suffix?)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text('付款账户尾号：$suffix'),
                          ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            if (!item.ignored)
                              TextButton(
                                key: ValueKey(
                                  'payment-ignore-${item.candidate.fingerprint}',
                                ),
                                onPressed: _busy == null
                                    ? () => _act(item, ignore: true)
                                    : null,
                                child: const Text('忽略'),
                              ),
                            const Spacer(),
                            FilledButton.tonal(
                              key: ValueKey(
                                'payment-record-${item.candidate.fingerprint}',
                              ),
                              onPressed: _busy == null
                                  ? () => _act(item, ignore: false)
                                  : null,
                              child: Text(
                                _busy == item.candidate.fingerprint
                                    ? '正在处理…'
                                    : '去记账',
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      );
}

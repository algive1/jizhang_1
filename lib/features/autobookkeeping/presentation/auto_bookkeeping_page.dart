import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/database/database_provider.dart';
import '../../../core/models/transaction_record.dart';
import '../../../core/platform/app_notice.dart';
import '../../books/data/book_repository.dart';
import '../../transactions/data/transactions_repository.dart';
import '../auto_bookkeeping_inbox.dart';
import '../auto_bookkeeping_settings.dart';
import '../auto_bookkeeping_strategy.dart';
import 'auto_bookkeeping_visuals.dart';

final recentAutoBookkeepingProvider = StreamProvider<List<TransactionRecord>>((
  ref,
) {
  final database = ref.watch(databaseProvider);
  final bookId = ref.watch(activeBookIdProvider);
  final repository = ref.watch(transactionRepositoryProvider);
  final query = database.select(database.transactionEntries)
    ..where(
      (row) =>
          row.bookId.equals(bookId) &
          row.source.equals('auto') &
          row.deletedAt.isNull(),
    )
    ..orderBy([(row) => OrderingTerm.desc(row.occurredAt)])
    ..limit(2);
  return query.watch().asyncMap(
    (rows) async => [
      for (final row in rows)
        if (await repository.getById(row.id)
            case final TransactionRecord record)
          record,
    ],
  );
});

class AutoBookkeepingPage extends ConsumerStatefulWidget {
  const AutoBookkeepingPage({super.key});
  @override
  ConsumerState<AutoBookkeepingPage> createState() =>
      _AutoBookkeepingPageState();
}

class _AutoBookkeepingPageState extends ConsumerState<AutoBookkeepingPage>
    with WidgetsBindingObserver {
  AutoBookkeepingRuntimeStatus? get _status =>
      ref.read(autoBookkeepingRuntimeProvider).value;
  bool? _enabled;
  bool _busy = false;
  bool _checking = false;
  bool _connecting = false;
  int _refreshRevision = 0;
  int _toggleRevision = 0;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh({bool refreshInbox = true}) async {
    final revision = ++_refreshRevision;
    try {
      final status = await ref
          .read(autoBookkeepingRuntimeProvider.notifier)
          .refresh();
      if (mounted && revision == _refreshRevision)
        setState(() {
          _enabled = status?.enabled ?? _enabled;
        });
    } on Object {
      // The shared runtime clears a failed read instead of reporting stale health.
    }
    if (mounted && revision == _refreshRevision && refreshInbox)
      ref.invalidate(pendingPaymentInboxProvider);
  }

  Future<void> _check() async {
    if (_checking || _busy) return;
    _checking = true;
    try {
      await context.push('/profile/autobookkeeping/check');
      if (mounted) await _refresh();
    } finally {
      _checking = false;
    }
  }

  Future<void> _toggle(bool enabled) async {
    if (_busy || _checking) return;
    if (Platform.isIOS ||
        (enabled && (_status == null || _status!.diagnosisIssues.isNotEmpty))) {
      await _check();
      return;
    }
    final revision = ++_toggleRevision;
    ++_refreshRevision;
    setState(() {
      _busy = true;
      _connecting = false;
    });
    try {
      // Paint the pending state before native service startup can block a frame.
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
      await ref.read(autoBookkeepingSettingsProvider).setEnabled(enabled);
      if (!mounted || revision != _toggleRevision) return;
      setState(() => _enabled = enabled);
      await _refresh(refreshInbox: false);
      if (!mounted || revision != _toggleRevision) return;
      // The native save is complete. Service connection checks must not lock
      // the switch: users can turn it off while the service is connecting.
      setState(() {
        _busy = false;
        _connecting = enabled && _status?.healthy != true;
      });
      for (var attempt = 0; attempt < 4; attempt++) {
        if (!enabled || _status?.healthy == true || attempt == 3) break;
        await Future<void>.delayed(const Duration(milliseconds: 350));
        if (!mounted || revision != _toggleRevision) return;
        await _refresh(refreshInbox: false);
        if (!mounted || revision != _toggleRevision) return;
      }
      if (mounted && revision == _toggleRevision) {
        setState(() => _connecting = false);
        await AppNotice.show(
          context,
          enabled
              ? (_status?.healthy == true ? '自动记账已开启' : '服务未正常连接，请点击一键检测')
              : '自动记账已关闭',
        );
      }
    } on Object {
      if (mounted && revision == _toggleRevision) {
        await _refresh(refreshInbox: false);
        if (mounted && revision == _toggleRevision) {
          setState(() {
            _busy = false;
            _connecting = false;
          });
          await AppNotice.show(context, '设置失败，请重新检测');
        }
      }
    } finally {
      if (mounted && revision == _toggleRevision)
        setState(() {
          _busy = false;
          _connecting = false;
        });
    }
  }

  Future<void> _selectStrategy(AutoBookkeepingStrategy value) async {
    try {
      await ref.read(autoBookkeepingStrategyProvider.notifier).select(value);
    } on Object {
      if (mounted) await AppNotice.show(context, '策略保存失败，请重试');
    }
  }

  void _showExamples() => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('识别示例', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            const Text(
              '微信支付 · 星巴克咖啡 ¥32.00 → 餐饮美食\n\n支付宝 · 地铁 ¥4.00 → 交通出行\n\n美团 · 午餐 ¥28.50 → 餐饮美食',
            ),
            const SizedBox(height: 16),
            const Text('以上为示例。实际分类使用当前账本规则；信息不完整时保留待确认。'),
          ],
        ),
      ),
    ),
  );
  @override
  Widget build(BuildContext context) {
    final runtime = ref.watch(autoBookkeepingRuntimeProvider);
    final strategy = ref.watch(autoBookkeepingStrategyProvider);
    final saved = ref.watch(recentAutoBookkeepingProvider);
    final pending = ref.watch(pendingPaymentInboxProvider);
    final records = [
      for (final item
          in pending.asData?.value ?? const <PendingPaymentReview>[])
        if (!item.ignored)
          _AutoRecord(
            item.candidate.merchant,
            item.candidate.timestamp,
            item.candidate.paymentMethod,
            item.candidate.amountInCents / 100,
            false,
            () async {
              if (await ref
                      .read(autoBookkeepingInboxBridgeProvider)
                      .select(item.candidate.fingerprint) &&
                  context.mounted) {
                await context.push('/profile/autobookkeeping/confirm');
                if (mounted) await _refresh();
              }
            },
          ),
      for (final item in saved.asData?.value ?? const <TransactionRecord>[])
        _AutoRecord(
          item.merchant ?? item.categoryName ?? '自动记账',
          item.occurredAt,
          _paymentMethod(item),
          item.amount,
          true,
          () => context.push('/transactions/${item.id}'),
        ),
    ]..sort((a, b) => b.time.compareTo(a.time));
    return Stack(
      children: [
        const Positioned.fill(child: AutoBookkeepingBackground()),
        SafeArea(
          child: Column(
            children: [
              SizedBox(
                height: 42,
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => context.canPop()
                          ? context.pop()
                          : context.go('/profile'),
                      icon: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: Colors.white,
                        size: 21,
                      ),
                    ),
                    Expanded(
                      child: Center(
                        child: Text(
                          '自动记账',
                          style: autoText(16, weight: FontWeight.w800),
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: _showExamples,
                      icon: const Icon(
                        Icons.help_outline_rounded,
                        size: 21,
                        color: Colors.black,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _refresh,
                  child: BackdropGroup(
                    child: ListView(
                      key: const ValueKey('autobookkeeping-scroll'),
                      padding: const EdgeInsets.fromLTRB(11, 5, 11, 64),
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: AutoBookkeepingHero(
                            enabled: (_status?.enabled ?? _enabled) == true,
                            healthy: _status?.healthy == true,
                            statusMessage: runtime.isLoading
                                ? '正在检测服务状态…'
                                : _status?.summary ?? '无法读取服务状态，请重新检测',
                            busy: _busy,
                            connecting: _connecting,
                            onChanged: _busy ? null : _toggle,
                          ),
                        ),
                        const SizedBox(height: 6),
                        RecognitionSources(
                          healthy: _status?.healthy == true,
                          onCheck: _check,
                        ),
                        const SizedBox(height: 6),
                        RecognitionRules(
                          healthy: _status?.healthy == true,
                          onCheck: _check,
                        ),
                        const SizedBox(height: 6),
                        AutoConfirmationStrategies(
                          value:
                              strategy.asData?.value ??
                              AutoBookkeepingStrategy.conservative,
                          onSelected: strategy.hasValue
                              ? _selectStrategy
                              : null,
                        ),
                        const SizedBox(height: 6),
                        RecognitionExample(onMore: _showExamples),
                        const SizedBox(height: 6),
                        AutoSection(
                          title: '最近自动记账记录',
                          headerPadding: 5,
                          bottomPadding: 4,
                          more: '查看全部',
                          onMore: () => context.push('/transactions'),
                          child: AutoSurface(
                            radius: 15,
                            blur: false,
                            padding: const EdgeInsets.symmetric(horizontal: 9),
                            child: records.isEmpty
                                ? SizedBox(
                                    height: 80,
                                    child: Center(
                                      child: Text(
                                        saved.hasError || pending.hasError
                                            ? '记录读取失败，下拉重试'
                                            : '暂无自动记账记录',
                                        style: autoText(10, color: autoMuted),
                                      ),
                                    ),
                                  )
                                : Column(
                                    children: [
                                      for (final (i, record)
                                          in records.take(2).indexed)
                                        _AutoRecordRow(
                                          record,
                                          divider:
                                              i < records.take(2).length - 1,
                                        ),
                                    ],
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: SafeArea(
            top: false,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(11, 0, 11, 12),
                child: SizedBox(
                  width: 170,
                  height: 44,
                  child: AutoSurface(
                    radius: 22,
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFFFFF9D4), Color(0xFFFFD88D)],
                    ),
                    child: InkWell(
                      key: const ValueKey('autobookkeeping-check'),
                      onTap: _check,
                      borderRadius: BorderRadius.circular(22),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.settings_outlined,
                            size: 23,
                            color: autoGold,
                          ),
                          const SizedBox(width: 11),
                          Text(
                            '一键检测',
                            style: autoText(
                              14,
                              weight: FontWeight.w700,
                              color: const Color(0xFF442804),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

String _paymentMethod(TransactionRecord record) {
  try {
    final metadata = jsonDecode(record.metadataJson ?? '{}') as Map;
    return (metadata['autobookkeeping'] as Map?)?['paymentMethod']
            ?.toString() ??
        metadata['paymentChannel']?.toString() ??
        '自动识别';
  } on Object {
    return '自动识别';
  }
}

class _AutoRecord {
  const _AutoRecord(
    this.merchant,
    this.time,
    this.method,
    this.amount,
    this.saved,
    this.onTap,
  );
  final String merchant, method;
  final DateTime time;
  final double amount;
  final bool saved;
  final VoidCallback onTap;
}

class _AutoRecordRow extends StatelessWidget {
  const _AutoRecordRow(this.record, {required this.divider});
  final _AutoRecord record;
  final bool divider;
  @override
  Widget build(BuildContext context) {
    final today = DateUtils.dateOnly(DateTime.now()),
        day = DateUtils.dateOnly(record.time);
    final label = day == today
        ? '今天'
        : day == today.subtract(const Duration(days: 1))
        ? '昨天'
        : DateFormat('M月d日').format(day);
    final source = autoSources
        .where((source) => record.method.contains(source.$1))
        .firstOrNull;
    return InkWell(
      onTap: record.onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 39.25),
        padding: const EdgeInsets.symmetric(vertical: 3),
        decoration: BoxDecoration(
          border: divider
              ? const Border(
                  bottom: BorderSide(color: Color(0xFFECECF0), width: .5),
                )
              : null,
        ),
        child: Row(
          children: [
            if (record.merchant.contains('星巴克'))
              ClipOval(
                child: Image.asset(
                  'assets/images/autobookkeeping/starbucks.png',
                  width: 29,
                  height: 29,
                  fit: BoxFit.cover,
                ),
              )
            else if (record.merchant.contains('麦当劳'))
              Container(
                width: 29,
                height: 29,
                decoration: BoxDecoration(
                  color: const Color(0xFFFF8C00),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.restaurant_rounded,
                  size: 22,
                  color: Colors.white,
                ),
              )
            else if (source != null)
              AutoSourceIcon(source.$2, size: 29)
            else
              Container(
                width: 29,
                height: 29,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFA123),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.receipt_long_rounded,
                  size: 21,
                  color: Colors.white,
                ),
              ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    record.merchant,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: autoText(10.5, weight: FontWeight.w700),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '$label ${DateFormat('HH:mm').format(record.time)} · ${record.method}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: autoText(9.5, color: autoMuted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '¥ ${record.amount.toStringAsFixed(2)}',
              style: autoText(11, weight: FontWeight.w700),
            ),
            const SizedBox(width: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 4),
              decoration: BoxDecoration(
                color: record.saved
                    ? const Color(0xFFDDF9E9)
                    : const Color(0xFFFFEFD2),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Text(
                record.saved ? '已入账' : '待确认',
                style: autoText(
                  9.5,
                  weight: FontWeight.w500,
                  color: record.saved ? autoGreen : const Color(0xFFFF8B00),
                ),
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right_rounded, size: 16, color: autoMuted),
          ],
        ),
      ),
    );
  }
}

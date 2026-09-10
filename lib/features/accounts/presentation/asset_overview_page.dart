import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/formatters/money_formatter.dart';
import '../../../core/models/account.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/money_text.dart';
import '../data/account_repository.dart';
import '../domain/asset_overview.dart';
import 'account_forms.dart';

class AssetOverviewPage extends ConsumerWidget {
  const AssetOverviewPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(allAccountsProvider);
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () =>
                    context.canPop() ? context.pop() : context.go('/profile'),
                icon: const Icon(Icons.arrow_back),
                tooltip: '返回',
              ),
              Expanded(
                child: Text(
                  '资产总览',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ),
              IconButton(
                onPressed: () => showAccountEditor(
                  context,
                  sortOrder: state.value?.length ?? 0,
                ),
                icon: const Icon(Icons.add),
                tooltip: '新增账户',
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            '按账本余额计算，可校准为实际资金。各币种分别统计，归档账户仍计入合计。',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 16),
          state.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => AppCard(
              child: Column(
                children: [
                  Text('资产读取失败：$e'),
                  TextButton(
                    onPressed: () => ref.invalidate(allAccountsProvider),
                    child: const Text('重新加载'),
                  ),
                ],
              ),
            ),
            data: (accounts) => accounts.isEmpty
                ? AppCard(
                    child: Column(
                      children: [
                        const Text('先添加一个账户，记录已有存款或欠款'),
                        TextButton(
                          onPressed: () => showAccountEditor(context),
                          child: const Text('添加账户'),
                        ),
                      ],
                    ),
                  )
                : Column(
                    children: [
                      for (final group in AssetOverview.group(accounts)) ...[
                        AssetSummaryCard(overview: group),
                        const SizedBox(height: 18),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            '资金形式 · ${group.currency}',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                        const SizedBox(height: 10),
                        AppCard(
                          child: Column(
                            children: [
                              if (group.byForm.isEmpty) const Text('暂无正余额资产'),
                              for (final entry in group.byForm.entries)
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 6,
                                  ),
                                  child: Column(
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(entry.key.label),
                                          ),
                                          Text(
                                            '${MoneyFormatter.decimal(entry.value)} · ${(entry.value / group.assets * 100).toStringAsFixed(1)}%',
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      LinearProgressIndicator(
                                        value: entry.value / group.assets,
                                        color: AppColors.primary,
                                        backgroundColor: AppColors.primarySoft,
                                        borderRadius: BorderRadius.circular(3),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            '账户与渠道',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                        const SizedBox(height: 10),
                        for (final account in group.accounts)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _AccountCard(account: account),
                          ),
                        const SizedBox(height: 12),
                      ],
                    ],
                  ),
          ),
          TextButton(
            onPressed: () => context.push('/profile/accounts'),
            child: const Text('管理账户与排序'),
          ),
          const Text(
            '信用卡还款请记为「转账」：从付款账户转入信用卡，避免重复计入支出。',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class AssetSummaryCard extends StatelessWidget {
  const AssetSummaryCard({required this.overview, this.onTap, super.key});
  final AssetOverview overview;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(24),
    child: AppCard(
      color: AppColors.primarySoft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '净资产 · ${overview.currency}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              if (onTap != null) const Icon(Icons.chevron_right),
            ],
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: MoneyText(
              overview.netAssets,
              currency: overview.currency,
              style: const TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w700,
                color: AppColors.primaryDark,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 28,
            runSpacing: 12,
            children: [
              _metric(context, '账面总资产', overview.assets),
              _metric(context, '账面总负债', overview.liabilities),
            ],
          ),
          if (overview.hasUnverifiedNegativeBalance) ...[
            const SizedBox(height: 12),
            const Text(
              '部分现金、钱包或银行卡为负余额，已计入账面负债；请核对初始资金并校准。',
              style: TextStyle(fontSize: 12, color: AppColors.warning),
            ),
          ],
        ],
      ),
    ),
  );
  Widget _metric(BuildContext context, String label, double value) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
      ),
      MoneyText(
        value,
        currency: overview.currency,
        style: Theme.of(context).textTheme.titleMedium,
      ),
    ],
  );
}

class _AccountCard extends ConsumerWidget {
  const _AccountCard({required this.account});
  final Account account;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final description = account.type.isDebt
        ? (account.balance < 0 ? '欠款' : '溢缴 / 预存')
        : account.assetForm.label;
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.account_balance_wallet_outlined,
                color: AppColors.primary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  account.name,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              PopupMenuButton<String>(
                tooltip: '账户操作',
                onSelected: (action) async {
                  if (action == 'edit') {
                    await showAccountEditor(context, account: account);
                    return;
                  }
                  if (action == 'calibrate') {
                    await showBalanceCalibration(context, account);
                    return;
                  }
                  if (action == 'archive') {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (c) => AlertDialog(
                        title: const Text('归档账户？'),
                        content: const Text('历史流水和余额仍保留，继续计入资产。以后可恢复使用。'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(c, false),
                            child: const Text('取消'),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.pop(c, true),
                            child: const Text('归档'),
                          ),
                        ],
                      ),
                    );
                    if (confirmed != true) return;
                  }
                  try {
                    final repo = ref.read(accountRepositoryProvider);
                    if (action == 'restore') {
                      await repo.restore(account.id);
                    } else {
                      await repo.archive(account.id);
                    }
                  } on Object catch (error) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context)
                          .showSnackBar(SnackBar(content: Text('操作失败：$error')));
                    }
                  }
                },
                itemBuilder: (_) => [
                  if (account.isArchived)
                    const PopupMenuItem(value: 'restore', child: Text('恢复账户'))
                  else ...[
                    const PopupMenuItem(
                      value: 'calibrate',
                      child: Text('校准余额'),
                    ),
                    const PopupMenuItem(value: 'edit', child: Text('编辑账户')),
                    const PopupMenuItem(value: 'archive', child: Text('归档账户')),
                  ],
                ],
              ),
            ],
          ),
          Text(
            '${account.type.label} · $description${account.isArchived ? ' · 已归档' : ''}',
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          MoneyText(
            account.type.isDebt ? account.balance.abs() : account.balance,
            currency: account.currency,
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ],
      ),
    );
  }
}

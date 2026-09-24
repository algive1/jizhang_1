import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme_tokens.dart';
import '../../../core/formatters/money_formatter.dart';
import '../../../core/models/account.dart';
import '../../../core/widgets/app_card.dart';
import '../data/account_management_repository.dart';
import '../data/receivable_repository.dart';
import '../domain/account_management.dart';
import 'account_management_visuals.dart';

class AccountManagementPage extends ConsumerStatefulWidget {
  const AccountManagementPage({super.key});

  @override
  ConsumerState<AccountManagementPage> createState() =>
      _AccountManagementPageState();
}

class _AccountManagementPageState extends ConsumerState<AccountManagementPage> {
  _OverviewFilter _filter = _OverviewFilter.all;
  bool _hidden = false;

  @override
  Widget build(BuildContext context) {
    final accountsState = ref.watch(managedAccountsProvider);
    final receivablesState = ref.watch(receivablesProvider);
    final accounts = (accountsState.value ?? const <ManagedAccount>[])
        .where(_isManagedHere)
        .toList();
    final receivables = receivablesState.value ?? const <Receivable>[];

    final available = _accountsFor(accounts, AccountFundCategory.available);
    final stored = _accountsFor(accounts, AccountFundCategory.storedValue);
    final restricted = _accountsFor(accounts, AccountFundCategory.restricted);
    final activeReceivables = receivables
        .where(
          (item) =>
              item.status != ReceivableStatus.completed &&
              item.status != ReceivableStatus.writtenOff,
        )
        .toList();

    final availableTotal = _sumAccounts(available);
    final storedTotal = _sumAccounts(stored);
    final restrictedTotal = _sumAccounts(restricted);
    final receivableTotal = activeReceivables.fold<double>(
      0,
      (sum, item) => sum + item.remainingAmount,
    );
    final fundTotal = accounts
        .where((item) => item.includeInTotal)
        .fold<double>(0, (sum, item) => sum + item.account.balance);

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            context.appPrimarySoft.withValues(alpha: .66),
            context.appBackground,
          ],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: [
            _Header(
              onBack: () => context.canPop()
                  ? context.pop()
                  : context.go('/profile/assets'),
              onSearch: () => _openSearch(context, accounts, receivables),
            ),
            const SizedBox(height: 10),
            _SummaryCard(
              total: fundTotal,
              hidden: _hidden,
              onHiddenChanged: () => setState(() => _hidden = !_hidden),
              available: availableTotal,
              stored: storedTotal,
              restricted: restrictedTotal,
              receivable: receivableTotal,
            ),
            const SizedBox(height: 12),
            _FilterBar(
              selected: _filter,
              onSelected: (value) => setState(() => _filter = value),
            ),
            const SizedBox(height: 12),
            if (accountsState.isLoading && accounts.isEmpty)
              const Padding(
                padding: EdgeInsets.all(28),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (accountsState.hasError)
              AppCard(
                child: Text(
                  '账户读取失败：${accountsState.error}',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              )
            else ...[
              if (_filter == _OverviewFilter.all ||
                  _filter == _OverviewFilter.available)
                _AccountGroup(
                  title: '可用资金',
                  total: availableTotal,
                  accounts: available,
                  hidden: _hidden,
                  onTap: _openAccount,
                ),
              if (_filter == _OverviewFilter.all ||
                  _filter == _OverviewFilter.stored)
                _AccountGroup(
                  title: '储值资金',
                  total: storedTotal,
                  accounts: stored,
                  hidden: _hidden,
                  onTap: _openAccount,
                ),
              if (_filter == _OverviewFilter.all ||
                  _filter == _OverviewFilter.restricted)
                _AccountGroup(
                  title: '受限资金',
                  total: restrictedTotal,
                  accounts: restricted,
                  hidden: _hidden,
                  onTap: _openAccount,
                ),
              if (_filter == _OverviewFilter.all ||
                  _filter == _OverviewFilter.receivable)
                _ReceivableGroup(
                  total: receivableTotal,
                  items: activeReceivables,
                  hidden: _hidden,
                  onOpenAll: () =>
                      context.push('/profile/accounts/receivables'),
                  onTap: (item) => context.push(
                    '/profile/accounts/receivables/${item.id}',
                  ),
                ),
            ],
            const SizedBox(height: 6),
            FilledButton.icon(
              key: const ValueKey('account-management-add'),
              onPressed: () => context.push('/profile/accounts/add'),
              icon: const Icon(Icons.add_circle_outline),
              label: const Padding(
                padding: EdgeInsets.symmetric(vertical: 13),
                child: Text('添加账户'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _isManagedHere(ManagedAccount item) =>
      !item.account.type.isDebt &&
      item.account.assetForm != AssetForm.investment;

  List<ManagedAccount> _accountsFor(
    List<ManagedAccount> accounts,
    AccountFundCategory category,
  ) => accounts
      .where((item) => item.overviewCategory == category)
      .toList(growable: false);

  double _sumAccounts(List<ManagedAccount> accounts) => accounts
      .where((item) => item.includeInTotal)
      .fold<double>(0, (sum, item) => sum + item.account.balance);

  void _openAccount(ManagedAccount item) {
    if (item.category == AccountFundCategory.restricted) {
      context.push('/profile/accounts/restricted/${item.account.id}');
      return;
    }
    context.push('/profile/accounts/${item.account.id}');
  }

  Future<void> _openSearch(
    BuildContext context,
    List<ManagedAccount> accounts,
    List<Receivable> receivables,
  ) {
    return showSearch<void>(
      context: context,
      delegate: _AccountSearchDelegate(accounts, receivables),
    );
  }
}

enum _OverviewFilter { all, available, stored, restricted, receivable }

class _Header extends StatelessWidget {
  const _Header({required this.onBack, required this.onSearch});
  final VoidCallback onBack;
  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      IconButton(onPressed: onBack, icon: const Icon(Icons.arrow_back)),
      Expanded(
        child: Text(
          '账户总览',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      IconButton(onPressed: onSearch, icon: const Icon(Icons.search)),
    ],
  );
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.total,
    required this.hidden,
    required this.onHiddenChanged,
    required this.available,
    required this.stored,
    required this.restricted,
    required this.receivable,
  });

  final double total;
  final bool hidden;
  final VoidCallback onHiddenChanged;
  final double available;
  final double stored;
  final double restricted;
  final double receivable;

  @override
  Widget build(BuildContext context) => AppCard(
    color: context.appSurface.withValues(alpha: .90),
    borderRadius: 22,
    child: Stack(
      children: [
        const Positioned(
          right: -6,
          top: -4,
          child: AccountLeafPlaceholder(size: 112, opacity: .16),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  '账户资金总额',
                  style: TextStyle(
                    color: context.appSecondaryText,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(width: 6),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints.tightFor(
                    width: 28,
                    height: 28,
                  ),
                  onPressed: onHiddenChanged,
                  icon: Icon(
                    hidden
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    size: 17,
                    color: context.appSecondaryText,
                  ),
                ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.only(right: 72),
                  child: Text(
                    '每一份资金\n都是生活的底气',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: context.appPrimary.withValues(alpha: .64),
                      fontSize: 10,
                      height: 1.35,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              hidden ? '••••••' : '¥${MoneyFormatter.decimal(total)}',
              style: const TextStyle(fontSize: 29, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _SummaryMetric(
                    icon: Icons.account_balance_wallet_outlined,
                    label: '可用资金',
                    value: available,
                    color: context.appPrimary,
                    hidden: hidden,
                  ),
                ),
                Expanded(
                  child: _SummaryMetric(
                    icon: Icons.toll_outlined,
                    label: '储值资金',
                    value: stored,
                    color: const Color(0xffE79B3A),
                    hidden: hidden,
                  ),
                ),
                Expanded(
                  child: _SummaryMetric(
                    icon: Icons.lock_outline_rounded,
                    label: '受限资金',
                    value: restricted,
                    color: const Color(0xff5B8DEF),
                    hidden: hidden,
                  ),
                ),
                Expanded(
                  child: _SummaryMetric(
                    icon: Icons.schedule_rounded,
                    label: '应收资金',
                    value: receivable,
                    color: const Color(0xff8867D8),
                    hidden: hidden,
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    ),
  );
}

class _SummaryMetric extends StatelessWidget {
  const _SummaryMetric({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.hidden,
  });

  final IconData icon;
  final String label;
  final double value;
  final Color color;
  final bool hidden;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: color.withValues(alpha: .12),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 17, color: color),
      ),
      const SizedBox(height: 5),
      Text(label, style: TextStyle(fontSize: 10, color: context.appSecondaryText)),
      const SizedBox(height: 2),
      FittedBox(
        child: Text(
          hidden ? '••••' : MoneyFormatter.decimal(value),
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        ),
      ),
    ],
  );
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({required this.selected, required this.onSelected});
  final _OverviewFilter selected;
  final ValueChanged<_OverviewFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    final items = <(_OverviewFilter, String)>[
      (_OverviewFilter.all, '全部'),
      (_OverviewFilter.available, '可用'),
      (_OverviewFilter.stored, '储值'),
      (_OverviewFilter.restricted, '受限'),
      (_OverviewFilter.receivable, '应收'),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(item.$2),
                selected: selected == item.$1,
                onSelected: (_) => onSelected(item.$1),
              ),
            ),
        ],
      ),
    );
  }
}

class _AccountGroup extends StatelessWidget {
  const _AccountGroup({
    required this.title,
    required this.total,
    required this.accounts,
    required this.hidden,
    required this.onTap,
  });

  final String title;
  final double total;
  final List<ManagedAccount> accounts;
  final bool hidden;
  final ValueChanged<ManagedAccount> onTap;

  @override
  Widget build(BuildContext context) {
    if (accounts.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        padding: const EdgeInsets.fromLTRB(14, 13, 14, 5),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '$title（${accounts.length}）',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                Text(
                  hidden ? '••••' : '¥${MoneyFormatter.decimal(total)}',
                  style: TextStyle(
                    color: context.appPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            for (var index = 0; index < accounts.length; index++) ...[
              _AccountRow(
                item: accounts[index],
                hidden: hidden,
                onTap: () => onTap(accounts[index]),
              ),
              if (index != accounts.length - 1)
                Divider(height: 1, color: context.appDivider),
            ],
          ],
        ),
      ),
    );
  }
}

class _AccountRow extends StatelessWidget {
  const _AccountRow({
    required this.item,
    required this.hidden,
    required this.onTap,
  });

  final ManagedAccount item;
  final bool hidden;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: _color(item).withValues(alpha: .13),
            child: Icon(_icon(item), color: _color(item), size: 19),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.account.displayName,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                if ((item.platform ?? '').isNotEmpty)
                  Text(
                    item.platform!,
                    style: TextStyle(fontSize: 11, color: context.appSecondaryText),
                  ),
              ],
            ),
          ),
          Text(
            hidden
                ? '••••'
                : '¥${MoneyFormatter.decimal(item.account.balance)}',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(width: 4),
          Icon(Icons.chevron_right, size: 18, color: context.appSecondaryText),
        ],
      ),
    ),
  );

  IconData _icon(ManagedAccount item) {
    if (item.category == AccountFundCategory.restricted) {
      return Icons.lock_outline_rounded;
    }
    if (item.category == AccountFundCategory.storedValue) {
      return Icons.toll_outlined;
    }
    return switch (item.account.type) {
      AccountType.cash => Icons.payments_outlined,
      AccountType.wechat => Icons.chat_bubble_outline,
      AccountType.alipay => Icons.account_balance_wallet_outlined,
      AccountType.debitCard => Icons.account_balance_outlined,
      _ => Icons.wallet_outlined,
    };
  }

  Color _color(ManagedAccount item) {
    if (item.category == AccountFundCategory.restricted) {
      return const Color(0xff5B8DEF);
    }
    if (item.category == AccountFundCategory.storedValue) {
      return const Color(0xffE79B3A);
    }
    return Color(item.account.color);
  }
}

class _ReceivableGroup extends StatelessWidget {
  const _ReceivableGroup({
    required this.total,
    required this.items,
    required this.hidden,
    required this.onOpenAll,
    required this.onTap,
  });

  final double total;
  final List<Receivable> items;
  final bool hidden;
  final VoidCallback onOpenAll;
  final ValueChanged<Receivable> onTap;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        padding: const EdgeInsets.fromLTRB(14, 13, 14, 5),
        child: Column(
          children: [
            InkWell(
              onTap: onOpenAll,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '应收资金（${items.length}）',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  Text(
                    hidden ? '••••' : '¥${MoneyFormatter.decimal(total)}',
                    style: const TextStyle(
                      color: Color(0xff8867D8),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Icon(Icons.chevron_right, size: 18),
                ],
              ),
            ),
            const SizedBox(height: 8),
            for (var index = 0; index < items.length; index++) ...[
              InkWell(
                onTap: () => onTap(items[index]),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: const Color(0xff8867D8).withValues(alpha: .12),
                        child: Icon(
                          items[index].type == ReceivableType.reimbursement
                              ? Icons.flight_takeoff_outlined
                              : items[index].type == ReceivableType.refund
                              ? Icons.shopping_cart_outlined
                              : Icons.schedule_rounded,
                          color: const Color(0xff8867D8),
                          size: 19,
                        ),
                      ),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              items[index].name,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              items[index].visibleStatus,
                              style: TextStyle(
                                fontSize: 11,
                                color: context.appSecondaryText,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        hidden
                            ? '••••'
                            : '¥${MoneyFormatter.decimal(items[index].remainingAmount)}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
              ),
              if (index != items.length - 1)
                Divider(height: 1, color: context.appDivider),
            ],
          ],
        ),
      ),
    );
  }
}

class _AccountSearchDelegate extends SearchDelegate<void> {
  _AccountSearchDelegate(this.accounts, this.receivables);

  final List<ManagedAccount> accounts;
  final List<Receivable> receivables;

  @override
  String get searchFieldLabel => '搜索账户、平台或应收';

  @override
  List<Widget>? buildActions(BuildContext context) => [
    if (query.isNotEmpty)
      IconButton(onPressed: () => query = '', icon: const Icon(Icons.close)),
  ];

  @override
  Widget? buildLeading(BuildContext context) => IconButton(
    onPressed: () => close(context, null),
    icon: const Icon(Icons.arrow_back),
  );

  @override
  Widget buildResults(BuildContext context) => _results(context);

  @override
  Widget buildSuggestions(BuildContext context) => _results(context);

  Widget _results(BuildContext context) {
    final keyword = query.trim().toLowerCase();
    final accountMatches = accounts.where((item) {
      if (keyword.isEmpty) return true;
      return item.account.displayName.toLowerCase().contains(keyword) ||
          (item.platform ?? '').toLowerCase().contains(keyword);
    }).toList();
    final receivableMatches = receivables.where((item) {
      if (keyword.isEmpty) return true;
      return item.name.toLowerCase().contains(keyword) ||
          item.counterparty.toLowerCase().contains(keyword);
    }).toList();

    return ListView(
      children: [
        for (final item in accountMatches)
          ListTile(
            leading: const Icon(Icons.account_balance_wallet_outlined),
            title: Text(item.account.displayName),
            subtitle: Text(item.category.label),
            onTap: () {
              close(context, null);
              if (item.category == AccountFundCategory.restricted) {
                context.push('/profile/accounts/restricted/${item.account.id}');
              } else {
                context.push('/profile/accounts/${item.account.id}');
              }
            },
          ),
        for (final item in receivableMatches)
          ListTile(
            leading: const Icon(Icons.schedule_outlined),
            title: Text(item.name),
            subtitle: Text('${item.counterparty} · ${item.visibleStatus}'),
            onTap: () {
              close(context, null);
              context.push('/profile/accounts/receivables/${item.id}');
            },
          ),
        if (accountMatches.isEmpty && receivableMatches.isEmpty)
          const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: Text('没有找到匹配结果')),
          ),
      ],
    );
  }
}

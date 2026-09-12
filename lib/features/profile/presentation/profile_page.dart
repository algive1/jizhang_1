import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/database/app_database.dart';
import '../../../core/formatters/money_formatter.dart';
import '../../../core/models/book.dart';
import '../../../core/models/membership.dart';
import '../../accounts/data/account_repository.dart';
import '../../books/data/book_repository.dart';
import '../../books/presentation/book_selector.dart';
import '../../budgets/data/budget_repository.dart';
import '../../categories/data/category_repository.dart';
import '../../membership/data/membership_repository.dart';
import '../../recurring/data/recurring_bill_repository.dart';
import '../../sharing/data/session_repository.dart';
import '../../transactions/data/transactions_repository.dart';
import '../data/profile_stats.dart';
import 'profile_cards.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accounts = ref.watch(allAccountsProvider);
    final categories = ref.watch(categoriesProvider);
    final transactions = ref.watch(allTransactionsProvider);
    final books = ref.watch(booksProvider);
    final photos = ref.watch(profilePhotosProvider);
    final recurring = ref.watch(recurringBillsProvider);
    final budget = ref.watch(budgetOverviewProvider).total;
    final membership = ref.watch(membershipProvider);
    final user = ref.watch(sessionProvider);
    final activity = ProfileActivity(transactions.value ?? [], DateTime.now());
    void push(String route) => context.push(route);
    void calendar() => push('/transactions/calendar');
    String count(AsyncValue<List<dynamic>> value, String unit) => value.hasError
        ? '读取失败'
        : value.hasValue
        ? '${value.value!.length}$unit'
        : '—';
    final errors = [
      accounts,
      categories,
      transactions,
      books,
      photos,
      recurring,
      membership,
      user,
    ].where((s) => s.hasError);
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFEEF2DE), profileCream, Color(0xFFF8F7EF)],
          stops: [0, .3, 1],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 130),
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    '我的',
                    style: TextStyle(
                      fontSize: 27,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF10140E),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: '设置',
                  onPressed: () => _settings(context),
                  icon: const Icon(Icons.settings_outlined, size: 25),
                ),
                IconButton(
                  tooltip: '通知',
                  onPressed: () => push('/profile/payment-notifications'),
                  icon: const Icon(Icons.notifications_none_outlined, size: 25),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ProfileHero(
              name: user.value?.username ?? '本地用户',
              days: transactions.hasValue ? '${activity.bookkeepingDays}' : '—',
              onTap: () => _profile(context, user.value),
            ),
            ProfileMembershipCard(
              snapshot: membership.value,
              onTap: () => push('/profile/membership'),
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: ProfileQuickStat(
                    icon: Icons.savings,
                    color: AppColors.primary,
                    value: '未开放',
                    label: '我的积分',
                    onTap: () =>
                        _info(context, '我的积分', '当前版本尚未上线积分服务，没有可查询的积分余额。'),
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: ProfileQuickStat(
                    icon: Icons.event_available,
                    color: const Color(0xFFF39558),
                    value: transactions.hasValue
                        ? '${activity.bookkeepingDays} 天'
                        : '—',
                    label: '记账天数',
                    onTap: calendar,
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: ProfileQuickStat(
                    icon: Icons.image,
                    color: const Color(0xFF74BEE4),
                    value: count(photos, ' 张'),
                    label: '记账照片',
                    onTap: () => _photos(context),
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: ProfileQuickStat(
                    icon: Icons.people,
                    color: const Color(0xFFA298E6),
                    value: count(books, ' 个'),
                    label: '我的账本',
                    onTap: () => showBookSelectorSheet(context, ref),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ProfileMonthlyCard(
              activity: activity,
              onTap: calendar,
              loading: !transactions.hasValue,
            ),
            const SizedBox(height: 10),
            ProfileMenuCard(
              items: [
                ProfileMenuItem(
                  Icons.home_outlined,
                  '共享账本',
                  '家庭、情侣、企业账本',
                  () => push('/profile/family'),
                ),
                ProfileMenuItem(
                  Icons.people_outline,
                  '账户与资产',
                  count(accounts, ' 个账户'),
                  () => push('/profile/assets'),
                ),
                ProfileMenuItem(
                  Icons.sell_outlined,
                  '分类管理',
                  count(categories, ' 个分类'),
                  () => push('/profile/categories'),
                ),
                ProfileMenuItem(
                  Icons.savings_outlined,
                  '预算管理',
                  budget == null
                      ? '未设置预算'
                      : '还剩 ¥${MoneyFormatter.whole(budget.remaining)}',
                  () => push('/profile/budgets'),
                ),
                ProfileMenuItem(
                  Icons.event_repeat_outlined,
                  '周期账单',
                  count(recurring, ' 个进行中'),
                  () => push('/profile/recurring-bills'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ProfileMenuCard(
              items: [
                ProfileMenuItem(
                  Icons.cloud_outlined,
                  '数据与安全',
                  membership.value?.has(EntitlementKey.cloudSync) == true
                      ? '云同步权益 · 导出 CSV'
                      : '本地备份 · 导出 CSV',
                  () => push('/profile/data'),
                ),
                ProfileMenuItem(
                  Icons.notifications_none,
                  '支付通知记账',
                  'Android 可开启',
                  () => push('/profile/payment-notifications'),
                ),
                ProfileMenuItem(
                  Icons.checkroom_outlined,
                  '个性化设置',
                  '主题、字体、图标',
                  () => _info(
                    context,
                    '个性化设置',
                    '当前使用草木绿主题，字体跟随系统。当前版本尚不支持切换主题、字体与图标。',
                  ),
                ),
                ProfileMenuItem(
                  Icons.help_outline,
                  '帮助与反馈',
                  '常见问题 · 使用说明',
                  () => _info(
                    context,
                    '帮助与反馈',
                    '在首页记账，在流水中编辑或删除记录，在账户、分类和预算页管理数据。\n\n设置内可管理信用卡分期和支付提醒。当前版本没有联网客服入口；反馈时请保留发生问题的时间和页面。',
                  ),
                ),
              ],
            ),
            if (errors.isNotEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Text(
                  '部分数据读取失败，请重新进入页面重试。',
                  style: TextStyle(color: AppColors.warning, fontSize: 12),
                ),
              ),
          ],
        ),
      ),
    );
  }

  static void _info(BuildContext context, String title, String message) =>
      showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('知道了'),
            ),
          ],
        ),
      );

  static void _profile(BuildContext context, SessionUser? user) =>
      showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (sheetContext) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user?.username ?? '本地用户',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                Text(
                  user == null
                      ? '当前使用本地记账。登录后可使用共享账本。'
                      : '已登录共享账本账号。头像为应用默认头像。',
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    context.push('/profile/family');
                  },
                  child: Text(user == null ? '登录 / 注册' : '管理共享账本'),
                ),
              ],
            ),
          ),
        ),
      );

  static void _settings(BuildContext context) => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const ListTile(title: Text('设置')),
          for (final item in [
            ('信用卡分期', '/profile/installments'),
            ('提醒设置', '/profile/payment-notifications'),
            ('数据与安全', '/profile/data'),
          ])
            ListTile(
              title: Text(item.$1),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.pop(sheetContext);
                context.push(item.$2);
              },
            ),
        ],
      ),
    ),
  );

  static void _photos(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => FractionallySizedBox(
        heightFactor: .7,
        child: Consumer(
          builder: (context, ref, _) {
            final photos = ref.watch(profilePhotosProvider);
            return _ProfilePhotosSheet(
              photos: photos,
              books: ref.watch(booksProvider).value ?? const [],
              onTap: (item) {
                Navigator.pop(sheetContext);
                context.push('/transactions/${item.transactionId}');
              },
            );
          },
        ),
      ),
    );
  }
}

class _ProfilePhotosSheet extends StatefulWidget {
  const _ProfilePhotosSheet({
    required this.photos,
    required this.books,
    required this.onTap,
  });

  final AsyncValue<List<TransactionAttachmentEntity>> photos;
  final List<LedgerBook> books;
  final void Function(TransactionAttachmentEntity item) onTap;

  @override
  State<_ProfilePhotosSheet> createState() => _ProfilePhotosSheetState();
}

class _ProfilePhotosSheetState extends State<_ProfilePhotosSheet> {
  String? _selectedBookId;

  @override
  Widget build(BuildContext context) {
    final books = widget.books.take(4).toList(growable: false);
    final selectedBook = books
        .where((book) => book.id == _selectedBookId)
        .firstOrNull;
    final items = _selectedBookId == null
        ? widget.photos.value ?? const <TransactionAttachmentEntity>[]
        : (widget.photos.value ?? const <TransactionAttachmentEntity>[])
              .where((item) => item.bookId == _selectedBookId)
              .toList(growable: false);
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Column(
              children: [
                Text(
                  '记账照片 · ${selectedBook == null ? '全部账本' : _bookLabel(selectedBook.name)}',
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _filter('全部', null),
                      for (final book in books) ...[
                        const SizedBox(width: 8),
                        _filter(_bookLabel(book.name), book.id),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(child: _photosContent(items)),
        ],
      ),
    );
  }

  Widget _photosContent(List<TransactionAttachmentEntity> items) {
    return widget.photos.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => const Center(child: Text('照片读取失败，请稍后重试')),
      data: (_) => items.isEmpty
          ? Center(
              child: Text(
                _selectedBookId == null ? '暂无记账照片，可在记账时添加附件' : '该账本暂无记账照片',
              ),
            )
          : GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
              ),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                return InkWell(
                  onTap: () => widget.onTap(item),
                  child: Image.file(
                    File(item.path),
                    fit: BoxFit.cover,
                    errorBuilder: (_, error, stack) =>
                        const Center(child: Icon(Icons.broken_image_outlined)),
                  ),
                );
              },
            ),
    );
  }

  Widget _filter(String label, String? bookId) {
    return FilterChip(
      key: ValueKey('profile-photo-filter-${bookId ?? 'all'}'),
      label: Text(label),
      selected: _selectedBookId == bookId,
      onSelected: (_) => setState(() => _selectedBookId = bookId),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  String _bookLabel(String name) {
    final value = name.trim();
    if (value.isEmpty) return '账本';
    return value.substring(0, value.length < 3 ? value.length : 3);
  }
}

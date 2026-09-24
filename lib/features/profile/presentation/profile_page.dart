import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/database/app_database.dart';
import '../../../core/formatters/money_formatter.dart';
import '../../../core/models/book.dart';
import '../../../core/models/membership.dart';
import '../../../core/widgets/app_bottom_sheet.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../account/application/account_session_controller.dart';
import '../../account/domain/account_session.dart';
import '../../account/domain/account_session_status.dart';
import '../../accounts/data/account_repository.dart';
import '../../books/data/book_repository.dart';
import '../../books/presentation/book_selector.dart';
import '../../budgets/data/budget_repository.dart';
import '../../categories/data/category_repository.dart';
import '../../membership/data/membership_repository.dart';
import '../../messages/application/system_message_service.dart';
import '../../recurring/data/recurring_bill_repository.dart';
import '../../sharing/data/session_repository.dart';
import '../../transactions/data/transactions_repository.dart';
import '../data/profile_stats.dart';
import 'profile_cards.dart';
import '../../../app/theme/app_theme_tokens.dart';

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
    final systemUnread = ref.watch(systemUnreadCountProvider).value ?? 0;
    final accountSession = ref.watch(accountSessionProvider);
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
      accountSession,
    ].where((s) => s.hasError);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            context.appPrimarySoft.withValues(alpha: .72),
            context.appBackground,
            context.appSurfaceSoft.withValues(alpha: .64),
          ],
          stops: const [0, .3, 1],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: ListView(
          // The glass bar floats over the page, so the profile list has to
          // clear its whole footprint rather than a hand-tuned constant.
          padding: EdgeInsets.fromLTRB(
            16,
            6,
            16,
            AppScaffold.reservedBottomInset(context),
          ),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '我的',
                    style: TextStyle(
                      fontSize: 27,
                      fontWeight: FontWeight.w800,
                      color: context.appPrimaryText,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: '设置',
                  onPressed: () => _settings(context),
                  icon: const Icon(Icons.settings_outlined, size: 25),
                ),
                IconButton(
                  tooltip: '消息',
                  onPressed: () async {
                    await context.push<void>('/profile/messages');
                    ref.invalidate(systemUnreadCountProvider);
                  },
                  icon: Badge(
                    isLabelVisible: systemUnread > 0,
                    label: Text(systemUnread > 99 ? '99+' : '$systemUnread'),
                    child: const Icon(Icons.smart_toy_outlined, size: 25),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ProfileHero(
              name: _profileName(accountSession.value),
              days: transactions.hasValue ? '${activity.bookkeepingDays}' : '—',
              onTap: () => _profile(context, ref, accountSession.value),
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
                    color: context.appPrimary,
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
                  Icons.document_scanner_outlined,
                  '小票识别',
                  '本地 OCR · 确认后记账',
                  () => push('/profile/receipt-ocr'),
                ),
                ProfileMenuItem(
                  Icons.upload_file_outlined,
                  '账单导入',
                  '微信 · 支付宝 CSV',
                  () => push('/profile/bill-import'),
                ),
                ProfileMenuItem(
                  Icons.receipt_long_outlined,
                  '财税与账单',
                  '发票 · 报税台账 · 银行卡账单',
                  () => push('/profile/finance-center'),
                ),
                ProfileMenuItem(
                  Icons.event_repeat_outlined,
                  '周期账单',
                  count(recurring, ' 个进行中'),
                  () => push('/profile/recurring-bills'),
                ),
                ProfileMenuItem(
                  Icons.auto_awesome_outlined,
                  '自动记账',
                  '微信支付识别 · 常驻通知',
                  () => push('/profile/autobookkeeping'),
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
                  '主题外观',
                  () => push('/profile/appearance'),
                ),
                ProfileMenuItem(
                  Icons.help_outline,
                  '帮助与反馈',
                  '使用手册 · 在线工单',
                  () => push('/profile/help'),
                ),
                ProfileMenuItem(
                  Icons.description_outlined,
                  '服务协议',
                  '用户协议 · 隐私协议 · 会员服务协议',
                  () => push('/profile/legal'),
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
          content: SingleChildScrollView(child: Text(message)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('知道了'),
            ),
          ],
        ),
      );

  static String _profileName(AccountSession? session) {
    final user = session?.user;
    if (user != null) return user.preferredName;
    return session?.status == AccountSessionStatus.initializing ? '正在读取账号…' : '本地使用中';
  }

  static void _profile(
    BuildContext context,
    WidgetRef ref,
    AccountSession? session,
  ) {
    final status = session?.status ?? AccountSessionStatus.initializing;
    final user = session?.user;
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                user?.preferredName ??
                    (status == AccountSessionStatus.initializing
                        ? '正在读取账号…'
                        : '本地使用中'),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              if (user != null) ...[
                const SizedBox(height: 4),
                Text(
                  '@${user.username}',
                  style: TextStyle(color: context.appSecondaryText),
                ),
              ],
              const SizedBox(height: 12),
              Text(
                switch (status) {
                  AccountSessionStatus.authenticated =>
                    '已登录好好记账账号。退出登录不会删除本机的个人账务数据。',
                  AccountSessionStatus.expired =>
                    '登录状态已失效。重新登录后可继续使用会员和共享功能，本地记账不受影响。',
                  AccountSessionStatus.error =>
                    '暂时无法读取账户状态。本地记账仍可继续使用。',
                  AccountSessionStatus.initializing => '正在读取账户状态…',
                  AccountSessionStatus.guest =>
                    '当前使用本地记账。登录后可使用会员、共享账本与后续云同步能力。',
                },
              ),
              const SizedBox(height: 16),
              if (status == AccountSessionStatus.authenticated) ...[
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
                      Navigator.pop(sheetContext);
                      context.push('/profile/account');
                    },
                    child: const Text('进入账号中心'),
                  ),
                ),
                TextButton(
                  onPressed: () async {
                    Navigator.pop(sheetContext);
                    await ref.read(sessionRepositoryProvider).logout();
                  },
                  child: const Text('退出登录'),
                ),
              ] else if (status == AccountSessionStatus.initializing)
                const Center(child: CircularProgressIndicator())
              else ...[
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
                      Navigator.pop(sheetContext);
                      context.push('/account/login');
                    },
                    child: Text(
                      status == AccountSessionStatus.expired ? '重新登录' : '登录',
                    ),
                  ),
                ),
                if (status != AccountSessionStatus.expired)
                  TextButton(
                    onPressed: () {
                      Navigator.pop(sheetContext);
                      context.push('/account/register');
                    },
                    child: const Text('创建账号'),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  static void _settings(BuildContext context) => AppBottomSheet.show<void>(
    context: context,
    builder: (sheetContext) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const ListTile(title: Text('设置')),
        for (final item in [
          ('信用卡分期', '/profile/installments'),
          ('财税与账单', '/profile/finance-center'),
          ('通知设置', '/profile/notification-settings'),
          ('自动记账', '/profile/autobookkeeping'),
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
        const Divider(height: 1),
        ListTile(
          leading: const Icon(Icons.menu_book_outlined),
          title: const Text('使用手册'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            Navigator.pop(sheetContext);
            context.push('/profile/help');
          },
        ),
        ListTile(
          leading: const Icon(Icons.feedback_outlined),
          title: const Text('反馈建议'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            Navigator.pop(sheetContext);
            context.push('/profile/feedback');
          },
        ),
        ListTile(
          leading: const Icon(Icons.info_outline),
          title: const Text('关于好好记账'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            Navigator.pop(sheetContext);
            context.push('/profile/about');
          },
        ),
      ],
    ),
  );

  static void _photos(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
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

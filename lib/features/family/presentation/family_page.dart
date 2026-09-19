import '../../../core/widgets/app_action_sheet.dart';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/formatters/money_formatter.dart';
import '../../../core/models/transaction_record.dart';
import '../../account/application/account_auth_gate.dart';
import '../../account/application/account_pending_intent.dart';
import '../../account/application/account_session_controller.dart';
import '../../account/domain/account_session_status.dart';
import '../../../core/models/family.dart';
import '../../../core/widgets/app_card.dart';
import '../../books/data/book_repository.dart';
import '../../books/presentation/book_selector.dart';
import '../../sharing/data/session_repository.dart';
import '../../sharing/application/shared_book_sync_service.dart';
import '../../transactions/data/transactions_repository.dart';
import '../data/shared_family_service.dart';
import 'unavailable_drafts_card.dart';

class FamilyPage extends ConsumerStatefulWidget {
  const FamilyPage({super.key});
  @override
  ConsumerState<FamilyPage> createState() => _FamilyPageState();
}

class _FamilyPageState extends ConsumerState<FamilyPage> {
  final _code = TextEditingController();
  bool _busy = false;
  String? _error;
  List<Json> _members = [];
  List<FamilyInvitation> _invitations = [];
  String? _loadedBook;
  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _joinInvitationWithGate() async {
    final code = _code.text.trim();
    if (code.isEmpty) {
      setState(() => _error = '请输入邀请码');
      return;
    }
    final intent = AccountPendingIntent(
      id: 'join-shared:${DateTime.now().microsecondsSinceEpoch}',
      action: AccountPendingAction.joinSharedLedger,
      returnLocation: '/profile/family',
    );
    final allowed = await AccountAuthGate.requireLogin(
      context,
      ref,
      reason: AccountAuthReason.sharedLedger,
      intent: intent,
    );
    if (!mounted || !allowed) return;
    final pending = ref.read(accountPendingIntentProvider).consume(intent.id);
    if (pending == null) return;

    await _run(() async {
      final member = await ref
          .read(familyServiceProvider)
          .acceptInvitation(code);
      _code.clear();
      final joined =
          (await ref.read(bookRepositoryProvider).getForUser('user-local'))
              .firstWhere((b) => b.sharedId == member.familyId);
      await ref.read(activeBookIdProvider.notifier).select(joined.id);
      _loadedBook = null;
    });
  }

  Future<void> _loadMembers() async {
    final book = ref.read(activeBookProvider);
    if (book?.sharedId == null) return;
    final service = ref.read(familyServiceProvider);
    final members = await service.memberDetails(book!.sharedId!);
    final invites = book.canManage
        ? await service.invitations(book.sharedId!)
        : <FamilyInvitation>[];
    if (mounted)
      setState(() {
        _members = members;
        _invitations = invites;
      });
  }

  Future<bool> _confirm(String title, String body) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: SingleChildScrollView(child: Text(body)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('确认'),
            ),
          ],
        ),
      ) ??
      false;
  Widget _memberSpendingCard(List<TransactionRecord> transactions) {
    final now = DateTime.now();
    final spending = <String, double>{};
    for (final transaction in transactions) {
      if (!transaction.isConsumptionExpense ||
          transaction.deletedAt != null ||
          transaction.occurredAt.year != now.year ||
          transaction.occurredAt.month != now.month) continue;
      final payer = transaction.userId;
      if (payer == null) continue;
      spending.update(payer, (value) => value + transaction.netExpenseAmount,
          ifAbsent: () => transaction.netExpenseAmount);
    }
    final total = spending.values.fold<double>(0, (sum, value) => sum + value);
    final rows = _members.map((member) {
      final id = member['user_id'] as String;
      final displayName =
          (member['display_name'] as String?)?.trim().isNotEmpty == true
          ? member['display_name'] as String
          : member['username'] as String;
      return (id: id, name: displayName, amount: spending[id] ?? 0);
    }).toList()
      ..sort((a, b) => b.amount.compareTo(a.amount));

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('本月成员消费',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text('家庭消费 ¥${MoneyFormatter.decimal(total)}',
              style: const TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 12),
          if (rows.isEmpty)
            const Text('暂无成员消费记录')
          else
            for (final row in rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(children: [
                  const Icon(Icons.person_outline_rounded, size: 20),
                  const SizedBox(width: 8),
                  Expanded(child: Text(row.name)),
                  Text('¥${MoneyFormatter.decimal(row.amount)}',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                ]),
              ),
          const SizedBox(height: 4),
          const Text('按流水付款成员归属统计；记录人和付款人可以不同。',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final accountState = ref.watch(accountSessionProvider);
    final session = accountState.value;
    final user = session?.user;
    final accountStatus = session?.status ?? AccountSessionStatus.initializing;
    final book = ref.watch(activeBookProvider);
    final sync = ref.watch(activeSharedStateProvider).value;
    final pending = (sync?['pending'] as List? ?? []).cast<Json>();
    final familyTransactions = book?.type == BookType.family && book != null
        ? ref.watch(transactionsByBookProvider(book.id)).value ?? const <TransactionRecord>[]
        : const <TransactionRecord>[];
    if (user != null &&
        book?.sharedId != null &&
        book!.sharedPhase != 'promoting' &&
        _loadedBook != book.id) {
      _loadedBook = book.id;
      _members = [];
      _invitations = [];
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _run(_loadMembers);
      });
    }
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
        children: [
          Row(
            children: [
              IconButton(
                onPressed: context.pop,
                icon: const Icon(Icons.arrow_back),
              ),
              const Expanded(
                child: Text(
                  '共享账本',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.only(left: 12, bottom: 4),
            child: Row(
              children: [
                Text(
                  '家庭共享',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
                Text(
                  ' · 企业协作',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (_busy) const LinearProgressIndicator(),
          if (_error != null || accountState.hasError)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Text(
                _error ?? '无法读取登录状态，请重试',
                style: const TextStyle(color: AppColors.warning),
              ),
            ),
          if (accountStatus == AccountSessionStatus.initializing)
            const AppCard(
              child: Row(
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 12),
                  Expanded(child: Text('正在读取账户状态…')),
                ],
              ),
            )
          else if (user == null)
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    accountStatus == AccountSessionStatus.expired
                        ? '登录状态已失效'
                        : accountStatus == AccountSessionStatus.error
                        ? '账户状态暂不可用'
                        : '登录后即可共享',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    accountStatus == AccountSessionStatus.expired
                        ? '重新登录后可继续使用共享账本。本地个人账务数据不会受到影响。'
                        : '家庭和企业账本支持整本共享。登录只建立服务器身份，不会自动上传或认领本地个人账务数据。',
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _busy ? null : () => context.push('/account/login'),
                    child: Text(
                      accountStatus == AccountSessionStatus.expired
                          ? '重新登录'
                          : '登录',
                    ),
                  ),
                  if (accountStatus != AccountSessionStatus.expired)
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () => context.push('/account/register'),
                      child: const Text('创建新账号'),
                    ),
                ],
              ),
            ),
          if (user == null &&
              accountStatus != AccountSessionStatus.initializing) ...[
            const SizedBox(height: 12),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    '有邀请码？',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  const Text('输入邀请码后继续。需要账号时会先登录，成功后自动完成加入。'),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _code,
                    decoration: const InputDecoration(labelText: '邀请码'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: _busy ? null : _joinInvitationWithGate,
                    child: const Text('加入共享账本'),
                  ),
                ],
              ),
            ),
          ],
          if (user != null) ...[
            AppCard(
              child: Row(
                children: [
                  const Icon(Icons.account_circle_outlined),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(user.preferredName),
                        if (user.preferredName != user.username)
                          Text(
                            '@${user.username}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () => _run(() async {
                            if (await _confirm(
                              '退出登录',
                              '共享缓存将隐藏。未提交的修改会保留，重新登录后可继续处理。',
                            ))
                              await ref
                                  .read(sessionRepositoryProvider)
                                  .logout();
                          }),
                    child: const Text('退出登录'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const BookSelectorButton(),
            const SizedBox(height: 12),
            if (book != null && !book.isShared)
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      book.type == BookType.personal
                          ? '个人账本仅在本机使用'
                          : '${book.name} · 本地账本',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      book.type == BookType.personal
                          ? '请从书架选择或新建家庭、企业账本，再启用共享。'
                          : '启用后，本账本的账户、余额、分类、全部流水、预算、目标与贡献记录将对成员可见。',
                    ),
                    if (book.type != BookType.personal)
                      FilledButton(
                        onPressed: _busy
                            ? null
                            : () => _run(() async {
                                if (await _confirm(
                                  '启用整本共享',
                                  '将上传「${book.name}」中的账户、分类、全部流水、预算、目标和贡献记录。成员可以查看整本数据。其他账本、商户私有记忆、通知原文和本机附件不会上传。',
                                )) {
                                  await ref
                                      .read(familyServiceProvider)
                                      .enableSharing(book.id);
                                  _loadedBook = null;
                                }
                              }),
                        child: const Text('启用共享'),
                      ),
                  ],
                ),
              ),
            if (book?.isShared == true) ...[
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      book?.sharedPhase == 'promoting'
                          ? '首次共享尚未完成'
                          : '${pending.length} 项待同步',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      sync?['error'] as String? ??
                          (pending.isEmpty ? '已与共享账本同步' : '修改已保存在本机，联网后提交'),
                    ),
                    TextButton.icon(
                      onPressed: _busy
                          ? null
                          : () => _run(() async {
                              await ref.read(sharedBookSyncProvider).sync();
                              await _loadMembers();
                            }),
                      icon: const Icon(Icons.sync),
                      label: const Text('立即同步'),
                    ),
                    if (pending.isNotEmpty &&
                        pending.first['status'] != 'pending') ...[
                      const Divider(),
                      const Text(
                        '本账本同步暂停，需先处理以下修改',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        pending.first['error'] == null
                            ? '提交未被接受'
                            : (jsonDecode(pending.first['error'] as String)
                                      as Json)['message']
                                  as String,
                      ),
                      Text(
                        '记录类型：${pending.first['kind']}；操作：${pending.first['action']}',
                      ),
                      Wrap(
                        spacing: 8,
                        children: [
                          OutlinedButton(
                            onPressed: _busy
                                ? null
                                : () => _run(() async {
                                    if (await _confirm(
                                      '采用服务端版本',
                                      '放弃这条记录的未同步修改及依赖它的新建内容，保留服务端最新账务数据。其他记录的待同步修改会继续提交。',
                                    ))
                                      await ref
                                          .read(sharedBookSyncProvider)
                                          .resolve(book!.id, useServer: true);
                                  }),
                            child: const Text('采用服务端版本'),
                          ),
                          if (pending.first['status'] == 'conflict')
                            OutlinedButton(
                              onPressed: _busy
                                  ? null
                                  : () => _run(() async {
                                      if (await _confirm(
                                        '基于最新版本重新提交',
                                        '将当前操作组的内容提交到最新版本。金额调整会重新应用本次差额，请核对后确认。权限不足的操作仍会被拒绝。',
                                      ))
                                        await ref
                                            .read(sharedBookSyncProvider)
                                            .resolve(
                                              book!.id,
                                              useServer: false,
                                            );
                                    }),
                              child: const Text('重新提交'),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
              if (book!.sharedPhase != 'promoting' &&
                  book.role == 'owner') ...[
                const SizedBox(height: 12),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        '共享账本管理',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '解散后所有成员将无法继续同步或写入此共享账本。此操作不会自动删除本机保留的数据。',
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton(
                        onPressed: _busy
                            ? null
                            : () => _run(() async {
                                if (await _confirm(
                                  '解散共享账本',
                                  '确认解散「${book.name}」？所有成员将失去共享访问权限，未使用的邀请码也会同时失效。',
                                )) {
                                  await ref
                                      .read(familyServiceProvider)
                                      .disband(book.sharedId!);
                                  _loadedBook = null;
                                }
                              }),
                        child: const Text('解散共享账本'),
                      ),
                    ],
                  ),
                ),
              ],
              if (book.sharedPhase != 'promoting' && book.type == BookType.family) ...[
                _memberSpendingCard(familyTransactions),
                const SizedBox(height: 12),
              ],
              if (book.sharedPhase != 'promoting')
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              '账本成员',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: _busy ? null : () => _run(_loadMembers),
                            icon: const Icon(Icons.refresh),
                          ),
                        ],
                      ),
                      for (final member in _members)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text((member['display_name'] as String?)?.trim().isNotEmpty == true ? member['display_name'] as String : member['username'] as String),
                          subtitle: Text(switch (member['role']) {
                            'owner' => '所有者',
                            'admin' => '管理员',
                            _ => '普通成员',
                          }),
                          trailing: member['role'] == 'owner'
                              ? null
                              : AppActionMenuButton<String>(
                                  onSelected: (action) => _run(() async {
                                    final service = ref.read(
                                          familyServiceProvider,
                                        ),
                                        id = member['user_id'] as String;
                                    if (action == 'remove') {
                                      if (await _confirm(
                                        id == user.id ? '退出共享账本' : '移除成员',
                                        '未提交的内容保留为本地草稿；操作完成后将失去对应访问权限。',
                                      ))
                                        await service.removeMember(
                                          book.sharedId!,
                                          id,
                                        );
                                    } else if (action == 'owner') {
                                      if (await _confirm(
                                        '转让账本所有权',
                                        '确认将「${book.name}」的所有权转让给该成员？转让后你将变为管理员，新所有者可以管理成员并解散共享账本。',
                                      ))
                                        await service.transferOwnership(
                                          book.sharedId!,
                                          id,
                                        );
                                    } else {
                                      await service.changeRole(
                                        book.sharedId!,
                                        id,
                                        FamilyRole.values.byName(action),
                                      );
                                    }
                                    if (ref.read(activeBookProvider)?.id ==
                                        book.id)
                                      await _loadMembers();
                                  }),
                                  itemBuilder: (_) => [
                                    if (book.role == 'owner') ...[
                                      const PopupMenuItem(
                                        value: 'owner',
                                        child: Text('转让所有权'),
                                      ),
                                      const PopupMenuItem(
                                        value: 'admin',
                                        child: Text('设为管理员'),
                                      ),
                                      const PopupMenuItem(
                                        value: 'member',
                                        child: Text('设为普通成员'),
                                      ),
                                    ],
                                    if (member['user_id'] == user.id ||
                                        book.role == 'owner' ||
                                        (book.role == 'admin' &&
                                            member['role'] == 'member'))
                                      PopupMenuItem(
                                        value: 'remove',
                                        child: Text(
                                          member['user_id'] == user.id
                                              ? '退出账本'
                                              : '移除成员',
                                        ),
                                      ),
                                  ],
                                ),
                        ),
                      if (book.canManage) ...[
                        OutlinedButton.icon(
                          onPressed: _busy
                              ? null
                              : () => _run(() async {
                                  await ref
                                      .read(familyServiceProvider)
                                      .createInvitation(
                                        familyId: book.sharedId!,
                                      );
                                  await _loadMembers();
                                }),
                          icon: const Icon(Icons.person_add_outlined),
                          label: const Text('生成邀请（七天有效）'),
                        ),
                        for (final invite in _invitations.where(
                          (i) => i.status == FamilyInvitationStatus.pending,
                        ))
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SelectableText(invite.code),
                              Wrap(
                                children: [
                                  TextButton(
                                    onPressed: () => Clipboard.setData(
                                      ClipboardData(text: invite.code),
                                    ),
                                    child: const Text('复制邀请码'),
                                  ),
                                  TextButton(
                                    onPressed: _busy
                                        ? null
                                        : () => _run(() async {
                                            await ref
                                                .read(familyServiceProvider)
                                                .revokeInvitation(
                                                  book.sharedId!,
                                                  invite.id,
                                                );
                                            await _loadMembers();
                                          }),
                                    child: const Text('撤销邀请'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                      ],
                    ],
                  ),
                ),
            ],
            const UnavailableDraftsCard(),
            const SizedBox(height: 12),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    '加入共享账本',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  TextField(
                    controller: _code,
                    decoration: const InputDecoration(labelText: '邀请码'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: _busy ? null : _joinInvitationWithGate,
                    child: const Text('接受邀请'),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

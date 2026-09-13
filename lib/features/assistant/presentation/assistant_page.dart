import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/widgets/category_icon.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../../core/models/membership.dart';
import '../../accounts/data/account_repository.dart';
import '../../bookkeeping/presentation/quick_add_sheet.dart';
import '../../intelligence/data/bill_inbox_repository.dart';
import '../../notifications/application/payment_notification_service.dart';
import '../../transactions/data/transactions_repository.dart';
import '../../voice/presentation/voice_bookkeeping_sheet.dart';
import '../../membership/presentation/membership_upgrade_prompt.dart';
import '../application/assistant_conversation.dart';
import '../application/assistant_engine.dart';
import '../application/assistant_policy.dart';
import 'assistant_entry_button.dart';

const _green = Color(0xFF567B27);
const _cream = Color(0xFFFAFAF4);

class AssistantPage extends ConsumerStatefulWidget {
  const AssistantPage({super.key});
  @override
  ConsumerState<AssistantPage> createState() => _AssistantPageState();
}

class _AssistantPageState extends ConsumerState<AssistantPage> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  bool _sending = false;
  late AssistantConversation _conversation;
  @override
  void initState() {
    super.initState();
    _conversation = ref.read(assistantConversationProvider.notifier);
    _conversation.viewers++;
    Future.microtask(() async {
      try {
        await _conversation.markRead();
      } on Object {
        if (mounted) _notice('会话读取失败，请稍后重试');
      }
    });
  }

  @override
  void dispose() {
    _conversation.viewers--;
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _notice(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  Future<void> _send([String? suggestion]) async {
    final text = suggestion ?? _input.text;
    if (_sending || text.trim().isEmpty) return;
    setState(() => _sending = true);
    _input.clear();
    try {
      await _conversation.send(text);
    } on Object {
      if (mounted) _notice('会话保存失败，请先检查流水，避免重复记账');
    }
    if (!mounted) return;
    setState(() => _sending = false);
    final authorization = _conversation.lastAuthorization;
    if (mounted &&
        (authorization?.requiresMembership == true || text.trim() == '会员权益')) {
      await showMembershipUpgradePrompt(
        context,
        MembershipFeature.automaticBookkeeping,
      );
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients)
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
    });
  }

  Future<void> _image() async {
    try {
      final selected = await FilePicker.pickFile(
        dialogTitle: '选择图片',
        type: FileType.image,
      );
      if (selected != null && mounted)
        _notice('已选择 ${selected.name}，图片记账识别开发中，尚未上传或创建账单');
    } on Object {
      if (mounted) _notice('当前设备暂时无法选择图片');
    }
  }

  Future<void> _menu(String value) async {
    if (value == 'notifications') {
      context.push('/profile/payment-notifications');
      return;
    }
    if (value == 'inbox') {
      context.push('/transactions/inbox');
      return;
    }
    if (value == 'clear') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('清空当前会话？'),
          content: const Text('仅清除当前账本的聊天记录，已保存的账单会保留。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('清空'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    try {
      if (value == 'clear') {
        await _conversation.clear();
      } else {
        await _conversation.markRead();
        if (mounted) _notice('助手消息已读；待处理账单需在提醒中处理');
      }
    } on Object {
      if (mounted) _notice('操作失败，请稍后重试');
    }
  }

  Future<void> _openVoice() async {
    final access = await ref
        .read(assistantPolicyServiceProvider)
        .authorize(feature: 'voice');
    if (!mounted) return;
    if (!access.allowed && access.requiresMembership) {
      await showMembershipUpgradePrompt(
        context,
        MembershipFeature.automaticBookkeeping,
      );
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const VoiceBookkeepingSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(assistantConversationProvider);
    final pending = ref.watch(pendingInboxProvider).value?.length ?? 0;
    final processingError = ref.watch(notificationProcessingErrorProvider);
    return Scaffold(
      backgroundColor: _cream,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(-.8, -.3),
            radius: 1.5,
            colors: [Color(0xFFF0F5E6), _cream],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              right: -6,
              top: 148,
              child: IgnorePointer(
                child: Opacity(
                  opacity: .24,
                  child: Image.asset(
                    'assets/images/assistant-chat-leaf-decoration.png',
                    width: 100,
                    height: 130,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
            DefaultTextStyle.merge(
              style: const TextStyle(color: Color(0xFF151B22)),
              child: SafeArea(
                child: Column(
                  children: [
                    SizedBox(
                      height: MediaQuery.textScalerOf(context).scale(72),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 46),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      '好好记账',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    SizedBox(width: 8),
                                    DecoratedBox(
                                      decoration: BoxDecoration(
                                        color: Color(0xFFE4EED3),
                                        borderRadius: BorderRadius.all(
                                          Radius.circular(5),
                                        ),
                                      ),
                                      child: Padding(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        child: Text(
                                          '官方',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: _green,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 3),
                                Text(
                                  '你的专属记账助手 · 随时为你服务',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF80827E),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: IconButton(
                              tooltip: '返回',
                              icon: const Icon(
                                Icons.arrow_back_ios_new_rounded,
                                size: 21,
                              ),
                              onPressed: () => context.canPop()
                                  ? context.pop()
                                  : context.go('/'),
                            ),
                          ),
                          Align(
                            alignment: Alignment.centerRight,
                            child: PopupMenuButton<String>(
                              tooltip: '更多',
                              onSelected: _sending ? null : _menu,
                              itemBuilder: (_) => [
                                const PopupMenuItem(
                                  value: 'read',
                                  child: Text('标记助手消息已读'),
                                ),
                                const PopupMenuItem(
                                  value: 'notifications',
                                  child: Text('支付通知记录与设置'),
                                ),
                                const PopupMenuItem(
                                  value: 'inbox',
                                  child: Text('待处理系统提醒'),
                                ),
                                if (!_sending)
                                  const PopupMenuItem(
                                    value: 'clear',
                                    child: Text('清空当前会话'),
                                  ),
                              ],
                              icon: const Icon(Icons.more_horiz),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: messages.when(
                        loading: () =>
                            const Center(child: CircularProgressIndicator()),
                        error: (_, _) => Center(
                          child: TextButton(
                            onPressed: () =>
                                ref.invalidate(assistantConversationProvider),
                            child: const Text('会话加载失败，点击重试'),
                          ),
                        ),
                        data: (items) => ListView(
                          controller: _scroll,
                          padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
                          children: [
                            _assistant(
                              const Text.rich(
                                TextSpan(
                                  children: [
                                    TextSpan(text: '你好！我是好好记账 '),
                                    WidgetSpan(
                                      child: Icon(
                                        Icons.waving_hand_rounded,
                                        size: 15,
                                        color: Color(0xFFE8B84C),
                                      ),
                                    ),
                                    TextSpan(
                                      text: '\n我可以帮你快速记账、查询数据、分析收支、设置预算，有任何问题都可以随时告诉我～',
                                    ),
                                  ],
                                ),
                                style: TextStyle(fontSize: 13, height: 1.35),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.only(
                                left: 48,
                                top: 8,
                                bottom: 16,
                              ),
                              child: Wrap(
                                spacing: 7,
                                runSpacing: 7,
                                children: [
                                  for (final label
                                      in ref
                                          .read(assistantEngineProvider)
                                          .getSuggestions())
                                    _chip(
                                      label,
                                      () => _send(label),
                                      outline: true,
                                    ),
                                ],
                              ),
                            ),
                            if (pending > 0)
                              _assistant(
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('有 $pending 条账单提醒待处理。'),
                                    TextButton(
                                      onPressed: () =>
                                          context.push('/transactions/inbox'),
                                      child: const Text('查看提醒'),
                                    ),
                                  ],
                                ),
                              ),
                            if (processingError != null)
                              _assistant(
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('支付通知处理遇到问题，请查看通知记录。'),
                                    TextButton(
                                      onPressed: () => context.push(
                                        '/profile/payment-notifications',
                                      ),
                                      child: const Text('查看支付通知'),
                                    ),
                                  ],
                                ),
                              ),
                            for (var i = 0; i < items.length; i++) ...[
                              if (i == 0 ||
                                  items[i].time
                                          .difference(items[i - 1].time)
                                          .inMinutes >=
                                      5)
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  child: Text(
                                    DateFormat('M月d日 HH:mm')
                                        .format(items[i].time),
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: Color(0xFF868882),
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: items[i].isUser
                                    ? _user(items[i].text)
                                    : _assistant(
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Wrap(
                                              crossAxisAlignment:
                                                  WrapCrossAlignment.center,
                                              spacing: 6,
                                              children: [
                                                Text(
                                                  items[i].text.replaceAll(
                                                    ' ✅',
                                                    '',
                                                  ),
                                                  style: const TextStyle(
                                                    fontSize: 14,
                                                    height: 1.4,
                                                  ),
                                                ),
                                                if (items[i].text.endsWith('✅'))
                                                  const Icon(
                                                    Icons.check_circle,
                                                    color: Color(0xFF67A934),
                                                    size: 18,
                                                  ),
                                              ],
                                            ),
                                            if (items[i].transactionId != null)
                                              AssistantRecordCard(
                                                transactionId:
                                                    items[i].transactionId!,
                                              ),
                                            if (items[i].route != null)
                                              TextButton(
                                                onPressed: () => context.push(
                                                  items[i].route!,
                                                ),
                                                child: const Text('打开查看'),
                                              ),
                                          ],
                                        ),
                                      ),
                              ),
                            ],
                            if (_sending) _assistant(const Text('正在按规则处理…')),
                          ],
                        ),
                      ),
                    ),
                    _composer(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _assistant(Widget child) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const AssistantAvatar(size: 40),
      const SizedBox(width: 8),
      Flexible(
        child: Container(
          padding: const EdgeInsets.all(11),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .94),
            borderRadius: BorderRadius.circular(16),
          ),
          child: child,
        ),
      ),
      const SizedBox(width: 54),
    ],
  );
  Widget _user(String text) => Row(
    mainAxisAlignment: MainAxisAlignment.end,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const SizedBox(width: 48),
      Flexible(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
          decoration: const BoxDecoration(
            color: Color(0xFFE3EFD2),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
              bottomLeft: Radius.circular(16),
            ),
          ),
          child: Text(text, style: const TextStyle(fontSize: 14, height: 1.4)),
        ),
      ),
      const SizedBox(width: 10),
      const UserAvatar(radius: 19),
    ],
  );
  Widget _chip(
    String text,
    VoidCallback action, {
    bool outline = false,
    IconData? icon,
  }) => Material(
    color: outline ? Colors.transparent : Colors.white,
    shape: StadiumBorder(
      side: outline
          ? const BorderSide(color: Color(0xFFD7E5C3))
          : BorderSide.none,
    ),
    child: InkWell(
      customBorder: const StadiumBorder(),
      onTap: _sending ? null : action,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: outline ? 10 : 8,
          vertical: 7,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 17, color: _green),
              const SizedBox(width: 5),
            ],
            Text(
              text,
              style: TextStyle(
                fontSize: 12,
                color: outline ? _green : const Color(0xFF202720),
              ),
            ),
          ],
        ),
      ),
    ),
  );
  Widget _composer() => Container(
    padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
    color: _cream.withValues(alpha: .96),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _chip(
                '快速记账',
                () => showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => const QuickAddSheet(),
                ),
                icon: Icons.add_circle,
              ),
              const SizedBox(width: 7),
              _chip(
                '本月收支',
                () => _send('本月收支'),
                icon: Icons.assessment_rounded,
              ),
              const SizedBox(width: 7),
              _chip(
                '设置预算',
                () => context.push('/profile/budgets'),
                icon: Icons.track_changes,
              ),
              const SizedBox(width: 7),
              _chip('导出数据', () => _send('导出数据'), icon: Icons.ios_share),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _green,
                border: Border.all(color: const Color(0xFFE2EBCE), width: 4),
              ),
              child: IconButton(
                tooltip: '语音记账',
                onPressed: _sending ? null : _openVoice,
                icon: const Icon(
                  Icons.mic_none_rounded,
                  color: Colors.white,
                  size: 23,
                ),
              ),
            ),
            const SizedBox(width: 5),
            Expanded(
              child: Container(
                padding: const EdgeInsets.only(left: 13, right: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _input,
                        minLines: 1,
                        maxLines: 4,
                        onChanged: (_) => setState(() {}),
                        onSubmitted: (_) => _send(),
                        textInputAction: TextInputAction.send,
                        style: const TextStyle(fontSize: 14),
                        decoration: const InputDecoration(
                          hintText: '输入消息，试试“帮我记一笔…”',
                          hintMaxLines: 1,
                          hintStyle: TextStyle(
                            color: Color(0xFFB4B7B1),
                            fontSize: 13,
                          ),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          isDense: true,
                          filled: false,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: '选择图片',
                      onPressed: _image,
                      constraints: const BoxConstraints.tightFor(
                        width: 30,
                        height: 44,
                      ),
                      padding: EdgeInsets.zero,
                      icon: const Icon(
                        Icons.image_outlined,
                        size: 23,
                        color: Colors.grey,
                      ),
                    ),
                    IconButton(
                      tooltip: '附件',
                      onPressed: () => _notice('文件上传功能开发中'),
                      constraints: const BoxConstraints.tightFor(
                        width: 28,
                        height: 44,
                      ),
                      padding: EdgeInsets.zero,
                      icon: const Icon(
                        Icons.attach_file,
                        size: 23,
                        color: Colors.grey,
                      ),
                    ),
                    IconButton.filled(
                      tooltip: '发送',
                      style: IconButton.styleFrom(
                        backgroundColor: _green,
                        disabledBackgroundColor: const Color(0xFFCEDBB9),
                      ),
                      onPressed: _sending || _input.text.trim().isEmpty
                          ? null
                          : () => _send(),
                      icon: const Icon(Icons.send_rounded, size: 22),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

class AssistantRecordCard extends ConsumerWidget {
  const AssistantRecordCard({super.key, required this.transactionId});
  final String transactionId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref
        .watch(transactionsProvider)
        .when(
          loading: () => const Padding(
            padding: EdgeInsets.all(12),
            child: LinearProgressIndicator(),
          ),
          error: (_, _) => const Text('账单加载失败，请到流水页查看'),
          data: (records) {
            final record = records
                .where((r) => r.id == transactionId && r.deletedAt == null)
                .firstOrNull;
            if (record == null)
              return const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Text('这笔账单已删除或不可访问'),
              );
            return Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: Color(0xFFF3F6EE),
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(12),
                      ),
                    ),
                    child: Row(
                      children: [
                        CategoryIcon(
                          category: record.categoryName ?? '其他',
                          size: 34,
                          vivid: true,
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Text(
                            record.categoryName ?? '其他',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Flexible(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              '${record.isIncome ? '+' : '-'} ¥${record.amount.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  _line(
                    Icons.access_time,
                    DateFormat('yyyy年M月d日 HH:mm').format(record.occurredAt),
                  ),
                  _line(
                    Icons.credit_card,
                    ref
                            .watch(allAccountsProvider)
                            .value
                            ?.where((a) => a.id == record.accountId)
                            .firstOrNull
                            ?.name ??
                        '账户已归档或不可用',
                  ),
                  _line(
                    Icons.description_outlined,
                    record.note ?? record.merchant ?? '无备注',
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _button(
                          '修改',
                          () => showModalBottomSheet<void>(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (_) =>
                                QuickAddSheet(initialTransaction: record),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: _button(
                          '查看详情',
                          () => context.push(
                            '/transactions/$transactionId',
                            extra: record,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
  }

  Widget _line(IconData icon, String text) => Padding(
    padding: const EdgeInsets.only(top: 7, left: 7),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: const Color(0xFF81847E)),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 12,
              height: 1.3,
              color: Color(0xFF777B75),
            ),
          ),
        ),
      ],
    ),
  );
  Widget _button(String text, VoidCallback action) => TextButton(
    style: TextButton.styleFrom(
      backgroundColor: const Color(0xFFF0F4E7),
      foregroundColor: _green,
      minimumSize: const Size(0, 28),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
    ),
    onPressed: action,
    child: Text(text, style: const TextStyle(fontSize: 13)),
  );
}

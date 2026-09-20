import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/models/account.dart';
import '../../../core/models/transaction_record.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/category_icon.dart';
import '../../../core/widgets/money_text.dart';
import '../../accounts/data/account_repository.dart';
import '../../bookkeeping/application/local_file_opener.dart';
import '../../bookkeeping/presentation/quick_add_sheet.dart';
import '../data/transaction_attachment_repository.dart';
import '../data/transactions_repository.dart';
import '../domain/transaction_attachment.dart';
import 'transaction_actions.dart';
import '../../../app/theme/app_theme_tokens.dart';

class TransactionDetailPage extends ConsumerStatefulWidget {
  const TransactionDetailPage({
    required this.transactionId,
    super.key,
    this.initialTransaction,
  });

  final String transactionId;
  final TransactionRecord? initialTransaction;

  @override
  ConsumerState<TransactionDetailPage> createState() =>
      _TransactionDetailPageState();
}

class _TransactionDetailPageState extends ConsumerState<TransactionDetailPage> {
  TransactionRecord? _transaction;
  Object? _loadError;
  bool _loading = false;
  bool _attachmentsLoading = false;
  List<TransactionAttachment> _attachments = const [];
  final _attachmentExists = <String, Future<bool>>{};

  @override
  void initState() {
    super.initState();
    _transaction = widget.initialTransaction;
    if (_transaction == null) {
      unawaited(_loadTransaction());
    } else {
      unawaited(_loadAttachments(_transaction!));
    }
  }

  Future<void> _loadTransaction() async {
    if (mounted && _transaction == null) setState(() => _loading = true);
    try {
      await ref.read(databaseBootstrapProvider.future);
      final transaction = await ref
          .read(transactionRepositoryProvider)
          .getById(widget.transactionId);
      if (transaction != null) await _loadAttachments(transaction);
      if (!mounted) return;
      setState(() {
        _transaction = transaction;
        _loadError = transaction == null ? StateError('当前账本中找不到这笔流水') : null;
        _loading = false;
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _loadError = error;
        _loading = false;
      });
    }
  }

  Future<void> _loadAttachments(TransactionRecord transaction) async {
    if (mounted) setState(() => _attachmentsLoading = true);
    List<TransactionAttachment>? attachments;
    try {
      final persisted = await ref
          .read(transactionAttachmentRepositoryProvider)
          .getForTransaction(transaction.id, bookId: transaction.bookId);
      if (persisted.isNotEmpty) attachments = persisted;
    } on Object {
      // Keep old metadata readable if the database is still on the previous schema.
    }
    attachments ??= TransactionAttachmentMetadata.fromJson(
      transaction.metadataJson,
    ).attachments;
    if (!mounted ||
        (_transaction != null && _transaction!.id != transaction.id)) {
      return;
    }
    setState(() {
      _attachments = List.unmodifiable(attachments!);
      _attachmentsLoading = false;
    });
  }

  Future<void> _reloadAfterEdit() async {
    ref.invalidate(transactionsProvider);
    await _loadTransaction();
  }

  Future<void> _editTransaction(TransactionRecord transaction) async {
    await showQuickAddSheet(context, initialTransaction: transaction);
    if (mounted) await _reloadAfterEdit();
  }

  Future<void> _showActions(TransactionRecord transaction) async {
    await showTransactionActions(
      context,
      ref,
      transaction,
      onCorrectCategory: transaction.type == TransactionType.transfer
          ? null
          : () => showTransactionCategoryCorrection(context, ref, transaction),
    );
    if (!mounted) return;
    await _reloadAfterEdit();
    if (mounted && _transaction == null) Navigator.of(context).pop();
  }

  Future<void> _showAttachmentMessage(String message) async {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openAttachment(TransactionAttachment attachment) async {
    final result = await ref
        .read(localFileOpenerProvider)
        .open(attachment.path);
    if (!mounted) return;
    switch (result) {
      case LocalFileOpenResult.opened:
        return;
      case LocalFileOpenResult.missing:
        await _showAttachmentMessage('文件未找到：${attachment.name}');
      case LocalFileOpenResult.noHandler:
        await _showAttachmentMessage('没有可打开此文件的应用：${attachment.name}');
      case LocalFileOpenResult.unsupported:
        await _showAttachmentMessage('当前平台暂不支持系统打开文件');
    }
  }

  Future<void> _previewImage(TransactionAttachment attachment) async {
    if (!await File(attachment.path).exists()) {
      if (!mounted) return;
      await _showAttachmentMessage('文件未找到：${attachment.name}');
      return;
    }
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog.fullscreen(
        backgroundColor: Colors.black,
        child: SafeArea(
          child: Stack(
            children: [
              Center(
                child: InteractiveViewer(
                  minScale: .5,
                  maxScale: 5,
                  child: Image.file(
                    File(attachment.path),
                    fit: BoxFit.contain,
                    errorBuilder: (_, error, stackTrace) => const Center(
                      child: Text(
                        '图片无法读取',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: IconButton(
                  tooltip: '关闭预览',
                  onPressed: () => Navigator.pop(dialogContext),
                  color: Colors.white,
                  icon: const Icon(Icons.close),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<bool> _exists(String path) => _attachmentExists.putIfAbsent(
    path,
    () async => path.trim().isNotEmpty && await File(path).exists(),
  );

  @override
  Widget build(BuildContext context) {
    final transaction = _transaction;
    if (transaction == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('交易详情')),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _DetailLoadFailure(error: _loadError),
      );
    }

    final accounts =
        ref.watch(assetDashboardAccountsProvider).value ?? const <Account>[];
    final accountNames = {
      for (final account in accounts) account.id: account.displayName,
    };
    final legacyMetadata = TransactionAttachmentMetadata.fromJson(
      transaction.metadataJson,
    );
    final attachments = _attachments.isNotEmpty
        ? _attachments
        : legacyMetadata.attachments;
    final category = transaction.displayCategoryLabel;
    final categoryPath = transaction.displayCategoryPath;

    return Scaffold(
      appBar: AppBar(
        title: const Text('交易详情'),
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        actions: [
          if (transaction.type != TransactionType.refund &&
              transaction.type != TransactionType.reimbursement)
            IconButton(
              tooltip: '编辑流水',
              onPressed: () => _editTransaction(transaction),
              icon: const Icon(Icons.edit_outlined),
            ),
          IconButton(
            tooltip: '更多操作',
            onPressed: () => _showActions(transaction),
            icon: const Icon(Icons.more_horiz),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
        children: [
          AppCard(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
            child: Column(
              children: [
                CategoryIcon(
                  category: category,
                  iconKey: transaction.categoryIcon,
                  vivid: true,
                  size: 48,
                ),
                const SizedBox(height: 10),
                Text(
                  transaction.displayTitle,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                MoneyText(
                  transaction.amount,
                  currency: transaction.currency,
                  positive: transaction.type == TransactionType.transfer
                      ? null
                      : transaction.isIncome,
                  showSign: transaction.type != TransactionType.transfer,
                  style: const TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          AppCard(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 8),
            child: Column(
              children: [
                _DetailRow(label: '类型', value: _typeLabel(transaction.type)),
                _DetailRow(
                  label: '发生时间',
                  value: _dateTimeLabel(transaction.occurredAt),
                ),
                _DetailRow(
                  label: '账户',
                  value: _accountLabel(accountNames, transaction.accountId),
                ),
                if (transaction.destinationAccountId != null)
                  _DetailRow(
                    label: '转入账户',
                    value: _accountLabel(
                      accountNames,
                      transaction.destinationAccountId!,
                    ),
                  ),
                _DetailRow(label: '分类', value: categoryPath),
                if (transaction.reimbursementStatus != ReimbursementStatus.none)
                  _DetailRow(
                    label: '报销状态',
                    value: _reimbursementLabel(transaction),
                  ),
                if (transaction.refundStatus != RefundStatus.none)
                  _DetailRow(label: '退款状态', value: _refundLabel(transaction)),
                if (transaction.relatedTransactionId != null)
                  _DetailRow(
                    label: '关联流水',
                    value: transaction.relatedTransactionId!,
                  ),
                if ((transaction.note ?? '').trim().isNotEmpty)
                  _DetailRow(label: '备注', value: transaction.note!.trim()),
                if ((transaction.createdBy ?? '').trim().isNotEmpty)
                  _DetailRow(
                    label: '记录人',
                    value: _actorLabel(transaction.createdBy!),
                  ),
                _DetailRow(
                  label: '同步状态',
                  value: _syncStatusLabel(transaction.syncStatus),
                ),
              ],
            ),
          ),
          SizedBox(height: 18),
          Row(
            children: [
              Text('附件', style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
              if (attachments.isNotEmpty)
                Text(
                  '${attachments.length} 个',
                  style: TextStyle(color: context.appSecondaryText),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (_attachmentsLoading && attachments.isEmpty)
            AppCard(
              padding: EdgeInsets.all(18),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (attachments.isEmpty &&
              !legacyMetadata.hasMalformedAttachments)
            AppCard(
              padding: EdgeInsets.all(18),
              child: Text(
                '暂无附件。需要补充时可点击右上角编辑流水。',
                style: TextStyle(color: context.appSecondaryText),
              ),
            )
          else ...[
            if (legacyMetadata.hasMalformedAttachments)
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text(
                  '附件记录格式异常，未能读取部分附件。请通过编辑流水重新添加。',
                  style: TextStyle(color: AppColors.warning, fontSize: 12),
                ),
              ),
            for (final attachment in attachments)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _AttachmentTile(
                  attachment: attachment,
                  exists: _exists(attachment.path),
                  onPreview: attachment.isImage
                      ? () => _previewImage(attachment)
                      : null,
                  onOpen: attachment.isImage
                      ? null
                      : () => _openAttachment(attachment),
                  onReAdd: () => _editTransaction(transaction),
                ),
              ),
          ],
        ],
      ),
    );
  }

  String _accountLabel(Map<String, String> names, String id) {
    return names[id] ?? '账户已归档（$id）';
  }

  String _dateTimeLabel(DateTime value) {
    final local = value.toLocal();
    return '${local.year}年${local.month}月${local.day}日 ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  String _actorLabel(String value) => value == 'user-local' ? '我' : value;

  String _reimbursementLabel(TransactionRecord value) {
    final status = switch (value.reimbursementStatus) {
      ReimbursementStatus.pending => '待报销',
      ReimbursementStatus.reimbursed => '已报销',
      ReimbursementStatus.partial => '部分报销',
      ReimbursementStatus.none => '无需报销',
    };
    final amount = value.reimbursementAmount;
    return amount == null ? status : '$status · ¥${amount.toStringAsFixed(2)}';
  }

  String _refundLabel(TransactionRecord value) {
    final status = switch (value.refundStatus) {
      RefundStatus.partial => '部分退款',
      RefundStatus.refunded => '已退款',
      RefundStatus.none => '无退款',
    };
    final amount = value.refundAmount;
    return amount == null ? status : '$status · ¥${amount.toStringAsFixed(2)}';
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 76,
            child: Text(
              label,
              style: TextStyle(color: context.appSecondaryText),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(value, textAlign: TextAlign.right)),
        ],
      ),
    );
  }
}

class _AttachmentTile extends StatelessWidget {
  const _AttachmentTile({
    required this.attachment,
    required this.exists,
    required this.onReAdd,
    this.onPreview,
    this.onOpen,
  });

  final TransactionAttachment attachment;
  final Future<bool> exists;
  final VoidCallback onReAdd;
  final VoidCallback? onPreview;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(12),
      borderRadius: 18,
      child: FutureBuilder<bool>(
        future: exists,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Row(
              children: [
                const SizedBox(
                  width: 42,
                  height: 42,
                  child: Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    attachment.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            );
          }
          if (snapshot.data != true) {
            return Row(
              children: [
                const Icon(
                  Icons.error_outline,
                  color: AppColors.warning,
                  size: 38,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        attachment.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      const Text(
                        '文件未找到',
                        style: TextStyle(
                          color: AppColors.warning,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(onPressed: onReAdd, child: const Text('重新添加')),
              ],
            );
          }

          final preview = onPreview;
          final open = onOpen;
          return Row(
            children: [
              if (attachment.isImage)
                InkWell(
                  onTap: preview,
                  borderRadius: BorderRadius.circular(10),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.file(
                      File(attachment.path),
                      width: 64,
                      height: 64,
                      fit: BoxFit.cover,
                      cacheWidth: 160,
                      errorBuilder: (_, error, stackTrace) => const SizedBox(
                        width: 64,
                        height: 64,
                        child: Icon(Icons.broken_image_outlined, size: 32),
                      ),
                    ),
                  ),
                )
              else
                Icon(
                  attachment.isPdf
                      ? Icons.picture_as_pdf_outlined
                      : Icons.insert_drive_file_outlined,
                  color: attachment.isPdf
                      ? AppColors.warning
                      : context.appPrimary,
                  size: 40,
                ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      attachment.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 3),
                    Text(
                      attachment.isImage
                          ? '点击缩略图预览'
                          : attachment.isPdf
                          ? '打开 PDF 预览'
                          : '通过系统应用打开',
                      style: TextStyle(
                        color: context.appSecondaryText,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (open != null)
                IconButton(
                  tooltip: attachment.isPdf ? '打开 PDF 预览' : '系统打开',
                  onPressed: open,
                  icon: Icon(
                    attachment.isPdf ? Icons.open_in_new : Icons.launch,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _DetailLoadFailure extends StatelessWidget {
  const _DetailLoadFailure({this.error});

  final Object? error;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: 48,
              color: context.appSecondaryText,
            ),
            const SizedBox(height: 12),
            Text(
              error == null ? '无法读取这笔流水' : '无法读取这笔流水：$error',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

String _typeLabel(TransactionType type) => switch (type) {
  TransactionType.assetSale => '资产卖出',
  TransactionType.expense => '支出',
  TransactionType.income => '收入',
  TransactionType.transfer => '转账',
  TransactionType.refund => '退款',
  TransactionType.reimbursement => '报销',
  TransactionType.borrow => '借入',
  TransactionType.lend => '借出',
  TransactionType.repayment => '还款',
  TransactionType.assetPurchase => '资产购买',
  TransactionType.adjustment => '余额校准',
};

String _syncStatusLabel(SyncStatus status) => switch (status) {
  SyncStatus.localOnly => '仅本机',
  SyncStatus.pending => '待同步',
  SyncStatus.synced => '已同步',
  SyncStatus.conflict => '存在冲突',
};

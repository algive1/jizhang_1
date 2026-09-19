import '../../bookkeeping/presentation/components/ai_confirm_card.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/models/account.dart';
import '../../../core/models/category.dart';
import '../../../core/models/transaction_record.dart';
import '../../../core/models/voice_bookkeeping.dart';
import '../../accounts/data/account_repository.dart';
import '../../books/data/book_repository.dart';
import '../../bookkeeping/application/quick_bookkeeping_service.dart';
import '../../categories/data/category_repository.dart';
import '../../intelligence/data/merchant_rule_repository.dart';
import '../application/speech_recognition_service.dart';
import '../../../app/theme/app_theme_tokens.dart';
import '../../../core/widgets/app_form.dart';

class VoiceBookkeepingSheet extends ConsumerStatefulWidget {
  const VoiceBookkeepingSheet({
    super.key,
    this.textOnly = false,
    this.initialText,
    this.bookId,
  });

  final bool textOnly;
  final String? initialText;
  final String? bookId;

  @override
  ConsumerState<VoiceBookkeepingSheet> createState() =>
      _VoiceBookkeepingSheetState();
}

class _VoiceBookkeepingSheetState extends ConsumerState<VoiceBookkeepingSheet> {
  final _transcriptController = TextEditingController();
  StreamSubscription<SpeechRecognitionEvent>? _subscription;
  late final SpeechRecognitionService _speechService;
  List<ParsedVoiceTransaction> _transactions = const [];
  final Set<int> _categoryCorrections = {};
  bool _listening = false;
  bool _parsing = false;
  bool _saving = false;
  bool _onDevice = true;
  String? _error;
  List<String> _unresolved = const [];

  @override
  void initState() {
    super.initState();
    _speechService = ref.read(speechRecognitionServiceProvider);
    if (widget.initialText != null) {
      _transcriptController.text = widget.initialText!;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.textOnly) {
        if (_transcriptController.text.trim().isNotEmpty) {
          unawaited(_parseTranscript());
        }
      } else {
        unawaited(_startListening());
      }
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    unawaited(_speechService.cancel());
    _transcriptController.dispose();
    super.dispose();
  }

  Future<void> _startListening() async {
    await _subscription?.cancel();
    _subscription = _speechService.events.listen(_handleSpeechEvent);
    setState(() {
      _error = null;
      _transactions = const [];
      _unresolved = const [];
    });
    await _speechService.start();
  }

  void _handleSpeechEvent(SpeechRecognitionEvent event) {
    if (!mounted) return;
    setState(() {
      _listening = event.status == SpeechRecognitionStatus.listening;
      _onDevice = event.onDevice;
      if (event.transcript.isNotEmpty) {
        _transcriptController.text = event.transcript;
      }
      if (event.errorMessage != null) _error = event.errorMessage;
    });
    if (event.isFinal && event.transcript.trim().isNotEmpty) {
      unawaited(_parseTranscript());
    }
  }

  Future<void> _parseTranscript() async {
    final text = _transcriptController.text.trim();
    if (text.isEmpty || _parsing) return;
    setState(() {
      _parsing = true;
      _error = null;
    });
    try {
      final result = await ref.read(voiceTransactionParserProvider).parse(text);
      if (!mounted) return;
      setState(() {
        _transactions = result.transactions;
        _unresolved = result.unresolvedFragments;
        _categoryCorrections.clear();
        if (_transactions.isEmpty) _error = '没有识别到金额，请修改文字后重试';
      });
    } on FormatException catch (error) {
      if (mounted) setState(() => _error = '解析格式错误：$error');
    } finally {
      if (mounted) setState(() => _parsing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeBookId = ref.watch(activeBookIdProvider);
    final selectedBookId = widget.bookId ?? activeBookId;
    final accounts = widget.bookId == null
        ? ref.watch(accountsProvider).value ?? const <Account>[]
        : ref.watch(accountsByBookProvider(selectedBookId)).value ??
              const <Account>[];
    final categories = widget.bookId == null
        ? ref.watch(categoriesProvider).value ?? const <Category>[]
        : ref.watch(categoriesByBookProvider(selectedBookId)).value ??
              const <Category>[];
    return SafeArea(
      bottom: false,
      child: FractionallySizedBox(
        heightFactor: .92,
        child: Material(
          color: context.appBackground,
          clipBehavior: Clip.antiAlias,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              18,
              10,
              18,
              16 +
                  MediaQuery.viewPaddingOf(context).bottom +
                  MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: Column(
              children: [
                Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: context.appDivider,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(
                      widget.textOnly
                          ? Icons.auto_awesome_outlined
                          : Icons.mic_none,
                      color: context.appPrimary,
                    ),
                    const SizedBox(width: 9),
                    Text(
                      widget.textOnly ? 'AI 记账' : '语音记账',
                      style: TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      widget.textOnly
                          ? '本机优先'
                          : (_onDevice ? '设备端优先' : '系统识别降级'),
                      style: TextStyle(
                        color: context.appSecondaryText,
                        fontSize: 12,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                TextField(
                  key: const ValueKey('voice-transcript'),
                  controller: _transcriptController,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    hintText: '例如：昨晚十一点唱歌680，打车38，都是微信',
                    labelText: '自然语言（可修改）',
                  ),
                ),
                const SizedBox(height: 10),
                if (widget.textOnly)
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.tonal(
                      onPressed: _parsing ? null : _parseTranscript,
                      child: Text(_parsing ? '解析中…' : '智能解析'),
                    ),
                  )
                else if (_listening)
                  Row(
                    children: [
                      const _ListeningPulse(),
                      const SizedBox(width: 10),
                      const Expanded(child: Text('正在聆听，说完后可点停止')),
                      TextButton.icon(
                        onPressed: _speechService.stop,
                        icon: const Icon(Icons.stop_circle_outlined),
                        label: const Text('停止'),
                      ),
                    ],
                  )
                else
                  Row(
                    children: [
                      TextButton.icon(
                        onPressed: _startListening,
                        icon: const Icon(Icons.mic),
                        label: const Text('重新录音'),
                      ),
                      const Spacer(),
                      FilledButton.tonal(
                        onPressed: _parsing ? null : _parseTranscript,
                        child: Text(_parsing ? '解析中…' : '解析文字'),
                      ),
                    ],
                  ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      _error!,
                      style: const TextStyle(color: AppColors.warning),
                    ),
                  ),
                if (_unresolved.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      '未能结构化：${_unresolved.join('、')}，请检查后再确认。',
                      style: TextStyle(color: AppColors.warning),
                    ),
                  ),
                Expanded(
                  child: _transactions.isEmpty
                      ? Center(
                          child: Text(
                            widget.textOnly
                                ? '先在本机解析金额、时间、分类和账户，再由你确认保存'
                                : '规则会先在本机解析金额、时间、分类和账户',
                            style: TextStyle(
                              color: context.appSecondaryText,
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.only(top: 6),
                          itemCount: _transactions.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) => AIConfirmCard(
                            index: index,
                            transaction: _transactions[index],
                            accounts: accounts,
                            categories: categories,
                            onChanged: (updated, categoryCorrected) {
                              setState(() {
                                _transactions = [..._transactions]
                                  ..[index] = updated;
                                if (categoryCorrected) {
                                  _categoryCorrections.add(index);
                                }
                              });
                            },
                          ),
                        ),
                ),
                if (_transactions.isNotEmpty)
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      key: ValueKey(
                        widget.textOnly ? 'ai-confirm' : 'voice-confirm',
                      ),
                      onPressed: _saving
                          ? null
                          : () => _save(accounts, categories),
                      icon: const Icon(Icons.check),
                      label: Text(
                        _saving ? '保存中…' : '确认 ${_transactions.length} 笔并保存',
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _save(List<Account> accounts, List<Category> categories) async {
    if (_unresolved.isNotEmpty) {
      setState(() => _error = '仍有未解析内容，请先修改原文并重新解析');
      return;
    }
    final resolvedTransactions = _transactions
        .map((item) => _resolveAccount(item, accounts))
        .toList(growable: false);
    if (resolvedTransactions.any(
      (item) =>
          item.amount <= 0 ||
          !item.amount.isFinite ||
          !accounts.any((account) => account.id == item.accountId) ||
          !categories.any((category) => category.id == item.categoryId),
    )) {
      setState(() => _error = '请补全每笔账单的金额、分类和账户');
      return;
    }
    setState(() => _saving = true);
    var committedCount = 0;
    try {
      final saved = await ref.read(quickBookkeepingServiceProvider).saveAll([
        for (var index = 0; index < resolvedTransactions.length; index++)
          QuickBookkeepingRequest(
            bookId: widget.bookId,
            type: resolvedTransactions[index].type,
            amount: resolvedTransactions[index].amount,
            currency: accounts
                .firstWhere(
                  (a) => a.id == resolvedTransactions[index].accountId,
                )
                .currency,
            accountId: resolvedTransactions[index].accountId!,
            occurredAt: resolvedTransactions[index].occurredAt,
            categoryId:
                categories
                    .firstWhere(
                      (category) =>
                          category.id == resolvedTransactions[index].categoryId,
                    )
                    .parentId ??
                resolvedTransactions[index].categoryId,
            subcategoryId: _resolvedSubcategory(
              resolvedTransactions[index],
              categories,
            ),
            categoryName: resolvedTransactions[index].categoryName,
            merchant: resolvedTransactions[index].merchant,
            source: TransactionSource.voice,
            metadata: {
              'entryMode': widget.textOnly ? 'text' : 'voice',
              'rawText': resolvedTransactions[index].rawFragment,
              'confidence': resolvedTransactions[index].confidence,
              'parser': resolvedTransactions[index].source.name,
            },
            userCorrected: _categoryCorrections.contains(index),
          ),
      ]);
      committedCount = saved.length;
      for (final index in _categoryCorrections) {
        final item = resolvedTransactions[index];
        if ((item.merchant ?? '').trim().isNotEmpty) {
          await ref
              .read(merchantRuleRepositoryProvider)
              .correctTransaction(
                transactionId: saved[index].id,
                categoryId: item.categoryId!,
                rememberForMerchant: true,
              );
        }
      }
      if (!mounted) return;
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '已保存 ${saved.length} 笔${widget.textOnly ? 'AI' : '语音'}账单',
          ),
        ),
      );
    } on BookkeepingCommittedException catch (error) {
      if (!mounted) return;
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '已入账 ${error.records.length} 笔，但${error.stage}失败，请稍后检查',
          ),
        ),
      );
    } on Object catch (error) {
      if (!mounted) return;
      if (committedCount > 0) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已保存 $committedCount 笔，但商户记忆未更新，请稍后检查')),
        );
      } else {
        setState(() => _error = '保存失败：$error');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String? _resolvedSubcategory(
    ParsedVoiceTransaction item,
    List<Category> categories,
  ) {
    final category = categories
        .where((category) => category.id == item.categoryId)
        .firstOrNull;
    if (category?.parentId != null) return category!.id;
    return categories
        .where(
          (child) =>
              child.parentId == item.categoryId &&
              child.name == item.subcategoryName,
        )
        .firstOrNull
        ?.id;
  }

  ParsedVoiceTransaction _resolveAccount(
    ParsedVoiceTransaction item,
    List<Account> accounts,
  ) {
    if (item.identifierSuffix != null) {
      final suffixMatches = accounts
          .where((account) => account.identifierSuffix == item.identifierSuffix)
          .toList();
      return suffixMatches.length == 1
          ? item.copyWith(
              accountId: suffixMatches.single.id,
              accountName: suffixMatches.single.displayName,
            )
          : item;
    }
    if (item.accountId != null && accounts.any((a) => a.id == item.accountId)) {
      final account = accounts.firstWhere((a) => a.id == item.accountId);
      return item.copyWith(accountName: account.displayName);
    }
    final matches = accounts.where((account) {
      if (item.identifierSuffix != null &&
          account.identifierSuffix == item.identifierSuffix) {
        return true;
      }
      final name = item.accountName?.trim();
      return name != null &&
          name.isNotEmpty &&
          (account.displayName == name || account.name == name);
    }).toList();
    return matches.length == 1
        ? item.copyWith(
            accountId: matches.single.id,
            accountName: matches.single.displayName,
          )
        : item;
  }
}

class _ListeningPulse extends StatelessWidget {
  const _ListeningPulse();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 13,
      height: 13,
      decoration: const BoxDecoration(
        color: AppColors.warning,
        shape: BoxShape.circle,
      ),
    );
  }
}

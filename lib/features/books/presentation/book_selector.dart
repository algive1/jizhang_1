import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/constants/app_assets.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/database/database_seeder.dart';
import '../../../core/models/book.dart';
import '../../../core/models/family.dart';
import '../../../core/models/membership.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../membership/data/membership_repository.dart';
import '../data/book_repository.dart';

class BookSelectorButton extends ConsumerWidget {
  const BookSelectorButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final book = ref.watch(activeBookProvider);
    return Semantics(
      button: true,
      label: '切换账本',
      child: InkWell(
        onTap: () => showBookSelectorSheet(context, ref),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  book?.name ?? '选择账本',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 18,
                color: AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> showBookSelectorSheet(BuildContext context, WidgetRef ref) async {
  await showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: '关闭账本书架',
    barrierColor: Colors.black45,
    transitionDuration: MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 240),
    transitionBuilder: (context, animation, secondary, child) =>
        SlideTransition(
          position: Tween(begin: const Offset(0, -1), end: Offset.zero).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
          ),
          child: child,
        ),
    pageBuilder: (context, animation, secondary) => const SafeArea(
      child: Align(alignment: Alignment.topCenter, child: _BookSelectorSheet()),
    ),
  );
}

class _BookSelectorSheet extends ConsumerStatefulWidget {
  const _BookSelectorSheet();
  @override
  ConsumerState<_BookSelectorSheet> createState() => _BookSelectorSheetState();
}

class _BookSelectorSheetState extends ConsumerState<_BookSelectorSheet> {
  bool _switching = false;

  Widget _shelfBuild(BuildContext context) {
    final booksState = ref.watch(booksProvider);
    final membership = ref.watch(membershipProvider).value;
    final books = booksState.value ?? const <LedgerBook>[];
    final selectedId = ref.watch(activeBookIdProvider);
    final largeText = MediaQuery.textScalerOf(context).scale(1) > 1.15;
    final width = MediaQuery.sizeOf(context).width.clamp(320.0, 600.0);
    final imageHeight = width * 1095 / 1437;
    final active = books.where((book) => book.id == selectedId).firstOrNull;
    final ordered = [...books];
    final previewBooks = ordered.take(3).toList();
    if (active != null && !previewBooks.any((book) => book.id == active.id)) {
      if (previewBooks.length == 3) {
        previewBooks[2] = active;
      } else {
        previewBooks.add(active);
      }
    }
    final ownedCount = BookLimitPolicy.ownedCount(
      books,
      ownerUserId: ref.read(databaseProvider).currentActor,
    );
    return Material(
      color: const Color(0xFFFAF7EF),
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 600,
          maxHeight: MediaQuery.sizeOf(context).height * .72,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: largeText ? 82 : 56,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 12, 4),
                  child: Row(
                    children: [
                      const UserAvatar(radius: 20),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '我的账本',
                                  style: TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                SizedBox(width: 4),
                                Icon(
                                  Icons.keyboard_arrow_up_rounded,
                                  size: 20,
                                  color: AppColors.textPrimary,
                                ),
                              ],
                            ),
                            Text(
                              '记录生活  更好地生活',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: '支付通知记账',
                        onPressed: () =>
                            context.push('/profile/payment-notifications'),
                        icon: Icon(
                          Icons.notifications_none_rounded,
                          color: AppColors.textPrimary,
                          size: 24,
                        ),
                      ),
                      IconButton(
                        tooltip: '搜索流水',
                        onPressed: () => context.push('/transactions/search'),
                        style: ButtonStyle(
                          backgroundColor: WidgetStatePropertyAll(
                            Color(0xFFF2EEE3),
                          ),
                        ),
                        icon: Icon(
                          Icons.search_rounded,
                          color: AppColors.textPrimary,
                          size: 21,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(
                width: width,
                height: imageHeight,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: Image.asset(AppAssets.bookshelf, fit: BoxFit.fill),
                    ),
                    Positioned(
                      top: imageHeight * .035,
                      left: width * .09,
                      right: width * .07,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Expanded(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                '选择账本',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF57351D),
                                ),
                              ),
                            ),
                          ),
                          TextButton.icon(
                            onPressed: active == null
                                ? null
                                : () => _manageBook(context, ref, active),
                            style: TextButton.styleFrom(
                              minimumSize: const Size(0, 36),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                              ),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            icon: const Icon(
                              Icons.settings_outlined,
                              size: 18,
                              color: Color(0xFF76502C),
                            ),
                            label: const Text(
                              '管理',
                              style: TextStyle(color: Color(0xFF76502C)),
                            ),
                          ),
                          IconButton(
                            tooltip: '关闭书架',
                            onPressed: () => Navigator.pop(context),
                            style: IconButton.styleFrom(
                              backgroundColor: const Color(0xFF76502C),
                              foregroundColor: Colors.white,
                              minimumSize: const Size(28, 28),
                              padding: EdgeInsets.zero,
                            ),
                            icon: const Icon(Icons.close, size: 18),
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      top: imageHeight * .095,
                      left: width * .22,
                      right: width * .16,
                      child: Text(
                        '让每一份账本，都记录一段美好生活',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: const Color(0xFF76502C).withValues(alpha: .75),
                          fontSize: 11,
                        ),
                      ),
                    ),
                    if (booksState.isLoading)
                      const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.primary,
                        ),
                      ),
                    if (booksState.hasError)
                      Center(
                        child: TextButton(
                          onPressed: () => ref.invalidate(booksProvider),
                          child: const Text('账本读取失败，点击重试'),
                        ),
                      ),
                    ...previewBooks.asMap().entries.map((entry) {
                      final book = entry.value;
                      final top =
                          imageHeight * [0.174, 0.369, 0.553][entry.key];
                      return Positioned(
                        left: width * .17,
                        right: width * .12,
                        top: top,
                        height: imageHeight * .145,
                        child: _ShelfBookRow(
                          key: ValueKey('book-shelf-row-${book.id}'),
                          book: book,
                          selected: book.id == selectedId,
                          onTap: _switching ? null : () => _select(book),
                          onLongPress: () => _manageBook(context, ref, book),
                        ),
                      );
                    }),
                    Positioned(
                      left: width * .23,
                      right: width * .15,
                      top: imageHeight * .72,
                      height: imageHeight * .14,
                      child: CustomPaint(
                        key: const ValueKey('book-create-area'),
                        painter: const _DashedBorderPainter(),
                        child: InkWell(
                          onTap: _switching
                              ? null
                              : (ownedCount >=
                                        BookLimitPolicy.forPlan(
                                          membership?.membership.plan ??
                                              MembershipPlan.free,
                                        )
                                    ? () =>
                                          _showLimitMessage(context, membership)
                                    : () => _createBook(context, ref)),
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            child: Row(
                              children: [
                                Container(
                                  width: imageHeight * .06,
                                  height: imageHeight * .06,
                                  decoration: const BoxDecoration(
                                    color: AppColors.primary,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.add,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Expanded(
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerLeft,
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '新建账本',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF4A3524),
                                          ),
                                        ),
                                        Text(
                                          '创建专属账本，开始新的记账之旅',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Color(0xFF806B58),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const Icon(
                                  Icons.chevron_right,
                                  color: Color(0xFF66503A),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: imageHeight * .035,
                      left: 0,
                      right: 0,
                      child: InkWell(
                        key: const ValueKey('book-more'),
                        onTap: books.length > 3
                            ? () => _showAllBooks(context, books)
                            : null,
                        child: Center(
                          child: Text(
                            books.length > 3
                                ? '—   查看全部账本（${books.length}）   —'
                                : '共 ${books.length} 个账本',
                            style: TextStyle(
                              color: const Color(
                                0xFF76502C,
                              ).withValues(alpha: books.length > 3 ? 1 : .72),
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _shelfBuild(context);
    /*
    final booksState = ref.watch(booksProvider);
    final membership = ref.watch(membershipProvider).value;
    final limit = BookLimitPolicy.forPlan(
      membership?.membership.plan ?? MembershipPlan.free,
    );
    final books = booksState.value ?? const <LedgerBook>[];
    final ownedCount = books
        .where((b) => !b.isShared || b.role == 'owner')
        .length;
    final width = MediaQuery.sizeOf(context).width;
    final largeText = MediaQuery.textScalerOf(context).scale(14) > 18;
    final columns = width < 360 || largeText ? 2 : 3;
    return Material(
      color: AppColors.background,
      elevation: 18,
      shadowColor: Colors.black54,
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 600,
          maxHeight: MediaQuery.sizeOf(context).height * .72,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFC9B99D),
                    borderRadius: BorderRadius.circular(4),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x24000000),
                        blurRadius: 2,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 7),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      '我的账本',
                      style: TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: '关闭书架',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              Text(
                '选择一本，专心记录这一部分生活',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              Flexible(
                child: booksState.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (error, stack) => TextButton(
                    onPressed: () => ref.invalidate(booksProvider),
                    child: const Text('账本读取失败，点击重试'),
                  ),
                  data: (books) => ListView.builder(
                    shrinkWrap: true,
                    itemCount: (books.length / columns).ceil(),
                    itemBuilder: (context, row) => Padding(
                      padding: const EdgeInsets.only(bottom: 20),
                      child: Column(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFFF3E9D8),
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(9),
                              ),
                              border: Border.all(
                                color: const Color(0xFFE4D6BE),
                              ),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x0F000000),
                                  blurRadius: 5,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
                            child: Column(
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    for (var col = 0; col < columns; col++)
                                      Expanded(
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 5,
                                          ),
                                          child:
                                              row * columns + col >=
                                                  books.length
                                              ? const SizedBox.shrink()
                                              : _BookCover(
                                                  book:
                                                      books[row * columns +
                                                          col],
                                                  selected:
                                                      books[row * columns + col]
                                                          .id ==
                                                      ref.watch(
                                                        activeBookIdProvider,
                                                      ),
                                                  height: largeText ? 212 : 166,
                                                  onSelect: _switching
                                                      ? null
                                                      : () => _select(
                                                          books[row * columns +
                                                              col],
                                                        ),
                                                  onManage: () => _manageBook(
                                                    context,
                                                    ref,
                                                    books[row * columns + col],
                                                  ),
                                                ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 5),
                                Container(
                                  height: 13,
                                  decoration: BoxDecoration(
                                    borderRadius: const BorderRadius.vertical(
                                      bottom: Radius.circular(4),
                                    ),
                                    gradient: const LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Color(0xFFE1CBAA),
                                        Color(0xFFC5A77D),
                                      ],
                                    ),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Color(0x35000000),
                                        blurRadius: 5,
                                        offset: Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                  child: const Align(
                                    alignment: Alignment.topCenter,
                                    child: SizedBox(
                                      height: 2,
                                      width: double.infinity,
                                      child: ColoredBox(
                                        color: Color(0x66FFF8EA),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              OutlinedButton.icon(
                onPressed: _switching
                    ? null
                    : ownedCount >= limit
                    ? () => _showLimitMessage(context, membership)
                    : () => _createBook(context, ref),
                icon: const Icon(Icons.add),
                label: Text('新建账本 · $ownedCount/$limit'),
              ),
            ],
          ),
        ),
      ),
    );
  }
  */
  }

  Future<void> _select(LedgerBook book) async {
    if (ref.read(activeBookIdProvider) == book.id) {
      if (mounted) {
        final messenger = ScaffoldMessenger.maybeOf(context);
        Navigator.pop(context);
        messenger?.showSnackBar(SnackBar(content: Text('当前已是「${book.name}」')));
      }
      return;
    }
    setState(() => _switching = true);
    try {
      await ref.read(activeBookIdProvider.notifier).select(book.id);
      if (mounted) {
        final messenger = ScaffoldMessenger.maybeOf(context);
        Navigator.pop(context);
        messenger?.showSnackBar(SnackBar(content: Text('已切换到「${book.name}」')));
      }
    } on Object catch (error) {
      if (mounted) {
        setState(() => _switching = false);
        _showError(context, error);
      }
    }
  }

  Future<void> _createBook(BuildContext context, WidgetRef ref) async {
    final type = await _askType(context);
    if (type == null || !context.mounted) return;
    final name = await _askName(context, title: '新建${type.label}');
    if (name == null || !context.mounted) return;
    try {
      final book = await ref
          .read(bookRepositoryProvider)
          .create(name: name, type: type);
      ref.invalidate(booksProvider);
      await ref.read(activeBookIdProvider.notifier).select(book.id);
      if (context.mounted) Navigator.pop(context);
    } on Object catch (error) {
      if (context.mounted) _showError(context, error);
    }
  }

  Future<void> _showAllBooks(
    BuildContext context,
    List<LedgerBook> books,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: ListView.separated(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
          itemCount: books.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (_, index) {
            final book = books[index];
            return _ShelfBookRow(
              book: book,
              selected: book.id == ref.read(activeBookIdProvider),
              onTap: _switching
                  ? null
                  : () {
                      Navigator.pop(sheetContext);
                      _select(book);
                    },
              onLongPress: () {
                Navigator.pop(sheetContext);
                _manageBook(context, ref, book);
              },
            );
          },
        ),
      ),
    );
  }

  Future<void> _manageBook(
    BuildContext context,
    WidgetRef ref,
    LedgerBook book,
  ) async {
    final action = await showModalBottomSheet<_BookAction>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              enabled: book.canManage,
              leading: const Icon(Icons.drive_file_rename_outline),
              title: const Text('重命名账本'),
              onTap: () => Navigator.pop(context, _BookAction.rename),
            ),
            if (book.id != SeedIds.personalBook && !book.isShared)
              ListTile(
                leading: const Icon(Icons.style_outlined),
                title: const Text('修改账本类型'),
                onTap: () => Navigator.pop(context, _BookAction.type),
              ),
            if (book.type != BookType.personal)
              ListTile(
                leading: const Icon(Icons.people_outline),
                title: Text(book.isShared ? '成员与同步' : '启用共享'),
                onTap: () => Navigator.pop(context, _BookAction.shared),
              ),
            if (book.id != SeedIds.personalBook &&
                (!book.isShared || book.role == 'owner'))
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('删除账本'),
                onTap: () => Navigator.pop(context, _BookAction.delete),
              ),
          ],
        ),
      ),
    );
    if (action == null || !context.mounted) return;
    if (action == _BookAction.shared) {
      final router = GoRouter.of(context);
      await ref.read(activeBookIdProvider.notifier).select(book.id);
      if (context.mounted) Navigator.pop(context);
      router.push('/profile/family');
      return;
    }
    if (action == _BookAction.type) {
      final type = await _askType(context);
      if (type != null) {
        try {
          await ref.read(bookRepositoryProvider).changeType(book.id, type);
        } on Object catch (error) {
          if (context.mounted) _showError(context, error);
        }
      }
      return;
    }
    if (action == _BookAction.rename) {
      final name = await _askName(context, title: '重命名账本', initial: book.name);
      if (name == null || !context.mounted) return;
      try {
        await ref.read(bookRepositoryProvider).rename(book.id, name);
        ref.invalidate(booksProvider);
      } on Object catch (error) {
        if (context.mounted) _showError(context, error);
      }
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('删除「${book.name}」？'),
        content: const Text('账本会从列表中移除，账本内记录不会再出现在当前统计中。此操作不可在应用内恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('确认删除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await ref.read(bookRepositoryProvider).archive(book.id);
      ref.invalidate(booksProvider);
      final remaining = await ref
          .read(bookRepositoryProvider)
          .getForUser(SeedIds.localUser);
      if (book.id == ref.read(activeBookIdProvider) && remaining.isNotEmpty) {
        await ref
            .read(activeBookIdProvider.notifier)
            .select(remaining.first.id);
      }
      if (context.mounted) Navigator.pop(context);
    } on Object catch (error) {
      if (context.mounted) _showError(context, error);
    }
  }

  Future<String?> _askName(
    BuildContext context, {
    required String title,
    String? initial,
  }) async {
    return showDialog<String>(
      context: context,
      builder: (_) => _BookNameDialog(title: title, initial: initial),
    );
  }

  void _showLimitMessage(BuildContext context, MembershipSnapshot? membership) {
    final plan = membership?.membership.plan.label ?? 'Free';
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('$plan 方案已达到账本数量上限，会员可创建更多账本。')));
  }

  void _showError(BuildContext context, Object error) {
    final message = error is BookLimitReachedException
        ? '已达到账本数量上限，请升级会员'
        : '操作失败：$error';
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}

class _BookNameDialog extends StatefulWidget {
  const _BookNameDialog({required this.title, this.initial});

  final String title;
  final String? initial;

  @override
  State<_BookNameDialog> createState() => _BookNameDialogState();
}

class _BookNameDialogState extends State<_BookNameDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initial,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final value = _controller.text.trim();
    if (value.isNotEmpty) Navigator.pop(context, value);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: TextField(
      controller: _controller,
      autofocus: true,
      maxLength: 40,
      decoration: const InputDecoration(hintText: '例如：旅行、装修、日常'),
      onSubmitted: (_) => _submit(),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('取消'),
      ),
      FilledButton(onPressed: _submit, child: const Text('保存')),
    ],
  );
}

class _ShelfBookRow extends StatelessWidget {
  const _ShelfBookRow({
    super.key,
    required this.book,
    required this.selected,
    this.onTap,
    this.onLongPress,
  });
  final LedgerBook book;
  final bool selected;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final icon = switch (book.type) {
      BookType.personal => Icons.person,
      BookType.family => Icons.home,
      BookType.enterprise => Icons.business,
    };
    final subtitle = switch (book.type) {
      BookType.personal => '记录自己的精彩生活',
      BookType.family => '和家人一起打理幸福',
      BookType.enterprise => '高效管理商务收支',
    };
    return Semantics(
      button: true,
      label: '${book.name}，$subtitle${selected ? '，当前账本' : ''}',
      child: GestureDetector(
        onLongPress: onLongPress,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Row(
            children: [
              SizedBox(
                width: 34,
                child: Center(
                  child: Icon(
                    icon,
                    color: selected
                        ? AppColors.primaryDark
                        : const Color(0xFF8B745E),
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        book.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF34271D),
                        ),
                      ),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 10,
                          color: Color(0xFF806B58),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (selected)
                const Padding(
                  padding: EdgeInsets.only(right: 6),
                  child: CircleAvatar(
                    radius: 11,
                    backgroundColor: AppColors.primary,
                    child: Icon(Icons.check, color: Colors.white, size: 15),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0x8866503A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(8)),
      );
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        canvas.drawPath(metric.extractPath(distance, distance + 5), paint);
        distance += 9;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) => false;
}

enum _BookAction { rename, delete, type, shared }

Future<BookType?> _askType(BuildContext context) => showDialog<BookType>(
  context: context,
  builder: (context) => SimpleDialog(
    title: const Text('选择账本用途'),
    children: [
      for (final type in BookType.values)
        SimpleDialogOption(
          onPressed: () => Navigator.pop(context, type),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Text(type.label),
          ),
        ),
    ],
  ),
);

// ignore: unused_element
class _BookCover extends StatelessWidget {
  const _BookCover({
    required this.book,
    required this.selected,
    required this.height,
    required this.onSelect,
    required this.onManage,
  });
  final LedgerBook book;
  final bool selected;
  final double height;
  final VoidCallback? onSelect;
  final VoidCallback onManage;
  @override
  Widget build(BuildContext context) {
    final color = switch (book.type) {
      BookType.personal => AppColors.primaryDark,
      BookType.family => const Color(0xFF976537),
      BookType.enterprise => const Color(0xFF44677E),
    };
    final dark = Color.lerp(color, Colors.black, .22)!;
    final light = Color.lerp(color, Colors.white, .34)!;
    return Semantics(
      selected: selected,
      button: true,
      label: '${book.name}，${book.type.label}',
      child: Container(
        height: height,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [light, color, dark],
            stops: const [0, .42, 1],
          ),
          borderRadius: const BorderRadius.horizontal(
            left: Radius.circular(4),
            right: Radius.circular(10),
          ),
          border: Border.all(
            color: selected ? Colors.white : Color.lerp(dark, color, .5)!,
            width: selected ? 2 : 1,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x30000000),
              blurRadius: 5,
              offset: Offset(3, 3),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.horizontal(
            left: Radius.circular(4),
            right: Radius.circular(10),
          ),
          child: Stack(
            children: [
              // The spine is kept visibly darker so each item reads as a real
              // book, even when several covers sit side by side.
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: 13,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [dark, color, light.withValues(alpha: .45)],
                    ),
                    border: Border(
                      right: BorderSide(
                        color: Colors.white.withValues(alpha: .26),
                      ),
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        height: 4,
                        color: Colors.white.withValues(alpha: .22),
                      ),
                      Container(
                        height: 4,
                        color: Colors.white.withValues(alpha: .22),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: 13,
                right: 6,
                top: 7,
                bottom: 7,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Colors.white.withValues(alpha: .25),
                    ),
                    borderRadius: const BorderRadius.horizontal(
                      right: Radius.circular(6),
                    ),
                    color: Colors.white.withValues(alpha: .045),
                  ),
                ),
              ),
              Positioned(
                left: 13,
                right: 0,
                top: 0,
                height: 4,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.white.withValues(alpha: .30),
                        Colors.white.withValues(alpha: .04),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: InkWell(
                  onTap: onSelect,
                  onLongPress: onManage,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 14, 9, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          selected
                              ? Icons.check_circle
                              : Icons.menu_book_outlined,
                          size: 24,
                          color: Colors.white.withValues(alpha: .92),
                          shadows: const [
                            Shadow(color: Color(0x55000000), blurRadius: 2),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Expanded(
                          child: Text(
                            book.name,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              shadows: const [
                                Shadow(color: Color(0x55000000), blurRadius: 2),
                              ],
                            ),
                          ),
                        ),
                        Text(
                          book.type.label,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: .94),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          book.sharedPhase == 'promoting'
                              ? '待上传'
                              : book.isShared
                              ? '共享'
                              : '本地',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: .78),
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 0,
                right: 0,
                child: IconButton(
                  tooltip: '管理${book.name}',
                  onPressed: onManage,
                  icon: Icon(
                    Icons.more_horiz,
                    size: 19,
                    color: Colors.white.withValues(alpha: .92),
                    shadows: const [
                      Shadow(color: Color(0x55000000), blurRadius: 2),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

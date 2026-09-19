import '../../../core/widgets/app_bottom_sheet.dart';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_assets.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/database/database_seeder.dart';
import '../../../core/formatters/book_title_formatter.dart';
import '../../../core/models/book.dart';
import '../../../core/models/family.dart';
import '../../../core/models/membership.dart';
import '../../../core/widgets/membership_button.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../../core/widgets/book_color_dot.dart';
import '../../membership/data/membership_repository.dart';
import '../data/book_repository.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_theme_tokens.dart';

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
                  style: TextStyle(
                    color: context.appPrimaryText,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 18,
                color: context.appSecondaryText,
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

Future<LedgerBook?> showBookChoiceSheet(
  BuildContext context, {
  required List<LedgerBook> books,
  required String selectedId,
}) {
  return showModalBottomSheet<LedgerBook>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: context.appBackground,
    builder: (_) => _BookChoiceSheet(books: books, selectedId: selectedId),
  );
}

class _BookChoiceSheet extends StatelessWidget {
  const _BookChoiceSheet({required this.books, required this.selectedId});

  final List<LedgerBook> books;
  final String selectedId;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * .72,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 2, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '选择记账账本',
                style: TextStyle(
                  color: context.appPrimaryText,
                  fontSize: 21,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '分类、账户和流水会跟随所选账本',
                style: TextStyle(color: context.appSecondaryText, fontSize: 12),
              ),
              const SizedBox(height: 10),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: books.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 6),
                  itemBuilder: (context, index) {
                    final book = books[index];
                    final selected = book.id == selectedId;
                    return _BookChoiceRow(
                      key: ValueKey('quick-book-${book.id}'),
                      book: book,
                      selected: selected,
                      onTap: () => Navigator.pop(context, book),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BookChoiceRow extends StatelessWidget {
  const _BookChoiceRow({
    super.key,
    required this.book,
    required this.selected,
    required this.onTap,
  });

  final LedgerBook book;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final icon = switch (book.type) {
      BookType.personal => Icons.person_outline,
      BookType.family => Icons.home_outlined,
      BookType.enterprise => Icons.business_outlined,
    };
    return Semantics(
      button: true,
      selected: selected,
      label: '${book.name}，${book.type.label}${selected ? '，当前账本' : ''}',
      child: Material(
        color: selected ? const Color(0xFFE4F5EF) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            child: Row(
              children: [
                Icon(icon, color: context.appPrimary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          BookColorDot(book: book, size: 10),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              book.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: context.appPrimaryText,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        book.type.label,
                        style: TextStyle(
                          color: context.appSecondaryText,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                if (selected)
                  Icon(Icons.check_circle, color: context.appPrimary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BookSelectorSheet extends ConsumerStatefulWidget {
  const _BookSelectorSheet();
  @override
  ConsumerState<_BookSelectorSheet> createState() => _BookSelectorSheetState();
}

class _BookSelectorSheetState extends ConsumerState<_BookSelectorSheet> {
  bool _switching = false;
  double _dragOffset = 0;

  void _onHeaderDragUpdate(DragUpdateDetails details) {
    final delta = details.primaryDelta ?? 0;
    if (delta <= 0 && _dragOffset == 0) return;
    setState(() {
      _dragOffset = (_dragOffset + delta).clamp(0, 260).toDouble();
    });
  }

  void _onHeaderDragEnd(DragEndDetails details) {
    if (_dragOffset >= 72) {
      Navigator.pop(context);
      return;
    }
    setState(() => _dragOffset = 0);
  }

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
    return Transform.translate(
      offset: Offset(0, _dragOffset),
      child: Material(
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
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onVerticalDragUpdate: _onHeaderDragUpdate,
                  onVerticalDragEnd: _onHeaderDragEnd,
                  child: SizedBox(
                    height: largeText ? 132 : 56,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 6, 10, 4),
                      child: Row(
                        children: [
                          const UserAvatar(radius: 19),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        formatBookTitle(active),
                                        style: TextStyle(
                                          color: context.appPrimaryText,
                                          fontSize: 20,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Icon(
                                        Icons.keyboard_arrow_up_rounded,
                                        size: 20,
                                        color: context.appPrimaryText,
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  '记录生活  更好地生活',
                                  maxLines: largeText ? 2 : 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: context.appSecondaryText,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          MembershipButton(
                            onPressed: () =>
                                _closeAndPush(context, '/profile/membership'),
                          ),
                          IconButton(
                            tooltip: '支付通知记账',
                            constraints: const BoxConstraints.tightFor(
                              width: 36,
                              height: 36,
                            ),
                            padding: EdgeInsets.zero,
                            onPressed: () => _closeAndPush(
                              context,
                              '/profile/payment-notifications',
                            ),
                            icon: Icon(
                              Icons.notifications_none_rounded,
                              color: context.appPrimaryText,
                              size: 24,
                            ),
                          ),
                          IconButton(
                            tooltip: '搜索流水',
                            onPressed: () =>
                                _closeAndPush(context, '/transactions/search'),
                            style: ButtonStyle(
                              backgroundColor: WidgetStatePropertyAll(
                                Color(0xFFF2EEE3),
                              ),
                              minimumSize: const WidgetStatePropertyAll(
                                Size(36, 36),
                              ),
                              maximumSize: const WidgetStatePropertyAll(
                                Size(36, 36),
                              ),
                              padding: const WidgetStatePropertyAll(
                                EdgeInsets.zero,
                              ),
                              shape: const WidgetStatePropertyAll(
                                CircleBorder(),
                              ),
                            ),
                            icon: Icon(
                              Icons.search_rounded,
                              color: context.appPrimaryText,
                              size: 21,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  width: width,
                  height: imageHeight,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: Image.asset(
                          AppAssets.bookshelfEmpty,
                          fit: BoxFit.fill,
                        ),
                      ),
                      Positioned(
                        top: imageHeight * .045,
                        left: width * .085,
                        right: width * .045,
                        height: imageHeight * .105,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  Flexible(
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment: Alignment.centerLeft,
                                      child: const Text(
                                        '选择账本',
                                        maxLines: 1,
                                        style: TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF57351D),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      '让每一份账本，都记录一段美好生活',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: Color(0xFF76502C)
                                            .withValues(alpha: .75),
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (booksState.isLoading)
                        Center(
                          child: CircularProgressIndicator(
                            color: context.appPrimary,
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
                          left: width * .12,
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
                                      ? () => _showLimitMessage(
                                          context,
                                          membership,
                                        )
                                      : () => _createBook(context, ref)),
                            borderRadius: BorderRadius.circular(12),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: imageHeight * .06,
                                    height: imageHeight * .06,
                                    decoration: BoxDecoration(
                                      color: context.appPrimary,
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
      color: context.appBackground,
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
                        color: context.appPrimaryText,
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
    final draft = await _askCreateBook(context);
    if (draft == null || !context.mounted) return;
    try {
      final book = await ref
          .read(bookRepositoryProvider)
          .create(
            name: draft.name,
            type: draft.type,
            usePrimaryAssets: draft.usePrimaryAssets,
          );
      ref.invalidate(booksProvider);
      await ref.read(activeBookIdProvider.notifier).select(book.id);
      if (context.mounted) {
        ScaffoldMessenger.maybeOf(context)
            ?.showSnackBar(SnackBar(content: Text('已创建并切换到「${book.name}」')));
      }
    } on Object catch (error) {
      if (context.mounted) _showError(context, error);
    }
  }

  Future<void> _showAllBooks(
    BuildContext context,
    List<LedgerBook> books,
  ) async {
    final membership = ref.read(membershipProvider).value;
    final ownedCount = BookLimitPolicy.ownedCount(
      books,
      ownerUserId: ref.read(databaseProvider).currentActor,
    );
    final limit = BookLimitPolicy.forPlan(
      membership?.membership.plan ?? MembershipPlan.free,
    );
    await showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => _AllBooksSheet(
        initialBooks: books,
        ownedCount: ownedCount,
        limit: limit,
        onCreate: () {
          Navigator.pop(sheetContext);
          if (ownedCount >= limit) {
            _showLimitMessage(context, membership);
          } else {
            _createBook(context, ref);
          }
        },
        onSelect: (book) {
          Navigator.pop(sheetContext);
          _select(book);
        },
        onManage: (book) {
          Navigator.pop(sheetContext);
          _manageBook(context, ref, book);
        },
      ),
    );
  }

  Future<void> _showBookOrder(BuildContext context, WidgetRef ref) async {
    final books = await ref
        .read(bookRepositoryProvider)
        .getForUser(SeedIds.localUser);
    if (!context.mounted || books.length < 2) return;
    final order = await showModalBottomSheet<List<String>>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _BookOrderSheet(books: books),
    );
    if (order == null || !context.mounted) return;
    try {
      await ref.read(bookRepositoryProvider).reorder(order);
      ref.invalidate(booksProvider);
      if (context.mounted) {
        ScaffoldMessenger.maybeOf(context)
            ?.showSnackBar(const SnackBar(content: Text('账本顺序已保存')));
      }
    } on Object catch (error) {
      if (context.mounted) _showError(context, error);
    }
  }

  Future<void> _manageBook(
    BuildContext context,
    WidgetRef ref,
    LedgerBook book,
  ) async {
    final action = await AppBottomSheet.show<_BookAction>(
      context: context,
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
            if (book.id != SeedIds.personalBook)
              ListTile(
                enabled: book.canManage,
                leading: const Icon(Icons.account_balance_wallet_outlined),
                title: const Text('使用主账本资产'),
                subtitle: Text(
                  book.usesPrimaryAssets ? '已开启：共用默认账本账户' : '已关闭：使用本账本账户',
                ),
                trailing: Switch(
                  value: book.usesPrimaryAssets,
                  onChanged: book.canManage
                      ? (_) => Navigator.pop(context, _BookAction.assets)
                      : null,
                ),
                onTap: book.canManage
                    ? () => Navigator.pop(context, _BookAction.assets)
                    : null,
              ),
            ListTile(
              leading: Icon(Icons.swap_vert_rounded),
              title: Text('排序账本'),
              onTap: () => Navigator.pop(context, _BookAction.sort),
            ),
            ListTile(
              leading: Icon(
                book.id == ref.read(activeBookIdProvider)
                    ? Icons.star
                    : Icons.star_border,
                color: context.appPrimary,
              ),
              title: Text(
                book.id == ref.read(activeBookIdProvider)
                    ? '设为默认账本（当前）'
                    : '设为默认账本',
              ),
              onTap: () => Navigator.pop(context, _BookAction.defaultBook),
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
    if (action == _BookAction.assets) {
      try {
        await ref
            .read(bookRepositoryProvider)
            .setUsePrimaryAssets(book.id, !book.usesPrimaryAssets);
        ref.invalidate(booksProvider);
        if (context.mounted) {
          ScaffoldMessenger.maybeOf(context)?.showSnackBar(
            SnackBar(
              content: Text(
                book.usesPrimaryAssets ? '已改为使用本账本资产' : '已改为使用主账本资产',
              ),
            ),
          );
        }
      } on Object catch (error) {
        if (context.mounted) _showError(context, error);
      }
      return;
    }
    if (action == _BookAction.sort) {
      await _showBookOrder(context, ref);
      return;
    }
    if (action == _BookAction.defaultBook) {
      try {
        await ref.read(bookRepositoryProvider).setDefault(book.id);
        await ref.read(activeBookIdProvider.notifier).select(book.id);
        ref.invalidate(booksProvider);
        if (context.mounted) {
          ScaffoldMessenger.maybeOf(context)
              ?.showSnackBar(SnackBar(content: Text('已将「${book.name}」设为默认账本')));
        }
      } on Object catch (error) {
        if (context.mounted) _showError(context, error);
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
      if (context.mounted) {
        ScaffoldMessenger.maybeOf(context)
            ?.showSnackBar(SnackBar(content: Text('已删除「${book.name}」')));
      }
    } on Object catch (error) {
      if (context.mounted) _showError(context, error);
    }
  }

  void _closeAndPush(BuildContext context, String location) {
    final router = GoRouter.of(context);
    Navigator.of(context).pop();
    router.push(location);
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

  Future<_CreateBookDraft?> _askCreateBook(BuildContext context) {
    return showModalBottomSheet<_CreateBookDraft>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => const _CreateBookSheet(),
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

class _AllBooksSheet extends ConsumerStatefulWidget {
  const _AllBooksSheet({
    required this.initialBooks,
    required this.ownedCount,
    required this.limit,
    required this.onCreate,
    required this.onSelect,
    required this.onManage,
  });

  final List<LedgerBook> initialBooks;
  final int ownedCount;
  final int limit;
  final VoidCallback onCreate;
  final ValueChanged<LedgerBook> onSelect;
  final ValueChanged<LedgerBook> onManage;

  @override
  ConsumerState<_AllBooksSheet> createState() => _AllBooksSheetState();
}

class _AllBooksSheetState extends ConsumerState<_AllBooksSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final books = ref.watch(booksProvider).value ?? widget.initialBooks;
    final query = _query.trim().toLowerCase();
    final filteredBooks = query.isEmpty
        ? books
        : books
              .where((book) => book.name.toLowerCase().contains(query))
              .toList();
    return Material(
      color: context.appBackground,
      child: SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * .86,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '全部账本',
                        style: TextStyle(
                          color: context.appPrimaryText,
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    TextButton.icon(
                      key: const ValueKey('all-books-create'),
                      onPressed: widget.onCreate,
                      icon: const Icon(Icons.add),
                      label: const Text('新建'),
                    ),
                  ],
                ),
                Text(
                  '自有账本 ${widget.ownedCount}/${widget.limit} · 加入的共享账本不占额度',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 10),
                TextField(
                  key: const ValueKey('all-books-search'),
                  onChanged: (value) => setState(() => _query = value),
                  decoration: const InputDecoration(
                    hintText: '搜索账本名称',
                    prefixIcon: Icon(Icons.search_rounded),
                  ),
                ),
                const SizedBox(height: 8),
                if (filteredBooks.isEmpty)
                  const Expanded(child: Center(child: Text('没有匹配的账本')))
                else
                  Expanded(
                    child: ListView.separated(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      itemCount: filteredBooks.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final book = filteredBooks[index];
                        return _AllBookListRow(
                          key: ValueKey('book-all-row-${book.id}'),
                          book: book,
                          selected: book.id == ref.watch(activeBookIdProvider),
                          onSelect: () => widget.onSelect(book),
                          onManage: () => widget.onManage(book),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AllBookListRow extends StatelessWidget {
  const _AllBookListRow({
    super.key,
    required this.book,
    required this.selected,
    required this.onSelect,
    required this.onManage,
  });

  final LedgerBook book;
  final bool selected;
  final VoidCallback onSelect;
  final VoidCallback onManage;

  @override
  Widget build(BuildContext context) {
    final icon = switch (book.type) {
      BookType.personal => Icons.person,
      BookType.family => Icons.home,
      BookType.enterprise => Icons.business,
    };
    final iconColor = switch (book.type) {
      BookType.personal => AppColors.primary,
      BookType.family => const Color(0xFF976537),
      BookType.enterprise => const Color(0xFF44677E),
    };
    final syncLabel = !book.isShared
        ? '仅本机'
        : book.sharedPhase == 'promoting'
        ? '同步中'
        : '已同步';
    return Semantics(
      button: true,
      selected: selected,
      label:
          '${book.name}，${book.type.label}，$syncLabel${selected ? '，当前账本' : ''}',
      child: Material(
        color: context.appSurface,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onSelect,
          onLongPress: onManage,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: iconColor.withValues(alpha: .12),
                  child: Icon(icon, color: iconColor, size: 21),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        book.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: context.appPrimaryText,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${book.type.label} · $syncLabel',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                if (selected)
                  Padding(
                    padding: EdgeInsets.only(right: 2),
                    child: Icon(Icons.check_circle, color: context.appPrimary),
                  ),
                IconButton(
                  key: ValueKey('book-manage-${book.id}'),
                  tooltip: '管理${book.name}',
                  onPressed: onManage,
                  icon: const Icon(Icons.more_horiz),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CreateBookDraft {
  const _CreateBookDraft({
    required this.name,
    required this.type,
    required this.usePrimaryAssets,
  });

  final String name;
  final BookType type;
  final bool usePrimaryAssets;
}

class _CreateBookSheet extends StatefulWidget {
  const _CreateBookSheet();

  @override
  State<_CreateBookSheet> createState() => _CreateBookSheetState();
}

class _CreateBookSheetState extends State<_CreateBookSheet> {
  late final TextEditingController _nameController = TextEditingController();
  BookType _type = BookType.personal;
  bool _usePrimaryAssets = false;
  String? _errorText;
  bool _submitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _errorText = '请输入账本名称');
      return;
    }
    if (_submitting) return;
    setState(() => _submitting = true);
    Navigator.pop(
      context,
      _CreateBookDraft(
        name: name,
        type: _type,
        usePrimaryAssets: _usePrimaryAssets,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final name = _nameController.text.trim();
    return Material(
      color: const Color(0xFFFAF7EF),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          0,
          20,
          MediaQuery.viewInsetsOf(context).bottom + 20,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '新建账本',
                      style: TextStyle(
                        color: context.appPrimaryText,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  TextButton(
                    key: const ValueKey('book-create-cancel'),
                    onPressed: () => Navigator.pop(context),
                    child: Text('取消'),
                  ),
                ],
              ),
              Text(
                '填写名称，选择一种用途，再开始记录。',
                style: TextStyle(color: context.appSecondaryText),
              ),
              const SizedBox(height: 16),
              TextField(
                key: const ValueKey('book-create-name'),
                controller: _nameController,
                autofocus: true,
                maxLength: 40,
                textInputAction: TextInputAction.done,
                onChanged: (_) => setState(() => _errorText = null),
                onSubmitted: (_) => _submit(),
                decoration: InputDecoration(
                  labelText: '账本名称',
                  hintText: '例如：旅行、装修、日常',
                  errorText: _errorText,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '选择用途',
                style: TextStyle(
                  color: context.appPrimaryText,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final type in BookType.values)
                    ChoiceChip(
                      key: ValueKey('book-type-${type.name}'),
                      selected: _type == type,
                      onSelected: (_) => setState(() => _type = type),
                      avatar: Icon(_bookTypeIcon(type), size: 18),
                      label: Text(type.label),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                key: const ValueKey('book-create-use-primary-assets'),
                contentPadding: EdgeInsets.zero,
                title: const Text('使用主账本资产'),
                subtitle: const Text('开启后此账本与默认账本共用账户和资产余额'),
                value: _usePrimaryAssets,
                onChanged: _submitting
                    ? null
                    : (value) => setState(() => _usePrimaryAssets = value),
              ),
              const SizedBox(height: 16),
              _BookCreatePreview(type: _type, name: name),
              const SizedBox(height: 18),
              FilledButton(
                key: const ValueKey('book-create-submit'),
                onPressed: _submitting ? null : _submit,
                child: const Text('创建账本'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BookCreatePreview extends StatelessWidget {
  const _BookCreatePreview({required this.type, required this.name});

  final BookType type;
  final String name;

  @override
  Widget build(BuildContext context) {
    final color = _bookTypeColor(type);
    return Container(
      key: const ValueKey('book-create-preview'),
      height: 116,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          colors: [color.withValues(alpha: .76), color],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: Colors.white.withValues(alpha: .86),
            child: Icon(_bookTypeIcon(type), color: color, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name.isEmpty ? '未命名账本' : name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  type.label,
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

IconData _bookTypeIcon(BookType type) => switch (type) {
  BookType.personal => Icons.person,
  BookType.family => Icons.home,
  BookType.enterprise => Icons.business,
};

Color _bookTypeColor(BookType type) => switch (type) {
  BookType.personal => AppColors.primary,
  BookType.family => const Color(0xFF976537),
  BookType.enterprise => const Color(0xFF44677E),
};

Color _shelfCoverColor(BookType type) => switch (type) {
  BookType.personal => const Color(0xFFE9EBCF),
  BookType.family => const Color(0xFFF0D8C6),
  BookType.enterprise => const Color(0xFFB9C8D6),
};

Color _shelfCoverAccent(BookType type) => switch (type) {
  BookType.personal => const Color(0xFF789B3B),
  BookType.family => const Color(0xFFB77E54),
  BookType.enterprise => const Color(0xFF5A7C92),
};

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
    final cover = _shelfCoverColor(book.type);
    final accent = _shelfCoverAccent(book.type);
    final spine = Color.lerp(accent, Colors.black, .18)!;
    final subtitle = switch (book.type) {
      BookType.personal => '记录自己的精彩生活',
      BookType.family => '和家人一起打理幸福',
      BookType.enterprise => '高效管理商务收支',
    };
    final radius = BorderRadius.circular(7);
    return Semantics(
      selected: selected,
      button: true,
      label: '${book.name}，$subtitle${selected ? '，当前账本' : ''}',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: radius,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: 0,
                top: 3,
                bottom: 3,
                width: 24,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Color.lerp(spine, Colors.black, .18)!,
                        spine,
                        Color.lerp(spine, Colors.white, .2)!,
                      ],
                    ),
                    borderRadius: const BorderRadius.horizontal(
                      left: Radius.circular(6),
                    ),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: .28),
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x30000000),
                        blurRadius: 3,
                        offset: Offset(1, 2),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: 8,
                top: 1,
                bottom: 1,
                width: 25,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Color.lerp(spine, Colors.white, .1)!,
                        spine,
                        Color.lerp(spine, Colors.black, .08)!,
                      ],
                    ),
                    borderRadius: const BorderRadius.horizontal(
                      left: Radius.circular(6),
                    ),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: .3),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 17,
                top: 0,
                bottom: 0,
                width: 25,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Color.lerp(spine, Colors.white, .18)!,
                        spine,
                        Color.lerp(spine, Colors.black, .13)!,
                      ],
                    ),
                    borderRadius: const BorderRadius.horizontal(
                      left: Radius.circular(6),
                    ),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: .34),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 25,
                right: 0,
                top: 0,
                bottom: 0,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color.lerp(cover, Colors.white, .27)!,
                        cover,
                        Color.lerp(cover, Colors.black, .12)!,
                      ],
                      stops: const [0, .54, 1],
                    ),
                    borderRadius: radius,
                    border: Border.all(
                      color: selected
                          ? Colors.white
                          : Color.lerp(cover, spine, .55)!,
                      width: selected ? 2 : 1,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x3B000000),
                        blurRadius: 5,
                        offset: Offset(2, 3),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: radius,
                    child: Stack(
                      children: [
                        Positioned(
                          left: 0,
                          top: 0,
                          bottom: 0,
                          width: 32,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: .75),
                              border: Border(
                                right: BorderSide(
                                  color: spine.withValues(alpha: .28),
                                ),
                              ),
                            ),
                            child: Icon(
                              _bookTypeIcon(book.type),
                              color: accent,
                              size: 21,
                            ),
                          ),
                        ),
                        Positioned(
                          left: 42,
                          right: selected ? 38 : 10,
                          top: 0,
                          bottom: 0,
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
                                  style: TextStyle(
                                    fontSize: 15.5,
                                    fontWeight: FontWeight.w700,
                                    color: Color.lerp(
                                      Colors.black,
                                      accent,
                                      .18,
                                    ),
                                  ),
                                ),
                                Text(
                                  subtitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Color.lerp(
                                      Colors.black,
                                      accent,
                                      .44,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Positioned(
                          right: selected ? 29 : 14,
                          top: 3,
                          bottom: 3,
                          child: Opacity(
                            opacity: selected ? .24 : .28,
                            child: Icon(
                              Icons.eco_outlined,
                              color: accent,
                              size: 35,
                            ),
                          ),
                        ),
                        if (selected)
                          Positioned(
                            right: 10,
                            top: 0,
                            bottom: 0,
                            child: Center(
                              child: CircleAvatar(
                                radius: 10.5,
                                backgroundColor: accent,
                                child: const Icon(
                                  Icons.check,
                                  color: Colors.white,
                                  size: 15,
                                ),
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

enum _BookAction { rename, delete, type, shared, assets, sort, defaultBook }

class _BookOrderSheet extends StatefulWidget {
  const _BookOrderSheet({required this.books});

  final List<LedgerBook> books;

  @override
  State<_BookOrderSheet> createState() => _BookOrderSheetState();
}

class _BookOrderSheetState extends State<_BookOrderSheet> {
  late final List<LedgerBook> _books = [...widget.books];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * .72,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '排序账本',
                style: TextStyle(fontSize: 21, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                '长按拖动，顺序会同步到书架和首页切换列表',
                style: TextStyle(color: context.appSecondaryText, fontSize: 12),
              ),
              const SizedBox(height: 10),
              Flexible(
                child: ReorderableListView.builder(
                  shrinkWrap: true,
                  itemCount: _books.length,
                  onReorderItem: (oldIndex, newIndex) {
                    setState(() {
                      final book = _books.removeAt(oldIndex);
                      _books.insert(newIndex, book);
                    });
                  },
                  itemBuilder: (context, index) {
                    final book = _books[index];
                    return ListTile(
                      key: ValueKey(book.id),
                      leading: const Icon(Icons.menu),
                      title: Text(book.name),
                      subtitle: Text(book.type.label),
                    );
                  },
                ),
              ),
              const SizedBox(height: 10),
              FilledButton(
                onPressed: () => Navigator.pop(
                  context,
                  _books.map((book) => book.id).toList(growable: false),
                ),
                child: const Text('保存顺序'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

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
      BookType.personal => AppColors.primary,
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

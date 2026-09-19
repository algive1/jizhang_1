import '../../../core/widgets/app_action_sheet.dart';
import '../../../core/widgets/app_form.dart';
import '../../../core/utils/entity_id.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/category.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/category_icon.dart';
import '../data/category_repository.dart';
import '../../../app/theme/app_theme_tokens.dart';

class CategoryManagementPage extends ConsumerStatefulWidget {
  const CategoryManagementPage({super.key, this.bookId, this.onBack});

  final String? bookId;
  final VoidCallback? onBack;

  @override
  ConsumerState<CategoryManagementPage> createState() =>
      _CategoryManagementPageState();
}

class _CategoryManagementPageState
    extends ConsumerState<CategoryManagementPage> {
  CategoryType _type = CategoryType.expense;

  CategoryRepository get _repository => widget.bookId == null
      ? ref.read(categoryRepositoryProvider)
      : DriftCategoryRepository(
          ref.read(databaseProvider),
          bookId: widget.bookId!,
        );

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = widget.bookId == null
        ? ref.watch(categoriesProvider)
        : ref.watch(categoriesByBookProvider(widget.bookId!));
    final all = categoriesAsync.value ?? const <Category>[];
    final categories = all.where((item) => item.type == _type).toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    final roots = categories.where((item) => item.parentId == null).toList();

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          Row(
            children: [
              IconButton(
                onPressed: widget.onBack ?? () => context.go('/profile'),
                icon: const Icon(Icons.arrow_back),
              ),
              Expanded(
                child: Text(
                  '分类管理',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ),
              FilledButton.icon(
                onPressed: () => _editCategory(all: all),
                icon: const Icon(Icons.add),
                label: const Text('新增'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SegmentedButton<CategoryType>(
            segments: const [
              ButtonSegment(value: CategoryType.expense, label: Text('支出分类')),
              ButtonSegment(value: CategoryType.income, label: Text('收入分类')),
            ],
            selected: {_type},
            onSelectionChanged: (selection) =>
                setState(() => _type = selection.single),
          ),
          const SizedBox(height: 14),
          if (categoriesAsync.isLoading && categories.isEmpty)
            const Center(child: CircularProgressIndicator())
          else if (roots.isEmpty)
            const Center(child: Text('还没有分类'))
          else
            ...roots.asMap().entries.map((entry) {
              final root = entry.value;
              final children = categories
                  .where((item) => item.parentId == root.id)
                  .toList();
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: AppCard(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 5,
                  ),
                  borderRadius: 18,
                  child: Column(
                    children: [
                      _CategoryRow(
                        category: root,
                        canMoveUp: entry.key > 0,
                        canMoveDown: entry.key < roots.length - 1,
                        onMoveUp: () => _moveRoot(roots, entry.key, -1),
                        onMoveDown: () => _moveRoot(roots, entry.key, 1),
                        onEdit: () => _editCategory(all: all, category: root),
                        onArchive: () => _archive(root),
                      ),
                      ...children.map(
                        (child) => Padding(
                          padding: const EdgeInsets.only(left: 28),
                          child: _CategoryRow(
                            category: child,
                            onEdit: () =>
                                _editCategory(all: all, category: child),
                            onArchive: () => _archive(child),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          const SizedBox(height: 8),
          Text(
            '默认分类归档后仅隐藏，不会物理删除；历史流水仍保留原分类。',
            textAlign: TextAlign.center,
            style: TextStyle(color: context.appSecondaryText, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Future<void> _moveRoot(List<Category> roots, int index, int direction) async {
    final reordered = [...roots];
    final target = index + direction;
    final moved = reordered.removeAt(index);
    reordered.insert(target, moved);
    await _repository.reorder(reordered);
  }

  Future<void> _editCategory({
    required List<Category> all,
    Category? category,
  }) async {
    final result = await showDialog<Category>(
      context: context,
      builder: (_) =>
          _CategoryEditorDialog(category: category, all: all, type: _type),
    );
    if (result == null) return;
    final repository = _repository;
    if (category == null) {
      await repository.create(result);
    } else {
      await repository.update(result);
    }
  }

  Future<void> _archive(Category category) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('隐藏分类'),
        content: Text(
          category.parentId == null
              ? '隐藏“${category.name}”及其二级分类？历史流水不会删除。'
              : '隐藏“${category.name}”？历史流水不会删除。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('隐藏'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _repository.archive(category.id);
    }
  }
}

class _CategoryEditorDialog extends StatefulWidget {
  const _CategoryEditorDialog({
    required this.category,
    required this.all,
    required this.type,
  });

  final Category? category;
  final List<Category> all;
  final CategoryType type;

  @override
  State<_CategoryEditorDialog> createState() => _CategoryEditorDialogState();
}

class _CategoryEditorDialogState extends State<_CategoryEditorDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.category?.name,
  );
  late String? _parentId = widget.category?.parentId;

  List<Category> get _roots => widget.all
      .where(
        (item) =>
            item.type == widget.type &&
            item.parentId == null &&
            item.id != widget.category?.id,
      )
      .toList(growable: false);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.category == null ? '新增分类' : '编辑分类'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _controller,
            autofocus: true,
            decoration: const InputDecoration(labelText: '分类名称'),
          ),
          const SizedBox(height: 12),
          AppSelect<String?>(
            initialValue: _parentId,
            decoration: const InputDecoration(labelText: '上级分类'),
            items: [
              const DropdownMenuItem<String?>(
                value: null,
                child: Text('无（一级分类）'),
              ),
              ..._roots.map(
                (root) => DropdownMenuItem<String?>(
                  value: root.id,
                  child: Text(root.name),
                ),
              ),
            ],
            onChanged: (value) => setState(() => _parentId = value),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () {
            final name = _controller.text.trim();
            if (name.isEmpty) return;
            Navigator.pop(
              context,
              Category(
                bookId: widget.category?.bookId ?? 'book-personal',
                id: widget.category?.id ?? 'category-${newEntityId()}',
                parentId: _parentId,
                name: name,
                icon: widget.category?.icon ?? 'category_outlined',
                type: widget.type,
                sortOrder:
                    widget.category?.sortOrder ??
                    widget.all.where((item) => item.type == widget.type).length,
                isDefault: widget.category?.isDefault ?? false,
                isArchived: false,
              ),
            );
          },
          child: const Text('保存'),
        ),
      ],
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.category,
    required this.onEdit,
    required this.onArchive,
    this.canMoveUp = false,
    this.canMoveDown = false,
    this.onMoveUp,
    this.onMoveDown,
  });

  final Category category;
  final VoidCallback onEdit;
  final VoidCallback onArchive;
  final bool canMoveUp;
  final bool canMoveDown;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;

  @override
  Widget build(BuildContext context) {
    return AppContextMenu(
      onOpen: () async {
        final value = await AppActionSheet.show<String>(
          context,
          title: category.name,
          items: const [
            PopupMenuItem(value: 'edit', child: Text('编辑')),
            PopupMenuItem(value: 'archive', child: Text('隐藏')),
          ],
        );
        if (value != null && context.mounted) {
          value == 'edit' ? onEdit() : onArchive();
        }
      },
      child: Column(
        children: [
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: CategoryIcon(
              category: category.name,
              iconKey: category.icon,
              vivid: true,
              size: 36,
            ),
            title: Row(
              children: [
                Flexible(child: Text(category.name)),
                if (category.isDefault) ...[
                  const SizedBox(width: 6),
                  Text(
                    '默认',
                    style: TextStyle(
                      color: context.appSecondaryText,
                      fontSize: 10,
                    ),
                  ),
                ],
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (onMoveUp != null)
                  IconButton(
                    onPressed: canMoveUp ? onMoveUp : null,
                    icon: const Icon(Icons.keyboard_arrow_up),
                    tooltip: '上移',
                  ),
                if (onMoveDown != null)
                  IconButton(
                    onPressed: canMoveDown ? onMoveDown : null,
                    icon: const Icon(Icons.keyboard_arrow_down),
                    tooltip: '下移',
                  ),
                AppActionMenuButton<String>(
                  onSelected: (value) =>
                      value == 'edit' ? onEdit() : onArchive(),
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'edit', child: Text('编辑')),
                    PopupMenuItem(value: 'archive', child: Text('隐藏')),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),
        ],
      ),
    );
  }
}

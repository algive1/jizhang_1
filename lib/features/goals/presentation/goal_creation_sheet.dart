import '../../../core/widgets/app_form.dart';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/formatters/money_formatter.dart';
import '../../../core/models/goal.dart';
import '../application/goal_cover_storage_service.dart';
import '../data/goal_repository.dart';
import '../../../app/theme/app_theme_tokens.dart';

class GoalCreationDraft {
  const GoalCreationDraft({
    required this.name,
    required this.type,
    required this.targetAmount,
    required this.currentAmount,
    required this.targetDate,
    required this.milestones,
    this.description,
    this.coverPath,
  });

  final String name;
  final GoalType type;
  final double targetAmount;
  final double currentAmount;
  final DateTime targetDate;
  final List<double> milestones;
  final String? description;
  final String? coverPath;
}

Future<GoalCreationDraft?> showGoalCreationSheet(BuildContext context) {
  return showModalBottomSheet<GoalCreationDraft>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _GoalCreationSheet(),
  );
}

class _GoalCreationSheet extends ConsumerStatefulWidget {
  const _GoalCreationSheet();

  @override
  ConsumerState<_GoalCreationSheet> createState() => _GoalCreationSheetState();
}

class _GoalCreationSheetState extends ConsumerState<_GoalCreationSheet> {
  final _nameController = TextEditingController();
  final _targetController = TextEditingController();
  final _currentController = TextEditingController(text: '0');
  final _descriptionController = TextEditingController();
  GoalType _type = GoalType.custom;
  DateTime _targetDate = DateTime(DateTime.now().year + 1, 12);
  List<double> _milestones = [];
  String? _coverPath;

  @override
  void dispose() {
    _nameController.dispose();
    _targetController.dispose();
    _currentController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final target = double.tryParse(_targetController.text) ?? 0;
    return SafeArea(
      child: FractionallySizedBox(
        heightFactor: .93,
        child: Material(
          color: context.appSurface,
          clipBehavior: Clip.antiAlias,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: context.appDivider,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 10, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '创建目标',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                  children: [
                    TextField(
                      controller: _nameController,
                      autofocus: true,
                      decoration: const InputDecoration(
                        labelText: '目标名称',
                        hintText: '例如：买车计划',
                      ),
                    ),
                    const SizedBox(height: 12),
                    AppSelect<GoalType>(
                      initialValue: _type,
                      decoration: const InputDecoration(labelText: '目标类型'),
                      items: GoalType.values
                          .map(
                            (type) => DropdownMenuItem(
                              value: type,
                              child: Text(type.label),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value != null) setState(() => _type = value);
                      },
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _targetController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            onChanged: _regenerateMilestones,
                            decoration: const InputDecoration(
                              labelText: '目标金额',
                              prefixText: '¥ ',
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: _currentController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: '当前已有',
                              prefixText: '¥ ',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      tileColor: context.appSurfaceSoft,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      leading: Icon(
                        Icons.calendar_month_outlined,
                        color: context.appPrimary,
                      ),
                      title: Text('目标日期'),
                      trailing: Text(
                        '${_targetDate.year}年${_targetDate.month}月',
                        style: TextStyle(color: context.appPrimary),
                      ),
                      onTap: _pickTargetDate,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _descriptionController,
                      maxLines: 2,
                      decoration: const InputDecoration(labelText: '目标描述（可选）'),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _pickCover,
                      icon: const Icon(Icons.image_outlined),
                      label: Text(_coverPath == null ? '选择封面（可选）' : '更换封面'),
                    ),
                    if (_coverPath != null) ...[
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.file(
                          File(_coverPath!),
                          height: 120,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ],
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Text(
                          '阶段节点',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const Spacer(),
                        TextButton.icon(
                          onPressed: target > 0 ? () => _editMilestone() : null,
                          icon: Icon(Icons.add),
                          label: Text('新增节点'),
                        ),
                      ],
                    ),
                    Text(
                      '已根据目标金额自动建议，可点击修改；最终节点不可删除。',
                      style: TextStyle(
                        color: context.appSecondaryText,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (_milestones.isEmpty)
                      const Text('输入目标金额后自动生成节点')
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _milestones.map((amount) {
                          final isFinal =
                              (amount * 100).round() == (target * 100).round();
                          return InputChip(
                            label: Text('¥${MoneyFormatter.whole(amount)}'),
                            avatar: isFinal
                                ? const Icon(Icons.flag_outlined, size: 18)
                                : null,
                            onPressed: isFinal
                                ? null
                                : () => _editMilestone(existing: amount),
                            onDeleted: isFinal
                                ? null
                                : () => setState(
                                    () => _milestones.remove(amount),
                                  ),
                          );
                        }).toList(),
                      ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _submit,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 15),
                      ),
                      child: const Text('创建目标'),
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

  void _regenerateMilestones(String value) {
    final target = double.tryParse(value);
    setState(() {
      _milestones = target == null || target <= 0
          ? []
          : ref.read(goalMilestoneServiceProvider).suggest(target);
    });
  }

  Future<void> _pickTargetDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _targetDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 50)),
    );
    if (date != null && mounted) setState(() => _targetDate = date);
  }

  Future<void> _pickCover() async {
    try {
      final path = await ref
          .read(goalCoverStorageServiceProvider)
          .pickAndStore();
      if (path != null && mounted) setState(() => _coverPath = path);
    } on Object {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('封面读取失败，请重新选择')));
    }
  }

  Future<void> _editMilestone({double? existing}) async {
    final target = double.tryParse(_targetController.text) ?? 0;
    final result = await showDialog<double>(
      context: context,
      builder: (_) => _MilestoneInputDialog(existing: existing, target: target),
    );
    if (result == null || !mounted) return;
    setState(() {
      if (existing != null) _milestones.remove(existing);
      _milestones = {..._milestones, result, target}.toList()..sort();
    });
  }

  void _submit() {
    final name = _nameController.text.trim();
    final target = double.tryParse(_targetController.text);
    final current = double.tryParse(_currentController.text) ?? 0;
    if (name.isEmpty ||
        target == null ||
        target <= 0 ||
        current < 0 ||
        _milestones.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('请完整填写名称、金额和目标日期')));
      return;
    }
    Navigator.pop(
      context,
      GoalCreationDraft(
        name: name,
        type: _type,
        targetAmount: target,
        currentAmount: current,
        targetDate: _targetDate,
        milestones: _milestones,
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        coverPath: _coverPath,
      ),
    );
  }
}

class _MilestoneInputDialog extends StatefulWidget {
  const _MilestoneInputDialog({this.existing, required this.target});

  final double? existing;
  final double target;

  @override
  State<_MilestoneInputDialog> createState() => _MilestoneInputDialogState();
}

class _MilestoneInputDialogState extends State<_MilestoneInputDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.existing?.toStringAsFixed(0),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.existing == null ? '新增节点' : '修改节点'),
    content: TextField(
      controller: _controller,
      autofocus: true,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: const InputDecoration(prefixText: '¥ '),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('取消'),
      ),
      FilledButton(
        onPressed: () {
          final amount = double.tryParse(_controller.text);
          if (amount == null || amount <= 0 || amount >= widget.target) return;
          Navigator.pop(context, amount);
        },
        child: const Text('保存'),
      ),
    ],
  );
}

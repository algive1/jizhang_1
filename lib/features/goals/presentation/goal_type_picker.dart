import 'package:flutter/material.dart';

import '../../../app/theme/app_theme_tokens.dart';
import '../../../core/models/goal.dart';
import '../../../core/widgets/app_bottom_sheet.dart';
import '../../../core/widgets/goal_icon.dart';

class GoalTypeSelect extends StatelessWidget {
  const GoalTypeSelect({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final GoalType value;
  final ValueChanged<GoalType> onChanged;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: '目标类型：${value.label}',
    child: InkWell(
      key: const ValueKey('goal-type-select'),
      borderRadius: BorderRadius.circular(16),
      onTap: () async {
        FocusManager.instance.primaryFocus?.unfocus();
        final selected = await AppBottomSheet.show<GoalType>(
          context: context,
          builder: (sheetContext) => Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('选择目标类型', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 16),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final scaler = MediaQuery.textScalerOf(context);
                    final columns =
                        constraints.maxWidth < 340 || scaler.scale(14) > 19
                        ? 2
                        : 3;
                    return GridView.count(
                      key: const ValueKey('goal-type-grid'),
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: columns,
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      mainAxisExtent: 58 + scaler.scale(14) * 2.2,
                      children: [
                        for (final type in GoalType.values)
                          Semantics(
                            selected: type == value,
                            button: true,
                            label: type.label,
                            child: Material(
                              color: type == value
                                  ? context.appPrimarySoft
                                  : context.appSurfaceSoft,
                              borderRadius: BorderRadius.circular(16),
                              child: InkWell(
                                key: ValueKey('goal-type-${type.name}'),
                                borderRadius: BorderRadius.circular(16),
                                onTap: () => Navigator.pop(sheetContext, type),
                                child: Stack(
                                  children: [
                                    Center(
                                      child: Padding(
                                        padding: const EdgeInsets.all(8),
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              goalTypeIcon(type),
                                              color: context.appPrimary,
                                              size: 28,
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              type.label,
                                              textAlign: TextAlign.center,
                                              maxLines: 2,
                                              style: TextStyle(
                                                color: context.appPrimaryText,
                                                fontSize: 14,
                                                fontWeight: type == value
                                                    ? FontWeight.w600
                                                    : FontWeight.w400,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    if (type == value)
                                      Positioned(
                                        top: 6,
                                        right: 6,
                                        child: Icon(
                                          Icons.check_circle,
                                          size: 16,
                                          color: context.appPrimary,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        );
        if (context.mounted && selected != null) onChanged(selected);
      },
      child: InputDecorator(
        decoration: const InputDecoration(labelText: '目标类型'),
        child: Row(
          children: [
            Icon(goalTypeIcon(value), color: context.appPrimary, size: 24),
            const SizedBox(width: 10),
            Expanded(child: Text(value.label)),
            const Icon(Icons.expand_more, size: 20),
          ],
        ),
      ),
    ),
  );
}

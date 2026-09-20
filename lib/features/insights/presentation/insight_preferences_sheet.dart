import 'package:flutter/material.dart';

import '../../../app/theme/app_theme_tokens.dart';
import '../domain/insight_models.dart';

Future<InsightPreferences?> showInsightPreferencesSheet(
  BuildContext context,
  InsightPreferences current, {
  bool firstRun = false,
}) {
  var intents = {...current.intents};
  var focus = {...current.focus};
  var tone = current.tone;
  return showModalBottomSheet<InsightPreferences>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) => StatefulBuilder(
      builder: (context, setModalState) => SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            20,
            0,
            20,
            20 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '你希望好好记账主要帮你什么？',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 6),
              Text(
                firstRun
                    ? '先选记账目的。之后的洞察会优先围绕这些目标，但不会为了迎合目标改变财务事实。'
                    : '可以多选。它只影响洞察的优先级，不会改变财务事实。',
                style: TextStyle(
                  color: context.appSecondaryText,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final intent in BookkeepingIntent.values)
                    FilterChip(
                      label: Text(intent.label),
                      selected: intents.contains(intent),
                      onSelected: (selected) => setModalState(() {
                        selected ? intents.add(intent) : intents.remove(intent);
                      }),
                    ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                '最近特别想关注',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 9),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final item in InsightFocus.values)
                    FilterChip(
                      label: Text(item.label),
                      selected: focus.contains(item),
                      onSelected: (selected) => setModalState(() {
                        selected ? focus.add(item) : focus.remove(item);
                      }),
                    ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                '提醒风格',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 9),
              SegmentedButton<InsightTone>(
                segments: [
                  for (final item in InsightTone.values)
                    ButtonSegment(value: item, label: Text(item.label)),
                ],
                selected: {tone},
                onSelectionChanged: (value) =>
                    setModalState(() => tone = value.first),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () => Navigator.pop(
                  sheetContext,
                  InsightPreferences(
                    intents: intents,
                    focus: focus,
                    tone: tone,
                    configured: true,
                    dismissedIds: current.dismissedIds,
                    kindAdjustments: current.kindAdjustments,
                  ),
                ),
                child: const Text('保存'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(
                  sheetContext,
                  current.copyWith(configured: true),
                ),
                child: const Text('暂时不设置'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

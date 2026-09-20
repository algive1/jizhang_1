import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme_tokens.dart';
import '../../../core/widgets/app_card.dart';
import '../application/insight_feed_provider.dart';
import '../data/insight_preferences_repository.dart';
import '../domain/insight_models.dart';
import 'insight_preferences_sheet.dart';

enum _InsightFilter { all, important, changes, discovery }

class InsightsPage extends ConsumerStatefulWidget {
  const InsightsPage({super.key});

  @override
  ConsumerState<InsightsPage> createState() => _InsightsPageState();
}

class _InsightsPageState extends ConsumerState<InsightsPage> {
  _InsightFilter _filter = _InsightFilter.all;
  bool _prompted = false;

  @override
  Widget build(BuildContext context) {
    final feed = ref.watch(insightFeedProvider);
    final preferencesAsync = ref.watch(insightPreferencesProvider);
    final preferences =
        preferencesAsync.value ?? const InsightPreferences();

    if (!_prompted && preferencesAsync.hasValue && !preferences.configured) {
      _prompted = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showPreferences(preferences);
      });
    }

    final items = feed.items.where((item) {
      return switch (_filter) {
        _InsightFilter.all => true,
        _InsightFilter.important => item.isImportant,
        _InsightFilter.changes =>
          item.kind == FinancialInsightKind.behavior ||
              item.kind == FinancialInsightKind.positive,
        _InsightFilter.discovery =>
          item.kind == FinancialInsightKind.discovery ||
              item.kind == FinancialInsightKind.life,
      };
    }).toList();

    return DecoratedBox(
      decoration: BoxDecoration(color: context.appBackground),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 110),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '洞察',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _showPreferences(preferences),
                  icon: const Icon(Icons.tune_rounded, size: 18),
                  label: const Text('关注设置'),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              preferences.intents.isEmpty
                  ? '不是为了多说，而是只告诉你真正值得知道的变化。'
                  : '会优先围绕「${preferences.intents.map((e) => e.label).join(' · ')}」来分析。',
              style: TextStyle(
                color: context.appSecondaryText,
                fontSize: 13,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 14),
            _QualityCard(feed: feed),
            const SizedBox(height: 16),
            Row(
              children: [
                Text('值得关注', style: Theme.of(context).textTheme.titleLarge),
                const Spacer(),
                Text(
                  '${feed.items.length} 条',
                  style: TextStyle(
                    color: context.appSecondaryText,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _FilterChip(
                    label: '全部',
                    selected: _filter == _InsightFilter.all,
                    onTap: () => setState(() => _filter = _InsightFilter.all),
                  ),
                  _FilterChip(
                    label: '重要',
                    selected: _filter == _InsightFilter.important,
                    onTap: () =>
                        setState(() => _filter = _InsightFilter.important),
                  ),
                  _FilterChip(
                    label: '变化',
                    selected: _filter == _InsightFilter.changes,
                    onTap: () =>
                        setState(() => _filter = _InsightFilter.changes),
                  ),
                  _FilterChip(
                    label: '发现',
                    selected: _filter == _InsightFilter.discovery,
                    onTap: () =>
                        setState(() => _filter = _InsightFilter.discovery),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            if (items.isEmpty)
              AppCard(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  child: Column(
                    children: [
                      Icon(
                        Icons.eco_outlined,
                        color: context.appPrimary,
                        size: 38,
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        '目前没有需要打扰你的事情',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        '继续正常记账即可。数据不足时，我们宁可不下结论。',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: context.appSecondaryText,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              ...items.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _InsightCard(
                    item: item,
                    onTap: () => context.push(
                      '/insights/${Uri.encodeComponent(item.id)}',
                      extra: item,
                    ),
                    onDismiss: () => _dismiss(item),
                  ),
                ),
              ),
            const SizedBox(height: 18),
            Text('深入看看', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 10),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.75,
              children: [
                _Shortcut(
                  icon: Icons.show_chart_rounded,
                  title: '趋势分析',
                  subtitle: '钱最近怎么变',
                  onTap: () => context.push('/analysis'),
                ),
                _Shortcut(
                  icon: Icons.account_balance_wallet_outlined,
                  title: '预算',
                  subtitle: '控制消费速度',
                  onTap: () => context.push('/profile/budgets'),
                ),
                _Shortcut(
                  icon: Icons.autorenew_rounded,
                  title: '周期账单',
                  subtitle: '固定支出与订阅',
                  onTap: () => context.push('/profile/recurring-bills'),
                ),
                _Shortcut(
                  icon: Icons.flag_outlined,
                  title: '财务目标',
                  subtitle: '存钱与目标进度',
                  onTap: () => context.push('/goals'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _dismiss(FinancialInsightItem item) async {
    await ref.read(insightPreferencesRepositoryProvider).dismiss(item.id);
    ref.invalidate(insightPreferencesProvider);
  }

  Future<void> _showPreferences(InsightPreferences current) async {
    final saved = await showInsightPreferencesSheet(context, current);
    if (saved == null) return;
    await ref.read(insightPreferencesRepositoryProvider).save(saved);
    ref.invalidate(insightPreferencesProvider);
  }

}

class _QualityCard extends StatelessWidget {
  const _QualityCard({required this.feed});
  final InsightFeed feed;

  @override
  Widget build(BuildContext context) {
    final confidence = (
      feed.dataConfidence * .3 +
      feed.completeness * .25 +
      feed.classificationConfidence * .2 +
      feed.baselineConfidence * .25
    ).clamp(0, 1);
    final label = feed.completeness < .15
        ? '先记几笔，我们再开始分析'
        : feed.isServerConfirmed
        ? '已基于当前账务上下文确认'
        : confidence >= .75
        ? '洞察基础较稳定'
        : confidence >= .5
        ? '洞察还在学习'
        : '有些数据还需要确认';
    return AppCard(
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: context.appPrimarySoft,
            child: Icon(Icons.auto_graph_rounded, color: context.appPrimary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 3),
                Text(
                  feed.completeness < .15
                      ? '目前样本还少，不会急着给你下结论。'
                      : feed.isServerConfirmed
                      ? '已用当前账本的流水、账户、预算、目标和周期账单统一复核；数据不足时仍会减少判断。'
                      : confidence >= .75
                      ? '已有足够数据建立个人基线，会优先和过去的你比较。'
                      : '数据覆盖、分类准确度和历史样本会共同决定我们敢不敢下结论。',
                  style: TextStyle(
                    color: context.appSecondaryText,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            feed.isServerConfirmed || confidence >= .75
                ? Icons.verified_outlined
                : Icons.hourglass_bottom_rounded,
            color: context.appPrimary,
            size: 20,
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
    ),
  );
}

class _InsightCard extends StatelessWidget {
  const _InsightCard({
    required this.item,
    required this.onTap,
    required this.onDismiss,
  });
  final FinancialInsightItem item;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) => AppCard(
    padding: EdgeInsets.zero,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: context.appPrimarySoft,
              child: Icon(_icon(item.kind), color: context.appPrimary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _KindPill(kind: item.kind),
                      const SizedBox(width: 6),
                      if (item.isImportant)
                        Text(
                          '值得先看',
                          style: TextStyle(
                            color: context.appPrimary,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    item.title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.summary,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: context.appSecondaryText,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: '隐藏这条',
              onPressed: onDismiss,
              icon: const Icon(Icons.close_rounded, size: 18),
            ),
          ],
        ),
      ),
    ),
  );

  IconData _icon(FinancialInsightKind kind) => switch (kind) {
    FinancialInsightKind.financial => Icons.account_balance_wallet_outlined,
    FinancialInsightKind.behavior => Icons.timeline_rounded,
    FinancialInsightKind.risk => Icons.notifications_active_outlined,
    FinancialInsightKind.goal => Icons.flag_outlined,
    FinancialInsightKind.discovery => Icons.search_rounded,
    FinancialInsightKind.positive => Icons.emoji_events_outlined,
    FinancialInsightKind.life => Icons.favorite_border_rounded,
  };
}

class _KindPill extends StatelessWidget {
  const _KindPill({required this.kind});
  final FinancialInsightKind kind;

  @override
  Widget build(BuildContext context) => Text(
    kind.label,
    style: TextStyle(
      color: context.appSecondaryText,
      fontSize: 10,
      fontWeight: FontWeight.w600,
    ),
  );
}

class _Shortcut extends StatelessWidget {
  const _Shortcut({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => AppCard(
    padding: EdgeInsets.zero,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.all(13),
        child: Row(
          children: [
            Icon(icon, color: context.appPrimary),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: context.appSecondaryText,
                      fontSize: 10,
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

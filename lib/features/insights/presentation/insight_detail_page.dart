import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme_tokens.dart';
import '../../../core/formatters/money_formatter.dart';
import '../../../core/widgets/app_card.dart';
import '../application/insight_feed_provider.dart';
import '../data/remote_insight_repository.dart';
import '../../membership/data/membership_repository.dart';
import '../../../core/models/membership.dart';
import '../data/insight_preferences_repository.dart';
import '../domain/insight_models.dart';

class InsightDetailPage extends ConsumerStatefulWidget {
  const InsightDetailPage({
    required this.insightId,
    this.fallback,
    super.key,
  });

  final String insightId;
  final FinancialInsightItem? fallback;

  @override
  ConsumerState<InsightDetailPage> createState() => _InsightDetailPageState();
}

class _InsightDetailPageState extends ConsumerState<InsightDetailPage> {
  bool _loadingAi = false;
  String? _aiText;
  String? _aiError;

  @override
  Widget build(BuildContext context) {
    final feed = ref.watch(insightFeedProvider);
    FinancialInsightItem? insight;
    for (final item in feed.items) {
      if (item.id == widget.insightId) {
        insight = item;
        break;
      }
    }
    insight ??= widget.fallback;
    if (insight == null) {
      return SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: context.pop,
                  icon: const Icon(Icons.arrow_back),
                ),
                Text(
                  '洞察详情',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ],
            ),
            const SizedBox(height: 32),
            const Center(child: Text('这条洞察已经失效或被关闭')),
          ],
        ),
      );
    }

    final item = insight;
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 32),
        children: [
          Row(
            children: [
              IconButton(
                onPressed: context.pop,
                icon: const Icon(Icons.arrow_back),
              ),
              Expanded(
                child: Text(
                  '洞察详情',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
              _KindBadge(kind: item.kind),
            ],
          ),
          const SizedBox(height: 12),
          Text(item.title, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 8),
          Text(
            item.summary,
            style: TextStyle(
              color: context.appSecondaryText,
              fontSize: 15,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 18),
          _Section(
            title: '发生了什么',
            child: Text(item.analysis, style: const TextStyle(height: 1.5)),
          ),
          const SizedBox(height: 12),
          _Section(
            title: '这意味着什么',
            child: Text(item.meaning, style: const TextStyle(height: 1.5)),
          ),
          if (item.evidence.isNotEmpty) ...[
            const SizedBox(height: 12),
            _Section(
              title: '为什么这么说',
              child: Column(
                children: [
                  for (final evidence in item.evidence)
                    _EvidenceRow(evidence: evidence),
                ],
              ),
            ),
          ],
          if (item.suggestion != null) ...[
            const SizedBox(height: 12),
            _Section(
              title: item.response == InsightResponse.encouragement
                  ? '给你一句'
                  : '可以怎么做',
              child: Text(
                item.suggestion!,
                style: const TextStyle(height: 1.5),
              ),
            ),
          ],
          if (item.actionRoute != null) ...[
            const SizedBox(height: 18),
            FilledButton(
              onPressed: () => context.push(item.actionRoute!),
              child: Text(item.actionLabel ?? '查看'),
            ),
          ],
          const SizedBox(height: 18),
          if (feed.isServerConfirmed &&
              (ref.watch(membershipProvider).value?.has(
                    EntitlementKey.aiAnalysis,
                  ) ??
                  false)) ...[
            if (_aiText != null)
              _Section(
                title: 'AI 深度解读',
                child: Text(_aiText!, style: const TextStyle(height: 1.55)),
              )
            else
              OutlinedButton.icon(
                onPressed: _loadingAi ? null : () => _loadAi(item),
                icon: _loadingAi
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.auto_awesome_outlined, size: 18),
                label: Text(_loadingAi ? '正在解读…' : 'AI 深度解读'),
              ),
            if (_aiError != null) ...[
              const SizedBox(height: 6),
              Text(
                _aiError!,
                style: TextStyle(
                  color: context.appSecondaryText,
                  fontSize: 11,
                ),
              ),
            ],
          ],
          const SizedBox(height: 24),
          Text(
            '这条分析对你有帮助吗？',
            style: TextStyle(
              color: context.appSecondaryText,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: () => _feedback(context, ref, item, 'helpful'),
                icon: const Icon(Icons.thumb_up_alt_outlined, size: 18),
                label: const Text('有帮助'),
              ),
              OutlinedButton.icon(
                onPressed: () => _feedback(context, ref, item, 'inaccurate'),
                icon: const Icon(
                  Icons.report_gmailerrorred_outlined,
                  size: 18,
                ),
                label: const Text('判断不准'),
              ),
              OutlinedButton.icon(
                onPressed: () => _dismiss(context, ref, item),
                icon: const Icon(Icons.visibility_off_outlined, size: 18),
                label: const Text('这条不用提醒'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            '结论只基于当前可用账务数据。数据覆盖、分类准确度或历史样本不足时，系统会减少判断。',
            style: TextStyle(
              color: context.appSecondaryText,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _loadAi(FinancialInsightItem item) async {
    setState(() {
      _loadingAi = true;
      _aiError = null;
    });
    try {
      final text = await ref.read(remoteInsightRepositoryProvider).interpret(item);
      if (!mounted) return;
      setState(() {
        _aiText = text;
        _aiError = text == null ? '当前无法提供 AI 深度解读' : null;
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _aiError = error.toString());
    } finally {
      if (mounted) setState(() => _loadingAi = false);
    }
  }

  Future<void> _feedback(
    BuildContext context,
    WidgetRef ref,
    FinancialInsightItem item,
    String action,
  ) async {
    await ref
        .read(insightPreferencesRepositoryProvider)
        .recordFeedback(item.id, item.kind, action);
    ref.invalidate(insightPreferencesProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已收到反馈，会用于后续洞察优化')),
      );
    }
  }

  Future<void> _dismiss(
    BuildContext context,
    WidgetRef ref,
    FinancialInsightItem item,
  ) async {
    await ref.read(insightPreferencesRepositoryProvider).dismiss(item.id);
    ref.invalidate(insightPreferencesProvider);
    if (context.mounted) context.pop();
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => AppCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 9),
        child,
      ],
    ),
  );
}

class _EvidenceRow extends StatelessWidget {
  const _EvidenceRow({required this.evidence});
  final InsightEvidence evidence;

  @override
  Widget build(BuildContext context) {
    String value(double value) {
      if (evidence.unit == 'CNY') {
        return '¥${MoneyFormatter.decimal(value)}';
      }
      if (evidence.unit == '%') return '${value.toStringAsFixed(0)}%';
      return '${value.toStringAsFixed(value % 1 == 0 ? 0 : 1)}'
          '${evidence.unit ?? ''}';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Expanded(child: Text(evidence.label)),
          Text(
            value(evidence.value),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          if (evidence.baselineValue != null) ...[
            const SizedBox(width: 8),
            Text(
              '平时 ${value(evidence.baselineValue!)}',
              style: TextStyle(
                color: context.appSecondaryText,
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _KindBadge extends StatelessWidget {
  const _KindBadge({required this.kind});
  final FinancialInsightKind kind;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
    decoration: BoxDecoration(
      color: context.appPrimarySoft,
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      kind.label,
      style: TextStyle(color: context.appPrimary, fontSize: 11),
    ),
  );
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/models/account.dart';
import '../../../core/widgets/app_date_picker.dart';
import '../../../core/widgets/app_form.dart';
import '../../accounts/data/account_repository.dart';
import '../data/investment_repository.dart';
import '../data/market_data_provider.dart';
import '../domain/investment_asset.dart';
import '../domain/investment_input.dart';
import 'investment_widgets.dart';
import '../../../app/theme/app_theme_tokens.dart';

/// 添加投资 — 搜索添加 or 手动添加.
///
/// One page serves all four asset classes; [initialType] only pre-selects the
/// class. The manual mode exists for assets no quote API can resolve and sets
/// `priceSource = manual`.
class InvestmentAddPage extends ConsumerStatefulWidget {
  const InvestmentAddPage({required this.initialType, super.key});

  final InvestmentAssetType initialType;

  @override
  ConsumerState<InvestmentAddPage> createState() => _InvestmentAddPageState();
}

enum _AddMode { search, manual }

class _InvestmentAddPageState extends ConsumerState<InvestmentAddPage> {
  _AddMode _mode = _AddMode.search;
  final _query = TextEditingController();
  Timer? _debounce;
  String _debouncedQuery = '';
  bool _saving = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 320), () {
      if (!mounted) return;
      setState(() => _debouncedQuery = value.trim());
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7EE),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _Header(
              mode: _mode,
              saving: _saving,
              onBack: () =>
                  context.canPop() ? context.pop() : context.go('/profile/investments'),
              onMode: (mode) => setState(() => _mode = mode),
            ),
            Expanded(
              child: _mode == _AddMode.search
                  ? _SearchMode(
                      type: widget.initialType,
                      query: _query,
                      debouncedQuery: _debouncedQuery,
                      saving: _saving,
                      onQueryChanged: _onQueryChanged,
                      onSubmit: _submit,
                    )
                  : _ManualMode(
                      type: widget.initialType,
                      saving: _saving,
                      onSubmit: _submit,
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit(AddInvestmentRequest request) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await ref.read(investmentRepositoryProvider).addHolding(request);
      ref.invalidate(investmentPortfolioProvider);
      ref.invalidate(investmentSnapshotsProvider);
      if (!mounted) return;
      _toast('已添加 ${request.name}');
      context.pop();
    } on ArgumentError catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      _toast(error.message?.toString() ?? '请检查填写内容');
    } on Object {
      if (!mounted) return;
      setState(() => _saving = false);
      _toast('保存失败，请重试');
    }
  }

  void _toast(String message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message)));
}

class _Header extends StatelessWidget {
  const _Header({
    required this.mode,
    required this.saving,
    required this.onBack,
    required this.onMode,
  });

  final _AddMode mode;
  final bool saving;
  final VoidCallback onBack;
  final ValueChanged<_AddMode> onMode;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(6, 6, 12, 0),
        child: Row(
          children: [
            IconButton(
              key: const ValueKey('investment-add-back'),
              onPressed: onBack,
              icon: Icon(Icons.chevron_left, size: 26),
              color: context.appPrimaryText,
              tooltip: '返回',
            ),
            Expanded(
              child: Text(
                '添加投资',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: context.appPrimaryText,
                ),
              ),
            ),
            SizedBox(
              width: 44,
              child: saving
                  ? const Padding(
                      padding: EdgeInsets.all(10),
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
        child: Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: const Color(0xFFEDEFE0),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            children: [
              for (final entry in const [
                (_AddMode.search, '搜索添加'),
                (_AddMode.manual, '手动添加'),
              ])
                Expanded(
                  child: Semantics(
                    selected: mode == entry.$1,
                    button: true,
                    child: InkWell(
                      key: ValueKey('investment-add-mode-${entry.$1.name}'),
                      onTap: () => onMode(entry.$1),
                      borderRadius: BorderRadius.circular(20),
                      child: AnimatedContainer(
                        duration: MediaQuery.disableAnimationsOf(context)
                            ? Duration.zero
                            : const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: mode == entry.$1
                              ? context.appPrimary
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          entry.$2,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: mode == entry.$1
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: mode == entry.$1
                                ? Colors.white
                                : context.appSecondaryText,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    ],
  );
}

/// 搜索添加: query the market provider, pick a hit, then confirm the purchase.
class _SearchMode extends ConsumerStatefulWidget {
  const _SearchMode({
    required this.type,
    required this.query,
    required this.debouncedQuery,
    required this.saving,
    required this.onQueryChanged,
    required this.onSubmit,
  });

  final InvestmentAssetType type;
  final TextEditingController query;
  final String debouncedQuery;
  final bool saving;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<AddInvestmentRequest> onSubmit;

  @override
  ConsumerState<_SearchMode> createState() => _SearchModeState();
}

class _SearchModeState extends ConsumerState<_SearchMode> {
  MarketSearchResult? _selected;

  @override
  Widget build(BuildContext context) {
    final selected = _selected;
    if (selected != null) {
      return _InvestmentForm(
        key: ValueKey('investment-form-${selected.symbol}'),
        saving: widget.saving,
        type: selected.type,
        name: selected.name,
        symbol: selected.symbol,
        suggestedPrice: selected.price,
        priceSource: PriceSource.market,
        onCancel: () => setState(() => _selected = null),
        onSubmit: widget.onSubmit,
      );
    }

    final async = widget.debouncedQuery.isEmpty
        ? const AsyncValue<List<MarketSearchResult>>.data([])
        : ref.watch(
            investmentSearchProvider((
              query: widget.debouncedQuery,
              type: widget.type,
            )),
          );
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: [
        TextField(
          key: const ValueKey('investment-search-field'),
          controller: widget.query,
          onChanged: widget.onQueryChanged,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: '搜索名称或代码，如 600519 / 贵州茅台 / BTC',
            prefixIcon: const Icon(Icons.search, size: 20),
            // Listens to the controller directly so the clear button follows
            // typing immediately instead of waiting for the debounced query.
            suffixIcon: ValueListenableBuilder<TextEditingValue>(
              valueListenable: widget.query,
              builder: (context, value, _) => value.text.isEmpty
                  ? const SizedBox.shrink()
                  : IconButton(
                      key: const ValueKey('investment-search-clear'),
                      onPressed: () {
                        widget.query.clear();
                        widget.onQueryChanged('');
                      },
                      icon: const Icon(Icons.close, size: 18),
                    ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (widget.debouncedQuery.isEmpty)
          const _SearchHint()
        else
          async.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 30),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, _) => _SearchError(
              message: error is MarketDataException
                  ? error.message
                  : '行情服务暂时不可用',
              onRetry: () => setState(() {}),
            ),
            data: (results) => results.isEmpty
                ? const _SearchEmpty()
                : Column(
                    children: [
                      for (final result in results)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _SearchResultRow(
                            result: result,
                            onTap: () => setState(() => _selected = result),
                          ),
                        ),
                    ],
                  ),
          ),
      ],
    );
  }
}

class _SearchHint extends StatelessWidget {
  const _SearchHint();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 16),
    decoration: BoxDecoration(
      color: const Color(0xF7FFFFFC),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: context.appDivider.withValues(alpha: .7)),
    ),
    child: Column(
      children: [
        Icon(Icons.travel_explore, size: 26, color: context.appPrimary),
        SizedBox(height: 8),
        Text(
          '输入名称、代码或 Symbol 搜索',
          style: TextStyle(fontSize: 13, color: context.appSecondaryText),
        ),
        SizedBox(height: 4),
        Text(
          '支持股票、基金、债券、虚拟币',
          style: TextStyle(fontSize: 11, color: context.appSecondaryText),
        ),
      ],
    ),
  );
}

class _SearchEmpty extends StatelessWidget {
  const _SearchEmpty();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 16),
    decoration: BoxDecoration(
      color: const Color(0xF7FFFFFC),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: context.appDivider.withValues(alpha: .7)),
    ),
    child: Column(
      children: [
        Icon(Icons.search_off, size: 26, color: context.appSecondaryText),
        SizedBox(height: 8),
        Text(
          '没有找到匹配的投资',
          style: TextStyle(fontSize: 13, color: context.appPrimaryText),
        ),
        SizedBox(height: 4),
        Text(
          '可以切换到「手动添加」自行填写',
          style: TextStyle(fontSize: 11, color: context.appSecondaryText),
        ),
      ],
    ),
  );
}

class _SearchError extends StatelessWidget {
  const _SearchError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
    decoration: BoxDecoration(
      color: const Color(0xF7FFFFFC),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: context.appDivider.withValues(alpha: .7)),
    ),
    child: Column(
      children: [
        Icon(Icons.cloud_off_outlined, size: 26, color: AppColors.warning),
        SizedBox(height: 8),
        Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: context.appSecondaryText),
        ),
        const SizedBox(height: 10),
        OutlinedButton(onPressed: onRetry, child: const Text('重试')),
      ],
    ),
  );
}

class _SearchResultRow extends StatelessWidget {
  const _SearchResultRow({required this.result, required this.onTap});

  final MarketSearchResult result;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    borderRadius: BorderRadius.circular(18),
    child: InkWell(
      key: ValueKey('investment-search-result-${result.symbol}'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
        decoration: BoxDecoration(
          color: const Color(0xF7FFFFFC),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: context.appDivider.withValues(alpha: .7)),
        ),
        child: Row(
          children: [
            InvestmentTypeAvatar(type: result.type, size: 36),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    result.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: context.appPrimaryText,
                    ),
                  ),
                  SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        result.symbol,
                        style: TextStyle(
                          fontSize: 11,
                          color: context.appSecondaryText,
                        ),
                      ),
                      const SizedBox(width: 6),
                      InvestmentChip(
                        label: result.type.label,
                        color: result.type.accent,
                        background: result.type.surface,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '¥${InvestmentInput.formatPriceLabel(result.price)}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: context.appPrimaryText,
                  ),
                ),
                ProfitText(percent: result.changePercent, fontSize: 10),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

/// 手动添加: the user enters everything, including an optional valuation.
class _ManualMode extends StatelessWidget {
  const _ManualMode({
    required this.type,
    required this.saving,
    required this.onSubmit,
  });

  final InvestmentAssetType type;
  final bool saving;
  final ValueChanged<AddInvestmentRequest> onSubmit;

  @override
  Widget build(BuildContext context) => _InvestmentForm(
    saving: saving,
    type: type,
    priceSource: PriceSource.manual,
    onSubmit: onSubmit,
  );
}

/// The shared purchase form. Search mode pre-fills and locks identity fields;
/// manual mode lets the user type them and adds a current-valuation field.
class _InvestmentForm extends ConsumerStatefulWidget {
  const _InvestmentForm({
    required this.saving,
    required this.type,
    required this.priceSource,
    required this.onSubmit,
    this.name,
    this.symbol,
    this.suggestedPrice,
    this.onCancel,
    super.key,
  });

  final bool saving;
  final InvestmentAssetType type;
  final PriceSource priceSource;
  final ValueChanged<AddInvestmentRequest> onSubmit;
  final String? name;
  final String? symbol;
  final double? suggestedPrice;
  final VoidCallback? onCancel;

  @override
  ConsumerState<_InvestmentForm> createState() => _InvestmentFormState();
}

class _InvestmentFormState extends ConsumerState<_InvestmentForm> {
  static const _homeAssetsTip =
      '关闭后，投资类金额仅在投资管理页面展示，不计入首页展示的账目净资产。';

  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.name);
  late final _symbol = TextEditingController(text: widget.symbol);
  late final _price = TextEditingController(
    text: widget.suggestedPrice == null
        ? ''
        : InvestmentInput.formatPrice(widget.suggestedPrice!),
  );
  final _quantity = TextEditingController();
  final _valuation = TextEditingController();
  final _note = TextEditingController();
  late InvestmentAssetType _type = widget.type;
  DateTime _date = DateUtils.dateOnly(DateTime.now());
  String? _accountId;
  bool _includeInHomeNetAssets = false;

  bool get _isLocked => widget.onCancel != null;

  @override
  void dispose() {
    _name.dispose();
    _symbol.dispose();
    _price.dispose();
    _quantity.dispose();
    _valuation.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accounts = ref.watch(assetDashboardAccountsProvider).value ??
        const <Account>[];
    final active = accounts
        .where((account) => !account.isArchived && !account.type.isDebt)
        .toList(growable: false);
    return Form(
      key: _formKey,
      child: ListView(
        key: const ValueKey('investment-form-scroll'),
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
        children: [
          if (_isLocked)
            _SelectedBanner(
              type: widget.type,
              name: widget.name ?? '',
              symbol: widget.symbol ?? '',
              onCancel: widget.onCancel!,
            ),
          AppInput(
            key: const ValueKey('investment-form-name'),
            controller: _name,
            enabled: !_isLocked,
            decoration: appFieldDecoration('投资名称'),
            validator: (value) =>
                (value ?? '').trim().isEmpty ? '请输入投资名称' : null,
          ),
          const SizedBox(height: 12),
          AppSelect<InvestmentAssetType>(
            initialValue: _type,
            decoration: appFieldDecoration('投资类型'),
            items: [
              for (final type in InvestmentAssetType.values)
                DropdownMenuItem(value: type, child: Text(type.label)),
            ],
            onChanged: _isLocked
                ? null
                : (value) => setState(() => _type = value ?? _type),
          ),
          const SizedBox(height: 12),
          AppInput(
            key: const ValueKey('investment-form-symbol'),
            controller: _symbol,
            enabled: !_isLocked,
            decoration: InputDecoration(
              labelText: '投资代码',
              hintText: _type == InvestmentAssetType.crypto ? 'BTC' : '600519',
            ),
            validator: (value) =>
                (value ?? '').trim().isEmpty ? '请输入投资代码' : null,
          ),
          const SizedBox(height: 12),
          AppFormRow(
            children: [
              AppInput(
                key: const ValueKey('investment-form-price'),
                controller: _price,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: appFieldDecoration('买入价格'),
                validator: (value) {
                  final parsed = InvestmentInput.parsePrice(value ?? '');
                  if (parsed == null) return '请输入有效价格';
                  if (parsed <= 0) return '价格必须大于 0';
                  return null;
                },
              ),
              AppInput(
                key: const ValueKey('investment-form-quantity'),
                controller: _quantity,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: appFieldDecoration('买入数量'),
                validator: (value) {
                  final parsed = InvestmentInput.parseQuantity(value ?? '');
                  if (parsed == null) return '请输入有效数量';
                  if (parsed <= 0) return '数量必须大于 0';
                  return null;
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (widget.priceSource == PriceSource.manual) ...[
            AppInput(
              key: const ValueKey('investment-form-valuation'),
              controller: _valuation,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: '当前估值（可选）',
                helperText: '留空则按买入价估值，之后可随时修改',
              ),
              validator: (value) {
                if ((value ?? '').trim().isEmpty) return null;
                return InvestmentInput.parsePrice(value!) == null
                    ? '请输入有效金额'
                    : null;
              },
            ),
            const SizedBox(height: 12),
          ],
          _DateField(
            date: _date,
            onPick: () async {
              final picked = await AppDatePicker.show(context, _date);
              if (picked != null) setState(() => _date = picked);
            },
          ),
          const SizedBox(height: 12),
          AppSelect<String>(
            initialValue: _accountId,
            decoration: appFieldDecoration('持有账户'),
            hint: const Text('请选择'),
            items: [
              for (final account in active)
                DropdownMenuItem(
                  value: account.id,
                  child: Text(
                    '${account.displayName} · ${account.type.label}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: (value) => setState(() => _accountId = value),
          ),
          const SizedBox(height: 12),
          AppTextarea(
            key: const ValueKey('investment-form-note'),
            controller: _note,
            decoration: appFieldDecoration('备注（可选）'),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            key: const ValueKey('investment-include-in-home-net-assets'),
            contentPadding: EdgeInsets.zero,
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('计入首页账目净资产'),
                IconButton(
                  key: const ValueKey('investment-home-assets-tip'),
                  tooltip: '提示',
                  visualDensity: VisualDensity.compact,
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (context) => AlertDialog(
                      content: const Text(_homeAssetsTip),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('知道了'),
                        ),
                      ],
                    ),
                  ),
                  icon: const Icon(Icons.info_outline, size: 18),
                ),
              ],
            ),
            value: _includeInHomeNetAssets,
            onChanged: (value) =>
                setState(() => _includeInHomeNetAssets = value),
          ),
          SizedBox(height: 20),
          FilledButton(
            key: const ValueKey('investment-form-submit'),
            onPressed: widget.saving ? null : _save,
            style: FilledButton.styleFrom(
              backgroundColor: context.appPrimary,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: Text(widget.saving ? '保存中…' : '保存'),
          ),
        ],
      ),
    );
  }

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final price = InvestmentInput.parsePrice(_price.text)!;
    final quantity = InvestmentInput.parseQuantity(_quantity.text)!;
    final valuation = InvestmentInput.parsePrice(_valuation.text);
    widget.onSubmit(
      AddInvestmentRequest(
        type: _type,
        symbol: _symbol.text.trim(),
        name: _name.text.trim(),
        price: price,
        quantity: quantity,
        transactionDate: _date,
        accountId: _accountId,
        note: _note.text.trim().isEmpty ? null : _note.text.trim(),
        priceSource: widget.priceSource,
        currentPrice: widget.priceSource == PriceSource.manual
            ? (valuation ?? price)
            : null,
        includeInHomeNetAssets: _includeInHomeNetAssets,
      ),
    );
  }

}

class _SelectedBanner extends StatelessWidget {
  const _SelectedBanner({
    required this.type,
    required this.name,
    required this.symbol,
    required this.onCancel,
  });

  final InvestmentAssetType type;
  final String name;
  final String symbol;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
    decoration: BoxDecoration(
      color: type.surface,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(
      children: [
        InvestmentTypeAvatar(type: type, size: 32),
        SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: context.appPrimaryText,
                ),
              ),
              Text(
                '$symbol · 点击下方确认买入价格与数量',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  color: context.appSecondaryText,
                ),
              ),
            ],
          ),
        ),
        TextButton(
          key: const ValueKey('investment-form-reselect'),
          onPressed: onCancel,
          style: TextButton.styleFrom(
            foregroundColor: context.appSecondaryText,
            minimumSize: const Size(0, 32),
          ),
          child: const Text('重选', style: TextStyle(fontSize: 12)),
        ),
      ],
    ),
  );
}

class _DateField extends StatelessWidget {
  const _DateField({required this.date, required this.onPick});

  final DateTime date;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: '买入日期，点击选择',
    child: InkWell(
    key: const ValueKey('investment-form-date'),
    onTap: onPick,
    borderRadius: BorderRadius.circular(16),
      child: InputDecorator(
        decoration: appFieldDecoration('买入日期'),
        child: Row(
          children: [
            Expanded(
              child: Text(
                '${date.year}-${date.month.toString().padLeft(2, '0')}-'
                '${date.day.toString().padLeft(2, '0')}',
                style: const TextStyle(fontSize: 15),
              ),
            ),
            const Icon(Icons.calendar_today_outlined, size: 16),
          ],
        ),
      ),
    ),
  );
}

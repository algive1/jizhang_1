import 'dart:math' as math;
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/membership.dart';
import '../../account/application/account_auth_gate.dart';
import '../../account/application/account_pending_intent.dart';
import '../../sharing/data/session_repository.dart';
import '../data/membership_catalog.dart';
import '../data/apple_purchase_service.dart';
import '../data/membership_repository.dart';
import '../data/payment_service.dart';
import '../domain/commercial_service_contracts.dart';
import 'membership_visuals.dart';

class MembershipPage extends ConsumerStatefulWidget {
  const MembershipPage({super.key});

  @override
  ConsumerState<MembershipPage> createState() => _MembershipPageState();
}

class _MembershipPageState extends ConsumerState<MembershipPage>
    with WidgetsBindingObserver {
  String? _selectedPlanId;
  String? _selectedVersionId;
  PaymentChannel _selectedChannel = PaymentChannel.wechatPay;
  bool _isPaying = false;
  String? _pendingOrderId;
  bool _checkingOrder = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _reloadRemote();
    });
  }

  void _reloadRemote() {
    if (ref.read(membershipCatalogProvider).value?.isRemote == true)
      ref.invalidate(membershipCatalogProvider);
    if (ref.read(membershipRepositoryProvider) is RemoteMembershipRepository)
      ref.invalidate(membershipProvider);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPendingOrder();
      if (!_isPaying) _reloadRemote();
    }
  }

  Future<void> _checkPendingOrder() async {
    final id = _pendingOrderId;
    if (id == null || _checkingOrder) return;
    _checkingOrder = true;
    try {
      final order = await ref.read(paymentServiceProvider).refreshOrder(id);
      if (order.status == PaymentOrderStatus.paid ||
          order.status == PaymentOrderStatus.refunded ||
          order.status == PaymentOrderStatus.failed)
        _pendingOrderId = null;
      if (mounted) _refreshMembershipStatus();
    } catch (_) {
      // Keep the original order available for a later status check.
    } finally {
      _checkingOrder = false;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = ref.watch(membershipProvider).value;
    final catalog = ref.watch(membershipCatalogProvider);
    final currentPlan = snapshot?.membership.plan ?? MembershipPlan.free;
    final statusBarHeight = MediaQuery.viewPaddingOf(context).top;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final selectedProduct = catalog is AsyncData<MembershipCatalog>
        ? _selectedProduct(catalog.value)
        : null;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: (dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark)
          .copyWith(
            statusBarColor: Colors.transparent,
            systemNavigationBarColor: memberBackgroundFor(context),
            systemNavigationBarIconBrightness: dark
                ? Brightness.light
                : Brightness.dark,
          ),
      child: Scaffold(
        extendBodyBehindAppBar: true,
        backgroundColor: memberBackgroundFor(context),
        bottomNavigationBar: MemberBottomPayBar(
          product: selectedProduct,
          isPaying: _isPaying,
          onPay: selectedProduct == null ? _noop : _purchaseSelected,
          onAgreement: _openAgreement,
        ),
        body: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.only(bottom: 96),
              sliver: SliverToBoxAdapter(
                child: RepaintBoundary(
                  key: const ValueKey('membership-content-boundary'),
                  child: Stack(
                    children: [
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        height: statusBarHeight + 266,
                        child: Image.asset(
                          '${memberAssets}hero-bg.webp',
                          fit: BoxFit.cover,
                          cacheWidth:
                              (MediaQuery.sizeOf(context).width *
                                      MediaQuery.devicePixelRatioOf(context))
                                  .ceil(),
                        ),
                      ),
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        height: statusBarHeight + 266,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                memberSurfaceFor(context)
                                    .withValues(alpha: dark ? .56 : .38),
                                memberSurfaceFor(context)
                                    .withValues(alpha: dark ? .20 : .06),
                                memberBackgroundFor(context),
                              ],
                              stops: const [0, .56, 1],
                            ),
                          ),
                        ),
                      ),
                      Column(
                        children: [
                          _MemberHeader(
                            topInset: statusBarHeight,
                            onBack: _goBack,
                            onRecords: _openRecords,
                            onRestore: Platform.isIOS
                                ? _restoreApplePurchases
                                : null,
                          ),
                          const MembershipHero(),
                          Transform.translate(
                            offset: const Offset(0, -8),
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                              child: catalog.when(
                                loading: () => const Padding(
                                  padding: EdgeInsets.all(36),
                                  child: Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                ),
                                error: (error, _) => _CatalogError(
                                  onRetry: () =>
                                      ref.invalidate(membershipCatalogProvider),
                                ),
                                data: (data) => _CatalogContent(
                                  catalog: data,
                                  currentPlan: currentPlan,
                                  selectedPlanId: _selectedPlanId,
                                  selectedVersionId: _selectedVersionId,
                                  selectedChannel: _selectedChannel,
                                  onSelectPlan: (plan) {
                                    if (_isPaying) return;
                                    setState(() => _selectedPlanId = plan.id);
                                  },
                                  onSelectVersion: (id) {
                                    if (_isPaying) return;
                                    setState(() {
                                      _selectedVersionId = id;
                                      _selectedPlanId = null;
                                    });
                                  },
                                  onPurchase: (plan) {
                                    if (_isPaying) return;
                                    setState(() => _selectedPlanId = plan.id);
                                    _purchase(plan);
                                  },
                                  onSelectChannel: (channel) {
                                    if (_isPaying) return;
                                    setState(() => _selectedChannel = channel);
                                  },
                                  onCompare: _showBenefits,
                                  onMore: _showMarketingNotice,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static void _noop() {}

  void _purchaseSelected() {
    final state = ref.read(membershipCatalogProvider);
    if (state is! AsyncData<MembershipCatalog>) return;
    final product = _selectedProduct(state.value);
    if (product != null) _purchase(product);
  }

  MembershipProduct? _selectedProduct(MembershipCatalog catalog) {
    final versions =
        catalog.versions
            .where(
              (v) =>
                  v.enabled &&
                  catalog
                      .availablePlans(
                        versionId: v.id,
                        appleOnly: Platform.isIOS,
                      )
                      .isNotEmpty,
            )
            .toList()
          ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    if (versions.isEmpty) return null;
    final versionId = versions.any((v) => v.id == _selectedVersionId)
        ? _selectedVersionId!
        : versions.first.id;
    final plans = catalog.availablePlans(
      versionId: versionId,
      appleOnly: Platform.isIOS,
    );
    if (plans.isEmpty) return null;
    final defaultPlan = plans.firstWhere(
      (plan) => plan.recommended,
      orElse: () => plans[plans.length ~/ 2],
    );
    final selectedId = _selectedPlanId ?? defaultPlan.id;
    return plans.firstWhere(
      (plan) => plan.id == selectedId,
      orElse: () => defaultPlan,
    );
  }

  void _goBack() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/profile');
    }
  }

  void _openRecords() => context.push('/profile/membership/records');

  Future<void> _restoreApplePurchases() async {
    try {
      await ref.read(appleMembershipPurchaseServiceProvider).restore();
      _refreshMembershipStatus();
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('正在恢复 App Store 购买记录')));
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  void _openAgreement() => context.push('/profile/membership/agreement');

  Future<void> _purchase(MembershipProduct product) async {
    if (_isPaying) return;
    final channel = _selectedChannel;
    if (Platform.isIOS) {
      final appleProductId = product.appleProductId;
      if (appleProductId == null) return;
      setState(() => _isPaying = true);
      try {
        await ref
            .read(appleMembershipPurchaseServiceProvider)
            .buy(appleProductId);
      } catch (error) {
        if (mounted)
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(error.toString())));
      } finally {
        if (mounted) setState(() => _isPaying = false);
      }
      return;
    }
    final intent = AccountPendingIntent(
      id: 'membership:${product.id}:${channel.name}',
      action: AccountPendingAction.membershipPurchase,
      returnLocation: '/profile/membership',
      payload: {'productId': product.id, 'channel': channel.name},
    );
    final allowed = await AccountAuthGate.requireLogin(
      context,
      ref,
      reason: AccountAuthReason.membership,
      intent: intent,
    );
    if (!mounted || !allowed) return;

    final pending = ref.read(accountPendingIntentProvider).consume(intent.id);
    if (pending == null ||
        pending.payload['productId'] != product.id ||
        pending.payload['channel'] != channel.name) {
      return;
    }

    setState(() => _isPaying = true);
    try {
      final session = ref.read(sessionRepositoryProvider);
      await session.initialize();
      final user = session.accountUser;
      if (user == null) return;

      final random = math.Random.secure().nextInt(1 << 32).toRadixString(16);
      final idempotencyKey =
          'membership-${DateTime.now().microsecondsSinceEpoch}-$random';
      final service = ref.read(paymentServiceProvider);
      final order = await service.createOrder(
        CreatePaymentOrderRequest(
          userId: user.id,
          productId: product.id,
          channel: channel,
          idempotencyKey: idempotencyKey,
        ),
      );
      if (order.amountInCents != product.priceInCents) {
        ref.invalidate(membershipCatalogProvider);
        throw StateError('套餐价格已更新，请确认新价格后重新开通');
      }
      _pendingOrderId = order.id;
      await service.invoke(order);
      await _checkPendingOrder();
      _refreshMembershipStatus();
      if (!mounted) return;
      setState(() => _isPaying = false);
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('已调起支付'),
          content: const Text('请在支付客户端完成付款。会员权益只会在服务端收到并验签确认后生效。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('完成'),
            ),
          ],
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _isPaying = false);
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('支付暂不可用'),
          content: Text(error.toString()),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('知道了'),
            ),
          ],
        ),
      );
    } finally {
      ref.read(accountPendingIntentProvider).clear(intent.id);
      if (mounted) setState(() => _isPaying = false);
    }
  }

  void _refreshMembershipStatus() {
    ref.invalidate(membershipProvider);
    ref.invalidate(membershipOrdersProvider);
    Future<void>.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      ref.invalidate(membershipProvider);
      ref.invalidate(membershipOrdersProvider);
    });
  }

  void _showBenefits() {
    final state = ref.read(membershipCatalogProvider);
    final catalog = state is AsyncData<MembershipCatalog> ? state.value : null;
    if (catalog == null) return;
    final product = _selectedProduct(catalog);
    if (product == null) return;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
          children: [
            const Text(
              '会员权益说明',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            ...catalog
                .benefitsFor(product)
                .map(
                  (benefit) => ListTile(
                    dense: true,
                    leading: Icon(
                      Icons.check_circle,
                      color: memberGreenFor(context),
                    ),
                    title: Text(benefit.title),
                    subtitle: Text('${benefit.subtitle}\n${benefit.detail}'),
                  ),
                ),
          ],
        ),
      ),
    );
  }

  void _showMarketingNotice() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
          children: [
            Text(
              '他们都在用',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
            SizedBox(height: 12),
            ListTile(
              leading: Icon(Icons.person, color: memberAccentFor(context)),
              title: Text('小橙子 · ★★★★★'),
              subtitle: Text('会员的自动记账太好用了！帮我省下很多时间，消费分析也很准，现在花钱更有计划了～'),
            ),
            ListTile(
              leading: Icon(Icons.person, color: memberAccentFor(context)),
              title: Text('阿凯 · ★★★★★'),
              subtitle: Text('用了半年，真的改变了我的消费习惯。无广告、数据同步、导出功能都很实用，强烈推荐！'),
            ),
            SizedBox(height: 8),
            Text(
              '以上为原型示例评价，当前版本没有可验证的更多评价数据。',
              style: TextStyle(color: memberMutedFor(context), fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _MemberHeader extends StatelessWidget {
  const _MemberHeader({
    required this.topInset,
    required this.onBack,
    required this.onRecords,
    this.onRestore,
  });
  final double topInset;
  final VoidCallback onBack, onRecords;
  final VoidCallback? onRestore;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(7, topInset + 4, 12, 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 48,
          height: 48,
          child: IconButton(
            onPressed: onBack,
            tooltip: '返回',
            padding: EdgeInsets.zero,
            icon: const Icon(Icons.arrow_back_rounded, size: 24),
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '开通会员',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: memberInkFor(context),
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '更多权益 · 让记账更简单',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: memberMutedFor(context),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 6),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextButton(
              onPressed: onRecords,
              style: TextButton.styleFrom(
                backgroundColor: memberSurfaceFor(context),
                foregroundColor: memberInkFor(context),
                padding: const EdgeInsets.symmetric(horizontal: 13),
                minimumSize: const Size(48, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
              child: const Text(
                '购买记录',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
              ),
            ),
            if (onRestore != null)
              TextButton(
                onPressed: onRestore,
                child: const Text('恢复购买', style: TextStyle(fontSize: 11)),
              ),
          ],
        ),
      ],
    ),
  );
}

class _CatalogContent extends StatelessWidget {
  const _CatalogContent({
    required this.catalog,
    required this.currentPlan,
    required this.selectedPlanId,
    required this.selectedVersionId,
    required this.selectedChannel,
    required this.onSelectPlan,
    required this.onSelectVersion,
    required this.onPurchase,
    required this.onSelectChannel,
    required this.onCompare,
    required this.onMore,
  });

  final MembershipCatalog catalog;
  final MembershipPlan currentPlan;
  final String? selectedPlanId;
  final String? selectedVersionId;
  final PaymentChannel selectedChannel;
  final ValueChanged<MembershipProduct> onSelectPlan;
  final ValueChanged<String> onSelectVersion;
  final ValueChanged<MembershipProduct> onPurchase;
  final ValueChanged<PaymentChannel> onSelectChannel;
  final VoidCallback onCompare;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    final versions =
        catalog.versions
            .where(
              (v) =>
                  v.enabled &&
                  catalog
                      .availablePlans(
                        versionId: v.id,
                        appleOnly: Platform.isIOS,
                      )
                      .isNotEmpty,
            )
            .toList()
          ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    if (versions.isEmpty)
      return const Padding(padding: EdgeInsets.all(28), child: Text('暂无可开通套餐'));
    final versionId = versions.any((v) => v.id == selectedVersionId)
        ? selectedVersionId!
        : versions.first.id;
    final plans = catalog.availablePlans(
      versionId: versionId,
      appleOnly: Platform.isIOS,
    );
    final defaultPlan = plans.firstWhere(
      (plan) => plan.recommended,
      orElse: () => plans[plans.length ~/ 2],
    );
    final selected = plans.any((plan) => plan.id == selectedPlanId)
        ? selectedPlanId!
        : defaultPlan.id;
    final product = plans.firstWhere((p) => p.id == selected);
    return Column(
      children: [
        if (versions.length > 1) ...[
          Wrap(
            spacing: 10,
            children: [
              for (final version in versions)
                ChoiceChip(
                  label: Text(version.title),
                  selected: version.id == versionId,
                  onSelected: (_) => onSelectVersion(version.id),
                ),
            ],
          ),
          const SizedBox(height: 18),
        ],
        MemberPlanSection(
          plans: plans,
          selectedPlanId: selected,
          onSelect: onSelectPlan,
          onPurchase: onPurchase,
          renewal: currentPlan != MembershipPlan.free,
        ),
        const SizedBox(height: 12),
        MemberBenefits(
          benefits: catalog.benefitsFor(product),
          onMore: onCompare,
        ),
        const SizedBox(height: 12),
        MemberTestimonials(onMore: onMore),
        const SizedBox(height: 12),
        if (!Platform.isIOS)
          PaymentMethodSection(
            selected: selectedChannel,
            onSelect: onSelectChannel,
          ),
      ],
    );
  }
}

class _CatalogError extends StatelessWidget {
  const _CatalogError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 35),
    child: Column(
      children: [
        Icon(
          Icons.cloud_off_outlined,
          color: memberMutedFor(context),
          size: 30,
        ),
        const SizedBox(height: 8),
        Text('会员配置暂时不可用', style: TextStyle(color: memberInkFor(context))),
        TextButton(onPressed: onRetry, child: const Text('重新加载')),
      ],
    ),
  );
}

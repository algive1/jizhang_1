import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/membership.dart';
import '../../account/application/account_auth_gate.dart';
import '../../account/application/account_pending_intent.dart';
import '../../sharing/data/session_repository.dart';
import '../data/membership_catalog.dart';
import '../data/membership_repository.dart';
import '../data/payment_service.dart';
import '../domain/commercial_service_contracts.dart';
import 'membership_visuals.dart';

class MembershipPage extends ConsumerStatefulWidget {
  const MembershipPage({super.key});

  @override
  ConsumerState<MembershipPage> createState() => _MembershipPageState();
}

class _MembershipPageState extends ConsumerState<MembershipPage> {
  String? _selectedPlanId;
  PaymentChannel _selectedChannel = PaymentChannel.wechatPay;
  bool _isPaying = false;

  @override
  Widget build(BuildContext context) {
    final snapshot = ref.watch(membershipProvider).value;
    final catalog = ref.watch(membershipCatalogProvider);
    final currentPlan = snapshot?.membership.plan ?? MembershipPlan.free;
    final statusBarHeight = MediaQuery.viewPaddingOf(context).top;
    final selectedProduct = catalog is AsyncData<MembershipCatalog>
        ? _selectedProduct(catalog.value)
        : null;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        extendBodyBehindAppBar: true,
        backgroundColor: memberBackground,
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
                                memberSurface.withValues(alpha: .38),
                                memberSurface.withValues(alpha: .06),
                                memberBackground,
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
                                  selectedChannel: _selectedChannel,
                                  onSelectPlan: (plan) {
                                    if (_isPaying) return;
                                    setState(() => _selectedPlanId = plan.id);
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
    final plans = [...catalog.plans]
      ..sort((a, b) => a.months.compareTo(b.months));
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

  void _openAgreement() => context.push('/profile/membership/agreement');

  Future<void> _purchase(MembershipProduct product) async {
    if (_isPaying) return;
    final channel = _selectedChannel;
    final intent = AccountPendingIntent(
      id: 'membership:${product.id}:${channel.name}',
      action: AccountPendingAction.membershipPurchase,
      returnLocation: '/profile/membership',
      payload: {
        'productId': product.id,
        'channel': channel.name,
      },
    );
    final allowed = await AccountAuthGate.requireLogin(
      context,
      ref,
      reason: AccountAuthReason.membership,
      intent: intent,
    );
    if (!mounted || !allowed) return;

    final pending = ref
        .read(accountPendingIntentProvider)
        .consume(intent.id);
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
      await service.invoke(order);
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
            ...catalog.benefits.map(
              (benefit) => ListTile(
                dense: true,
                leading: const Icon(Icons.check_circle, color: memberGreen),
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
          children: const [
            Text(
              '他们都在用',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
            SizedBox(height: 12),
            ListTile(
              leading: Icon(Icons.person, color: memberAccent),
              title: Text('小橙子 · ★★★★★'),
              subtitle: Text('会员的自动记账太好用了！帮我省下很多时间，消费分析也很准，现在花钱更有计划了～'),
            ),
            ListTile(
              leading: Icon(Icons.person, color: memberAccent),
              title: Text('阿凯 · ★★★★★'),
              subtitle: Text('用了半年，真的改变了我的消费习惯。无广告、数据同步、导出功能都很实用，强烈推荐！'),
            ),
            SizedBox(height: 8),
            Text(
              '以上为原型示例评价，当前版本没有可验证的更多评价数据。',
              style: TextStyle(color: memberMuted, fontSize: 12),
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
  });

  final double topInset;
  final VoidCallback onBack;
  final VoidCallback onRecords;

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(1);
    return SizedBox(
      height: topInset + 50 + (scale - 1) * 54,
      child: Stack(
        children: [
          Positioned(
            left: 7,
            top: topInset + 2,
            child: IconButton(
              onPressed: onBack,
              tooltip: '返回',
              constraints: const BoxConstraints.tightFor(
                width: 48,
                height: 48,
              ),
              padding: EdgeInsets.zero,
              icon: const Icon(Icons.arrow_back_rounded, size: 24),
            ),
          ),
          Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: EdgeInsets.only(top: topInset + (scale > 1.2 ? 5 : 4)),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Text(
                    '开通会员',
                    style: TextStyle(
                      color: memberInk,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      height: 1.1,
                    ),
                  ),
                  SizedBox(height: 5),
                  Text(
                    '更多权益 · 让记账更简单',
                    style: TextStyle(color: memberMuted, fontSize: 11),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            right: 12,
            top: topInset + 5,
            child: TextButton(
              onPressed: onRecords,
              style: TextButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: memberInk,
                padding: const EdgeInsets.symmetric(horizontal: 13),
                minimumSize: const Size(0, 32),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: const Text(
                '购买记录',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CatalogContent extends StatelessWidget {
  const _CatalogContent({
    required this.catalog,
    required this.currentPlan,
    required this.selectedPlanId,
    required this.selectedChannel,
    required this.onSelectPlan,
    required this.onSelectChannel,
    required this.onCompare,
    required this.onMore,
  });

  final MembershipCatalog catalog;
  final MembershipPlan currentPlan;
  final String? selectedPlanId;
  final PaymentChannel selectedChannel;
  final ValueChanged<MembershipProduct> onSelectPlan;
  final ValueChanged<PaymentChannel> onSelectChannel;
  final VoidCallback onCompare;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    final plans = [...catalog.plans]
      ..sort((a, b) => a.months.compareTo(b.months));
    if (plans.isEmpty) return const SizedBox.shrink();
    final defaultPlan = plans.firstWhere(
      (plan) => plan.recommended,
      orElse: () => plans[plans.length ~/ 2],
    );
    final selected = plans.any((plan) => plan.id == selectedPlanId)
        ? selectedPlanId!
        : defaultPlan.id;
    return Column(
      children: [
        MemberPlanSection(
          plans: plans,
          selectedPlanId: selected,
          onSelect: onSelectPlan,
          renewal: currentPlan != MembershipPlan.free,
        ),
        const SizedBox(height: 12),
        MemberBenefits(benefits: catalog.benefits, onMore: onCompare),
        const SizedBox(height: 12),
        MemberTestimonials(onMore: onMore),
        const SizedBox(height: 12),
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
        const Icon(Icons.cloud_off_outlined, color: memberMuted, size: 30),
        const SizedBox(height: 8),
        const Text('会员配置暂时不可用', style: TextStyle(color: memberInk)),
        TextButton(onPressed: onRetry, child: const Text('重新加载')),
      ],
    ),
  );
}

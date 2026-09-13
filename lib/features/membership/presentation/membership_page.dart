import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/membership.dart';
import '../../sharing/data/session_repository.dart';
import '../data/membership_catalog.dart';
import '../data/payment_service.dart';
import '../data/membership_repository.dart';
import '../domain/commercial_service_contracts.dart';
import 'membership_visuals.dart';

class MembershipPage extends ConsumerStatefulWidget {
  const MembershipPage({super.key});

  @override
  ConsumerState<MembershipPage> createState() => _MembershipPageState();
}

class _MembershipPageState extends ConsumerState<MembershipPage> {
  String? _selectedPlanId;
  String? _expandedFaqId;

  @override
  Widget build(BuildContext context) {
    final snapshot = ref.watch(membershipProvider).value;
    final catalog = ref.watch(membershipCatalogProvider);
    final currentPlan = snapshot?.membership.plan ?? MembershipPlan.free;
    return ColoredBox(
      color: const Color(0xFFFAF7EF),
      child: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 22),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _Header(onBack: _goBack, onRecords: _openRecords),
                  const SizedBox(height: 4),
                  const MembershipHero(),
                  const SizedBox(height: 8),
                  catalog.when(
                    loading: () => const Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                    error: (error, _) => _CatalogError(
                      onRetry: () => ref.invalidate(membershipCatalogProvider),
                    ),
                    data: (data) => _CatalogContent(
                      catalog: data,
                      currentPlan: currentPlan,
                      snapshot: snapshot,
                      selectedPlanId: _selectedPlanId,
                      expandedFaqId: _expandedFaqId,
                      onSelectPlan: (id) =>
                          setState(() => _selectedPlanId = id),
                      onPurchase: _purchase,
                      onFaq: (id) => setState(
                        () => _expandedFaqId = _expandedFaqId == id ? null : id,
                      ),
                      onCompare: _showBenefits,
                      onMore: _showMarketingNotice,
                      onFaqMore: _showFaqs,
                    ),
                  ),
                ]),
              ),
            ),
          ],
        ),
      ),
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

  Future<void> _purchase(MembershipProduct product) async {
    final session = ref.read(sessionRepositoryProvider);
    await session.initialize();
    if (!mounted) return;
    if (session.user == null) {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('登录后开通会员'),
          content: const Text('支付订单需要绑定登录账号，请先登录后再继续。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('知道了'),
            ),
          ],
        ),
      );
      return;
    }
    final channel = await _selectPaymentChannel(product);
    if (!mounted || channel == null) return;
    final random = math.Random.secure().nextInt(1 << 32).toRadixString(16);
    final idempotencyKey =
        'membership-${DateTime.now().microsecondsSinceEpoch}-$random';
    try {
      final service = ref.read(paymentServiceProvider);
      final order = await service.createOrder(
        CreatePaymentOrderRequest(
          userId: session.user!.id,
          productId: product.id,
          channel: channel,
          idempotencyKey: idempotencyKey,
        ),
      );
      await service.invoke(order);
      _refreshMembershipStatus();
      if (!mounted) return;
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
    }
  }

  void _refreshMembershipStatus() {
    // The payment app returns before the provider callback is guaranteed to
    // reach the server. Refresh once immediately and once after the callback
    // retry window so the page catches the confirmed entitlement without
    // trusting the client SDK result.
    ref.invalidate(membershipProvider);
    ref.invalidate(membershipOrdersProvider);
    Future<void>.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      ref.invalidate(membershipProvider);
      ref.invalidate(membershipOrdersProvider);
    });
  }

  Future<PaymentChannel?> _selectPaymentChannel(MembershipProduct product) {
    return showModalBottomSheet<PaymentChannel>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '选择支付方式',
                style: Theme.of(context).textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                '开通 ${product.title} · ¥${MembershipProduct.money(product.priceInCents)}',
                style: const TextStyle(color: memberMuted, fontSize: 13),
              ),
              const SizedBox(height: 12),
              _PaymentMethodTile(
                icon: Icons.chat_bubble_rounded,
                color: const Color(0xFF20B65A),
                title: '微信支付',
                subtitle: '使用微信客户端完成付款',
                onTap: () =>
                    Navigator.pop(sheetContext, PaymentChannel.wechatPay),
              ),
              const SizedBox(height: 8),
              _PaymentMethodTile(
                icon: Icons.account_balance_wallet_rounded,
                color: const Color(0xFF1677FF),
                title: '支付宝',
                subtitle: '使用支付宝客户端完成付款',
                onTap: () => Navigator.pop(sheetContext, PaymentChannel.alipay),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showBenefits() {
    final catalogState = ref.read(membershipCatalogProvider);
    final catalog = catalogState is AsyncData<MembershipCatalog>
        ? catalogState.value
        : null;
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
              '会员权益对比',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            ...catalog.benefits.map(
              (benefit) => ListTile(
                dense: true,
                leading: const Icon(Icons.check_circle, color: memberGreen),
                title: Text(benefit.title),
                subtitle: Text(benefit.subtitle),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showMarketingNotice() {
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('更多内容正在准备中')));
  }

  void _showFaqs() {
    final state = ref.read(membershipCatalogProvider);
    final catalog = state is AsyncData<MembershipCatalog> ? state.value : null;
    if (catalog == null) return;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              child: Text(
                '常见问题',
                style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
              ),
            ),
            for (final faq in catalog.faqs)
              ExpansionTile(
                title: Text(faq.question),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(faq.answer),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _PaymentMethodTile extends StatelessWidget {
  const _PaymentMethodTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title, subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    borderRadius: BorderRadius.circular(14),
    onTap: onTap,
    child: Ink(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAF4),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: .12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 23),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(color: memberMuted, fontSize: 11),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: memberMuted),
        ],
      ),
    ),
  );
}

class _Header extends StatelessWidget {
  const _Header({required this.onBack, required this.onRecords});

  final VoidCallback onBack;
  final VoidCallback onRecords;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 48,
    child: Row(
      children: [
        IconButton(
          onPressed: onBack,
          tooltip: '返回',
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints.tightFor(width: 42, height: 42),
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 21),
        ),
        const Expanded(
          child: Center(
            child: Text(
              '会员中心',
              style: TextStyle(
                color: memberInk,
                fontSize: 23,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
        TextButton.icon(
          onPressed: onRecords,
          style: TextButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: memberInk,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            minimumSize: const Size(0, 34),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
          icon: const Icon(Icons.receipt_long_outlined, size: 17),
          label: const Text('会员记录', style: TextStyle(fontSize: 11)),
        ),
      ],
    ),
  );
}

class _CatalogContent extends StatelessWidget {
  const _CatalogContent({
    required this.catalog,
    required this.currentPlan,
    required this.snapshot,
    required this.selectedPlanId,
    required this.expandedFaqId,
    required this.onSelectPlan,
    required this.onPurchase,
    required this.onFaq,
    required this.onCompare,
    required this.onMore,
    required this.onFaqMore,
  });

  final MembershipCatalog catalog;
  final MembershipPlan currentPlan;
  final MembershipSnapshot? snapshot;
  final String? selectedPlanId;
  final String? expandedFaqId;
  final ValueChanged<String> onSelectPlan;
  final ValueChanged<MembershipProduct> onPurchase;
  final ValueChanged<String> onFaq;
  final VoidCallback onCompare;
  final VoidCallback onMore;
  final VoidCallback onFaqMore;

  @override
  Widget build(BuildContext context) {
    final plans = [...catalog.plans]
      ..sort((a, b) => a.months.compareTo(b.months));
    final defaultPlan = plans.firstWhere(
      (plan) => plan.recommended,
      orElse: () => plans[plans.length ~/ 2],
    );
    final selected = selectedPlanId ?? defaultPlan.id;
    final monthly = plans
        .firstWhere((plan) => plan.months == 1, orElse: () => plans.first)
        .priceInCents;
    final renewal = currentPlan != MembershipPlan.free;
    final cloudEnabled = snapshot?.has(EntitlementKey.cloudSync) ?? false;
    return Column(
      children: [
        MembershipSection(
          title: '选择会员套餐',
          action: '对比权益',
          onAction: onCompare,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const AlwaysScrollableScrollPhysics(),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < plans.length; i++)
                  SizedBox(
                    width: 104,
                    child: Padding(
                      padding: EdgeInsets.only(
                        right: i == plans.length - 1 ? 0 : 6,
                      ),
                      child: MembershipPlanCard(
                        product: plans[i],
                        monthlyPrice: monthly,
                        selected: plans[i].id == selected,
                        renewal: renewal,
                        onSelect: () => onSelectPlan(plans[i].id),
                        onPurchase: () => onPurchase(plans[i]),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        MembershipSection(
          title: '会员专享权益',
          action: '查看全部权益',
          onAction: onCompare,
          child: _BenefitsGrid(benefits: catalog.benefits),
        ),
        MembershipSection(
          title: '他们都在用好好记账会员',
          action: '查看更多',
          onAction: onMore,
          child: const _Testimonials(),
        ),
        MembershipSection(
          title: '常见问题',
          action: '查看更多',
          onAction: onFaqMore,
          child: _FaqList(
            faqs: catalog.faqs,
            expandedFaqId: expandedFaqId,
            onFaq: onFaq,
          ),
        ),
        const SizedBox(height: 18),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.favorite, size: 16, color: Color(0xFF9A9B93)),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                '好好记账 · 记录生活 更好地生活',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
              ),
            ),
          ],
        ),
        const SizedBox(height: 7),
        Text(
          cloudEnabled ? '云同步权益已授权' : '数据保存在本机，安心记录每一天',
          style: TextStyle(color: Colors.grey.shade500, fontSize: 10),
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

class _BenefitsGrid extends StatelessWidget {
  const _BenefitsGrid({required this.benefits});

  final List<MembershipBenefit> benefits;
  static const _icons = <String, IconData>{
    'automatic': Icons.smart_toy_outlined,
    'books': Icons.menu_book_outlined,
    'statistics': Icons.bar_chart_rounded,
    'cloud': Icons.cloud_outlined,
    'assets': Icons.account_balance_wallet_outlined,
    'export': Icons.file_download_outlined,
    'theme': Icons.palette_outlined,
    'support': Icons.headset_mic_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final largeText = MediaQuery.textScalerOf(context).scale(1) > 1.2;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: benefits.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: largeText ? 7 : 4,
        crossAxisSpacing: 2,
        childAspectRatio: largeText ? .65 : .85,
      ),
      itemBuilder: (context, index) {
        final benefit = benefits[index];
        return Column(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: const BoxDecoration(
                color: Color(0xFFEEF5E3),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _icons[benefit.id] ?? Icons.check,
                color: memberGreen,
                size: 25,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              benefit.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: memberInk,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 1),
            Text(
              benefit.subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: memberMuted, fontSize: 9),
            ),
          ],
        );
      },
    );
  }
}

class _Testimonials extends StatelessWidget {
  const _Testimonials();

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      const cards = [
        _Testimonial(
          image: '${memberAssets}testimonial-user-female.webp',
          name: '@ 小**鹿',
          quote: '自动记账太方便了，\n再也不用手动输入，\n省下了很多时间！',
        ),
        _Testimonial(
          image: '${memberAssets}testimonial-user-male.webp',
          name: '@ 晨**阳',
          quote: '多账本功能很好用，\n家庭开支一目了然，\n生活更有规划了！',
        ),
      ];
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: constraints.maxWidth < 350
            ? const AlwaysScrollableScrollPhysics()
            : const NeverScrollableScrollPhysics(),
        child: Row(
          children: [
            for (var i = 0; i < cards.length; i++)
              SizedBox(
                width: constraints.maxWidth < 350
                    ? constraints.maxWidth * .80
                    : (constraints.maxWidth - 6) / 2,
                child: Padding(
                  padding: EdgeInsets.only(
                    right: i == cards.length - 1 ? 0 : 6,
                  ),
                  child: cards[i],
                ),
              ),
          ],
        ),
      );
    },
  );
}

class _Testimonial extends StatelessWidget {
  const _Testimonial({
    required this.image,
    required this.name,
    required this.quote,
  });

  final String image;
  final String name;
  final String quote;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(8, 9, 7, 8),
    decoration: BoxDecoration(
      color: const Color(0xFFFEFAF1),
      borderRadius: BorderRadius.circular(13),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            ClipOval(
              child: Image.asset(
                image,
                width: 48,
                height: 48,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              name,
              style: const TextStyle(color: memberMuted, fontSize: 10),
            ),
          ],
        ),
        const SizedBox(width: 7),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '“',
                style: TextStyle(
                  color: Color(0xFF78A64D),
                  fontSize: 29,
                  height: .65,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                quote,
                style: const TextStyle(
                  color: memberInk,
                  fontSize: 10,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 2),
              const Text(
                '★★★★★',
                style: TextStyle(
                  color: memberGreen,
                  fontSize: 13,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _FaqList extends StatelessWidget {
  const _FaqList({
    required this.faqs,
    required this.expandedFaqId,
    required this.onFaq,
  });

  final List<MembershipFaq> faqs;
  final String? expandedFaqId;
  final ValueChanged<String> onFaq;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (final faq in faqs.take(3))
        Container(
          margin: const EdgeInsets.only(bottom: 5),
          decoration: BoxDecoration(
            color: const Color(0xFFFAF9F4),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            children: [
              InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => onFaq(faq.id),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 7,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 25,
                        height: 25,
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(
                          color: memberGreen,
                          shape: BoxShape.circle,
                        ),
                        child: const Text(
                          '?',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          faq.question,
                          style: const TextStyle(
                            color: memberInk,
                            fontSize: 11,
                          ),
                        ),
                      ),
                      Icon(
                        expandedFaqId == faq.id
                            ? Icons.keyboard_arrow_up
                            : Icons.keyboard_arrow_down,
                        color: memberMuted,
                        size: 19,
                      ),
                    ],
                  ),
                ),
              ),
              if (expandedFaqId == faq.id)
                Padding(
                  padding: const EdgeInsets.fromLTRB(41, 0, 14, 10),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      faq.answer,
                      style: const TextStyle(
                        color: memberMuted,
                        fontSize: 10,
                        height: 1.45,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
    ],
  );
}

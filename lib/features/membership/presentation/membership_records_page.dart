import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/membership_catalog.dart';
import '../data/payment_service.dart';
import '../domain/commercial_service_contracts.dart';

class MembershipRecordsPage extends ConsumerWidget {
  const MembershipRecordsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orders = ref.watch(membershipOrdersProvider);
    final catalogState = ref.watch(membershipCatalogProvider);
    final catalog = catalogState is AsyncData<MembershipCatalog>
        ? catalogState.value
        : null;
    final productTitles = {
      for (final product in catalog?.plans ?? const <MembershipProduct>[])
        product.id: product.title,
    };
    return Scaffold(
      appBar: AppBar(title: const Text('会员记录')),
      body: orders.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _ErrorState(
          message: error.toString(),
          onRetry: () => ref.invalidate(membershipOrdersProvider),
        ),
        data: (items) => RefreshIndicator(
          onRefresh: () => ref.refresh(membershipOrdersProvider.future),
          child: items.isEmpty
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: const [SizedBox(height: 180), _EmptyState()],
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) => _OrderTile(
                    items[index],
                    productTitle:
                        productTitles[items[index].productId] ??
                        items[index].productId,
                  ),
                ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.receipt_long_outlined,
            size: 44,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 12),
          const Text(
            '暂无会员记录',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            '完成支付后，订单状态和会员有效期会显示在这里。',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
          ),
        ],
      ),
    ),
  );
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_outlined, size: 42),
          const SizedBox(height: 10),
          Text(message, textAlign: TextAlign.center),
          TextButton(onPressed: onRetry, child: const Text('重新加载')),
        ],
      ),
    ),
  );
}

class _OrderTile extends StatelessWidget {
  const _OrderTile(this.order, {required this.productTitle});
  final PaymentOrder order;
  final String productTitle;

  @override
  Widget build(BuildContext context) {
    final channel = order.channel == PaymentChannel.wechatPay ? '微信支付' : '支付宝';
    final status = switch (order.status) {
      PaymentOrderStatus.created => '待发起',
      PaymentOrderStatus.pending => '待支付',
      PaymentOrderStatus.paid => '已支付',
      PaymentOrderStatus.failed => '支付失败',
      PaymentOrderStatus.refunded => '已退款',
    };
    final statusColor = order.status == PaymentOrderStatus.paid
        ? const Color(0xFF557D2D)
        : Colors.grey.shade600;
    return Card(
      elevation: 0,
      color: const Color(0xFFFEFAF1),
      child: ListTile(
        title: Text(
          productTitle,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text('$channel · ${order.createdAt.toLocal()}'),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '¥${MembershipProduct.money(order.amountInCents)}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            Text(status, style: TextStyle(color: statusColor, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

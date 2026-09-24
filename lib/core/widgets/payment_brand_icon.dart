import 'package:flutter/material.dart';

import '../models/account.dart';

const paymentWechatAsset = 'assets/images/membership/wechat-pay.png';
const paymentAlipayAsset = 'assets/images/membership/alipay.png';

enum PaymentBrand {
  wechat,
  alipay;

  String get asset => switch (this) {
    PaymentBrand.wechat => paymentWechatAsset,
    PaymentBrand.alipay => paymentAlipayAsset,
  };

  Color get fallbackColor => switch (this) {
    PaymentBrand.wechat => const Color(0xFF20B65A),
    PaymentBrand.alipay => const Color(0xFF1677FF),
  };
}

PaymentBrand? paymentBrandForAccountType(AccountType? type) => switch (type) {
  AccountType.wechat => PaymentBrand.wechat,
  AccountType.alipay => PaymentBrand.alipay,
  _ => null,
};

class PaymentBrandIcon extends StatelessWidget {
  const PaymentBrandIcon({
    required this.brand,
    this.size = 20,
    this.fallbackColor,
    super.key,
  });

  final PaymentBrand brand;
  final double size;
  final Color? fallbackColor;

  @override
  Widget build(BuildContext context) => Image.asset(
    brand.asset,
    width: size,
    height: size,
    fit: BoxFit.contain,
    errorBuilder: (context, error, stackTrace) => SizedBox(
      width: size,
      height: size,
      child: ColoredBox(
        color: (fallbackColor ?? brand.fallbackColor).withValues(alpha: .12),
        child: Icon(
          brand == PaymentBrand.wechat
              ? Icons.chat_bubble_rounded
              : Icons.account_balance_wallet_rounded,
          color: fallbackColor ?? brand.fallbackColor,
          size: size * .65,
        ),
      ),
    ),
  );
}

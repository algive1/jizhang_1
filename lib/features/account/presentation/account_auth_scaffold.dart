import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';

class AccountAuthScaffold extends StatelessWidget {
  const AccountAuthScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xFFF7F8EE),
        body: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFFEEF2DE),
                Color(0xFFF7F4E8),
                Color(0xFFFAF9F2),
              ],
            ),
          ),
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: IconButton(
                          tooltip: '返回',
                          onPressed: () => Navigator.maybePop(context),
                          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        width: 58,
                        height: 58,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: .12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.account_balance_wallet_outlined,
                          color: AppColors.primary,
                          size: 29,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 30,
                          height: 1.2,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF151912),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 14,
                          height: 1.55,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: .82),
                          borderRadius: BorderRadius.circular(26),
                          border: Border.all(
                            color: const Color(0xFFE6E8D9),
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x0D000000),
                              blurRadius: 24,
                              offset: Offset(0, 10),
                            ),
                          ],
                        ),
                        child: child,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
}

String accountAuthError(Object error) {
  final text = error.toString().trim();
  if (text.isEmpty) return '操作失败，请稍后重试';
  if (text.contains('SocketException') ||
      text.contains('Connection refused') ||
      text.contains('Failed host lookup')) {
    return '暂时无法连接账户服务，请检查网络后重试';
  }
  return text.replaceFirst(RegExp(r'^Exception:\s*'), '');
}

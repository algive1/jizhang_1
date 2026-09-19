import 'package:flutter/material.dart';

class AccountAuthScaffold extends StatelessWidget {
  const AccountAuthScaffold({super.key, required this.title, required this.subtitle, required this.child});
  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color.alphaBlend(colors.primary.withValues(alpha: .08), theme.scaffoldBackgroundColor),
              theme.scaffoldBackgroundColor,
              colors.surface,
            ],
            stops: const [0, .46, 1],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      tooltip: '返回',
                      onPressed: () => Navigator.maybePop(context),
                      icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Center(
                    child: Container(
                      width: 56, height: 56,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: colors.primaryContainer.withValues(alpha: .62), shape: BoxShape.circle),
                      child: Icon(Icons.account_balance_wallet_outlined, color: colors.primary, size: 28),
                    ),
                  ),
                  const SizedBox(height: 28),
                  Text(title, style: theme.textTheme.headlineLarge),
                  const SizedBox(height: 10),
                  Text(subtitle, style: theme.textTheme.bodyLarge?.copyWith(color: colors.onSurfaceVariant, height: 1.55)),
                  const SizedBox(height: 30),
                  child,
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String accountAuthError(Object error) {
  final text = error.toString().trim();
  if (text.isEmpty) return '操作失败，请稍后重试';
  if (text.contains('SocketException') || text.contains('Connection refused') || text.contains('Failed host lookup')) {
    return '暂时无法连接账户服务，请检查网络后重试';
  }
  return text.replaceFirst(RegExp(r'^Exception:\s*'), '');
}

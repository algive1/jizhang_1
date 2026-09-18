import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../sharing/data/session_repository.dart';
import '../domain/account_session_status.dart';
import 'account_pending_intent.dart';

enum AccountAuthReason {
  membership,
  sharedLedger,
  cloudSync,
  ai,
  generic,
}

class AccountAuthGate {
  const AccountAuthGate._();

  static Future<bool> requireLogin(
    BuildContext context,
    WidgetRef ref, {
    required AccountAuthReason reason,
    required AccountPendingIntent intent,
  }) async {
    final pending = ref.read(accountPendingIntentProvider);
    pending.set(intent);
    final session = ref.read(sessionRepositoryProvider);
    await session.initialize();
    if (session.accountStatus == AccountSessionStatus.authenticated &&
        session.accountUser != null) {
      return true;
    }
    if (!context.mounted) return false;

    final choice = await showModalBottomSheet<_AuthChoice>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => _AuthGateSheet(reason: reason),
    );
    if (!context.mounted || choice == null) {
      pending.clear(intent.id)
      return false;
    }

    final path = choice == _AuthChoice.register
        ? '/account/register?gate=1'
        : '/account/login?gate=1';
    final signedIn = await context.push<bool>(path);
    if (!context.mounted || signedIn != true) {
      ref.read(accountPendingIntentProvider).clear(intent.id);
      return false;
    }

    await session.initialize();
    final allowed =
        session.accountStatus == AccountSessionStatus.authenticated &&
        session.accountUser != null;
    if (!allowed) {
      ref.read(accountPendingIntentProvider).clear(intent.id);
    }
    return allowed;
  }
}

enum _AuthChoice { login, register }

class _AuthGateSheet extends StatelessWidget {
  const _AuthGateSheet({required this.reason});

  final AccountAuthReason reason;

  @override
  Widget build(BuildContext context) {
    final copy = switch (reason) {
      AccountAuthReason.membership => (
          '登录后继续开通',
          '支付订单需要绑定到你的好好记账账号。登录完成后会继续刚才选择的会员方案。',
          Icons.workspace_premium_outlined,
        ),
      AccountAuthReason.sharedLedger => (
          '登录后继续共享',
          '共享账本需要服务器身份。登录不会自动上传或认领你的本地个人账务数据。',
          Icons.people_outline,
        ),
      AccountAuthReason.cloudSync => (
          '登录后继续云同步',
          '云同步需要服务器身份。登录本身不会上传本地数据，后续仍会单独确认数据绑定。',
          Icons.cloud_outlined,
        ),
      AccountAuthReason.ai => (
          '登录后继续使用',
          '联网 AI 能力需要账号来校验会员权益与使用额度。',
          Icons.auto_awesome_outlined,
        ),
      AccountAuthReason.generic => (
          '登录后继续',
          '这项功能需要好好记账账号。登录后会返回并继续刚才的操作。',
          Icons.account_circle_outlined,
        ),
    };

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 54,
              height: 54,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: .12),
                shape: BoxShape.circle,
              ),
              child: Icon(copy.$3, color: AppColors.primary, size: 28),
            ),
            const SizedBox(height: 16),
            Text(
              copy.$1,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              copy.$2,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textSecondary,
                height: 1.55,
              ),
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(context, _AuthChoice.login),
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 13),
                  child: Text('登录'),
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, _AuthChoice.register),
              child: const Text('创建账号'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('暂不登录'),
            ),
          ],
        ),
      ),
    );
  }
}

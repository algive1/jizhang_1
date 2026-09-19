import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/membership.dart';
import '../data/membership_repository.dart';
import '../../../app/theme/app_theme_tokens.dart';

/// Checks a server-controlled capability and opens the shared upgrade prompt
/// when the current member snapshot does not grant it.
///
/// Existing local-only policies are pass-through, so adopting this helper at
/// feature entry points does not change behavior before the backend policy is
/// available.
Future<bool> ensureMembershipFeatureAvailable(
  BuildContext context,
  WidgetRef ref,
  MembershipFeature feature,
) async {
  final access = await ref
      .read(membershipFeatureAccessServiceProvider)
      .accessFor(feature);
  if (access.allowed) return true;
  if (access.requiresUpgrade && context.mounted) {
    await showMembershipUpgradePrompt(context, feature);
  }
  return false;
}

Future<void> showMembershipUpgradePrompt(
  BuildContext context,
  MembershipFeature feature,
) {
  return showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    showDragHandle: true,
    builder: (sheetContext) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${feature.label}需要会员',
            style: Theme.of(sheetContext).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            '该功能的开放范围由后台会员策略控制，开通会员后即可继续使用。',
            style: TextStyle(color: context.appSecondaryText, height: 1.5),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () {
                Navigator.of(sheetContext).pop();
                if (context.mounted) context.push('/profile/membership');
              },
              icon: const Icon(Icons.workspace_premium_outlined),
              label: const Text('快捷开通会员'),
            ),
          ),
        ],
      ),
    ),
  );
}

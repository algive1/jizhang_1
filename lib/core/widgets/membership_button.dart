import 'package:flutter/material.dart';

import '../../app/theme/app_theme_tokens.dart';

class MembershipButton extends StatelessWidget {
  const MembershipButton({required this.onPressed, super.key});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      tooltip: '会员',
      constraints: const BoxConstraints.tightFor(width: 36, height: 36),
      padding: EdgeInsets.zero,
      style: IconButton.styleFrom(
        backgroundColor: context.appPrimarySoft,
        foregroundColor: context.appPrimary,
        shape: CircleBorder(
          side: BorderSide(
            color: Color.alphaBlend(
              context.appPrimary.withValues(alpha: .22),
              context.appDivider,
            ),
          ),
        ),
      ),
      icon: const Icon(Icons.workspace_premium_outlined, size: 21),
    );
  }
}

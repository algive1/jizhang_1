import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';

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
        backgroundColor: AppColors.primarySoft,
        foregroundColor: AppColors.primaryDark,
        shape: const CircleBorder(side: BorderSide(color: Color(0xFFDCE8BF))),
      ),
      icon: const Icon(Icons.workspace_premium_outlined, size: 21),
    );
  }
}

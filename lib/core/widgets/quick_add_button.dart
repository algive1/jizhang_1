import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';

class QuickAddButton extends StatelessWidget {
  const QuickAddButton({
    required this.onPressed,
    required this.onLongPress,
    super.key,
  });

  final VoidCallback onPressed;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: onLongPress,
      child: FloatingActionButton(
        onPressed: onPressed,
        elevation: 5,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        shape: const CircleBorder(),
        child: Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.primary,
            border: Border.all(color: Colors.white.withValues(alpha: .6)),
          ),
          child: const Icon(Icons.add, size: 38, weight: 400),
        ),
      ),
    );
  }
}

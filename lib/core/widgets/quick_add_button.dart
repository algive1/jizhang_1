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
    return DecoratedBox(
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Color(0x38638332),
            blurRadius: 13,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: GestureDetector(
        onLongPress: onLongPress,
        child: FloatingActionButton(
          onPressed: onPressed,
          elevation: 0,
          focusElevation: 0,
          hoverElevation: 0,
          highlightElevation: 0,
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          shape: const CircleBorder(),
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary,
              border: Border.all(color: Colors.white.withValues(alpha: .65)),
            ),
            child: const Icon(Icons.add, size: 38, weight: 400),
          ),
        ),
      ),
    );
  }
}

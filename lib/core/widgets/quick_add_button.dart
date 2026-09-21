import 'package:flutter/material.dart';

import '../../app/theme/app_theme_tokens.dart';
import 'app_glass_surface.dart';

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
    final glass = context.appUsesLiquidGlass;

    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: context.appPrimary.withValues(alpha: glass ? .18 : .28),
            blurRadius: glass ? 18 : 13,
            offset: const Offset(0, 5),
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
          backgroundColor: glass ? Colors.transparent : context.appPrimary,
          foregroundColor: glass ? context.appPrimary : Colors.white,
          shape: const CircleBorder(),
          child: glass
              ? AppGlassSurface(
                  borderRadius: 28,
                  shadow: false,
                  tint: context.appPrimarySoft.withValues(alpha: .72),
                  child: SizedBox(
                    width: 56,
                    height: 56,
                    child: Icon(
                      Icons.add,
                      size: 36,
                      weight: 400,
                      color: context.appPrimary,
                    ),
                  ),
                )
              : Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: context.appPrimary,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: .65),
                    ),
                  ),
                  child: const Icon(Icons.add, size: 38, weight: 400),
                ),
        ),
      ),
    );
  }
}

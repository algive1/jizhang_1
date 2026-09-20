import 'dart:ui';

import 'package:flutter/material.dart';

import '../../app/theme/app_theme_tokens.dart';

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
    final material = context.appMaterial;
    final highContrast = MediaQuery.of(context).highContrast;
    final blur = highContrast ? material.blurSigma * .55 : material.blurSigma;

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
              ? ClipOval(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(
                      sigmaX: blur,
                      sigmaY: blur,
                      tileMode: TileMode.decal,
                    ),
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            material.glassHighlight.withValues(
                              alpha: highContrast ? .98 : .82,
                            ),
                            material.glassTint.withValues(
                              alpha: highContrast ? .98 : .80,
                            ),
                          ],
                        ),
                        border: Border.all(
                          color: highContrast
                              ? context.appPrimary.withValues(alpha: .48)
                              : material.glassBorder,
                          width: highContrast ? 1.4 : 1,
                        ),
                      ),
                      child: Icon(
                        Icons.add,
                        size: 36,
                        weight: 400,
                        color: context.appPrimary,
                      ),
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

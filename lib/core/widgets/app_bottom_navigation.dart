import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/app_theme_tokens.dart';

class AppBottomNavigation extends StatelessWidget {
  const AppBottomNavigation({required this.location, super.key});

  static const double _horizontalInset = 10;
  static const double _bottomInset = 8;
  static const double _cornerRadius = 32;

  final String location;

  @override
  Widget build(BuildContext context) {
    final glass = context.appUsesLiquidGlass;
    final material = context.appMaterial;
    final highContrast = MediaQuery.of(context).highContrast;
    final blur = highContrast ? material.blurSigma * .55 : material.blurSigma;

    return SafeArea(
      top: false,
      child: SizedBox(
        height: 72,
        child: BottomAppBar(
          key: const ValueKey('app-bottom-navigation-bar'),
          padding: const EdgeInsets.fromLTRB(
            _horizontalInset + 8,
            4,
            _horizontalInset + 8,
            _bottomInset + 4,
          ),
          // BottomAppBar applies [padding] inside its Material. Keep a
          // translucent tint on the Material itself so the entire notched
          // pill stays glass-like, including the padded edge around the
          // BackdropFilter content.
          color: glass
              ? material.glassTint.withValues(alpha: highContrast ? .94 : .72)
              : context.appSurface,
          surfaceTintColor: Colors.transparent,
          elevation: glass ? 7 : 0,
          shadowColor: glass
              ? context.appPrimary.withValues(alpha: .16)
              : Colors.transparent,
          clipBehavior: Clip.antiAlias,
          shape: const _InsetRoundedCircularNotchedShape(
            horizontalInset: _horizontalInset,
            bottomInset: _bottomInset,
            cornerRadius: _cornerRadius,
          ),
          notchMargin: 8,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (glass)
                RepaintBoundary(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(
                      sigmaX: blur,
                      sigmaY: blur,
                      tileMode: TileMode.decal,
                    ),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            material.glassHighlight.withValues(
                              alpha: highContrast ? .96 : .70,
                            ),
                            material.glassTint.withValues(
                              alpha: highContrast ? .96 : .84,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              Row(
                children: [
                  Expanded(
                    child: _item(
                      context,
                      0,
                      Icons.home_outlined,
                      Icons.home,
                      '首页',
                      '/',
                    ),
                  ),
                  Expanded(
                    child: _item(
                      context,
                      1,
                      Icons.receipt_long_outlined,
                      Icons.receipt_long,
                      '流水',
                      '/transactions',
                    ),
                  ),
                  const SizedBox(width: 72),
                  Expanded(
                    child: _item(
                      context,
                      2,
                      Icons.auto_graph_outlined,
                      Icons.auto_graph,
                      '洞察',
                      '/insights',
                    ),
                  ),
                  Expanded(
                    child: _item(
                      context,
                      3,
                      Icons.person_outline,
                      Icons.person,
                      '我的',
                      '/profile',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  int get _selectedIndex {
    if (location.startsWith('/transactions') || location == '/analysis') {
      return 1;
    }
    if (location.startsWith('/insights')) {
      return 2;
    }
    if (location.startsWith('/profile')) {
      return 3;
    }
    return 0;
  }

  Widget _item(
    BuildContext context,
    int index,
    IconData icon,
    IconData activeIcon,
    String label,
    String route,
  ) {
    final selected = index == _selectedIndex;
    final color = selected ? context.appPrimary : context.appSecondaryText;
    return InkWell(
      onTap: () => context.go(route),
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(selected ? activeIcon : icon, color: color, size: 24),
            const SizedBox(height: 1),
            Text(
              label,
              textScaler: TextScaler.noScaling,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Keeps the [BottomAppBar] itself full-width so Flutter's FAB geometry and
/// notch geometry share the same coordinate system. Only the painted/clipped
/// navigation surface is inset, preserving the floating pill appearance.
///
/// This avoids compensating with an arbitrary FAB X offset: the FAB remains
/// truly centered in the Scaffold while the notch is cut around that same
/// center point on every screen width and safe-area configuration.
class _InsetRoundedCircularNotchedShape extends NotchedShape {
  const _InsetRoundedCircularNotchedShape({
    required this.horizontalInset,
    required this.bottomInset,
    required this.cornerRadius,
  });

  final double horizontalInset;
  final double bottomInset;
  final double cornerRadius;

  @override
  Path getOuterPath(Rect host, Rect? guest) {
    final visualHost = Rect.fromLTRB(
      host.left + horizontalInset,
      host.top,
      host.right - horizontalInset,
      host.bottom - bottomInset,
    );

    final notchedPath = const CircularNotchedRectangle().getOuterPath(
      visualHost,
      guest,
    );
    final roundedPath = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          visualHost,
          Radius.circular(cornerRadius),
        ),
      );

    return Path.combine(PathOperation.intersect, notchedPath, roundedPath);
  }
}

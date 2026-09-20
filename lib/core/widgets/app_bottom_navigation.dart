import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/app_theme_tokens.dart';
import 'app_glass_surface.dart';

class AppBottomNavigation extends StatelessWidget {
  const AppBottomNavigation({required this.location, super.key});

  static const double _horizontalInset = 10;
  static const double _bottomInset = 8;
  static const double _cornerRadius = 28;
  static const double _centerGap = 72;
  static const Duration _indicatorDuration = Duration(milliseconds: 280);

  final String location;

  @override
  Widget build(BuildContext context) {
    final selectedIndex = _selectedIndex;
    final glass = context.appUsesLiquidGlass;

    return SafeArea(
      top: false,
      child: SizedBox(
        key: const ValueKey('app-bottom-navigation-bar'),
        height: 78,
        width: double.infinity,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            _horizontalInset,
            0,
            _horizontalInset,
            _bottomInset,
          ),
          child: AppGlassSurface(
            borderRadius: _cornerRadius,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            tint: glass
                ? Color.alphaBlend(
                    context.appPrimary.withValues(alpha: .12),
                    context.appSurface.withValues(alpha: .80),
                  )
                : context.appSurface,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final tabWidth = ((constraints.maxWidth - _centerGap) / 4)
                    .clamp(1.0, double.infinity)
                    .toDouble();
                final bubbleWidth = (tabWidth - 6).clamp(42.0, 58.0).toDouble();
                final indicatorLeft = _slotStart(selectedIndex, tabWidth) +
                    (tabWidth - bubbleWidth) / 2;

                return Stack(
                  fit: StackFit.expand,
                  clipBehavior: Clip.none,
                  children: [
                    AnimatedPositioned(
                      key: const ValueKey('app-nav-glass-indicator'),
                      duration: MediaQuery.disableAnimationsOf(context)
                          ? Duration.zero
                          : _indicatorDuration,
                      curve: Curves.easeOutCubic,
                      left: indicatorLeft,
                      top: 2,
                      width: bubbleWidth,
                      height: 50,
                      child: IgnorePointer(
                        child: AppGlassSurface(
                          borderRadius: 23,
                          shadow: false,
                          tint: glass
                              ? context.appPrimary.withValues(alpha: .78)
                              : context.appPrimarySoft,
                          child: const SizedBox.expand(),
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: _NavItem(
                            key: const ValueKey('app-nav-home'),
                            selected: selectedIndex == 0,
                            icon: Icons.home_outlined,
                            activeIcon: Icons.home_rounded,
                            label: '首页',
                            route: '/',
                          ),
                        ),
                        Expanded(
                          child: _NavItem(
                            key: const ValueKey('app-nav-transactions'),
                            selected: selectedIndex == 1,
                            icon: Icons.receipt_long_outlined,
                            activeIcon: Icons.receipt_long_rounded,
                            label: '流水',
                            route: '/transactions',
                          ),
                        ),
                        const SizedBox(width: _centerGap),
                        Expanded(
                          child: _NavItem(
                            key: const ValueKey('app-nav-insights'),
                            selected: selectedIndex == 2,
                            icon: Icons.auto_graph_outlined,
                            activeIcon: Icons.auto_graph_rounded,
                            label: '洞察',
                            route: '/insights',
                          ),
                        ),
                        Expanded(
                          child: _NavItem(
                            key: const ValueKey('app-nav-profile'),
                            selected: selectedIndex == 3,
                            icon: Icons.person_outline_rounded,
                            activeIcon: Icons.person_rounded,
                            label: '我的',
                            route: '/profile',
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  double _slotStart(int index, double tabWidth) {
    if (index < 2) return tabWidth * index;
    return tabWidth * index + _centerGap;
  }

  int get _selectedIndex {
    if (location.startsWith('/transactions') || location == '/analysis') {
      return 1;
    }
    if (location.startsWith('/insights')) return 2;
    if (location.startsWith('/profile')) return 3;
    return 0;
  }
}

class _NavItem extends StatefulWidget {
  const _NavItem({
    required this.selected,
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.route,
    super.key,
  });

  final bool selected;
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final String route;

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  double _scale = 1;
  Duration _scaleDuration = Duration.zero;
  int _animationTicket = 0;

  void _press() {
    _animationTicket++;
    setState(() {
      _scaleDuration = const Duration(milliseconds: 70);
      _scale = .92;
    });
  }

  void _release() {
    final ticket = ++_animationTicket;
    setState(() {
      _scaleDuration = const Duration(milliseconds: 90);
      _scale = 1.04;
    });
    Future<void>.delayed(const Duration(milliseconds: 90), () {
      if (!mounted || ticket != _animationTicket) return;
      setState(() {
        _scaleDuration = const Duration(milliseconds: 80);
        _scale = 1;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final glass = context.appUsesLiquidGlass;
    final selectedColor = glass ? Colors.white : context.appPrimary;
    final inactiveColor = glass
        ? context.appSecondaryText.withValues(alpha: .74)
        : context.appSecondaryText;
    final color = widget.selected ? selectedColor : inactiveColor;
    final animationsDisabled = MediaQuery.disableAnimationsOf(context);

    return Semantics(
      selected: widget.selected,
      button: true,
      label: widget.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) {
          if (!animationsDisabled) _press();
        },
        onTapUp: (_) {
          if (!animationsDisabled) _release();
        },
        onTapCancel: () {
          if (!animationsDisabled) _release();
        },
        onTap: () {
          if (!widget.selected) context.go(widget.route);
        },
        child: AnimatedScale(
          scale: animationsDisabled ? 1 : _scale,
          duration: animationsDisabled ? Duration.zero : _scaleDuration,
          curve: Curves.easeOutCubic,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedSwitcher(
                duration: animationsDisabled
                    ? Duration.zero
                    : const Duration(milliseconds: 160),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeOutCubic,
                child: Icon(
                  widget.selected ? widget.activeIcon : widget.icon,
                  key: ValueKey(widget.selected),
                  color: color,
                  size: 23,
                ),
              ),
              const SizedBox(height: 1),
              AnimatedDefaultTextStyle(
                duration: animationsDisabled
                    ? Duration.zero
                    : const Duration(milliseconds: 160),
                curve: Curves.easeOutCubic,
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight:
                      widget.selected ? FontWeight.w600 : FontWeight.w400,
                ),
                child: Text(
                  widget.label,
                  textScaler: TextScaler.noScaling,
                  maxLines: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../../app/theme/app_theme_tokens.dart';

/// Lightweight placeholder for the botanical artwork used by the prototype.
///
/// This deliberately uses theme colors instead of bundling another fixed green
/// image, so the account-management pages continue to follow every app theme.
class AccountLeafPlaceholder extends StatelessWidget {
  const AccountLeafPlaceholder({
    super.key,
    this.size = 82,
    this.opacity = .18,
  });

  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: size,
    height: size,
    child: Stack(
      alignment: Alignment.center,
      children: [
        Positioned(
          left: size * .05,
          bottom: size * .05,
          child: Transform.rotate(
            angle: -.55,
            child: Icon(
              Icons.eco_rounded,
              size: size * .62,
              color: context.appPrimary.withValues(alpha: opacity),
            ),
          ),
        ),
        Positioned(
          right: 0,
          top: size * .04,
          child: Transform.rotate(
            angle: .46,
            child: Icon(
              Icons.eco_rounded,
              size: size * .58,
              color: context.appPrimary.withValues(alpha: opacity * .82),
            ),
          ),
        ),
        Positioned(
          right: size * .22,
          bottom: 0,
          child: Transform.rotate(
            angle: .10,
            child: Icon(
              Icons.eco_rounded,
              size: size * .48,
              color: context.appPrimary.withValues(alpha: opacity * .68),
            ),
          ),
        ),
      ],
    ),
  );
}

class AccountPrototypeStatusPill extends StatelessWidget {
  const AccountPrototypeStatusPill({
    required this.label,
    required this.color,
    super.key,
    this.icon,
  });

  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .13),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
        ],
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}

class AccountPrototypeFilterBar<T> extends StatelessWidget {
  const AccountPrototypeFilterBar({
    required this.items,
    required this.selected,
    required this.onSelected,
    super.key,
  });

  final List<(T, String)> items;
  final T selected;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      for (var index = 0; index < items.length; index++) ...[
        Expanded(
          child: InkWell(
            onTap: () => onSelected(items[index].$1),
            borderRadius: BorderRadius.circular(999),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: items[index].$1 == selected
                    ? context.appPrimary
                    : context.appSurfaceSoft,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                items[index].$2,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: items[index].$1 == selected
                      ? context.appColors.onPrimary
                      : context.appSecondaryText,
                  fontSize: 12,
                  fontWeight: items[index].$1 == selected
                      ? FontWeight.w700
                      : FontWeight.w500,
                ),
              ),
            ),
          ),
        ),
        if (index != items.length - 1) const SizedBox(width: 7),
      ],
    ],
  );
}

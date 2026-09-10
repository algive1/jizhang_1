import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/app_colors.dart';

class AppBottomNavigation extends StatelessWidget {
  const AppBottomNavigation({required this.location, super.key});

  final String location;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: SizedBox(
        height: 78,
        child: BottomAppBar(
          color: const Color(0xFFFFFEFB),
          elevation: 0,
          shape: const CircularNotchedRectangle(),
          notchMargin: 8,
          child: Row(
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
                  Icons.track_changes_outlined,
                  Icons.track_changes,
                  '目标',
                  '/goals',
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
        ),
      ),
    );
  }

  int get _selectedIndex {
    if (location.startsWith('/transactions') || location == '/analysis') {
      return 1;
    }
    if (location.startsWith('/goals')) {
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
    final color = selected ? AppColors.primary : AppColors.textSecondary;
    return InkWell(
      onTap: () => context.go(route),
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(selected ? activeIcon : icon, color: color, size: 22),
            const SizedBox(height: 1),
            Text(
              label,
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

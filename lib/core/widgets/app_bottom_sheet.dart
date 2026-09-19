import 'package:flutter/material.dart';

import '../../app/theme/app_theme_tokens.dart';

abstract final class AppBottomSheet {
  static Future<T?> show<T>({
    required BuildContext context,
    required WidgetBuilder builder,
  }) => showModalBottomSheet<T>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: context.appSurface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    clipBehavior: Clip.antiAlias,
    sheetAnimationStyle: const AnimationStyle(
      duration: Duration(milliseconds: 240),
      reverseDuration: Duration(milliseconds: 220),
    ),
    builder: (context) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight:
                (MediaQuery.sizeOf(context).height -
                    MediaQuery.viewInsetsOf(context).bottom) *
                .9,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: context.appDivider,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                builder(context),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class AppSheetOption extends StatelessWidget {
  const AppSheetOption({
    super.key,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.selected = false,
    this.icon,
    this.destructive = false,
    this.chevron = false,
  });
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final bool selected, destructive, chevron;
  final IconData? icon;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
    child: Material(
      color: selected ? context.appPrimarySoft : context.appSurfaceSoft,
      borderRadius: BorderRadius.circular(16),
      child: ListTile(
        minVerticalPadding: 12,
        minTileHeight: 56,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        leading: icon == null
            ? null
            : Icon(
                icon,
                color: destructive
                    ? Colors.red.shade700
                    : context.appPrimary,
              ),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 16,
            color: destructive ? Colors.red.shade700 : context.appPrimaryText,
          ),
        ),
        subtitle: subtitle == null
            ? null
            : Text(subtitle!, style: TextStyle(fontSize: 13)),
        trailing: selected
            ? Icon(Icons.check, color: context.appPrimary)
            : chevron
            ? const Icon(Icons.chevron_right)
            : null,
        onTap: onTap,
      ),
    ),
  );
}

abstract final class AppConfirmDialog {
  static Future<bool> show(
    BuildContext context, {
    required String title,
    required String message,
  }) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red.shade700,
              ),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('确认'),
            ),
          ],
        ),
      ) ??
      false;
}

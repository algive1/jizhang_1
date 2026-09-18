import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_bottom_sheet.dart';

abstract final class AppActionSheet {
  static Future<T?> show<T>(
    BuildContext context, {
    String? title,
    required List<PopupMenuEntry<T>> items,
  }) => AppBottomSheet.show<T>(
    context: context,
    builder: (sheet) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (title != null)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
          ),
        for (final entry in items)
          if (entry is PopupMenuItem<T>)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
              child: Material(
                borderRadius: BorderRadius.circular(16),
                color: Theme.of(context).inputDecorationTheme.fillColor,
                child: ListTile(
                  minTileHeight: 56,
                  leading: Icon(
                    _icon(entry.value),
                    color: _destructive(entry.value)
                        ? Colors.red.shade700
                        : null,
                  ),
                  title: DefaultTextStyle.merge(
                    style: TextStyle(
                      fontSize: 16,
                      color: _destructive(entry.value)
                          ? Colors.red.shade700
                          : null,
                    ),
                    child: entry.child ?? const SizedBox(),
                  ),
                  onTap: entry.enabled
                      ? () => Navigator.pop(sheet, entry.value)
                      : null,
                ),
              ),
            )
          else
            const Divider(),
        AppSheetOption(title: '取消', onTap: () => Navigator.pop(sheet)),
        const SizedBox(height: 12),
      ],
    ),
  );
  static bool _destructive(Object? value) =>
      ['delete', 'remove', 'archive'].contains(value);
  static IconData _icon(Object? value) => switch (value) {
    'edit' => Icons.edit_outlined,
    'delete' || 'remove' || 'archive' => Icons.delete_outline,
    'copy' => Icons.copy_outlined,
    'pause' => Icons.pause_circle_outline,
    _ => Icons.chevron_right,
  };
}

/// Drop-in migration for old popup buttons; no desktop popup is created.
class AppActionMenuButton<T> extends StatelessWidget {
  const AppActionMenuButton({
    super.key,
    required this.itemBuilder,
    this.onSelected,
    this.child,
    this.icon,
    this.padding = const EdgeInsets.all(8),
    this.tooltip,
    this.enabled = true,
  });
  final PopupMenuItemBuilder<T> itemBuilder;
  final ValueChanged<T>? onSelected;
  final Widget? child, icon;
  final EdgeInsetsGeometry padding;
  final String? tooltip;
  final bool enabled;
  Future<void> _open(BuildContext context) async {
    final value = await AppActionSheet.show(
      context,
      items: itemBuilder(context),
    );
    if (value != null && context.mounted) onSelected?.call(value);
  }

  @override
  Widget build(BuildContext context) => child != null
      ? Semantics(
          button: true,
          child: InkWell(
            onTap: enabled ? () => _open(context) : null,
            child: child,
          ),
        )
      : IconButton(
          tooltip: tooltip ?? '更多操作',
          padding: padding,
          onPressed: enabled ? () => _open(context) : null,
          icon: icon ?? const Icon(Icons.more_vert),
        );
}

/// Attach only to a business card, never to a form or an editable region.
class AppContextMenu extends StatelessWidget {
  const AppContextMenu({super.key, required this.child, required this.onOpen});
  final Widget child;
  final VoidCallback onOpen;
  @override
  Widget build(BuildContext context) => GestureDetector(
    onLongPress: () {
      HapticFeedback.selectionClick();
      onOpen();
    },
    child: child,
  );
}

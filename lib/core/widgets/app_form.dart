import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import 'app_bottom_sheet.dart';

/// Controlled selection; every choice uses the same accessible bottom sheet.
class AppSelect<T> extends StatelessWidget {
  const AppSelect({
    super.key,
    this.initialValue,
    required this.items,
    required this.onChanged,
    this.decoration = const InputDecoration(),
    this.isExpanded = true,
    this.validator,
    this.hint,
  });
  final T? initialValue;
  final List<DropdownMenuItem<T>>? items;
  final ValueChanged<T?>? onChanged;
  final InputDecoration decoration;
  final bool isExpanded;
  final FormFieldValidator<T>? validator;
  final Widget? hint;
  @override
  Widget build(BuildContext context) {
    final options = items ?? [];
    final selected = options
        .where((item) => item.value == initialValue)
        .firstOrNull;
    return FormField<T>(
      initialValue: initialValue,
      validator: validator,
      builder: (field) => Semantics(
        button: true,
        enabled: onChanged != null,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onChanged == null
              ? null
              : () async {
                  await AppBottomSheet.show<void>(
                    context: context,
                    builder: (sheet) => Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text(
                            decoration.labelText ?? '请选择',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        for (final item in options)
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 3,
                            ),
                            child: Material(
                              color: item.value == initialValue
                                  ? AppColors.primarySoft
                                  : AppColors.surfaceSoft,
                              borderRadius: BorderRadius.circular(16),
                              child: ListTile(
                                minTileHeight: 56,
                                title: item.child,
                                trailing: item.value == initialValue
                                    ? const Icon(
                                        Icons.check,
                                        color: AppColors.primaryDark,
                                      )
                                    : null,
                                onTap: !item.enabled
                                    ? null
                                    : () {
                                        field.didChange(item.value);
                                        onChanged!(item.value);
                                        Navigator.pop(sheet);
                                      },
                              ),
                            ),
                          ),
                        const SizedBox(height: 12),
                      ],
                    ),
                  );
                },
          child: InputDecorator(
            decoration: decoration.copyWith(
              errorText: field.errorText,
              enabled: onChanged != null,
            ),
            child: Row(
              children: [
                Expanded(
                  child: DefaultTextStyle.merge(
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    child: selected?.child ?? hint ?? const Text('请选择'),
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.expand_more, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

InputDecoration appFieldDecoration(
  String label, {
  String? hintText,
  Widget? prefixIcon,
  Widget? suffixIcon,
  String? prefixText,
  String? helperText,
}) => InputDecoration(
  labelText: label,
  hintText: hintText,
  prefixIcon: prefixIcon,
  suffixIcon: suffixIcon,
  prefixText: prefixText,
  helperText: helperText,
  floatingLabelBehavior: FloatingLabelBehavior.never,
);

class AppInput extends TextFormField {
  AppInput({
    super.key,
    super.controller,
    super.initialValue,
    super.onChanged,
    super.validator,
    super.keyboardType,
    super.enabled,
    super.autofocus,
    super.maxLines = 1,
    super.minLines,
    super.decoration = const InputDecoration(),
  });
}

class AppTextarea extends AppInput {
  AppTextarea({
    super.key,
    super.controller,
    super.initialValue,
    super.onChanged,
    super.validator,
    super.decoration,
  }) : super(minLines: 3, maxLines: 6);
}

class AppFormRow extends StatelessWidget {
  const AppFormRow({super.key, required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) =>
        constraints.maxWidth < 360 ||
            MediaQuery.textScalerOf(context).scale(16) > 22
        ? Column(
            children: [
              for (final child in children)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: child,
                ),
            ],
          )
        : Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) const SizedBox(width: 12),
                Expanded(child: children[i]),
              ],
            ],
          ),
  );
}

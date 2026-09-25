import 'package:flutter/material.dart';

import '../../../../../app/theme/app_theme_tokens.dart';

class NumberKeyboard extends StatelessWidget {
  const NumberKeyboard({
    super.key,
    required this.canRepeat,
    required this.isSaving,
    required this.onKey,
    required this.onBackspace,
    required this.onDone,
    required this.onRepeat,
  });

  final bool canRepeat;
  final bool isSaving;
  final ValueChanged<String> onKey;
  final VoidCallback onBackspace;
  final VoidCallback onDone;
  final VoidCallback onRepeat;

  @override
  Widget build(BuildContext context) {
    final height = (MediaQuery.sizeOf(context).height * .28).clamp(
      208.0,
      264.0,
    );
    return Container(
      height: height,
      padding: const EdgeInsets.fromLTRB(7, 4, 7, 8),
      child: Column(
        children: [
          Expanded(
            child: Row(
              children: [
                _digit('1'),
                _digit('2'),
                _digit('3'),
                Expanded(
                  child: _KeypadKey(
                    key: const ValueKey('amount-key-backspace'),
                    icon: Icons.backspace_outlined,
                    semanticLabel: '删除金额字符',
                    muted: true,
                    onTap: onBackspace,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Row(
              children: [
                _digit('4'),
                _digit('5'),
                _digit('6'),
                _operatorPair(context, '+', '-'),
              ],
            ),
          ),
          Expanded(
            child: Row(
              children: [
                _digit('7'),
                _digit('8'),
                _digit('9'),
                _operatorPair(context, '×', '÷'),
              ],
            ),
          ),
          Expanded(
            child: Row(
              children: [
                if (canRepeat)
                  Expanded(
                    child: _KeypadKey(
                      key: const ValueKey('quick-repeat'),
                      label: '再记',
                      muted: true,
                      fontSize: 17,
                      onTap: isSaving ? null : onRepeat,
                    ),
                  ),
                Expanded(
                  child: _KeypadKey(
                    key: const ValueKey('amount-key-0'),
                    label: '0',
                    onTap: () => onKey('0'),
                  ),
                ),
                Expanded(
                  child: _KeypadKey(
                    key: const ValueKey('amount-key-.'),
                    label: '.',
                    onTap: () => onKey('.'),
                  ),
                ),
                Expanded(
                  flex: canRepeat ? 1 : 2,
                  child: _KeypadKey(
                    key: const ValueKey('quick-done'),
                    label: '完成',
                    fontSize: 17,
                    primary: true,
                    busy: isSaving,
                    onTap: isSaving ? null : onDone,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _digit(String value) => Expanded(
    child: _KeypadKey(
      key: ValueKey('amount-key-$value'),
      label: value,
      onTap: () => onKey(value),
    ),
  );

  Widget _operatorPair(
    BuildContext context,
    String multiplication,
    String division,
  ) => Expanded(
    child: Padding(
      padding: const EdgeInsets.all(3),
      child: Material(
        color: context.appSurfaceSoft,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: Row(
          children: [
            for (final operator in [multiplication, division]) ...[
              if (operator == division)
                const SizedBox(height: 22, child: VerticalDivider(width: 1)),
              Expanded(
                child: InkWell(
                  key: ValueKey('amount-key-$operator'),
                  onTap: () => onKey(switch (operator) {
                    '×' => '*',
                    '÷' => '/',
                    _ => operator,
                  }),
                  child: Center(
                    child: Text(operator, style: const TextStyle(fontSize: 24)),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

class _KeypadKey extends StatelessWidget {
  const _KeypadKey({
    super.key,
    this.label,
    this.icon,
    this.semanticLabel,
    this.fontSize = 24,
    this.primary = false,
    this.muted = false,
    this.busy = false,
    this.onTap,
  });

  final String? label;
  final IconData? icon;
  final String? semanticLabel;
  final double fontSize;
  final bool primary;
  final bool muted;
  final bool busy;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(3),
      child: Semantics(
        label: semanticLabel,
        button: true,
        child: Material(
          color: primary
              ? context.appPrimary
              : muted
              ? context.appSurfaceSoft
              : context.appSurfaceRaised,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(14),
            child: Ink(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: busy
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Theme.of(context).colorScheme.onPrimary,
                        ),
                      )
                    : icon != null
                    ? Icon(icon, color: context.appPrimaryText, size: 20)
                    : Text(
                        label!,
                        style: TextStyle(
                          fontSize: fontSize,
                          fontWeight: FontWeight.w500,
                          color: primary
                              ? Theme.of(context).colorScheme.onPrimary
                              : context.appPrimaryText,
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

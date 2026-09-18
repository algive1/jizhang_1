/// Amount entry value object for the quick-add keypad.
///
/// [value] is exactly what the user typed. It is either a plain decimal number
/// (`36`, `1.5`) or an arithmetic expression built from the keypad operators
/// (`100*2`, `12.5+7-1.25`). Operators are stored as ASCII `+ - * /`; the
/// keypad renders them as `+ - × ÷`.
class AmountInput {
  const AmountInput([this.value = '']);

  final String value;

  /// ASCII operator characters accepted in [value].
  static const operators = {'+', '-', '*', '/'};

  /// Digit cap for a single number segment, matching the previous behaviour.
  static const _maxDigitsPerNumber = 10;

  /// Decimal places allowed in a single number segment.
  static const _maxDecimals = 2;

  /// Whether [value] contains at least one arithmetic operator.
  bool get hasOperator => value.split('').any(operators.contains);

  /// Whether the expression is finished, i.e. it does not end with an
  /// operator. A trailing `.` stays acceptable because `double.tryParse`
  /// accepts `5.` and the previous implementation also saved `5.` as `5.00`.
  bool get isComplete =>
      value.isNotEmpty && !operators.contains(value[value.length - 1]);

  /// The evaluated amount rounded to cents, or null when [value] cannot be
  /// evaluated. Incomplete expressions are still evaluated so the keypad can
  /// show the running result while the user types.
  double? get amount {
    final result = _evaluate(value);
    if (result == null || !result.isFinite || result.abs() > 1e12) return null;
    return (result * 100).roundToDouble() / 100;
  }

  /// Only a complete expression with a positive result may be saved.
  bool get isValid => isComplete && (amount ?? 0) > 0;

  /// The two-decimal amount text. A plain number keeps the historical
  /// zero-padding (`36` -> `36.00`); an expression shows its evaluated result.
  String get displayValue {
    if (!hasOperator) {
      if (value.isEmpty) return '0.00';
      if (!value.contains('.')) return '$value.00';
      final decimalPlaces = value.length - value.indexOf('.') - 1;
      if (decimalPlaces == 0) return '${value}00';
      if (decimalPlaces == 1) return '${value}0';
      return value;
    }
    final result = amount;
    if (result == null) return '0.00';
    return result.toStringAsFixed(2);
  }

  /// The text shown as the typed expression (`100*2`) or the padded number.
  String get label => hasOperator ? value : (value.isEmpty ? '' : displayValue);

  AmountInput enter(String key) {
    key = switch (key) {
      '×' => '*',
      '÷' => '/',
      _ => key,
    };
    if (operators.contains(key)) return _enterOperator(key);
    if (key == '.') return _enterDot();
    if (!RegExp(r'^\d$').hasMatch(key)) return this;
    return _enterDigit(key);
  }

  AmountInput backspace() {
    if (value.isEmpty) return this;
    return AmountInput(value.substring(0, value.length - 1));
  }

  AmountInput _enterOperator(String key) {
    if (value.isEmpty) return this;
    final last = value[value.length - 1];
    if (operators.contains(last)) {
      // Replace the pending operator instead of stacking two of them.
      return AmountInput('${value.substring(0, value.length - 1)}$key');
    }
    if (last == '.') return this;
    return AmountInput('$value$key');
  }

  AmountInput _enterDot() {
    final segment = _currentSegment;
    if (segment.contains('.')) return this;
    return AmountInput(segment.isEmpty ? '${value}0.' : '$value.');
  }

  AmountInput _enterDigit(String key) {
    final segment = _currentSegment;
    final dot = segment.indexOf('.');
    if (dot >= 0 && segment.length - dot > _maxDecimals) return this;
    if (segment == '0') {
      return AmountInput(
        key == '0' ? value : '${value.substring(0, value.length - 1)}$key',
      );
    }
    if (segment.replaceAll('.', '').length >= _maxDigitsPerNumber) return this;
    return AmountInput('$value$key');
  }

  /// The number currently being typed, i.e. everything after the last
  /// operator.
  String get _currentSegment {
    final index = value.lastIndexOf(RegExp(r'[+\-*/]'));
    return index < 0 ? value : value.substring(index + 1);
  }

  /// Evaluates `+ - * /` with the usual precedence. Returns null when the
  /// expression is malformed or divides by zero.
  static double? _evaluate(String expression) {
    if (expression.isEmpty) return null;
    final tokens = <Object>[];
    final buffer = StringBuffer();
    for (var index = 0; index < expression.length; index++) {
      final character = expression[index];
      if (operators.contains(character)) {
        final number = double.tryParse(buffer.toString());
        if (number == null) return null;
        tokens
          ..add(number)
          ..add(character);
        buffer.clear();
      } else {
        buffer.write(character);
      }
    }
    if (buffer.isNotEmpty) {
      final number = double.tryParse(buffer.toString());
      if (number == null) return null;
      tokens.add(number);
    }
    if (tokens.isEmpty || tokens.first is String) return null;
    // A trailing operator is the running preview of the finished part.
    if (tokens.last is String) tokens.removeLast();
    if (tokens.isEmpty) return null;

    final products = <Object>[];
    var index = 0;
    while (index < tokens.length) {
      final token = tokens[index];
      if (token is String && (token == '*' || token == '/')) {
        final left = products.removeLast() as double;
        final right = tokens[index + 1] as double;
        if (token == '/' && right == 0) return null;
        products.add(token == '*' ? left * right : left / right);
        index += 2;
      } else {
        products.add(token);
        index += 1;
      }
    }

    var result = products.first as double;
    for (var position = 1; position + 1 < products.length; position += 2) {
      final operator = products[position] as String;
      final right = products[position + 1] as double;
      result = operator == '+' ? result + right : result - right;
    }
    return result;
  }
}

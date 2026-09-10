class AmountInput {
  const AmountInput([this.value = '']);

  final String value;

  double? get amount {
    if (value.isEmpty || value.endsWith('.')) return double.tryParse(value);
    return double.tryParse(value);
  }

  bool get isValid => (amount ?? 0) > 0;

  String get displayValue {
    if (value.isEmpty) return '0.00';
    if (!value.contains('.')) return '$value.00';
    final decimalPlaces = value.length - value.indexOf('.') - 1;
    if (decimalPlaces == 0) return '${value}00';
    if (decimalPlaces == 1) return '${value}0';
    return value;
  }

  AmountInput enter(String key) {
    if (key == '.') {
      if (value.contains('.')) return this;
      return AmountInput(value.isEmpty ? '0.' : '$value.');
    }
    if (!RegExp(r'^\d$').hasMatch(key)) return this;
    final dot = value.indexOf('.');
    if (dot >= 0 && value.length - dot > 2) return this;
    if (value == '0') return AmountInput(key == '0' ? value : key);
    if (value.replaceAll('.', '').length >= 10) return this;
    return AmountInput('$value$key');
  }

  AmountInput backspace() {
    if (value.isEmpty) return this;
    return AmountInput(value.substring(0, value.length - 1));
  }
}

/// Input rules for investment prices and unit counts.
///
/// Deliberately separate from `MoneyFormatter.parseInput`: that parser caps a
/// value at two decimals because CNY cash is two decimals, and it is shared
/// with the bookkeeping amount flow. Investment figures are not cash — a fund
/// NAV is quoted to three or four decimals and a crypto position is routinely
/// fractional — so reusing the cash rule would reject a price the app itself
/// pre-filled from the market data source.
abstract final class InvestmentInput {
  /// A price quoted by a market source: up to four decimals, which covers
  /// equity, bond and fund NAV quoting.
  static const priceDecimals = 4;

  /// A held unit count: funds and crypto are fractional, so allow more.
  static const quantityDecimals = 8;

  static final _pricePattern = RegExp(r'^\d+(\.\d{1,4})?$');
  static final _quantityPattern = RegExp(r'^\d+(\.\d{1,8})?$');

  /// Same shape and bounds as [MoneyFormatter.parseInput] but with the wider
  /// decimal allowance. Returns null when the text is not acceptable.
  static double? parsePrice(String value) =>
      _parse(value, _pricePattern, priceDecimals);

  static double? parseQuantity(String value) =>
      _parse(value, _quantityPattern, quantityDecimals);

  static double? _parse(String value, RegExp pattern, int decimals) {
    final text = value.trim();
    if (!pattern.hasMatch(text)) return null;
    final amount = double.tryParse(text);
    if (amount == null || !amount.isFinite) return null;
    if (amount > 1000000000000) return null;
    // Guard the regex against a platform-specific decimal separator surprise.
    final fraction = text.contains('.') ? text.split('.').last.length : 0;
    if (fraction > decimals) return null;
    return amount;
  }

  /// Renders a price for an editable text field without inventing or dropping
  /// significant digits: `100` stays `100`, `36.7859` stays `36.7859`.
  static String formatPrice(double value) {
    if (value == value.roundToDouble() && value.abs() < 1e15) {
      return value.round().toString();
    }
    return value.toString();
  }

  static String formatQuantity(double value) => formatPrice(value);

  /// A grouped, human-readable price (`1,234.5678`, `100`, `2.35`).
  ///
  /// Used wherever a *price* is displayed. Money amounts keep using
  /// `MoneyFormatter.decimal` at two decimals — a fund NAV needs its extra
  /// digits, a market value does not.
  static String formatPriceLabel(double value) {
    final negative = value < 0;
    final fixed = value.abs().toStringAsFixed(priceDecimals);
    var integer = fixed.split('.').first;
    var fraction = fixed.split('.').last;
    // Keep two decimals so a normal price still reads as `¥36.78`, and drop
    // trailing zeros beyond that so a whole price reads as `¥100`.
    while (fraction.length > 2 && fraction.endsWith('0')) {
      fraction = fraction.substring(0, fraction.length - 1);
    }
    final grouped = integer.replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => ',',
    );
    integer = grouped;
    return '${negative ? '-' : ''}$integer.$fraction';
  }
}

import 'package:intl/intl.dart';

/// Formats an amount as Indian Rupees, e.g. `₹1,234` or `₹1,234.50`.
String formatCurrency(num amount) {
  final isWhole = amount == amount.roundToDouble();
  final format = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: isWhole ? 0 : 2,
  );
  return format.format(amount);
}

/// Converts a rupee amount to integer paise. Amounts that need splitting,
/// summing, or exact-equality comparison should convert to paise first —
/// rupee doubles (e.g. three shares of 33.33...) drift under float math in
/// ways that break both equal-split distribution and greedy settle-up
/// matching.
int amountToPaise(num amount) => (amount * 100).round();

/// The inverse of [amountToPaise], formatted for display in a text field
/// (no ₹ symbol or thousands separator) — whole rupees show with no decimal.
String paiseToText(int paise) {
  if (paise % 100 == 0) return (paise ~/ 100).toString();
  return (paise / 100).toStringAsFixed(2);
}

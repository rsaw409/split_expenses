import 'package:intl/intl.dart';

// Every amount in the app is an int of paise: what the API sends and accepts,
// what the models and cache hold, and what all arithmetic runs on. Rupees only
// exist at the edges — parsed from what the user types ([rupeesToPaise]) and
// rendered for display ([formatPaise], [paiseToText]).

/// Formats paise as Indian Rupees, e.g. `₹1,234` or `₹1,234.50`.
String formatPaise(int paise) {
  final format = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: paise % 100 == 0 ? 0 : 2,
  );
  return format.format(paise / 100);
}

/// Converts a rupee amount the user typed into paise.
int rupeesToPaise(num rupees) => (rupees * 100).round();

/// Paise formatted for a text field (no ₹ symbol or thousands separator):
/// whole rupees show with no decimal.
String paiseToText(int paise) {
  if (paise % 100 == 0) return (paise ~/ 100).toString();
  return (paise / 100).toStringAsFixed(2);
}

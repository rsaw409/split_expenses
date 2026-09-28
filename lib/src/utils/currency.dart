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

/// A currency a group can use: its ISO code, how to show it, and how many
/// minor units make up one major unit (paise per rupee is 10², so 2).
class Currency {
  const Currency({
    required this.code,
    required this.name,
    required this.symbol,
    required this.decimals,
  });

  final String code;
  final String name;
  final String symbol;
  final int decimals;

  String get label => '$name ($symbol)';
}

/// The currencies groups can be created in or switched to. Only rupees for
/// now; the backend refuses any other code.
///
/// Every amount is still formatted as rupees ([formatPaise]): a group's
/// currency is stored and shown, but does not yet change how amounts are
/// entered or displayed. Adding a currency means routing those through its
/// [Currency.symbol] and [Currency.decimals].
const supportedCurrencies = [
  Currency(code: 'INR', name: 'Indian Rupee', symbol: '₹', decimals: 2),
];

/// The currency for [code], falling back to the default for an unknown or
/// missing code (a group saved before currencies existed).
Currency currencyFor(String? code) => supportedCurrencies.firstWhere(
      (c) => c.code == code,
      orElse: () => supportedCurrencies.first,
    );

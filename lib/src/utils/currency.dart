import 'package:intl/intl.dart';

// Every amount in the app is an int count of the group currency's smallest
// unit (its "minor unit": paise, cents, yen, fils): what the API sends and
// accepts, what the models and cache hold, and what all arithmetic runs on.
// Only the edges know about decimals — parsing what the user types
// ([Currency.parse]) and rendering for display ([Currency.format],
// [Currency.toText]) — so splitting, balances and settle-up are exact integer
// maths whatever the currency.
//
// The unit comes from the group's currency, so a group's currency must not
// change once it has transactions: 10000 is ₹100.00 in INR but ¥10,000 in
// JPY.

/// A currency a group can use.
class Currency {
  const Currency({
    required this.code,
    required this.name,
    required this.symbol,
    required this.decimals,
    this.locale = 'en_US',
  });

  /// ISO 4217 code, as the API stores it.
  final String code;
  final String name;
  final String symbol;

  /// Digits after the decimal point: minor units per major unit is
  /// 10^[decimals] (100 paise per rupee, 1 yen per yen, 1000 fils per dinar).
  final int decimals;

  /// Digit grouping for [format]: `en_IN` groups ₹1,00,000 the Indian way.
  final String locale;

  String get label => '$name (${symbol.trim()})';

  /// The currency as the API takes it when creating or updating a group.
  /// The backend stores `currency_decimals` without checking it and formats
  /// notification amounts with it, so it must always come from here, never
  /// from anything a user typed.
  Map<String, Object> toApiFields() =>
      {'currency': code, 'currency_decimals': decimals};

  /// Minor units per major unit.
  int get _scale {
    var scale = 1;
    for (var i = 0; i < decimals; i++) {
      scale *= 10;
    }
    return scale;
  }

  /// For display, e.g. `₹1,234`, `₹1,234.50`, `¥1,234`, `KWD 1.250`. Whole
  /// amounts drop the decimals.
  String format(int minor) {
    final whole = minor % _scale == 0;
    return NumberFormat.currency(
      locale: locale,
      symbol: symbol,
      decimalDigits: whole ? 0 : decimals,
    ).format(minor / _scale);
  }

  /// For a text field: no symbol or grouping, whole amounts without
  /// decimals (`120.50`, `100`). Built from integers, so never off by a
  /// rounding error.
  String toText(int minor) {
    final sign = minor < 0 ? '-' : '';
    final abs = minor.abs();
    final major = abs ~/ _scale;
    final fraction = abs % _scale;
    if (fraction == 0) return '$sign$major';
    return '$sign$major.${fraction.toString().padLeft(decimals, '0')}';
  }

  /// What the user typed, in minor units, or null if it is not a valid
  /// amount for this currency (too many decimals, or any for a currency
  /// without them). Parsed as text rather than through a double, so
  /// `166.67` is exactly 16667.
  int? parse(String text) {
    final match = _amountPattern.firstMatch(text.trim());
    if (match == null) return null;
    final major = int.parse(match.group(1)!);
    // A currency without decimals has no fraction group to read.
    final typed = match.groupCount > 1 ? match.group(2) : null;
    final fraction = (typed ?? '').padRight(decimals, '0');
    return major * _scale + (fraction.isEmpty ? 0 : int.parse(fraction));
  }

  RegExp get _amountPattern => decimals == 0
      ? RegExp(r'^(\d+)$')
      : RegExp('^(\\d+)(?:\\.(\\d{0,$decimals}))?\$');

  /// For an input formatter: accepts a partly typed amount, e.g. `12.` for
  /// a currency with decimals, and no decimal point for one without.
  RegExp get inputPattern => decimals == 0
      ? RegExp(r'^\d+')
      : RegExp('^\\d+\\.?\\d{0,$decimals}');

  @override
  String toString() => code;
}

/// The currencies a group can be created in. Symbols and decimals match
/// what the backend's `Intl.NumberFormat('en', {style: 'currency'})` uses
/// for notifications, so both show the same amount the same way; recheck
/// that when adding a currency (for IDR and HUF, Intl says 0 decimals where
/// ISO 4217 says 2).
///
/// Include at least one with no
/// minor unit (JPY) and one with three (KWD), so code never quietly assumes
/// two decimals again.
const supportedCurrencies = [
  Currency(
    code: 'INR',
    name: 'Indian Rupee',
    symbol: '₹',
    decimals: 2,
    locale: 'en_IN',
  ),
  Currency(code: 'USD', name: 'US Dollar', symbol: r'$', decimals: 2),
  Currency(code: 'EUR', name: 'Euro', symbol: '€', decimals: 2),
  Currency(code: 'GBP', name: 'British Pound', symbol: '£', decimals: 2),
  Currency(code: 'AUD', name: 'Australian Dollar', symbol: r'A$', decimals: 2),
  Currency(code: 'CAD', name: 'Canadian Dollar', symbol: r'CA$', decimals: 2),
  Currency(code: 'SGD', name: 'Singapore Dollar', symbol: 'SGD ', decimals: 2),
  Currency(code: 'AED', name: 'UAE Dirham', symbol: 'AED ', decimals: 2),
  Currency(code: 'JPY', name: 'Japanese Yen', symbol: '¥', decimals: 0),
  Currency(code: 'KWD', name: 'Kuwaiti Dinar', symbol: 'KWD ', decimals: 3),
];

/// The currency for [code], falling back to INR for an unknown or missing
/// code (a group saved before currencies existed).
Currency currencyFor(String? code) => supportedCurrencies.firstWhere(
      (c) => c.code == code,
      orElse: () => supportedCurrencies.first,
    );

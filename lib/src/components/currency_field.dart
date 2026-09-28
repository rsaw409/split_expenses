import 'package:flutter/material.dart';

import '../utils/currency.dart';

/// The currency picker for creating or editing a group.
class CurrencyField extends StatelessWidget {
  const CurrencyField({
    super.key,
    required this.value,
    required this.onChanged,
    this.enabled = true,
    this.helperText,
  });

  /// The selected currency's code.
  final String value;
  final ValueChanged<String> onChanged;
  final bool enabled;

  /// Shown under the field, e.g. why it is locked. Defaults to a note that
  /// more currencies are coming while there is only one.
  final String? helperText;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: currencyFor(value).code,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: 'Currency',
        prefixIcon: const Icon(Icons.payments_outlined),
        helperMaxLines: 2,
        helperText: helperText ??
            (supportedCurrencies.length < 2
                ? 'More currencies coming soon.'
                : null),
      ),
      items: [
        for (final c in supportedCurrencies)
          DropdownMenuItem(
            value: c.code,
            child: Text(c.label, overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: enabled ? (code) => onChanged(code!) : null,
    );
  }
}

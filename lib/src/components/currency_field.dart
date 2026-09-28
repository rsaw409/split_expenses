import 'package:flutter/material.dart';

import '../utils/currency.dart';

/// The currency picker for creating or editing a group.
class CurrencyField extends StatelessWidget {
  const CurrencyField({
    super.key,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  /// The selected currency's code.
  final String value;
  final ValueChanged<String> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: currencyFor(value).code,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: 'Currency',
        prefixIcon: const Icon(Icons.payments_outlined),
        helperText: supportedCurrencies.length < 2
            ? 'More currencies coming soon.'
            : null,
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

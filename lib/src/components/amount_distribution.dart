import 'package:chips_choice/chips_choice.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:split_expense/src/components/customchip.dart';

import '../models/user.dart';
import '../theme/app_theme.dart';
import '../utils/currency.dart';

void showAmountDistributionModal(
    BuildContext context,
    int totalPaise,
    List<User> userOptions,
    List<Map<String, dynamic>> selectedUsers,
    Function onSubmit) {
  List<Map<String, dynamic>> allUsers =
      userOptions.map((e) => e.toMap()).toList();

  showModalBottomSheet(
    isDismissible: true,
    context: context,
    isScrollControlled: true,
    builder: (BuildContext context) {
      return AmountDistributionModal(
        totalPaise: totalPaise,
        users: allUsers,
        selectedUsers: selectedUsers,
        onSubmitSelectedUser: onSubmit,
      );
    },
  );
}

class AmountDistributionModal extends StatefulWidget {
  /// The expense total, in paise. Shares are read and handed back in paise.
  final int totalPaise;
  final List<Map<String, dynamic>> users;
  final List<Map<String, dynamic>> selectedUsers;
  final Function onSubmitSelectedUser;

  const AmountDistributionModal({
    super.key,
    required this.totalPaise,
    required this.users,
    required this.selectedUsers,
    required this.onSubmitSelectedUser,
  });

  @override
  State<AmountDistributionModal> createState() =>
      _AmountDistributionModalState();
}

/// Splits [totalCents] into [count] shares that sum to exactly [totalCents].
/// Cents that don't divide evenly are handed one-by-one to the first few
/// shares, so at most a few participants carry an extra paisa/rupee instead
/// of the split silently failing to add up.
List<int> _splitCentsEqually(int totalCents, int count) {
  if (count <= 0) return const [];
  if (totalCents <= 0) return List.filled(count, 0);
  final base = totalCents ~/ count;
  final remainder = totalCents % count;
  return List.generate(count, (i) => base + (i < remainder ? 1 : 0));
}

class _AmountDistributionModalState extends State<AmountDistributionModal> {
  final _formKey = GlobalKey<FormState>();
  String? _errorMessage;

  // Selection is tracked by user id, never by map identity. The chips' options
  // are rebuilt from `User.toMap()` on every open, so a map handed back from a
  // previous open is a different object (Dart maps compare by identity) and
  // would neither show as selected nor be recognised when tapped again, which
  // appended the same person a second time.
  List<int> _selectedIds = [];
  final Map<int, TextEditingController> _controllers = {};

  Map<String, dynamic>? _userById(int id) {
    for (final user in widget.users) {
      if (user['id'] == id) return user;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    for (final user in widget.selectedUsers) {
      final id = user['id'] as int;
      // Skip members who are no longer offered, and any duplicate a previous
      // build of this sheet may already have stored.
      if (_userById(id) == null || _controllers.containsKey(id)) continue;
      _selectedIds.add(id);
      _controllers[id] = TextEditingController(
          text: paiseToText(user['amount'] as int));
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void onSelectionChanged(List<int> ids) {
    final removed = [
      for (final id in _controllers.keys)
        if (!ids.contains(id)) id,
    ];
    final stale = [for (final id in removed) _controllers.remove(id)!];

    setState(() {
      _selectedIds = ids.toSet().toList();
      final shares = _splitCentsEqually(
        widget.totalPaise,
        _selectedIds.length,
      );
      for (var i = 0; i < _selectedIds.length; i++) {
        final controller = _controllers.putIfAbsent(
            _selectedIds[i], TextEditingController.new);
        controller.text = paiseToText(shares[i]);
      }
    });

    // The removed rows' fields are still mounted until this rebuild lands.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final controller in stale) {
        controller.dispose();
      }
    });
  }

  /// Hands whatever the edited share leaves over to everyone else, so the
  /// shares always add up to the total. Runs on every keystroke: waiting for
  /// the keyboard's action key let a user edit one field and press Done with
  /// the others never rebalanced. The edited field itself is left exactly as
  /// typed, or a trailing "16." would be rewritten out from under the user.
  void onAmountChange(int editedId) {
    final controller = _controllers[editedId]!;
    final editedCents = rupeesToPaise(double.tryParse(controller.text) ?? 0);

    final others = _selectedIds.where((id) => id != editedId).toList();
    if (others.isEmpty) return;

    final remainingCents = widget.totalPaise - editedCents;
    final shares = _splitCentsEqually(remainingCents, others.length);

    for (var i = 0; i < others.length; i++) {
      _controllers[others[i]]!.text = paiseToText(shares[i]);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: SafeArea(
        child: Container(
          height: MediaQuery.of(context).size.height * 0.8,
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.xl,
            top: AppSpacing.md,
            left: AppSpacing.md,
            right: AppSpacing.md,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                'Split amount',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              Expanded(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    const SizedBox(height: AppSpacing.md),
                    Column(
                      children: _selectedIds.map((id) {
                        final user = _userById(id)!;
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                              vertical: AppSpacing.xs),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  user["name"],
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              SizedBox(
                                width: 120,
                                child: TextFormField(
                                  controller: _controllers[id],
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                          decimal: true),
                                  textAlign: TextAlign.end,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.allow(
                                        // Same filter as the expense and payment
                                        // amount fields. The old `\d*\.?\d+`
                                        // deleted a trailing ".", so no decimal
                                        // could ever be typed.
                                        RegExp(r'^\d+\.?\d{0,2}')),
                                  ],
                                  decoration: const InputDecoration(
                                    prefixText: '₹ ',
                                  ),
                                  onChanged: (_) => onAmountChange(id),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Enter amount';
                                    }
                                    if (double.tryParse(value) == null) {
                                      return 'Invalid number';
                                    }
                                    if (double.tryParse(value)! <= 0) {
                                      return 'Must be greater than zero';
                                    }
                                    if (rupeesToPaise(double.parse(value)) >
                                        widget.totalPaise) {
                                      return 'Must be less the total amount';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              if (_errorMessage != null) ...[
                Text(
                  _errorMessage!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
              FilledButton(
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    final totalCents = widget.totalPaise;
                    final enteredCents = [
                      for (final id in _selectedIds)
                        rupeesToPaise(double.parse(_controllers[id]!.text)),
                    ];
                    final sumCents = enteredCents.fold<int>(0, (a, b) => a + b);

                    if (sumCents == totalCents) {
                      // Hand back fresh maps: the caller must not hold on to
                      // this sheet's controllers, which die with it.
                      widget.onSubmitSelectedUser([
                        for (var i = 0; i < _selectedIds.length; i++)
                          {
                            ..._userById(_selectedIds[i])!,
                            'amount': enteredCents[i],
                          },
                      ]);
                      Navigator.pop(context);
                    } else {
                      final diffCents = totalCents - sumCents;
                      setState(() {
                        _errorMessage = diffCents > 0
                            ? '${paiseToText(diffCents)} left to distribute.'
                            : '${paiseToText(-diffCents)} over the total amount.';
                      });
                    }
                  }
                },
                child: const Text('Done'),
              ),
              if (widget.users.isNotEmpty)
                ChipsChoice<int>.multiple(
                  value: _selectedIds,
                  onChanged: onSelectionChanged,
                  choiceItems: C2Choice.listFrom<int, Map<String, dynamic>>(
                    source: widget.users,
                    value: (i, v) => v['id'] as int,
                    label: (i, v) => v['name'],
                  ),
                  choiceBuilder: (item, i) {
                    return CustomChip(
                      label: item.label,
                      radius: 35,
                      selected: item.selected,
                      onSelect: item.select!,
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_expandable_fab/flutter_expandable_fab.dart';
import 'package:provider/provider.dart';

import '../notify_controllers/groups_controller.dart';
import '../notify_controllers/settings_controller.dart';
import '../views/new_expense.dart';
import '../views/new_form.dart';
import '../views/new_payment.dart';

class ExpandableFloatingActionButton extends StatelessWidget {
  ExpandableFloatingActionButton({
    super.key,
  });

  final _key = GlobalKey<ExpandableFabState>();

  void _addNewPersonInGroup(BuildContext context) {
    if (context.read<GroupsController>().selectedGroup['id'] == null) {
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (ctx) => const NewForm(
          saveButtonText: 'Save person',
          textFieldLabel: 'Person Name',
        ),
      ),
    ).then((_) {
      final state = _key.currentState;
      if (state != null) {
        state.toggle();
      }
    });
  }

  void _addNewExpenseInGroup(BuildContext context) {
    if (context.read<GroupsController>().selectedGroup['id'] == null) {
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (ctx) => const NewExpense(),
      ),
    ).then((_) {
      final state = _key.currentState;
      if (state != null) {
        state.toggle();
      }
    });
  }

  void _addNewPaymentInGroup(BuildContext context) {
    if (context.read<GroupsController>().selectedGroup['id'] == null) {
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (ctx) => const NewPayment(),
      ),
    ).then((_) {
      final state = _key.currentState;
      if (state != null) {
        state.toggle();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return ExpandableFab(
      key: _key,
      openButtonBuilder: RotateFloatingActionButtonBuilder(
        child: const Icon(Icons.add),
        fabSize: ExpandableFabSize.regular,
        shape: const CircleBorder(),
      ),
      type: ExpandableFabType.up,
      childrenAnimation: ExpandableFabAnimation.none,
      distance: 70,
      overlayStyle: ExpandableFabOverlayStyle(
        color: context.watch<SettingsController>().themeMode == ThemeMode.light
            ? Colors.white.withOpacity(0.9)
            : Colors.black.withOpacity(0.9),
      ),
      children: [
        InkWell(
          onTap: () {
            _addNewPersonInGroup(context);
          },
          child: const Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('New person'),
                  Text(
                    'Somebody to split costs with',
                    style: TextStyle(color: Colors.grey, fontSize: 12.0),
                  )
                ],
              ),
              SizedBox(width: 20),
              FloatingActionButton.small(
                heroTag: null,
                onPressed: null,
                child: Icon(Icons.person_2_outlined),
              ),
            ],
          ),
        ),
        InkWell(
          onTap: () {
            _addNewPaymentInGroup(context);
          },
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('New payment'),
                  Text(
                    'A payment made within the group',
                    style: TextStyle(color: Colors.grey, fontSize: 12.0),
                  ),
                ],
              ),
              SizedBox(width: 20),
              FloatingActionButton.small(
                heroTag: null,
                onPressed: null,
                child: Icon(Icons.arrow_forward),
              ),
            ],
          ),
        ),
        InkWell(
          onTap: () {
            _addNewExpenseInGroup(context);
          },
          child: const Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('New expense'),
                  Text(
                    'A purchase made for the group',
                    style: TextStyle(color: Colors.grey, fontSize: 12.0),
                  ),
                ],
              ),
              SizedBox(width: 20),
              FloatingActionButton.small(
                heroTag: null,
                onPressed: null,
                child: Icon(Icons.shopping_bag_outlined),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

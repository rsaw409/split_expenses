import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/backend.dart';
import '../settings/groups_controller.dart';
import 'settle_view.dart';
import 'user_view.dart';

class OverviewView extends StatelessWidget {
  const OverviewView({super.key});

  @override
  Widget build(BuildContext context) {
    final groupId = context.watch<GroupsController>().selectedGroup['id'];
    return FutureBuilder(
      future: groupId == null
          ? Future.error(Exception('Please create or join a group'))
          : fetchUserBalances(groupId),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text(snapshot.error.toString()));
        }

        if (!snapshot.hasData) {
          return const Center(child: Text('Loading'));
        }

        return ListView.builder(
          itemCount: snapshot.data!.length + 1,
          itemBuilder: (context, index) {
            if (index == snapshot.data.length) {
              return Padding(
                padding: const EdgeInsets.only(top: 14),
                child: Center(
                  child: Transform.scale(
                    scale: 1.2,
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (ctx) =>
                                SettleView(userBalances: snapshot.data),
                          ),
                        );
                      },
                      child: const Text('Settle up'),
                    ),
                  ),
                ),
              );
            } else {
              return ListTile(
                leading: const Icon(Icons.person_2_outlined),
                title: Text(snapshot.data?[index].name ?? ""),
                trailing: Text('INR ${snapshot.data?[index].balances}'),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (ctx) =>
                          UserView(userBalance: snapshot.data![index]),
                    ),
                  );
                },
              );
            }
          },
        );
      },
    );
  }
}

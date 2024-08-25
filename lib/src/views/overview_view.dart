import 'package:flutter/material.dart';
import '../services/backend.dart';
import 'settle_view.dart';
import 'user_view.dart';

class OverviewView extends StatelessWidget {
  const OverviewView({super.key, required this.groupId});

  final int? groupId;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: groupId == null
          ? Future.error(Exception('Please create or join a group'))
          : fetchUserBalances(groupId),
      builder: (context, snapshot) {
        // WHEN THE CALL IS DONE BUT HAPPENS TO HAVE AN ERROR
        if (snapshot.hasError) {
          return Center(child: Text(snapshot.error.toString()));
        }

        // WHILE THE CALL IS BEING MADE AKA LOADING
        if (!snapshot.hasData) {
          return const Center(child: Text('Loading'));
        }

        // IF IT WORKS IT GOES HERE!
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
                      builder: (ctx) => UserView(
                          groupId: groupId, userBalance: snapshot.data![index]),
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

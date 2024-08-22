import 'package:http/http.dart' as http;
import 'dart:convert';

import '../models/user.dart';
import '../models/user_balance.dart';
import '../models/expense/expense.dart';

import './server.dart';

Future<List<Expense>> fetchExpenses(groupId, userId, byId, isPayments) async {
  var url = '$server/getAllExpensesInGroup';

  final response = await http.post(
    Uri.parse(url),
    headers: <String, String>{
      'Content-Type': 'application/json; charset=UTF-8',
    },
    body: jsonEncode(<String, dynamic>{
      'group_id': '$groupId',
      'user_id': '$userId',
      'by': '$byId',
      'payments': isPayments
    }),
  );

  if (response.statusCode == 200) {
    var tmp = jsonDecode(response.body);

    List<Expense> expenses = [];
    for (int i = 0; i < tmp.length; i++) {
      expenses.add(Expense.fromJson(tmp[i]));
    }

    return expenses;
  } else {
    throw Exception('Failed to load Expenses');
  }
}

Future<List<UserBalance>> fetchUserBalances(groupId) async {
  var url = '$server/getOverviewDataInGroup';

  final response = await http.post(
    Uri.parse(url),
    headers: <String, String>{
      'Content-Type': 'application/json; charset=UTF-8',
    },
    body: jsonEncode(<String, String>{
      'group_id': '$groupId',
    }),
  );

  if (response.statusCode == 200) {
    var tmp = jsonDecode(response.body);

    List<UserBalance> users = [];
    for (int i = 0; i < tmp.length; i++) {
      users.add(UserBalance.fromJson(tmp[i]));
    }

    return users;
  } else {
    throw Exception('Failed to load User Profile');
  }
}

Future<String> addUserInGroup(groupId, userName) async {
  var url = '$server/createUser';

  print("In Api call");
  print("payload $groupId $userName");

  final response = await http.post(
    Uri.parse(url),
    headers: <String, String>{
      'Content-Type': 'application/json; charset=UTF-8',
    },
    body: jsonEncode(<String, String>{
      'group_id': '$groupId',
      'name': '$userName',
    }),
  );

  if (response.statusCode == 200) {
    print("success");
    return 'Success';
  } else {
    print("success");
    return 'Failed';
  }
}

Future<List<User>> getUsersInGroup(groupId) async {
  var url = '$server/getAllUsersInGroup';

  final response = await http.post(
    Uri.parse(url),
    headers: <String, String>{
      'Content-Type': 'application/json; charset=UTF-8',
    },
    body: jsonEncode(<String, String>{
      'group_id': '$groupId',
    }),
  );

  if (response.statusCode == 200) {
    var tmp = jsonDecode(response.body);

    print("tmp, $tmp");

    List<User> users = [];
    for (int i = 0; i < tmp.length; i++) {
      users.add(User.fromJson(tmp[i]));
    }
    return users;
  } else {
    print("somthing went wrong, $groupId");
    throw Exception('Failed to create group details in Server');
  }
}

Future<String> saveTransaction(transaction) async {
  var url = '$server/saveTransaction';

  final response = await http.post(
    Uri.parse(url),
    headers: <String, String>{
      'Content-Type': 'application/json; charset=UTF-8',
    },
    body: jsonEncode(transaction),
  );

  if (response.statusCode == 200) {
    return 'success';
  } else {
    throw Exception('Failed to save expense details in Server');
  }
}

Future<String> savePayment(payment) async {
  var url = '$server/savePayment';

  final response = await http.post(
    Uri.parse(url),
    headers: <String, String>{
      'Content-Type': 'application/json; charset=UTF-8',
    },
    body: jsonEncode(payment),
  );

  if (response.statusCode == 200) {
    return 'success';
  } else {
    throw Exception('Failed to save expense details in Server');
  }
}

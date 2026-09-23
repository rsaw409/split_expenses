import 'package:http/http.dart' as http;
import 'dart:convert';

import '../models/user.dart';
import '../models/user_balance.dart';
import '../models/expense/expense.dart';

import './api_exception.dart';
import './server.dart';

Future<List<Expense>> fetchExpenses(
    int? groupId, int? userId, int? byId, bool? isPayments) async {
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
    throw apiExceptionFrom(response, 'Failed to load expenses.');
  }
}

Future<List<UserBalance>> fetchUserBalances(int? groupId) async {
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
    throw apiExceptionFrom(response, 'Failed to load balances.');
  }
}

Future<String> addUserInGroup(int? groupId, String userName) async {
  var url = '$server/createUser';
  final response = await http.post(
    Uri.parse(url),
    headers: <String, String>{
      'Content-Type': 'application/json; charset=UTF-8',
    },
    body: jsonEncode(<String, String>{
      'group_id': '$groupId',
      'name': userName,
    }),
  );

  if (response.statusCode == 200) {
    return 'Success';
  } else {
    throw apiExceptionFrom(response, 'Failed to add person to group.');
  }
}

Future<List<User>> getUsersInGroup(int? groupId) async {
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

    List<User> users = [];
    for (int i = 0; i < tmp.length; i++) {
      users.add(User.fromJson(tmp[i]));
    }
    return users;
  } else {
    throw apiExceptionFrom(response, 'Failed to load people in this group.');
  }
}

/// Bounded so a hung write fails predictably instead of sitting on an open
/// socket for minutes, which leaves the user unsure whether it landed.
const Duration _writeTimeout = Duration(seconds: 20);

const Map<String, String> _jsonHeaders = {
  'Content-Type': 'application/json; charset=UTF-8',
};

/// Every write carries an `idempotency_key` in its body — a payment is a
/// transaction too, so all three use the same transport, and it matches how
/// the rest of this API passes everything as body fields. The key lets the
/// server recognise a retry of the same logical write and return the original
/// result rather than committing it twice; see `utils/idempotency.dart` for
/// the key's lifecycle.
Future<String> saveTransaction(
  Map<String, dynamic> transaction, {
  required String idempotencyKey,
}) async {
  var url = '$server/saveTransaction';

  final response = await http
      .post(
        Uri.parse(url),
        headers: _jsonHeaders,
        body: jsonEncode({
          ...transaction,
          'idempotency_key': idempotencyKey,
        }),
      )
      .timeout(_writeTimeout);

  if (response.statusCode == 200) {
    return 'success';
  } else {
    throw apiExceptionFrom(response, 'Failed to save expense.');
  }
}

Future<String> savePayment(
  Map<String, dynamic> payment, {
  required String idempotencyKey,
}) async {
  var url = '$server/savePayment';

  final response = await http
      .post(
        Uri.parse(url),
        headers: _jsonHeaders,
        body: jsonEncode({
          ...payment,
          'idempotency_key': idempotencyKey,
        }),
      )
      .timeout(_writeTimeout);

  if (response.statusCode == 200) {
    return 'success';
  } else {
    throw apiExceptionFrom(response, 'Failed to save payment.');
  }
}

/// Each payment carries its own `idempotency_key` rather than the batch
/// sharing one, so retrying after a partial failure re-applies only the
/// payments that did not land. A single key for the request would only be safe
/// if the server applied the batch atomically.
Future<String> savePayments(List<Map<String, dynamic>> payments) async {
  assert(
    payments.every((p) => p['idempotency_key'] is String),
    'every payment must carry its own idempotency_key',
  );

  var url = '$server/savePayments';

  final response = await http
      .post(
        Uri.parse(url),
        headers: _jsonHeaders,
        body: jsonEncode(payments),
      )
      .timeout(_writeTimeout);

  if (response.statusCode == 200) {
    return 'success';
  } else {
    throw apiExceptionFrom(response, 'Failed to save payments.');
  }
}

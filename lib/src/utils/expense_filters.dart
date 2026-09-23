import '../models/expense/expense.dart';

/// The backend marks payments by title rather than a dedicated field.
bool isPayment(Expense expense) => expense.transactionTitle == 'payment';

/// Mirrors `getAllExpensesInGroup`'s server-side filters so the per-user views
/// can be served from the cached full list instead of a round trip.
///
/// Verified against the live backend: for every user in a test group these
/// predicates returned the same transaction ids as the filtered endpoint, and
/// the same counts it reports in `getOverviewDataInGroup`.
List<Expense> filterExpenses(
  List<Expense> all, {
  /// Benefited from the transaction — appears in its distributions.
  int? userId,

  /// Paid for the transaction.
  int? byId,
  bool? isPayments,
}) {
  return all.where((expense) {
    if (isPayments != null && isPayments != isPayment(expense)) return false;
    if (byId != null && expense.userId != byId) return false;
    if (userId != null &&
        !expense.distributions.any((d) => d.userId == userId)) {
      return false;
    }
    return true;
  }).toList();
}

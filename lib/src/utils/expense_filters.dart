import '../models/expense/expense.dart';

/// Payments are identified by the server's own category, not by their title.
///
/// Matching on `transactionTitle == 'payment'` meant a user who titled an
/// ordinary expense "payment" had it rendered as a transfer and counted in the
/// Payments row. There is deliberately no fallback to that title check: it
/// cannot tell a real payment from an expense named like one, so keeping it
/// would preserve the very bug this replaces. The cost is that cache entries
/// written before this field existed decode with a null category, so on the
/// first launch after updating, a payment may paint as an expense until the
/// refetch lands a moment later.
bool isPayment(Expense expense) => expense.transactionCategory == 'payment';

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

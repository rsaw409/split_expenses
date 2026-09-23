import 'package:flutter_test/flutter_test.dart';
import 'package:split_expense/src/utils/idempotency.dart';

void main() {
  group('IdempotencyKey', () {
    final expense = {'title': 'Dinner', 'totalAmount': 2400, 'by': 139};

    test('reuses the key while the payload is unchanged', () {
      // The case this exists for: the write timed out, the user taps Save
      // again with the same content, and the server must see one write.
      final key = IdempotencyKey();
      final first = key.forPayload(expense);
      final retry = key.forPayload(expense);

      expect(retry, first);
    });

    test('is insensitive to map identity, only to content', () {
      final key = IdempotencyKey();
      final first = key.forPayload(expense);
      final sameContent = key.forPayload(
        {'title': 'Dinner', 'totalAmount': 2400, 'by': 139},
      );

      expect(sameContent, first);
    });

    test('reissues when the payload changes', () {
      // Otherwise editing the amount after a failure would be swallowed by
      // the server returning the result of the original write.
      final key = IdempotencyKey();
      final first = key.forPayload(expense);
      final edited = key.forPayload({...expense, 'totalAmount': 2500});

      expect(edited, isNot(first));
    });

    test('reissues after reset, so the next write is a new one', () {
      // Two genuinely separate but identical expenses must not collapse.
      final key = IdempotencyKey();
      final first = key.forPayload(expense);
      key.reset();
      final second = key.forPayload(expense);

      expect(second, isNot(first));
    });

    test('keys from separate form sessions differ', () {
      expect(
        IdempotencyKey().forPayload(expense),
        isNot(IdempotencyKey().forPayload(expense)),
      );
    });

    test('generates a non-empty, header-safe key', () {
      final value = IdempotencyKey().forPayload(expense);

      expect(value, isNotEmpty);
      expect(value, matches(RegExp(r'^[A-Za-z0-9_-]+$')));
    });

  });

  group('IdempotencyKeySet', () {
    // Mirrors what settle_view sends: one identity per payment.
    Map<String, Object> payment(int from, int to, num amount) =>
        {'from': from, 'to': to, 'amount': amount};

    test('gives each payment in a batch its own key', () {
      final keys = IdempotencyKeySet();

      expect(
        keys.forPayload(payment(142, 139, 1500)),
        isNot(keys.forPayload(payment(140, 139, 500))),
      );
    });

    test('reuses each key when the same batch is retried', () {
      final keys = IdempotencyKeySet();
      final batch = [payment(142, 139, 1500), payment(140, 139, 500)];

      final first = batch.map(keys.forPayload).toList();
      final retry = batch.map(keys.forPayload).toList();

      expect(retry, first);
    });

    test('a partial retry keeps committed keys and mints only for new items',
        () {
      // The scenario this design exists for: the server applied payment A,
      // then failed. The user retries with A still selected plus B added.
      final keys = IdempotencyKeySet();
      final a = payment(142, 139, 1500);
      final keyForA = keys.forPayload(a);

      final b = payment(140, 139, 500);
      final keyForB = keys.forPayload(b);

      expect(keys.forPayload(a), keyForA,
          reason: 'A is already committed; its key must not change');
      expect(keyForB, isNot(keyForA));
    });

    test('distinguishes payments differing only by amount', () {
      final keys = IdempotencyKeySet();

      expect(
        keys.forPayload(payment(142, 139, 1500)),
        isNot(keys.forPayload(payment(142, 139, 1600))),
      );
    });

    test('reissues after reset, so a later identical batch is a new write', () {
      final keys = IdempotencyKeySet();
      final only = payment(142, 139, 1500);

      final first = keys.forPayload(only);
      keys.reset();

      expect(keys.forPayload(only), isNot(first));
    });
  });
}

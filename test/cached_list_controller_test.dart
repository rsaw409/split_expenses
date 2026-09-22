import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:split_expense/src/notify_controllers/cached_list_controller.dart';
import 'package:split_expense/src/services/api_exception.dart';

class _FakeController extends CachedListController<String> {
  _FakeController(
    super.groupId, {
    this.cached,
    required this.onFetch,
  });

  final List<String>? cached;
  final Future<List<String>> Function(int callCount) onFetch;

  int fetchCount = 0;
  List<String>? written;

  @override
  Future<List<String>> fetchFromNetwork(int id) {
    fetchCount++;
    return onFetch(fetchCount);
  }

  @override
  Future<List<String>?> readFromCache(int id) async => cached;

  @override
  Future<void> writeToCache(int id, List<String> items) async {
    written = List.of(items);
  }

  @override
  String get fetchFailureMessage => 'fetch failed';
}

void main() {
  group('CachedListController', () {
    test('serves cache immediately on cold start, then the fetched data',
        () async {
      final fetch = Completer<List<String>>();
      final controller = _FakeController(
        1,
        cached: ['cached'],
        onFetch: (_) => fetch.future,
      );

      await pumpEventQueue();
      expect(controller.items, ['cached']);
      expect(controller.isLoading, isFalse,
          reason: 'a cache hit should skip the spinner');
      expect(controller.isStale, isTrue);

      fetch.complete(['fetched']);
      await pumpEventQueue();
      expect(controller.items, ['fetched']);
      expect(controller.isStale, isFalse);
      expect(controller.written, ['fetched']);
    });

    test('keeps cached data and reports stale, not error, when fetch fails',
        () async {
      final controller = _FakeController(
        1,
        cached: ['cached'],
        onFetch: (_) => Future.error(Exception('offline')),
      );

      await pumpEventQueue();
      expect(controller.items, ['cached']);
      expect(controller.isError, isFalse,
          reason: 'data on screen should survive a failed refetch');
      expect(controller.isStale, isTrue);
    });

    test('reports an error when the fetch fails with no cache', () async {
      final controller = _FakeController(
        1,
        onFetch: (_) => Future.error(Exception('offline')),
      );

      await pumpEventQueue();
      expect(controller.isError, isTrue);
      expect(controller.errorMessage, 'fetch failed');
      expect(controller.items, isEmpty);
    });

    test('surfaces an ApiException message verbatim', () async {
      final controller = _FakeController(
        1,
        onFetch: (_) =>
            Future.error(const ApiException('Group not found', statusCode: 404)),
      );

      await pumpEventQueue();
      expect(controller.errorMessage, 'Group not found');
    });

    test('treats an empty cached list as loaded data, not as absent data',
        () async {
      final controller = _FakeController(
        1,
        cached: [],
        onFetch: (_) => Future.error(Exception('offline')),
      );

      await pumpEventQueue();
      expect(controller.items, isEmpty);
      expect(controller.isError, isFalse,
          reason: 'a group with zero expenses has loaded successfully');
      expect(controller.isStale, isTrue);
    });

    test('ignores a superseded load result', () async {
      final first = Completer<List<String>>();
      final second = Completer<List<String>>();
      final controller = _FakeController(
        1,
        onFetch: (callCount) =>
            callCount == 1 ? first.future : second.future,
      );

      await pumpEventQueue();
      controller.refresh();
      await pumpEventQueue();

      second.complete(['newer']);
      await pumpEventQueue();
      expect(controller.items, ['newer']);

      first.complete(['older']);
      await pumpEventQueue();
      expect(controller.items, ['newer'],
          reason: 'a late response from an earlier request must not win');
    });

    test('does not notify after dispose', () async {
      final fetch = Completer<List<String>>();
      final controller = _FakeController(1, onFetch: (_) => fetch.future);

      await pumpEventQueue();
      controller.dispose();

      // Would throw "A ChangeNotifier was used after being disposed" if the
      // in-flight load notified without checking.
      fetch.complete(['fetched']);
      await pumpEventQueue();
    });

    test('refetches only on an offline to online transition', () async {
      final controller = _FakeController(
        1,
        onFetch: (_) async => ['fetched'],
      );

      await pumpEventQueue();
      expect(controller.fetchCount, 1);

      controller.onConnectivityChanged(true);
      await pumpEventQueue();
      expect(controller.fetchCount, 1,
          reason: 'first observation is not a transition');

      controller.onConnectivityChanged(false);
      controller.onConnectivityChanged(true);
      await pumpEventQueue();
      expect(controller.fetchCount, 2);
    });

    test('retries once when a fetch fails while online', () async {
      // Mirrors what happened on a real device: the fetch issued the instant
      // connectivity returned failed while the radio was still settling, and
      // no further transition followed to trigger another attempt.
      final controller = _FakeController(
        1,
        onFetch: (callCount) => callCount <= 2
            ? Future.error(Exception('radio still settling'))
            : Future.value(['fetched']),
      );

      await pumpEventQueue();
      expect(controller.fetchCount, 1);

      controller.onConnectivityChanged(false);
      controller.onConnectivityChanged(true);
      await pumpEventQueue();
      expect(controller.fetchCount, 2, reason: 'reconnect refetches');

      await Future<void>.delayed(const Duration(seconds: 4));
      await pumpEventQueue();
      expect(controller.fetchCount, 3, reason: 'failure schedules one retry');
      expect(controller.items, ['fetched']);
      expect(controller.isStale, isFalse);
    });

    test('does not retry in a loop against a failing backend', () async {
      final controller = _FakeController(
        1,
        onFetch: (_) => Future.error(Exception('backend down')),
      );

      await pumpEventQueue();
      controller.onConnectivityChanged(false);
      controller.onConnectivityChanged(true);
      await pumpEventQueue();
      final afterReconnect = controller.fetchCount;

      await Future<void>.delayed(const Duration(seconds: 8));
      await pumpEventQueue();
      expect(controller.fetchCount, afterReconnect + 1,
          reason: 'at most one automatic retry until the next success or edge');
    });

    test('does not retry while offline', () async {
      final controller = _FakeController(
        1,
        onFetch: (_) => Future.error(Exception('offline')),
      );

      await pumpEventQueue();
      controller.onConnectivityChanged(false);
      await Future<void>.delayed(const Duration(seconds: 4));
      await pumpEventQueue();
      expect(controller.fetchCount, 1,
          reason: 'retrying with no connectivity just burns battery');
    });

    test('treats having no group as empty, not as an error', () async {
      // A first-run user has no group yet; that is an onboarding state, and
      // rendering it as an error puts a red error icon on their first screen.
      final controller = _FakeController(
        null,
        onFetch: (_) async => ['unused'],
      );

      await pumpEventQueue();
      expect(controller.isError, isFalse);
      expect(controller.isLoading, isFalse);
      expect(controller.items, isEmpty);
      expect(controller.fetchCount, 0);
    });
  });
}

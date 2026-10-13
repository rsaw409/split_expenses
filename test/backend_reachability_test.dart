import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:split_expense/src/notify_controllers/backend_reachability.dart';

/// Probes that stay pending until the test answers them, in order of calls.
class _Probes {
  final calls = <Completer<bool>>[];

  Future<bool> call() {
    final completer = Completer<bool>();
    calls.add(completer);
    return completer.future;
  }

  void answer(int index, bool reachable) => calls[index].complete(reachable);
}

void main() {
  late _Probes probes;
  late BackendReachability reachability;
  late List<bool> reported;

  // testWidgets for its fake clock: pump(duration) runs the probe timers.
  // Each test disposes at the end, since its pending-timer check runs before
  // tear-downs would.
  Future<void> start(WidgetTester tester) async {
    probes = _Probes();
    reachability = BackendReachability(probe: probes.call);
    reported = [];
    reachability.addListener(() => reported.add(reachability.isReachable));
    await tester.pump();
  }

  testWidgets('checks a failed launch probe again before reporting it',
      (tester) async {
    // The web app's first request after a launch can fail on a dead pooled
    // connection; reported at once, it showed the banner for ten seconds.
    await start(tester);
    probes.answer(0, false);
    await tester.pump();
    expect(reachability.isReachable, isTrue);

    await tester.pump(const Duration(seconds: 2));
    expect(probes.calls, hasLength(2), reason: 'a quick second probe');
    probes.answer(1, true);
    await tester.pump();
    expect(reachability.isReachable, isTrue);
    expect(reported, isNot(contains(false)));
    reachability.dispose();
  });

  testWidgets('reports unreachable after two failures in a row',
      (tester) async {
    await start(tester);
    probes.answer(0, false);
    await tester.pump(const Duration(seconds: 2));
    probes.answer(1, false);
    await tester.pump();
    expect(reachability.isReachable, isFalse);
    reachability.dispose();
  });

  testWidgets('a successful fetch clears unreachable at once',
      (tester) async {
    await start(tester);
    probes.answer(0, false);
    await tester.pump(const Duration(seconds: 2));
    probes.answer(1, false);
    await tester.pump();
    expect(reachability.isReachable, isFalse);

    reachability.reportReachable();
    expect(reachability.isReachable, isTrue,
        reason: 'not only at the next probe, ten seconds later');
    reachability.dispose();
  });

  testWidgets('a failure from before a resume does not count',
      (tester) async {
    await start(tester);
    probes.answer(0, true);
    await tester.pump(const Duration(seconds: 10));
    probes.answer(1, false);
    await tester.pump();

    // Backgrounded while the confirming probe was due, then resumed.
    reachability.didChangeAppLifecycleState(AppLifecycleState.paused);
    reachability.didChangeAppLifecycleState(AppLifecycleState.resumed);
    probes.answer(2, false);
    await tester.pump();
    expect(reachability.isReachable, isTrue,
        reason: 'one failure since resuming, so it is checked again first');

    await tester.pump(const Duration(seconds: 2));
    probes.answer(3, true);
    await tester.pump();
    expect(reported, isNot(contains(false)));
    reachability.dispose();
  });

  testWidgets('ignores a probe answered after a newer one started',
      (tester) async {
    await start(tester);

    // The launch probe is still in flight when the app resumes and probes
    // again; the old one then fails late, as a suspended request does.
    reachability.didChangeAppLifecycleState(AppLifecycleState.paused);
    reachability.didChangeAppLifecycleState(AppLifecycleState.resumed);
    probes.answer(0, false);
    probes.answer(1, false);
    await tester.pump();
    expect(reachability.isReachable, isTrue,
        reason: 'only the newer failure counts, and it is checked again');

    await tester.pump(const Duration(seconds: 2));
    probes.answer(2, true);
    await tester.pump();
    expect(reported, isNot(contains(false)));
    reachability.dispose();
  });
}

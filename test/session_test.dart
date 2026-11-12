import 'package:flutter_test/flutter_test.dart';
import 'package:tooth_time/session.dart';

void main() {
  test('Switching sections preserves time and supports out-of-order completion',
      () async {
    final session = BrushingSession();
    session.start();
    await Future<void>.delayed(const Duration(milliseconds: 1050));
    session.select(3);
    expect(session.watch.elapsed, Duration.zero);
    expect(session.watch.isRunning, false);
    session.select(0);
    expect(session.watch.elapsed.inMilliseconds, greaterThanOrEqualTo(1000));
    expect(session.finishSection(), true);
    expect(session.completedCount, 1);
    expect(session.select(0), false);
    expect(session.select(3), true);
    session.start();
    await Future<void>.delayed(const Duration(milliseconds: 1050));
    expect(session.finishSection(), true);
    expect(session.section, 1);
    expect(session.completedCount, 2);
  });
  test('Four sections record independent active times and one total', () async {
    final session = BrushingSession();
    expect(session.finishSection(), false);
    for (var i = 0; i < 4; i++) {
      expect(session.section, i);
      session.start();
      await Future<void>.delayed(const Duration(milliseconds: 1050));
      session.pause();
      final paused = session.watch.elapsed;
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(session.watch.elapsed, paused);
      expect(session.finishSection(), true);
      expect(session.times[i], paused);
      expect(session.watch.elapsed, Duration.zero);
    }
    expect(session.complete, true);
    expect(session.total.inSeconds, greaterThanOrEqualTo(4));
    expect(session.finishSection(), false);
  });
}

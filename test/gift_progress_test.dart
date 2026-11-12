import 'package:flutter_test/flutter_test.dart';
import 'package:tooth_time/gift_progress.dart';

void main() {
  test('Today may still be completed; yesterday keeps streak alive', () {
    expect(
        GiftProgress({'2026-10-06', '2026-10-07'}, 7, DateTime(2026, 10, 8))
            .remaining,
        5);
  });
  test('Missing a full day resets streak', () {
    expect(GiftProgress({'2026-10-06'}, 7, DateTime(2026, 10, 8)).streak, 0);
  });
  test('Seven consecutive dates reach goal', () {
    expect(
        GiftProgress({
          for (int i = 2; i <= 8; i++) '2026-10-${i.toString().padLeft(2, '0')}'
        }, 7, DateTime(2026, 10, 8))
            .remaining,
        0);
  });
  test('Monthly goal is thirty consecutive days', () {
    expect(
        GiftProgress({'2026-10-08'}, 30, DateTime(2026, 10, 8)).remaining, 29);
  });
}

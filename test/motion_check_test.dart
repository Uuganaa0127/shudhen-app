import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:tooth_time/motion_check.dart';
import 'package:tooth_time/camera_coach.dart';
import 'package:tooth_time/session.dart';

void main() {
  testWidgets('Camera screen combines external timer and tappable teeth',
      (tester) async {
    final session = BrushingSession();
    await tester.pumpWidget(MaterialApp(
        home: CameraCoach(session: session, onFinish: () async {})));
    expect(find.byKey(const ValueKey('camera-external-timer')), findsOneWidget);
    final selector = find.byKey(const ValueKey('camera-teeth-selector'));
    await tester.scrollUntilVisible(selector, 200);
    await tester.pump();
    final center = tester.getCenter(selector);
    await tester.tapAt(center + const Offset(-25, 20));
    await tester.pump();
    expect(session.section, 3);
    expect(session.watch.isRunning, false);
    await tester.pumpWidget(const SizedBox());
  });
  test(
      'Experimental motion distinguishes still, movement, dark and lighting changes',
      () {
    final check = MotionCheck();
    final still = List.filled(576, 100);
    expect(check.inspect(still), contains('Эхлэхийн өмнө'));
    for (int i = 0; i < 8; i++) {
      check.inspect(still);
    }
    expect(check.inspect(still), contains('Хөдөлгөөн бага'));
    expect(check.inspect(List.generate(576, (i) => i.isEven ? 120 : 80)),
        contains('Хөдөлгөөн илэрлээ'));
    expect(check.inspect(List.filled(576, 200)), contains('Гэрэл өөрчлөгдлөө'));
    expect(check.inspect(List.filled(576, 5)), contains('Гэрлээ нэмээрэй'));
  });
  testWidgets('Camera requires an explicit start and explains limits',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: CameraCoach(session: BrushingSession(), onFinish: () async {})));
    await tester.scrollUntilVisible(find.byTooltip('Камер асаах'), 300);
    expect(find.byTooltip('Камер асаах'), findsOneWidget);

    expect(find.text('Бэлэн бол эхлээрэй'), findsOneWidget);
  });
}

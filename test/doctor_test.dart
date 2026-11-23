import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tooth_time/camera_coach.dart';
import 'package:tooth_time/session.dart';

void main() {
  testWidgets(
    'Failed durable save allows retry without success or completion',
    (tester) async {
      final session = BrushingSession()..start();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 1050)),
      );
      session.pause();
      var attempts = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: CameraCoach(
            session: session,
            onFinish: () async {
              attempts++;
              throw StateError('disk full');
            },
          ),
        ),
      );
      await tester.tap(find.text('Дуусгах →'));
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(session.completedCount, 0);
      expect(find.text('Мундаг байна!'), findsNothing);
      await tester.tap(find.text('Дуусгах →'));
      await tester.pump();
      expect(attempts, 2);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'Camera timer shows elapsed and remaining seconds on a narrow screen',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: CameraCoach(
            session: BrushingSession(),
            age: 5,
            onFinish: () async {},
          ),
        ),
      );
      expect(find.text('⏳ 30 сек'), findsOneWidget);
      expect(find.text('🪥 0 сек угаасан'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('Floss confirmation records only after Done', (tester) async {
    var recorded = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: CameraCoach(
          session: BrushingSession(),
          onFinish: () async {},
          onFloss: () async {
            recorded++;
          },
        ),
      ),
    );
    await tester.scrollUntilVisible(find.byTooltip('Шүдний утас'), 250);
    await tester.drag(find.byType(ListView).first, const Offset(0, -150));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byTooltip('Шүдний утас'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(recorded, 0);
    await tester.tap(find.byTooltip('Утас хэрэглэж дууслаа'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(recorded, 1);
    await tester.pumpWidget(const SizedBox());
  });
}

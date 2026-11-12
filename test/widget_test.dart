import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tooth_time/main.dart';
import 'package:tooth_time/camera_coach.dart';

void main() {
  testWidgets('Multiple saved reminders have independent controls',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'doctorClients': <String>['KID-001'],
      'activeClient': 'KID-001',
      'signedIn': true,
      'reminderTimes:KID-001':
          '[{"hour":8,"minute":0,"enabled":true},{"hour":20,"minute":30,"enabled":false}]',
    });
    await tester.pumpWidget(const ToothTime());
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.byTooltip('Тохиргоо'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Бэлэн үү? Угаацгаая!'), findsNothing);
    expect(find.byTooltip('Сануулга устгах'), findsNWidgets(2));
    expect(find.text('Сануулга нэмэх'), findsOneWidget);
    final switches = tester.widgetList<Switch>(find.byType(Switch)).toList();
    expect(switches.map((s) => s.value).toList(), [true, false]);
    await tester.pumpWidget(const SizedBox());
  });
  test('Day and night switch at local 7 AM and 7 PM', () {
    expect(isNightTime(DateTime(2026, 9, 7, 6, 59)), true);
    expect(isNightTime(DateTime(2026, 9, 7, 7)), false);
    expect(isNightTime(DateTime(2026, 9, 7, 18, 59)), false);
    expect(isNightTime(DateTime(2026, 9, 7, 19)), true);
    expect(isNightTime(DateTime(2026, 9, 7, 0)), true);
  });
  testWidgets('Introduction opens and closes', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const ToothTime());
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.scrollUntilVisible(find.byTooltip('Хэрхэн угаах вэ?'), 150,
        scrollable: find.byType(Scrollable).first);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byTooltip('Хэрхэн угаах вэ?'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Шүдхэн найзтайгаа танилцаарай ✨'), findsOneWidget);
    expect(find.text('2. Хэсгээ сонгоорой'), findsOneWidget);
    await tester.tap(find.text('Ойлголоо!'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Шүдхэн найзтайгаа танилцаарай ✨'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('ID login validates required fields', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const ToothTime());
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('123456'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).first, '');
    await tester.ensureVisible(find.text('Нэвтрэх'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text('Нэвтрэх'));
    await tester.pump();
    expect(find.text('ID-гаа оруулна уу'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('Start brushing opens camera directly with selectable filters',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'doctorClients': <String>['KID-001'],
      'activeClient': 'KID-001',
      'signedIn': true
    });
    await tester.pumpWidget(const ToothTime());
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Бяцхан найз'), findsOneWidget);
    await tester.ensureVisible(find.text('Шүдээ угаах'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text('Шүдээ угаах'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('🦷 Угаацгаая!'), findsOneWidget);
    expect(find.text('За, шүдээ угаая'), findsNothing);
    await tester.scrollUntilVisible(find.text('🐱'), 200,
        scrollable: find
            .descendant(
                of: find.byType(CameraCoach), matching: find.byType(Scrollable))
            .first);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('🐱'));
    await tester.pump();
    final kitty = tester.widget<ChoiceChip>(
        find.ancestor(of: find.text('🐱'), matching: find.byType(ChoiceChip)));
    expect(kitty.selected, true);
    await tester.pumpWidget(const SizedBox());
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tooth_time/kid_home.dart';

void main() {
  for (final size in [
    const Size(320, 568),
    const Size(568, 320),
    const Size(1024, 768)
  ]) {
    testWidgets('Home and calendar fit $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(MaterialApp(
          home: KidHome(
              name: 'Бяцхан найз',
              stars: 12,
              dates: {},
              gift: {},
              night: false,
              onBrush: () {},
              onSettings: () {})));
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
      final gift = find.text('Бэлэг хүртэл 7 өдөр');
      await tester.scrollUntilVisible(gift, 150);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(gift);
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.takeException(), isNull);
      expect(find.text('Хаах'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });
  }
}

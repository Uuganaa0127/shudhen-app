import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tooth_time/reward_cards.dart';
import 'support/connection_fakes.dart';

void main() {
  test('Offline gift progress resets after a missed clinic day', () {
    final reward = {
      'goalDays': 7,
      'progress': 6,
      'lastQualifiedDay': '2026-11-21',
    };
    expect(RewardCards.progressAt(reward, DateTime.utc(2026, 11, 22, 15)), 6);
    expect(RewardCards.progressAt(reward, DateTime.utc(2026, 11, 22, 16)), 0);
  });
  testWidgets(
    'Weekly and monthly gift cards fit a narrow screen with collected gifts',
    (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: RewardCards(
                data: {
                  'items': [
                    {
                      'name': 'Долоо хоногийн жижиг бэлэг',
                      'goalDays': 7,
                      'progress': 6,
                    },
                    {'name': 'Сарын том бэлэг', 'goalDays': 30, 'progress': 29},
                  ],
                  'awards': [
                    {'name': 'Миний анхны бэлэг', 'earnedDay': '2026-11-21'},
                  ],
                },
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('7 өдөр тутам'), findsOneWidget);
      expect(find.text('30 өдөр тутам'), findsOneWidget);
      expect(find.text('Бэлэг хүртэл 1 өдөр'), findsNWidgets(2));
      expect(find.text('Миний анхны бэлэг'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  test(
    'Gift cache survives restart and stays scoped to the connected child',
    () async {
      SharedPreferences.setMockInitialValues({});
      final credentials = MemoryCredentials(account());
      final care = testController(
        credentials: credentials,
        respond: (r) async {
          final reply = defaultReply(r);
          if (r.url.path.endsWith('/me')) {
            return jsonReply({
              ...jsonDecode(reply.body) as Map<String, dynamic>,
              'rewards': {
                'items': [
                  {
                    'id': 'weekly',
                    'name': 'Gift',
                    'goalDays': 7,
                    'progress': 2,
                  },
                ],
                'awards': [],
              },
            });
          }
          return reply;
        },
      );
      addTearDown(care.dispose);
      await care.initialize();
      await care.refreshProfile();
      expect((care.rewards['items'] as List).length, 1);
      final restart = testController(credentials: credentials);
      addTearDown(restart.dispose);
      await restart.initialize();
      expect((restart.rewards['items'] as List).single['name'], 'Gift');
      final another = testController(
        credentials: MemoryCredentials(account(enrollment: enrollmentB)),
      );
      addTearDown(another.dispose);
      await another.initialize();
      expect(another.rewards, isEmpty);
      await restart.disconnect();
      expect(restart.rewards, isEmpty);
    },
  );
}

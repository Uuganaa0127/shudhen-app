import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tooth_time/care_data.dart';

void main() {
  test('Gift progress counts complete days once, excluding partial sessions',
      () {
    final rows = <Map<String, dynamic>>[
      for (final id in ['a', 'b'])
        for (int i = 0; i < 4; i++)
          {
            'sessionId': id,
            'type': 'brush',
            'section': i,
            'date': '2026-10-08T10:00:00',
            'milliseconds': 30000
          },
      {
        'sessionId': 'c',
        'type': 'brush',
        'section': 0,
        'date': '2026-10-09T10:00:00',
        'milliseconds': 30000
      },
    ];
    expect(CareStats(rows).complete, 2);
    expect(CareStats(rows).completedDays, 1);
  });

  test('Only issued IDs can log in, and IDs are remembered', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final store = CareData(prefs);
    expect(await store.login('random'), false);
    expect(await store.addClient('kid-001'), true);
    expect(await store.addClient('KID-001'), false);
    expect(await store.addClient('a!'), false);
    expect(await store.login(' kid-001 '), true);
    expect(prefs.getString('activeClient'), 'KID-001');
    expect(prefs.getString('rememberedClient'), 'KID-001');
    expect(store.clients, ['KID-001']);
  });
  test('Test ID supports optional remembered login', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final store = CareData(prefs);
    await store.addClient('123456');
    expect(await store.login('123456'), true);
    expect(prefs.getBool('signedIn'), true);
    expect(await store.login('123456', rememberMe: false), true);
    expect(prefs.getBool('signedIn'), false);
    expect(prefs.getString('rememberedClient'), isNull);
    expect(prefs.getString('activeClient'), '123456');
  });
  test('Child records and suggestions remain separate', () async {
    final rows = [
      for (int i = 0; i < 4; i++)
        {
          'childId': 'A',
          'type': 'brush',
          'section': i,
          'sessionId': 'one',
          'date': '2026-09-21T08:00:00',
          'milliseconds': i == 0 ? 10000 : 30000
        },
      {
        'childId': 'B',
        'type': 'brush',
        'section': 0,
        'sessionId': 'two',
        'date': '2026-09-21T08:00:00',
        'milliseconds': 60000
      }
    ];
    SharedPreferences.setMockInitialValues({'careEvents': jsonEncode(rows)});
    final store = CareData(await SharedPreferences.getInstance());
    final a = CareStats(store.forChild('A'));
    expect(a.complete, 1);
    expect(a.average(0), 10);
    expect(a.total(1), 30);
    expect(a.childTip, contains('Дээд зүүн'));
    expect(CareStats(store.forChild('B')).average(0), 60);
    expect(CareStats([]).doctorTips.single, contains('Өгөгдөл хүрэлцэхгүй'));
  });
}

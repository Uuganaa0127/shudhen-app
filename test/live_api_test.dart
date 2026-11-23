import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tooth_time/connection/api.dart';
import 'package:tooth_time/connection/controller.dart';
import 'package:tooth_time/connection/store_native.dart';
import 'support/connection_fakes.dart';

// Opt in only against an isolated backend and a newly issued, disposable invite.
// Fixture JSON: {baseUrl, invitation, enrollmentId}. Never commit credentials.
void main() {
  final fixturePath = Platform.environment['SHUDHEN_LIVE_FIXTURE'];
  test(
    'real hospital API: consent, exchange, SQLite upload, retry and logout',
    () async {
      final fixture =
          jsonDecode(await File(fixturePath!).readAsString())
              as Map<String, dynamic>;
      sqfliteFfiInit();
      final api = CareApi(baseUrl: fixture['baseUrl'] as String);
      final credentials = MemoryCredentials();
      final store = SqliteSessionStore(
        factory: databaseFactoryFfi,
        databasePath: inMemoryDatabasePath,
      );
      final care = CareController(
        api: api,
        credentials: credentials,
        store: store,
      );
      addTearDown(care.dispose);
      await care.initialize();
      final consent = await care.consent();
      await care.link(
        invitation: fixture['invitation'] as String,
        guardianName: 'Test parent',
        relationship: 'Parent',
        deviceName: 'Integration test',
        consentVersion: consent['version'] as String,
      );
      expect(care.connection!.enrollmentId, fixture['enrollmentId']);
        final token = care.connection!.token;
    final profile = await api.request('GET', 'me', token: token);
    expect(care.connection!.name, profile['firstName']);
      final input = payload();
      await care.saveSession(input, finalized: true);
      await care.sync();
      expect(care.records.single.state, 'synced');
      expect(care.pending, 0);
      expect(care.stars, 1);
      final retry = await api.request(
        'POST',
        'sessions',
        token: token,
        body: input,
      );
      expect(retry['id'], input['id']);
      expect(retry['targetMet'], true);
      final history = await api.request('GET', 'sessions', token: token);
      expect((history['items'] as List).length, 1);
      await care.disconnect();
      expect(credentials.value, isNull);
      await expectLater(
        api.request('GET', 'me', token: token),
        throwsA(isA<ApiFailure>().having((e) => e.status, 'status', 401)),
      );
    },
    skip: fixturePath == null
        ? 'SHUDHEN_LIVE_FIXTURE is not configured'
        : false,
  );
}

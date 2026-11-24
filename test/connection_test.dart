import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:tooth_time/connection/api.dart';
import 'package:tooth_time/connection/controller.dart';
import 'package:tooth_time/connection/records.dart';
import 'support/connection_fakes.dart';

Future<void> link(CareController care) => care.link(
  invitation: 'one-time-invite',
  guardianName: 'Ээж',
  relationship: 'Ээж',
  deviceName: 'Утас',
  consentVersion: 'shudhen-care-v1',
);

void main() {
  test(
    'profile credential write cannot resurrect a logged-out credential',
    () async {
      final credentials = PausedCredentials();
      final care = testController(credentials: credentials);
      addTearDown(care.dispose);
      await care.initialize();
      final profile = care.refreshProfile();
      await credentials.started.future;
      final logout = care.disconnect();
      credentials.release.complete();
      await Future.wait([profile, logout]);
      expect(credentials.value, isNull);
      expect(care.connection, isNull);
    },
  );
  test(
    'offline restart recovers draft at last checkpoint, preserving UUID',
    () async {
      final store = MemorySessions();
      final draft = payload(status: 'INTERRUPTED');
      await store.put(LocalSession(account().scope, draft, 'draft'));
      final care = testController(
        store: store,
        respond: (_) async => throw const ApiFailure('offline'),
      );
      addTearDown(care.dispose);
      await care.initialize();
      await care.sync();
      expect(care.connection!.name, 'Саруул');
      expect(care.records.single.state, 'pending');
      expect(care.records.single.payload, draft);
      expect(care.records.single.id, sessionID);
    },
  );
  test('failed local save does not create completion or reward', () async {
    final store = MemorySessions()..failWrite = true;
    final care = testController(store: store);
    addTearDown(care.dispose);
    await care.initialize();
    await expectLater(
      care.saveSession(payload(), finalized: true),
      throwsStateError,
    );
    expect(care.stars, 0);
    expect(care.records, isEmpty);
    store.failWrite = false;
    await care.saveSession(payload(), finalized: true);
    expect(care.pending, 1);
    expect(care.stars, 1);
  });
  test(
    'concurrent sync callers share one upload; last draft cannot overwrite ack',
    () async {
      var uploads = 0;
      final release = Completer<void>();
      final care = testController(
        respond: (request) async {
          if (request.method == 'POST' &&
              request.url.path.endsWith('/sessions')) {
            uploads++;
            await release.future;
          }
          return defaultReply(request);
        },
      );
      addTearDown(care.dispose);
      await care.initialize();
      final body = payload();
      await care.saveSession(body, finalized: true);
      final first = care.sync();
      final second = care.sync();
      await Future<void>.delayed(Duration.zero);
      release.complete();
      await Future.wait([first, second]);
      expect(uploads, 1);
      expect(care.pending, 0);
      expect(care.records.single.state, 'synced');
      expect(care.lastSync, isNotNull);
      await care.saveSession({...body, 'flossed': true}, finalized: false);
      expect(care.records.single.state, 'synced');
      expect(care.records.single.payload['flossed'], false);
    },
  );
  test(
    'dropped response retries the exact immutable payload and UUID',
    () async {
      final requests = <String>[];
      final care = testController(
        respond: (request) async {
          if (request.url.path.endsWith('/sessions')) {
            requests.add(request.body);
            if (requests.length == 1) throw const ApiFailure('response lost');
          }
          return defaultReply(request);
        },
      );
      addTearDown(care.dispose);
      await care.initialize();
      await care.saveSession(payload(), finalized: true);
      await care.sync();
      expect(care.pending, 1);
      await care.sync();
      expect(care.records.single.state, 'synced');
      expect(requests.length, 2);
      expect(requests[0], requests[1]);
    },
  );
  test(
    '401 preserves pending and requests relink without repeated uploads',
    () async {
      var requests = 0;
      final care = testController(
        respond: (_) async {
          requests++;
          return jsonReply({}, 401);
        },
      );
      addTearDown(care.dispose);
      await care.initialize();
      await care.saveSession(payload(), finalized: true);
      await care.sync();
      await care.sync();
      expect(care.needsRelink, true);
      expect(care.pending, 1);
      expect(requests, 1);
    },
  );
  test('expired local credential never uploads', () async {
    var calls = 0;
    final care = testController(
      credentials: MemoryCredentials(account(expiry: DateTime(2020))),
      respond: (r) async {
        calls++;
        return defaultReply(r);
      },
    );
    addTearDown(care.dispose);
    await care.initialize();
    await care.saveSession(payload(), finalized: true);
    await care.sync();
    expect(care.needsRelink, true);
    expect(calls, 0);
    expect(care.pending, 1);
  });
  test(
    'one rejected record does not block later records; neither is deleted',
    () async {
      final care = testController(
        respond: (r) async => (jsonDecode(r.body) as Map)['id'] == sessionID
            ? jsonReply({}, 409)
            : defaultReply(r),
      );
      addTearDown(care.dispose);
      await care.initialize();
      await care.saveSession(payload(), finalized: true);
      await care.saveSession(
        payload(id: 'dddddddd-dddd-4ddd-8ddd-dddddddddddd'),
        finalized: true,
      );
      await care.sync();
      expect(care.blocked, 1);
      expect(care.records.length, 2);
      expect(care.records.where((r) => r.state == 'synced').length, 1);
    },
  );
  test('mismatched server receipt is not acknowledged', () async {
    final care = testController(
      respond: (_) async =>
          jsonReply({'id': sessionID, 'enrollmentId': enrollmentB}),
    );
    addTearDown(care.dispose);
    await care.initialize();
    await care.saveSession(payload(), finalized: true);
    await care.sync();
    expect(care.pending, 1);
    expect(care.lastSync, isNull);
  });
  test(
    'relinking another child cannot upload the previous child pending data',
    () async {
      final store = MemorySessions();
      final uploads = <String>[];
      final care = testController(
        store: store,
        respond: (r) async {
          if (r.method == 'POST' && r.url.path.endsWith('/sessions')) {
            uploads.add(r.body);
          }
          return defaultReply(r, enrollment: enrollmentB);
        },
      );
      addTearDown(care.dispose);
      await care.initialize();
      await care.saveSession(payload(), finalized: true);
      await link(care);
      expect(care.connection!.enrollmentId, enrollmentB);
      expect(care.records, isEmpty);
      expect(uploads, isEmpty);
      expect((await store.all(account().scope)).single.state, 'pending');
    },
  );
  test(
    'same enrollment relink sends retained pending data with new token',
    () async {
      final tokens = <String?>[];
      final care = testController(
        respond: (r) async {
          if (r.url.path.endsWith('/sessions')) {
            tokens.add(r.headers['Authorization']);
          }
          return defaultReply(r);
        },
      );
      addTearDown(care.dispose);
      await care.initialize();
      await care.saveSession(payload(), finalized: true);
      care.needsRelink = true;
      await link(care);
      expect(tokens, ['Bearer new-secret']);
      expect(care.pending, 0);
    },
  );
  test(
    'backend switch does not forward credentials to another origin',
    () async {
      final wrong = Connection(
        baseUrl: 'https://production.test/api/v1',
        token: 'production-secret',
        enrollmentId: enrollmentA,
        expiresAt: DateTime.now().add(const Duration(days: 1)),
      );
      var requests = 0;
      final care = testController(
        credentials: MemoryCredentials(wrong),
        respond: (r) async {
          requests++;
          return defaultReply(r);
        },
      );
      addTearDown(care.dispose);
      await care.initialize();
      await care.sync();
      expect(care.connection, isNull);
      expect(requests, 0);
    },
  );
  test('exchange persists credential before profile fetch fails', () async {
    final credentials = MemoryCredentials();
    final care = testController(
      credentials: credentials,
      respond: (r) async {
        if (r.url.path.endsWith('/me')) throw const ApiFailure('offline');
        return defaultReply(r);
      },
    );
    addTearDown(care.dispose);
    await care.initialize();
    await link(care);
    expect(care.connection!.token, 'new-secret');
    expect(credentials.value, contains('new-secret'));
  });
  test(
    'secure write failure revokes new grant and does not replace previous account',
    () async {
      final credentials = MemoryCredentials(account())..failWrite = true;
      var revoked = false;
      final care = testController(
        credentials: credentials,
        respond: (r) async {
          if (r.url.path.endsWith('/logout')) revoked = true;
          return defaultReply(r);
        },
      );
      addTearDown(care.dispose);
      await care.initialize();
      await expectLater(link(care), throwsStateError);
      expect(revoked, true);
      expect(care.connection!.token, 'secret-token');
    },
  );
  test('offline logout removes credential but preserves outbox', () async {
    final store = MemorySessions();
    final credentials = MemoryCredentials(account());
    final care = testController(
      credentials: credentials,
      store: store,
      respond: (_) async => throw const ApiFailure('offline'),
    );
    addTearDown(care.dispose);
    await care.initialize();
    await care.saveSession(payload(), finalized: true);
    await care.disconnect();
    expect(credentials.value, isNull);
    expect(care.connection, isNull);
    expect((await store.all(account().scope)).single.state, 'pending');
    expect(care.syncMessage, contains('Серверийн эрхийг цуцалж чадсангүй'));
  });
  test(
    'short completed sessions earn no star, calendar uses captured time zone',
    () async {
      final care = testController();
      addTearDown(care.dispose);
      await care.initialize();
      await care.saveSession(payload(activeMs: 1000), finalized: true);
      expect(care.stars, 0);
      final second = payload(id: 'dddddddd-dddd-4ddd-8ddd-dddddddddddd')
        ..['endedAt'] = '2026-11-14T23:30:00Z';
      await care.saveSession(second, finalized: true);
      expect(care.stars, 1);
      expect(care.dates, {'2026-11-15'});
    },
  );
}

class PausedCredentials extends MemoryCredentials {
  final started = Completer<void>();
  final release = Completer<void>();
  PausedCredentials() : super(account());
  @override
  Future<void> write(String value) async {
    started.complete();
    await release.future;
    await super.write(value);
  }
}

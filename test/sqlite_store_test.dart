import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tooth_time/connection/records.dart';
import 'package:tooth_time/connection/store_native.dart';
import 'support/connection_fakes.dart';

void main() {
  test(
    'committed SQLite outbox survives reopen and isolates enrollment keys',
    () async {
      sqfliteFfiInit();
      final directory = await Directory.systemTemp.createTemp(
        'shudhen-store-test-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final dbPath = '${directory.path}/care.db';
      var store = SqliteSessionStore(
        factory: databaseFactoryFfi,
        databasePath: dbPath,
      );
      await store.open();
      final body = payload();
      await store.put(LocalSession(account().scope, body, 'pending'));
      await store.put(
        LocalSession(account(enrollment: enrollmentB).scope, body, 'draft'),
      );
      await store.close();
      store = SqliteSessionStore(
        factory: databaseFactoryFfi,
        databasePath: dbPath,
      );
      await store.open();
      expect((await store.all(account().scope)).single.payload, body);
      expect(
        (await store.all(account(enrollment: enrollmentB).scope)).single.state,
        'draft',
      );
      final row = (await store.all(account().scope)).single;
      await store.put(row.withState('synced'));
      await store.close();
      await store.open();
      final restored = (await store.all(account().scope)).single;
      expect(restored.state, 'synced');
      expect(restored.syncedAt, isNotNull);
      expect(
        (await store.all(account(enrollment: enrollmentB).scope)).single.state,
        'draft',
      );
      await store.close();
    },
  );
}

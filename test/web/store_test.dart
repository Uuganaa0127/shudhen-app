@TestOn('browser')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'package:tooth_time/connection/device_zone_web.dart';
import 'package:tooth_time/connection/records.dart';
import 'package:tooth_time/connection/store_web.dart';
import '../support/connection_fakes.dart';

void main() {
  test(
    'IndexedDB commit survives reopen and isolates identical UUIDs by scope',
    () async {
      final store = IndexedSessionStore();
      final scope = 'browser-test-${DateTime.now().microsecondsSinceEpoch}';
      final body = payload();
      await store.open();
      await store.put(LocalSession('$scope/A', body, 'pending'));
      await store.put(LocalSession('$scope/B', body, 'draft'));
      await store.close();
      await store.open();
      expect((await store.all('$scope/A')).single.payload, body);
      expect((await store.all('$scope/B')).single.state, 'draft');
      final row = (await store.all('$scope/A')).single;
      await store.put(row.withState('synced'));
      await store.close();
      await store.open();
      expect((await store.all('$scope/A')).single.syncedAt, isNotNull);
      expect((await store.all('$scope/B')).single.state, 'draft');
      await store.close();
    },
  );
  test('Browser Intl returns an IANA zone understood by the tracker', () async {
    tzdata.initializeTimeZones();
    final zone = await deviceTimeZone();
    expect(tz.getLocation(zone).name, zone);
  });
}

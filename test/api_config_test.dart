import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:tooth_time/connection/api.dart';
import 'support/connection_fakes.dart';

void main() {
  test('all builds default to the deployed hospital backend', () {
    for (final debug in [true, false]) {
      expect(resolveApiBase(configured: '', debug: debug), hospitalApiBase);
      expect(resolveApiBase(debug: debug), hospitalApiBase);
    }
  });
  test('local development is an explicit override', () {
    expect(
      resolveApiBase(explicit: 'http://localhost:8082/api/v1', debug: true),
      'http://localhost:8082/api/v1',
    );
    expect(
      resolveApiBase(explicit: 'http://10.0.2.2:8082/api/v1', debug: true),
      'http://10.0.2.2:8082/api/v1',
    );
  });
  test('explicit URL wins over compiled configuration and is normalized', () {
    expect(
      resolveApiBase(
        explicit: ' https://clinic.test/api/v1/// ',
        configured: 'https://another.test/api/v1',
        debug: false,
      ),
      'https://clinic.test/api/v1',
    );
    expect(
      resolveApiBase(
        configured: 'https://configured.test/api/v1',
        debug: false,
      ),
      'https://configured.test/api/v1',
    );
  });
  test('release requires HTTPS; unsafe URLs are rejected', () {
    for (final value in [
      'http://clinic.test/api/v1',
      'https://user:pass@clinic.test/api/v1',
      'https://clinic.test/api/v1?token=secret',
      'https://clinic.test/api/v1#fragment',
      'file:///tmp/api',
      'not a URL',
    ]) {
      expect(
        () => resolveApiBase(explicit: value, debug: false),
        throwsA(isA<ApiFailure>()),
      );
    }
  });
  test(
    'missing consent route is distinguishable from network failure',
    () async {
      final api = CareApi(
        baseUrl: testBase,
        client: MockClient((_) async => jsonReply({}, 404)),
      );
      addTearDown(api.close);
      await expectLater(
        api.request('GET', 'consent'),
        throwsA(
          isA<ApiFailure>()
              .having((e) => e.status, 'status', 404)
              .having(
                (e) => e.message,
                'message',
                contains('үйлчилгээ олдсонгүй'),
              ),
        ),
      );
    },
  );
}

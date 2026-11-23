import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tooth_time/connection/api.dart';
import 'package:tooth_time/connection/controller.dart';
import 'package:tooth_time/connection/credentials.dart';
import 'package:tooth_time/connection/records.dart';

const testBase = 'https://clinic.test/api/v1';
const enrollmentA = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
const enrollmentB = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
const sessionID = 'cccccccc-cccc-4ccc-8ccc-cccccccccccc';
Connection account({
  String enrollment = enrollmentA,
  String token = 'secret-token',
  DateTime? expiry,
}) => Connection(
  baseUrl: testBase,
  token: token,
  enrollmentId: enrollment,
  expiresAt: expiry ?? DateTime.now().add(const Duration(days: 5)),
  name: 'Саруул',
);

class MemoryCredentials implements CredentialStore {
  String? value;
  bool failWrite = false, failRead = false;
  MemoryCredentials([Connection? connection])
    : value = connection == null ? null : jsonEncode(connection.toJson());
  @override
  Future<String?> read() async {
    if (failRead) throw StateError('storage unavailable');
    return value;
  }

  @override
  Future<void> write(String value) async {
    if (failWrite) throw StateError('storage unavailable');
    this.value = value;
  }

  @override
  Future<void> clear() async {
    value = null;
  }
}

class MemorySessions implements SessionStore {
  final Map<String, Map<String, dynamic>> rows = {};
  bool failWrite = false;
  @override
  Future<void> open() async {}
  @override
  Future<void> close() async {}
  @override
  Future<List<LocalSession>> all(String scope) async => rows.values
      .map(
        (r) => LocalSession.fromRow(
          Map<String, dynamic>.from(jsonDecode(jsonEncode(r))),
        ),
      )
      .where((r) => r.scope == scope)
      .toList();
  @override
  Future<void> put(LocalSession row) async {
    if (failWrite) throw StateError('disk full');
    rows['${row.scope}#${row.id}'] = Map<String, dynamic>.from(
      jsonDecode(jsonEncode(row.toRow())),
    );
  }
}

Map<String, dynamic> payload({
  String id = sessionID,
  String status = 'COMPLETED',
  int activeMs = 30000,
}) {
  final end = DateTime.now().toUtc();
  return {
    'id': id,
    'startedAt': end.subtract(const Duration(minutes: 2)).toIso8601String(),
    'endedAt': end.toIso8601String(),
    'timeZone': 'Asia/Ulaanbaatar',
    'status': status,
    'sections': [
      for (int i = 0; i < 4; i++) {'index': i, 'activeMs': activeMs},
    ],
    'flossed': false,
  };
}

http.Response jsonReply(Object value, [int status = 200]) => http.Response(
  jsonEncode(value),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);
http.Response defaultReply(
  http.Request request, {
  String enrollment = enrollmentA,
}) {
  if (request.url.path.endsWith('/consent')) {
    return jsonReply({
      'version': 'shudhen-care-v1',
      'text': 'Мэдээлэл хуваалцах зөвшөөрөл',
    });
  }
  if (request.url.path.endsWith('/exchange')) {
    return jsonReply({
      'accessToken': 'new-secret',
      'device': {
        'enrollmentId': enrollment,
        'expiresAt': DateTime.now()
            .add(const Duration(days: 30))
            .toUtc()
            .toIso8601String(),
      },
    }, 201);
  }
  if (request.url.path.endsWith('/me')) {
    return jsonReply({
      'firstName': 'Саруул',
      'birthDate': '2020-05-10T00:00:00Z',
      'device': {'enrollmentId': enrollment},
    });
  }
  if (request.url.path.endsWith('/sessions') && request.method == 'POST') {
    final body = jsonDecode(request.body) as Map<String, dynamic>;
    return jsonReply({...body, 'enrollmentId': enrollment}, 201);
  }
  return http.Response('', 204);
}

CareController testController({
  MemoryCredentials? credentials,
  MemorySessions? store,
  Future<http.Response> Function(http.Request)? respond,
}) => CareController(
  api: CareApi(
    baseUrl: testBase,
    client: MockClient(respond ?? (r) async => defaultReply(r)),
  ),
  credentials: credentials ?? MemoryCredentials(account()),
  store: store ?? MemorySessions(),
);

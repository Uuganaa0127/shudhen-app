import 'dart:convert';
import 'package:timezone/timezone.dart' as tz;

class LocalSession {
  final String scope;
  final Map<String, dynamic> payload;
  final String state; // draft, pending, synced, blocked
  final String? problem;
  final DateTime? syncedAt;
  const LocalSession(
    this.scope,
    this.payload,
    this.state, [
    this.problem,
    this.syncedAt,
  ]);
  String get id => payload['id'] as String;
  bool get targetMet =>
      payload['status'] == 'COMPLETED' &&
      (payload['sections'] as List).length == 4 &&
      (payload['sections'] as List).every(
        (s) => (s['activeMs'] as num) >= 30000,
      );
  String get date {
    final time = DateTime.parse(payload['endedAt'] as String);
    try {
      final local = tz.TZDateTime.from(
        time,
        tz.getLocation(payload['timeZone'] as String),
      );
      return local.toIso8601String().substring(0, 10);
    } catch (_) {
      return time.toUtc().toIso8601String().substring(0, 10);
    }
  }

  Map<String, dynamic> toRow() => {
    'id': id,
    'scope': scope,
    'payload': jsonEncode(payload),
    'state': state,
    'problem': problem,
    'synced_at': syncedAt?.toUtc().toIso8601String(),
  };
  factory LocalSession.fromRow(Map<String, dynamic> row) => LocalSession(
    row['scope'] as String,
    Map<String, dynamic>.from(jsonDecode(row['payload'] as String)),
    row['state'] as String,
    row['problem'] as String?,
    DateTime.tryParse(row['synced_at'] as String? ?? ''),
  );
  LocalSession withState(String value, [String? error]) => LocalSession(
    scope,
    payload,
    value,
    error,
    value == 'synced' ? DateTime.now().toUtc() : syncedAt,
  );
}

abstract class SessionStore {
  Future<void> open();
  Future<List<LocalSession>> all(String scope);
  Future<void> put(LocalSession row);
  Future<void> close();
}

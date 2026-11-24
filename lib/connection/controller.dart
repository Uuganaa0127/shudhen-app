import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'api.dart';
import 'credentials.dart';
import 'records.dart';

class Connection {
  final String baseUrl, token, enrollmentId, name;
  final DateTime expiresAt;
  final DateTime? birthDate;
  const Connection({
    required this.baseUrl,
    required this.token,
    required this.enrollmentId,
    required this.expiresAt,
    this.name = 'Бяцхан найз',
    this.birthDate,
  });
  String get scope => '$baseUrl#$enrollmentId';
  Map<String, dynamic> toJson() => {
    'baseUrl': baseUrl,
    'token': token,
    'enrollmentId': enrollmentId,
    'expiresAt': expiresAt.toUtc().toIso8601String(),
    'name': name,
    'birthDate': birthDate?.toIso8601String(),
  };
  factory Connection.fromJson(Map<String, dynamic> json) => Connection(
    baseUrl: json['baseUrl'] as String,
    token: json['token'] as String,
    enrollmentId: json['enrollmentId'] as String,
    expiresAt: DateTime.parse(json['expiresAt'] as String),
    name: json['name'] as String? ?? 'Бяцхан найз',
    birthDate: DateTime.tryParse(json['birthDate'] as String? ?? ''),
  );
  int? ageAt(DateTime now) {
    final birth = birthDate;
    if (birth == null) return null;
    var age = now.year - birth.year;
    if (now.month < birth.month ||
        (now.month == birth.month && now.day < birth.day)) {
      age--;
    }
    return age < 0 ? null : age;
  }
}

class CareController extends ChangeNotifier {
  final CareApi api;
  final CredentialStore credentials;
  final SessionStore store;
  Connection? connection;
  List<LocalSession> records = [];
  Map<String, dynamic> rewards = {};
  bool needsRelink = false, syncing = false;
  String? syncMessage;
  DateTime? lastSync;
  Future<void>? _syncTask;
  Future<void> _writes = Future.value();
  bool _disposed = false, _leaving = false;
  CareController({
    required this.api,
    required this.credentials,
    required this.store,
  });
  void changed() {
    if (!_disposed) notifyListeners();
  }

  int get pending => records.where((r) => r.state == 'pending').length;
  int get blocked => records.where((r) => r.state == 'blocked').length;
  int get stars =>
      records.where((r) => r.state != 'draft' && r.targetMet).length;
  Set<String> get dates => records
      .where((r) => r.state != 'draft' && r.targetMet)
      .map((r) => r.date)
      .toSet();

  Future<void> initialize() async {
    tzdata.initializeTimeZones();
    await store.open();
    final saved = await credentials.read();
    if (saved != null) {
      final value = Connection.fromJson(
        Map<String, dynamic>.from(jsonDecode(saved)),
      );
      // A dev/prod switch must never leak a device token to a different server.
      if (value.baseUrl == api.baseUrl) {
        connection = value;
        needsRelink = !value.expiresAt.isAfter(DateTime.now());
        await _loadRewards(value.scope);
        await _recover(value.scope);
        records = await store.all(value.scope);
        _restoreLastSync();
      }
    }
    changed();
  }

  Future<void> _recover(String scope) async {
    for (final row in await store.all(scope)) {
      if (row.state == 'draft') {
        // End at the last durable checkpoint, not at this later app launch.
        await store.put(
          LocalSession(scope, {
            ...row.payload,
            'status': 'INTERRUPTED',
          }, 'pending'),
        );
      }
    }
  }

  void _restoreLastSync() {
    final times = records.map((r) => r.syncedAt).whereType<DateTime>().toList()
      ..sort();
    lastSync = times.isEmpty ? null : times.last;
  }

  Future<Map<String, dynamic>> consent() => api.request('GET', 'consent');

  Future<void> link({
    required String invitation,
    required String guardianName,
    required String relationship,
    required String deviceName,
    required String consentVersion,
  }) async {
    if (_leaving) {
      throw const ApiFailure('Гарч дууссаны дараа дахин оролдоно уу.');
    }
    // Do not swap identities underneath a running sync batch.
    await _syncTask;
    final response = await api.request(
      'POST',
      'exchange',
      body: {
        'token': invitation.trim(),
        'guardianName': guardianName.trim(),
        'guardianRelationship': relationship.trim(),
        'deviceName': deviceName.trim(),
        'consentVersion': consentVersion,
        'consentAccepted': true,
      },
    );
    final device = response['device'] as Map<String, dynamic>;
    final next = Connection(
      baseUrl: api.baseUrl,
      token: response['accessToken'] as String,
      enrollmentId: device['enrollmentId'] as String,
      expiresAt: DateTime.parse(device['expiresAt'] as String),
    );
    // Persist before /me: a dropped profile request must not lose a consumed invite.
    try {
      await _write(() async {
        await credentials.write(jsonEncode(next.toJson()));
        connection = next;
      });
    } catch (_) {
      try {
        await api.request('POST', 'logout', token: next.token);
      } catch (_) {}
      rethrow;
    }
    needsRelink = false;
    syncMessage = null;
    lastSync = null;
    await _loadRewards(next.scope);
    await _recover(next.scope);
    records = await store.all(next.scope);
    _restoreLastSync();
    changed();
    await refreshProfile();
    await sync();
  }

  Future<void> _loadRewards(String scope) async {
    rewards = {};
    try {
      final prefs = await SharedPreferences.getInstance();
      final value = prefs.getString('care.rewards:$scope');
      if (connection?.scope == scope && value != null) {
        rewards = Map<String, dynamic>.from(jsonDecode(value));
      }
    } catch (_) {
      /* A cache failure must not block linking or session recovery. */
    }
  }

  Future<void> refreshProfile() async {
    final account = connection;
    if (account == null || needsRelink || _leaving) return;
    try {
      final data = await api.request('GET', 'me', token: account.token);
      final device = data['device'] as Map<String, dynamic>;
      if (device['enrollmentId'] != account.enrollmentId) {
        throw const ApiFailure('Хүүхдийн холбоосын мэдээлэл зөрж байна.');
      }
      if (connection != account || _leaving) return;
      final next = Connection(
        baseUrl: account.baseUrl,
        token: account.token,
        enrollmentId: account.enrollmentId,
        expiresAt: account.expiresAt,
        name: data['firstName'] as String? ?? 'Бяцхан найз',
        birthDate: DateTime.tryParse(data['birthDate'] as String? ?? ''),
      );
      await _write(() async {
        if (connection?.token != account.token || _leaving) return;
        await credentials.write(jsonEncode(next.toJson()));
        if (!_leaving) {
          connection = next;
          rewards = Map<String, dynamic>.from(data['rewards'] as Map? ?? {});
          try {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString(
              'care.rewards:${account.scope}',
              jsonEncode(rewards),
            );
          } catch (_) {
            /* Session delivery must not depend on the gift cache. */
          }
        }
      });
      changed();
    } on ApiFailure catch (error) {
      if (connection?.token == account.token) {
        if (error.status == 401) needsRelink = true;
        syncMessage = error.message;
        changed();
      }
    }
  }

  // Serialize checkpoints, finalization and sync acknowledgements. A late draft
  // write cannot overwrite an already finalized or acknowledged session.
  Future<void> _write(Future<void> Function() action) {
    final task = _writes.then((_) => action());
    _writes = task.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return task;
  }

  Future<void> saveSession(
    Map<String, dynamic> payload, {
    required bool finalized,
  }) {
    final account = connection;
    if (account == null || _leaving) throw StateError('No connected child');
    final frozen = Map<String, dynamic>.from(jsonDecode(jsonEncode(payload)));
    return _write(() async {
      final rows = await store.all(account.scope);
      final matches = rows.where((r) => r.id == frozen['id']);
      if (matches.isNotEmpty && matches.first.state != 'draft') return;
      await store.put(
        LocalSession(account.scope, frozen, finalized ? 'pending' : 'draft'),
      );
      if (connection?.scope == account.scope) {
        records = await store.all(account.scope);
        changed();
      }
    });
  }

  Future<void> sync() {
    if (_syncTask != null) return _syncTask!;
    final task = _sync();
    _syncTask = task;
    return task.whenComplete(() {
      _syncTask = null;
    });
  }

  Future<void> _sync() async {
    final account = connection;
    if (account == null || _leaving || needsRelink) return;
    if (!account.expiresAt.isAfter(DateTime.now())) {
      needsRelink = true;
      changed();
      return;
    }
    syncing = true;
    changed();
    try {
      await _writes;
      final queue = (await store.all(
        account.scope,
      )).where((r) => r.state == 'pending').toList();
      for (final row in queue) {
        if (_leaving || connection?.token != account.token) break;
        try {
          final receipt = await api.request(
            'POST',
            'sessions',
            token: account.token,
            body: row.payload,
          );
          if (receipt['id'] != row.id ||
              receipt['enrollmentId'] != account.enrollmentId) {
            throw const ApiFailure(
              'Серверийн баталгаажуулалт зөрж байна. Бүртгэл утсанд хадгалагдсан.',
            );
          }
          // If this commit fails, retain pending: the next upload uses the same UUID.
          await _write(() => store.put(row.withState('synced')));
          lastSync = DateTime.now();
          syncMessage = null;
        } on ApiFailure catch (error) {
          syncMessage = error.message;
          if (error.status == 401) {
            needsRelink = true;
            break;
          }
          if (error.status == 400 ||
              error.status == 409 ||
              error.status == 413) {
            await _write(
              () => store.put(row.withState('blocked', error.message)),
            );
            continue; // One rejected record must not starve the whole queue.
          }
          break; // Network/5xx/429: retry on resume, timer or explicit action.
        }
      }
      if (!_leaving && !needsRelink && connection?.token == account.token) {
        await refreshProfile();
      }
    } catch (_) {
      syncMessage =
          'Дамжуулалтыг дуусгаж чадсангүй. Бүртгэл утсанд хадгалагдсан.';
    } finally {
      try {
        if (connection?.scope == account.scope) {
          records = await store.all(account.scope);
        }
      } catch (_) {
        syncMessage = 'Утасны бүртгэлийг нээж чадсангүй. Дахин оролдоно уу.';
      }
      syncing = false;
      changed();
    }
  }

  Future<void> disconnect() async {
    final account = connection;
    if (account == null) return;
    _leaving = true;
    try {
      await _syncTask;
      await _writes;
      // Clear local credentials even when the network is unavailable.
      await _write(() async {
        await credentials.clear();
        connection = null;
        rewards = {};
      });
      records = [];
      needsRelink = false;
      lastSync = null;
      syncMessage = null;
      changed();
      try {
        await api.request('POST', 'logout', token: account.token);
      } catch (_) {
        syncMessage =
            'Утаснаас гарлаа. Серверийн эрхийг цуцалж чадсангүй; эмнэлгээс төхөөрөмжөө салгуулна уу.';
      }
    } finally {
      _leaving = false;
      changed();
    }
  }

  static String validZone(String zone) {
    try {
      tz.getLocation(zone);
      return zone;
    } catch (_) {
      return 'UTC';
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _leaving = true;
    // Widgets may unmount during an upload; finish local writes before closing.
    unawaited(() async {
      await _syncTask;
      await _writes;
      await store.close();
      api.close();
    }());
    super.dispose();
  }
}

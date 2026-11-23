import 'dart:async';
import 'dart:js_interop';
import 'package:web/web.dart' as web;
import 'records.dart';

SessionStore createStore() => IndexedSessionStore();

class IndexedSessionStore implements SessionStore {
  web.IDBDatabase? _db;
  @override
  Future<void> open() async {
    final ready = Completer<void>();
    final request = web.window.indexedDB.open('shudhen-care', 1);
    request.onupgradeneeded = ((web.Event event) {
      final db = request.result as web.IDBDatabase;
      db.createObjectStore(
        'sessions',
        web.IDBObjectStoreParameters(keyPath: 'key'.toJS),
      );
    }).toJS;
    request.onsuccess = ((web.Event event) {
      final db = request.result as web.IDBDatabase;
      if (ready.isCompleted) {
        db.close();
        return;
      }
      _db = db;
      ready.complete();
    }).toJS;
    void failed(web.Event _) {
      if (!ready.isCompleted) {
        ready.completeError(StateError('IndexedDB unavailable'));
      }
    }

    request.onerror = failed.toJS;
    request.onblocked = failed.toJS;
    await ready.future;
  }

  Future<void> committed(web.IDBTransaction tx) {
    final ready = Completer<void>();
    tx.oncomplete = ((web.Event _) {
      if (!ready.isCompleted) ready.complete();
    }).toJS;
    void failed(web.Event _) {
      if (!ready.isCompleted) {
        ready.completeError(StateError('IndexedDB transaction failed'));
      }
    }

    tx.onabort = failed.toJS;
    tx.onerror = failed.toJS;
    return ready.future;
  }

  @override
  Future<List<LocalSession>> all(String scope) async {
    final tx = _db!.transaction('sessions'.toJS, 'readonly');
    final done = committed(tx);
    final request = tx.objectStore('sessions').getAll();
    List<dynamic> rows = [];
    request.onsuccess = ((web.Event _) {
      rows = request.result.dartify() as List;
    }).toJS;
    await done;
    return rows
        .map((r) => LocalSession.fromRow(Map<String, dynamic>.from(r as Map)))
        .where((r) => r.scope == scope)
        .toList();
  }

  @override
  Future<void> put(LocalSession row) async {
    final tx = _db!.transaction(
      'sessions'.toJS,
      'readwrite',
      web.IDBTransactionOptions(durability: 'strict'),
    );
    final done = committed(tx);
    tx
        .objectStore('sessions')
        .put({...row.toRow(), 'key': '${row.scope}#${row.id}'}.jsify());
    await done;
  }

  @override
  Future<void> close() async => _db?.close();
}

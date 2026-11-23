import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';
import 'records.dart';

SessionStore createStore() => SqliteSessionStore();

class SqliteSessionStore implements SessionStore {
  final DatabaseFactory factory;
  final String? databasePath;
  SqliteSessionStore({DatabaseFactory? factory, this.databasePath})
    : factory = factory ?? databaseFactory;
  Database? _db;
  @override
  Future<void> open() async {
    _db = await factory.openDatabase(
      databasePath ??
          path.join(await factory.getDatabasesPath(), 'shudhen_care.db'),
      options: OpenDatabaseOptions(
        version: 1,
        onConfigure: (db) => db.execute('PRAGMA synchronous = FULL'),
        onCreate: (db, _) async {
          await db.execute(
            'CREATE TABLE sessions (id TEXT NOT NULL, scope TEXT NOT NULL, '
            'payload TEXT NOT NULL, state TEXT NOT NULL, problem TEXT, '
            'synced_at TEXT, PRIMARY KEY(scope, id))',
          );
          await db.execute('CREATE INDEX sessions_scope ON sessions(scope)');
        },
      ),
    );
  }

  @override
  Future<List<LocalSession>> all(String scope) async => (await _db!.query(
    'sessions',
    where: 'scope = ?',
    whereArgs: [scope],
  )).map(LocalSession.fromRow).toList();
  @override
  Future<void> put(LocalSession row) async {
    // Await the SQLite transaction commit before the UI confirms completion.
    await _db!.transaction((tx) async {
      await tx.insert(
        'sessions',
        row.toRow(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
  }

  @override
  Future<void> close() async => _db?.close();
}

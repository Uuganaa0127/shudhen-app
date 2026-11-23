import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract class CredentialStore {
  Future<String?> read();
  Future<void> write(String value);
  Future<void> clear();
}

class SecureCredentials implements CredentialStore {
  static const _key = 'shudhen.connection.v1';
  final FlutterSecureStorage storage;
  SecureCredentials({FlutterSecureStorage? storage})
    : storage =
          storage ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions(resetOnError: false),
          );
  @override
  Future<String?> read() => storage.read(key: _key);
  @override
  Future<void> write(String value) async {
    await storage.write(key: _key, value: value);
    if (await read() != value) throw StateError('Credential was not persisted');
  }

  @override
  Future<void> clear() async {
    await storage.delete(key: _key);
    if (await read() != null) throw StateError('Credential was not removed');
  }
}

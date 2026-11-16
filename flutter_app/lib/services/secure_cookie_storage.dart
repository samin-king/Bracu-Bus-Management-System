import 'dart:convert';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// CookieJar storage backed by Android Keystore protected storage.
/// Prefixes isolate auth cookies from any other module's secure values.
class SecureCookieStorage implements Storage {
  SecureCookieStorage(this.storage, {required String origin})
    : _prefix = 'bracu.auth.${base64Url.encode(utf8.encode(origin))}.';

  final FlutterSecureStorage storage;
  final String _prefix;

  @override
  Future<void> init(bool persistSession, bool ignoreExpires) async {}

  @override
  Future<String?> read(String key) => storage.read(key: '$_prefix$key');

  @override
  Future<void> write(String key, String value) =>
      storage.write(key: '$_prefix$key', value: value);

  @override
  Future<void> delete(String key) => storage.delete(key: '$_prefix$key');

  @override
  Future<void> deleteAll(List<String> keys) async {
    final values = await storage.readAll();
    for (final key
        in values.keys.where((key) => key.startsWith(_prefix)).toList()) {
      await storage.delete(key: key);
    }
  }
}

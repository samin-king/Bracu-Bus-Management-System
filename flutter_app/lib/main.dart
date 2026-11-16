import 'package:cookie_jar/cookie_jar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'app.dart';
import 'providers/auth_provider.dart';
import 'services/auth_config.dart';
import 'services/auth_failure.dart';
import 'services/auth_service.dart';
import 'services/secure_cookie_storage.dart';
import 'services/session_http_client.dart';
import 'theme/app_theme.dart';
export 'app.dart' show TransportApp;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    final config = AuthConfig.fromEnvironment();
    final cookies = PersistCookieJar(
      persistSession: false,
      ignoreExpires: false,
      deleteHostCookiesWhenLoadFailed: false,
      storage: SecureCookieStorage(
        const FlutterSecureStorage(),
        origin: config.api.origin,
      ),
    );
    final client = SessionHttpClient(config: config, cookies: cookies);
    runApp(
      TransportApp(auth: AuthProvider(AuthService(client)), ownsAuth: true),
    );
  } on AuthFailure catch (failure) {
    runApp(
      MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(
          body: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(failure.message),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

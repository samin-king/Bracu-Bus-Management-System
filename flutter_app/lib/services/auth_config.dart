import 'auth_failure.dart';

class AuthConfig {
  AuthConfig({
    required String apiOrigin,
    required String frontendOrigin,
    String? googleCallbackUrl,
    this.allowLocalHttp = false,
  }) {
    try {
      api = _origin(apiOrigin);
      frontend = _origin(frontendOrigin);
      if (googleCallbackUrl != null && googleCallbackUrl.isNotEmpty) {
        callback = Uri.parse(googleCallbackUrl);
        if (callback!.scheme != 'https' ||
            callback!.port != 443 ||
            callback!.origin != api.origin ||
            callback!.userInfo.isNotEmpty ||
            callback!.path != '/api/auth/google/callback' ||
            callback!.hasQuery ||
            callback!.hasFragment) {
          throw const AuthFailure('configuration');
        }
      }
    } on FormatException {
      throw const AuthFailure('configuration');
    }
  }

  factory AuthConfig.fromEnvironment() => AuthConfig(
    apiOrigin: const String.fromEnvironment('AUTH_API_ORIGIN'),
    frontendOrigin: const String.fromEnvironment('AUTH_FRONTEND_ORIGIN'),
    googleCallbackUrl: const String.fromEnvironment('AUTH_CALLBACK_URL'),
    // Release builds always require HTTPS. This opt-in is emulator development only.
    allowLocalHttp:
        !const bool.fromEnvironment('dart.vm.product') &&
        const bool.fromEnvironment('AUTH_ALLOW_LOCAL_HTTP'),
  );

  final bool allowLocalHttp;
  late final Uri api, frontend;
  Uri? callback;
  Uri _origin(String value) {
    final uri = Uri.parse(value);
    final local = {
      'localhost',
      '127.0.0.1',
      '10.0.2.2',
      '::1',
    }.contains(uri.host);
    if ((uri.scheme != 'https' &&
            !(allowLocalHttp && local && uri.scheme == 'http')) ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        (uri.path.isNotEmpty && uri.path != '/')) {
      throw const AuthFailure('configuration');
    }
    return Uri.parse(uri.origin);
  }
}

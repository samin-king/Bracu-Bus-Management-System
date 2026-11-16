import 'package:flutter/services.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'auth_failure.dart';

abstract interface class OAuthBrowser {
  Future<Uri> authenticate(Uri authorizationUrl, Uri callback);
}

class AndroidOAuthBrowser implements OAuthBrowser {
  @override
  Future<Uri> authenticate(Uri authorizationUrl, Uri callback) async {
    try {
      final result = await FlutterWebAuth2.authenticate(
        url: authorizationUrl.toString(),
        callbackUrlScheme: callback.scheme,
        options: FlutterWebAuth2Options(
          httpsHost: callback.host,
          httpsPath: callback.path,
        ),
      );
      return Uri.parse(result);
    } on PlatformException catch (error) {
      throw AuthFailure(
        error.code == 'CANCELED' ? 'cancelled' : 'browser_unavailable',
      );
    } on FormatException {
      throw const AuthFailure('invalid_callback');
    }
  }
}

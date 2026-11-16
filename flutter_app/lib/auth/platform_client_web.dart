import 'package:http/browser_client.dart';
import 'package:http/http.dart' as http;
import 'package:web/web.dart' as web;

http.Client createSessionClient() => BrowserClient()..withCredentials = true;
bool openLogin(String url) {
  web.window.location.assign(url);
  return true;
}

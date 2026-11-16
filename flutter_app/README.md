# BRACU Transport Android frontend

See [Member 3 — Flutter Contribution](../README.md) for the complete feature
list, file inventory, API contracts, authentication integration and verification.

This app reuses ../server. Standalone launch starts signed out; the parent
application must supply a verified TransportSession after login.

```powershell
flutter pub get
flutter analyze
flutter test
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000/api
```

Android SDK and a device/emulator are required for flutter run. Debug builds
allow HTTP for local development; release builds require an HTTPS API.

# Native Android setup

Inspected 16 November 2026. No app source or database changes made.

## Verified environment

- Flutter: `D:\Bracubus\.local\flutter\bin\flutter.bat`.
- Android SDK location now configured in Flutter:
  `D:\Bracubus\.local\android-sdk`.
- Official Google command-line tools 15859902 downloaded, SHA-256 matched
  Google's published checksum, and installed under `cmdline-tools/latest`.
- Latest doctor/devices checks still show no usable Android toolchain or
  Android device; command-line tools alone are insufficient without Java,
  platform-tools, and a platform package.
- Android Studio and Java not found in checked standard locations or PATH.
- Intel Core i5-1135G7; firmware virtualization and SLAT enabled.
- HypervisorPresent is false. Windows Hypervisor Platform feature status could
  not be queried without an administrator prompt; no feature changes made.
- RAM: 15.7 GB; initial free space on D: approximately 80.7 GB.

## Android Studio installation (user interaction)

1. Visit https://developer.android.com/studio and choose the stable Windows
   installer. Review and accept the download license yourself.
2. Run the installer. Choose Next, retain Android Studio and Android Virtual
   Device components when offered, then Next, Install, Next, Finish.
3. In the setup wizard choose Custom, then use SDK location
   `D:\Bracubus\.local\android-sdk`. Review licenses and finish installation.
4. If the wizard cannot set the SDK location, at the Welcome screen choose
   More Actions > SDK Manager. Set Android SDK Location to the requested path.

## SDK Manager

In SDK Platforms, select Android API 36 (Android 16). In SDK Tools, enable
Show Package Details and select:

- Android SDK Command-line Tools (latest)
- Android SDK Platform-Tools
- Android Emulator
- Android SDK Build-Tools 36.0.0
- NDK (Side by side) > 28.2.13676358

Click Apply, review the changes (no removals), click OK, review the licenses,
and click Finish after downloads complete.

An optional interactive PowerShell helper is prepared at
`../.local/android-downloads/Install-BracuAndroidSdk.ps1`; it requires Android
Studio's JDK and extracted command-line tools. It installs the above components
plus the Google APIs API 36 x86_64 system image, and prompts for license review.
It does not enable Windows features or reboot.

## Emulator

After approval, inspect Windows Hypervisor Platform. If it needs enabling,
open Turn Windows features on or off, check Windows Hypervisor Platform, and
click OK. Restart only after saving work and explicitly agreeing to restart.

In Android Studio Welcome > More Actions > Virtual Device Manager (or open
project > Tools > Device Manager), click + / Create Device. Choose a phone
such as Pixel 6, Next, select API 36 Google APIs with ABI x86_64 (download if
necessary), Next, name it BRACU_API_36, then Finish. Click its Play button.

## Native launch after setup

Run from `D:\Bracubus\flutter_app`:

```powershell
& 'D:\Bracubus\.local\flutter\bin\flutter.bat' config --android-sdk 'D:\Bracubus\.local\android-sdk' --jdk-dir 'C:\Program Files\Android\Android Studio\jbr'
& 'D:\Bracubus\.local\flutter\bin\flutter.bat' doctor -v
& 'D:\Bracubus\.local\flutter\bin\flutter.bat' devices
& 'D:\Bracubus\.local\flutter\bin\flutter.bat' emulators
& 'D:\Bracubus\.local\flutter\bin\flutter.bat' run -d emulator-5554 --target lib/main.dart --dart-define=API_BASE_URL=http://10.0.2.2:3000/api
```

Use the actual emulator ID printed by devices. The real entry point starts
signed out. This setup does not implement authentication or use fixture data.

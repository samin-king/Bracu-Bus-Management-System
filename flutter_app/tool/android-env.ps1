# Dot-source from PowerShell: . ./tool/android-env.ps1
# Only changes the current shell. SDKs and Gradle caches remain ignored.
[CmdletBinding()]
param(
    [string]$FlutterSdk,
    [string]$AndroidSdk,
    [string]$JavaSdk
)

$repositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$toolchainRoot = Join-Path $repositoryRoot '.local/android-toolchain'

if (-not $FlutterSdk) {
    $flutterCommand = Get-Command flutter -ErrorAction SilentlyContinue
    if ($flutterCommand) {
        $FlutterSdk = Split-Path (Split-Path $flutterCommand.Source -Parent) -Parent
    } else {
        $FlutterSdk = Join-Path (Split-Path $repositoryRoot -Parent) 'Bracubus/.local/flutter'
    }
}
if (-not $AndroidSdk) {
    $AndroidSdk = if ($env:ANDROID_HOME) { $env:ANDROID_HOME }
        elseif ($env:ANDROID_SDK_ROOT) { $env:ANDROID_SDK_ROOT }
        else { Join-Path $toolchainRoot 'sdk' }
}
if (-not $JavaSdk) {
    $JavaSdk = $env:JAVA_HOME
    if (-not $JavaSdk) {
        $portableJava = Get-ChildItem (Join-Path $toolchainRoot 'java') -Directory -ErrorAction SilentlyContinue |
            Where-Object { Test-Path (Join-Path $_.FullName 'bin/java.exe') } |
            Select-Object -First 1
        if ($portableJava) { $JavaSdk = $portableJava.FullName }
    }
}
foreach ($requiredTool in @(
    (Join-Path $FlutterSdk 'bin/flutter.bat'),
    (Join-Path $AndroidSdk 'cmdline-tools/latest/bin/sdkmanager.bat')
)) {
    if (-not (Test-Path -LiteralPath $requiredTool)) { throw "Missing tool: $requiredTool" }
}
if (-not $JavaSdk -or -not (Test-Path (Join-Path $JavaSdk 'bin/java.exe'))) {
    throw 'Set JAVA_HOME or pass -JavaSdk with an installed JDK 21 directory.'
}
$env:JAVA_HOME = (Resolve-Path $JavaSdk).Path
$env:ANDROID_HOME = (Resolve-Path $AndroidSdk).Path
$env:ANDROID_SDK_ROOT = $env:ANDROID_HOME
$env:GRADLE_USER_HOME = Join-Path $toolchainRoot 'gradle'
$env:Path = @(
    (Join-Path $FlutterSdk 'bin'),
    (Join-Path $env:JAVA_HOME 'bin'),
    (Join-Path $env:ANDROID_HOME 'platform-tools'),
    (Join-Path $env:ANDROID_HOME 'emulator'),
    (Join-Path $env:ANDROID_HOME 'cmdline-tools/latest/bin'),
    $env:Path
) -join ';'
Write-Host 'Android build environment configured for this PowerShell session.'

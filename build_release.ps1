# Release APK და App Bundle (Play Store). საჭიროა Flutter PATH-ში.
$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

Write-Host "flutter pub get..."
flutter pub get

Write-Host "flutter analyze..."
flutter analyze

Write-Host "Building app-release.apk..."
flutter build apk --release

Write-Host "Building app-release.aab..."
flutter build appbundle --release

Write-Host "Done:"
Write-Host "  build\app\outputs\flutter-apk\app-release.apk"
Write-Host "  build\app\outputs\bundle\release\app-release.aab"

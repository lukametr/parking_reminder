# Release signing (do not commit the keystore)

1. Generate an upload keystore locally:

```bash
keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

2. Copy `android/key.properties.example` to `android/key.properties` and fill paths/passwords.

3. `android/key.properties` and `*.jks` are gitignored.

4. Build: `flutter build appbundle --release --dart-define=MAPS_API_KEY=YOUR_ROTATED_KEY`

A debug-signed bundle will be rejected by Play. Keep the upload key in a password manager — losing it blocks updates.

/// Maps/Places SDK key.
/// Prefer `--dart-define=MAPS_API_KEY=...` / GitHub secret after rotation.
/// The default is the already-public GitHub key so Places work until LM rotates.
class MapsConfig {
  static const String apiKey = String.fromEnvironment(
    'MAPS_API_KEY',
    defaultValue: 'AIzaSyDm_j_wiq5Y45WT8X-JvJ007PiQ7Emk0Pw',
  );

  static bool get isConfigured => apiKey.isNotEmpty;
}

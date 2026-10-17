/// Maps/Places key from `--dart-define=MAPS_API_KEY=...`.
/// Do not hardcode keys; the previous key was public on GitHub and must be rotated.
class MapsConfig {
  static const String apiKey = String.fromEnvironment('MAPS_API_KEY');

  static bool get isConfigured => apiKey.isNotEmpty;
}

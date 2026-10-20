/// Maps/Places SDK key from `--dart-define=MAPS_API_KEY=...` or
/// `--dart-define-from-file` (CI secret / gitignored local.properties).
/// Do not put the key in git-tracked source.
class MapsConfig {
  static const String apiKey = String.fromEnvironment('MAPS_API_KEY');

  static bool get isConfigured => apiKey.isNotEmpty;
}

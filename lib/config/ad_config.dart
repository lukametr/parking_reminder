import 'package:flutter/foundation.dart';

/// Banner uses the real AdMob unit from `main`. Interstitial stays on Google
/// **test** IDs in debug. Release does not serve a placeholder/test interstitial
/// (Play/AdMob ban risk) until LM creates a real unit in AdMob Console.
class AdConfig {
  static const String adMobAppId = 'ca-app-pub-8872582533953072~4948596381';
  static const String bannerAdUnitId = 'ca-app-pub-8872582533953072/4282381975';
  static const String interstitialAdUnitId =
      'ca-app-pub-8872582533953072/0000000000';

  static const String testBannerAdUnitId =
      'ca-app-pub-3940256099942544/6300978111';
  static const String testInterstitialAdUnitId =
      'ca-app-pub-3940256099942544/1033173712';

  static String get bannerId => bannerAdUnitId;

  static String? get interstitialId {
    if (kDebugMode) return testInterstitialAdUnitId;
    if (interstitialAdUnitId.contains('0000000000')) return null;
    return interstitialAdUnitId;
  }
}

import 'package:flutter/foundation.dart';

/// AdMob IDs. App ID uses `~`; ad units use `/`.
/// Interstitial unit is public by design and is committed.
class AdConfig {
  static const String adMobAppId = 'ca-app-pub-8872582533953072~4948596381';
  static const String bannerAdUnitId = 'ca-app-pub-8872582533953072/4282381975';
  static const String interstitialAdUnitId =
      'ca-app-pub-8872582533953072/1616568991';

  static const String testBannerAdUnitId =
      'ca-app-pub-3940256099942544/6300978111';
  static const String testInterstitialAdUnitId =
      'ca-app-pub-3940256099942544/1033173712';

  /// Google sample interstitial — debug only. Release always uses the real unit.
  static const bool useGoogleTestInterstitial = kDebugMode;

  static String get bannerId => bannerAdUnitId;

  static String get interstitialId {
    if (useGoogleTestInterstitial) return testInterstitialAdUnitId;
    return interstitialAdUnitId;
  }
}

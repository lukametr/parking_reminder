import 'package:flutter/foundation.dart';

/// AdMob IDs for `com.lukacode.sosapp`. App ID uses `~`; ad units use `/`.
/// Release builds use the real units; debug builds use Google's sample units.
class AdConfig {
  static const String adMobAppId = 'ca-app-pub-8872582533953072~4948596381';

  /// Must be a Banner-format unit. Empty means no banner in release builds.
  static const String bannerAdUnitId = 'ca-app-pub-8872582533953072/5359269234';
  static const String interstitialAdUnitId =
      'ca-app-pub-8872582533953072/1616568991';

  static const String testBannerAdUnitId =
      'ca-app-pub-3940256099942544/6300978111';
  static const String testInterstitialAdUnitId =
      'ca-app-pub-3940256099942544/1033173712';

  static const bool useTestAds = kDebugMode;

  static String? get bannerId {
    if (useTestAds) return testBannerAdUnitId;
    return bannerAdUnitId.isEmpty ? null : bannerAdUnitId;
  }

  static String get interstitialId =>
      useTestAds ? testInterstitialAdUnitId : interstitialAdUnitId;
}

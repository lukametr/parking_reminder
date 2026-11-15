/// AdMob IDs for Parking Reminder+ (`com.lukacode.sosapp`) only.
/// App ID uses `~`; ad units use `/`.
///
/// Policy: Banner only. Interstitial / App Open / Rewarded are disabled —
/// opening Services/Resources must not show a full-screen ad.
class AdConfig {
  static const String adMobAppId = 'ca-app-pub-8872582533953072~4948596381';

  /// Standard Banner (`main-banner`). Not the Native unit `…/4282381975`.
  static const String bannerAdUnitId =
      'ca-app-pub-8872582533953072/5359269234';

  static const String testBannerAdUnitId =
      'ca-app-pub-3940256099942544/6300978111';

  /// Production uses the real banner unit. Tests may override via [useTestAds].
  static const bool useTestAds = false;

  static String get bannerId =>
      useTestAds ? testBannerAdUnitId : bannerAdUnitId;
}

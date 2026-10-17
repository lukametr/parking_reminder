/// AdMob units cherry-picked from `main`. Interstitial stays on Google test IDs
/// until a real unit exists (placeholder `/0000000000` is not valid).
class AdConfig {
  static const String adMobAppId = 'ca-app-pub-8872582533953072~4948596381';
  static const String bannerAdUnitId = 'ca-app-pub-8872582533953072/4282381975';
  static const String interstitialAdUnitId =
      'ca-app-pub-8872582533953072/0000000000';

  static const String testBannerAdUnitId =
      'ca-app-pub-3940256099942544/6300978111';
  static const String testInterstitialAdUnitId =
      'ca-app-pub-3940256099942544/1033173712';

  static const bool useTestAds = false;
  static const bool useGoogleTestInterstitial = true;

  static String get bannerId {
    if (useTestAds) return testBannerAdUnitId;
    return bannerAdUnitId;
  }

  static String get interstitialId {
    if (useTestAds || useGoogleTestInterstitial) {
      return testInterstitialAdUnitId;
    }
    return interstitialAdUnitId;
  }
}

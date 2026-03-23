/// AdMob — ბანერი რეალური ერთეულით; ინტერსტიციალი: შექმენით AdMob-ში და ჩასვით ID.
/// სანამ რეალური ინტერსტიციალი არ გაქვთ, დარჩით `useGoogleTestInterstitial` = true
/// (Google-ის ტესტ-რეკლამა — შიდა ტესტირებისთვის; პროდაქშენის საჯარო რელიზამდე შეცვალეთ).
class AdConfig {
  static const String adMobAppId = 'ca-app-pub-8872582533953072~4948596381';

  static const String bannerAdUnitId = 'ca-app-pub-8872582533953072/4282381975';

  /// რეალური ინტერსტიციალის ერთეული AdMob კონსოლიდან (შეცვალეთ როცა შექმნით).
  static const String interstitialAdUnitId =
      'ca-app-pub-8872582533953072/0000000000';

  static const String testBannerAdUnitId =
      'ca-app-pub-3940256099942544/6300978111';
  static const String testInterstitialAdUnitId =
      'ca-app-pub-3940256099942544/1033173712';

  /// true = ყველა რეკლამა Google-ის ტესტ ID-ებზე (დეველოპმენტი / შიდა ტრეკი).
  static const bool useTestAds = false;

  /// true = ინტერსტიციალი იტვირთება Google ტესტ ერთეულზე (სანამ ზემოთ შეცვით რეალური ID).
  static const bool useGoogleTestInterstitial = true;

  static String get bannerId {
    if (useTestAds) return testBannerAdUnitId;
    return bannerAdUnitId;
  }

  static String get interstitialId {
    if (useTestAds) return testInterstitialAdUnitId;
    if (useGoogleTestInterstitial) return testInterstitialAdUnitId;
    return interstitialAdUnitId;
  }
}

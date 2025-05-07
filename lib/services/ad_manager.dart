// lib/services/ad_manager.dart

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdManager {
  // ჩავანაცვლო ჩემი ID
  static const String bannerAdUnitId = 'ca-app-pub-3940256099942544/6300978111';

  BannerAd? _bannerAd;

  /// LOAD BANNER
  void loadBannerAd() {
    _bannerAd = BannerAd(
      adUnitId: bannerAdUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) => debugPrint('BannerAd loaded'),
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          debugPrint('BannerAd failed to load: ${error.message}');
        },
      ),
    )..load();
  }

  /// RETURNS LOADED BANNER, OR NULL
  BannerAd? get bannerAd => _bannerAd;

  /// DISPOSE BANNER RESOURCES
  void disposeBanner() {
    _bannerAd?.dispose();
  }
}

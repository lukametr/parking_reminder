// lib/services/ad_manager.dart

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdManager {
  // Замените на ваш реальный ID баннера
  static const String bannerAdUnitId = 'ca-app-pub-3940256099942544/6300978111';

  BannerAd? _bannerAd;

  /// Загружает баннер
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

  /// Возвращает загруженный баннер, или null
  BannerAd? get bannerAd => _bannerAd;

  /// Освобождает ресурсы баннера
  void disposeBanner() {
    _bannerAd?.dispose();
  }
}

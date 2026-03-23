import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../config/ad_config.dart';

class AdService {
  static final AdService _instance = AdService._internal();
  factory AdService() => _instance;
  AdService._internal();

  final FirebaseRemoteConfig _remoteConfig = FirebaseRemoteConfig.instance;
  bool _adsEnabled = true;
  bool _isInitialized = false;

  // ინიციალიზაცია
  Future<void> initialize() async {
    try {
      // Mobile Ads ინიციალიზაცია
      await MobileAds.instance.initialize();
      
      // Remote Config ინიციალიზაცია
      await _remoteConfig.setConfigSettings(
        RemoteConfigSettings(
          fetchTimeout: const Duration(minutes: 1),
          minimumFetchInterval: const Duration(hours: 1),
        ),
      );
      
      // პარამეტრების ჩატვირთვა
      await _remoteConfig.setDefaults({
        'ads_enabled': true,
        'banner_ad_frequency': 3, // ყოველ 3-ე გახსნაზე
        'interstitial_ad_frequency': 10, // ყოველ 10-ე მოქმედებაზე
      });
      
      await _remoteConfig.fetchAndActivate();
      
      _adsEnabled = _remoteConfig.getBool('ads_enabled');
      _isInitialized = true;

      debugPrint('AdService: ads=$_adsEnabled');
    } catch (e) {
      debugPrint('AdService init error: $e');
      _adsEnabled = false;
    }
  }

  // რეკლამების ჩართ/გამორთ
  bool get adsEnabled => _adsEnabled && _isInitialized;

  // ბანერის სიხშირის მიღება
  int get bannerFrequency => _remoteConfig.getInt('banner_ad_frequency');

  // ინტერსტიციალური რეკლამის სიხშირე
  int get interstitialFrequency => _remoteConfig.getInt('interstitial_ad_frequency');

  // ინტერსტიციალური რეკლამის ჩვენება
  Future<void> showInterstitialAd() async {
    if (!adsEnabled) return;

    try {
      InterstitialAd.load(
        adUnitId: AdConfig.interstitialId,
        request: const AdRequest(),
        adLoadCallback: InterstitialAdLoadCallback(
          onAdLoaded: (InterstitialAd ad) {
            ad.fullScreenContentCallback = FullScreenContentCallback(
              onAdDismissedFullScreenContent: (ad) {
                ad.dispose();
              },
              onAdFailedToShowFullScreenContent: (ad, error) {
                ad.dispose();
                debugPrint('Interstitial show failed: ${error.message}');
              },
            );
            ad.show();
          },
          onAdFailedToLoad: (LoadAdError error) {
            debugPrint('Interstitial load failed: ${error.message}');
          },
        ),
      );
    } catch (e) {
      debugPrint('Interstitial error: $e');
    }
  }

  // რეკლამის სტატუსის განახლება
  Future<void> updateAdStatus() async {
    try {
      await _remoteConfig.fetchAndActivate();
      _adsEnabled = _remoteConfig.getBool('ads_enabled');
      debugPrint('Ad status: $_adsEnabled');
    } catch (e) {
      debugPrint('Ad status update error: $e');
    }
  }

  // სერვისის დახურვა
  void dispose() {
    // საჭიროების შემთხვევაში დამატებითი ლოგიკა
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:permission_handler/permission_handler.dart';

import '../widgets/ad_banner_widget.dart';
import '../widgets/service_buttons.dart';
import '../services/ad_service.dart';
import '../services/background_service.dart';

/// ბანერის სიმაღლე + მცირე padding — ცალკე ზოლად, რომ არ დაფაროს კონტენტი.
double get _bannerStripHeight => AdSize.banner.height + 6;

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool _showButtons = false;
  bool _showSOSButtons = false;
  final BackgroundService _backgroundService = BackgroundService();
  final AdService _adService = AdService();
  int _actionCounter = 0;

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    try {
      await _backgroundService.startForegroundService();

      final PermissionStatus status = await Permission.notification.status;
      if (status.isDenied || status.isLimited) {
        await Permission.notification.request();
      }

      await _adService.initialize();

      if (mounted) setState(() {});

      debugPrint('სერვისები წარმატებით გაეშვა');
    } catch (e) {
      debugPrint('სერვისების გაშვის შეცდომა: $e');
    }
  }

  void _handleAction() {
    setState(() {
      _actionCounter++;
    });

    final int freq = _adService.interstitialFrequency;
    if (!_adService.adsEnabled || freq <= 0) return;
    if (_actionCounter % freq != 0) return;
    _adService.showInterstitialAd();
  }

  Widget _bannerStrip({required bool top}) {
    return Container(
      width: double.infinity,
      height: _bannerStripHeight,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: top ? 0.22 : 0.28),
        border: Border(
          bottom: top
              ? BorderSide(color: Colors.white.withValues(alpha: 0.06))
              : BorderSide.none,
          top: !top
              ? BorderSide(color: Colors.white.withValues(alpha: 0.06))
              : BorderSide.none,
        ),
      ),
      child: const FittedBox(
        fit: BoxFit.scaleDown,
        child: AdBannerWidget(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool ads = _adService.adsEnabled;

    return Scaffold(
      body: Column(
        children: [
          if (ads) SafeArea(bottom: false, child: _bannerStrip(top: true)),
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: <Color>[
                        Color(0xFF1B5E20),
                        Color(0xFF0D47A1),
                        Color(0xFF212121),
                      ],
                    ),
                  ),
                ),
                Container(
                  color: Colors.black.withValues(alpha: 0.28),
                ),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8, left: 12, right: 12),
                    child: Align(
                      alignment: Alignment.topRight,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _circleIcon(
                            icon: Icons.minimize,
                            onTap: _minimizeApp,
                          ),
                          const SizedBox(width: 10),
                          _circleIcon(
                            icon: Icons.close,
                            onTap: _terminateApp,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 56, 16, 8),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Text(
                          'ზონალური პარკირების',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            height: 1.2,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        Text(
                          'კონტროლის სისტემა',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            height: 1.2,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: 10),
                        Text(
                          'აპლიკაცია შეგიძლიათ ჩაკეცოთ;\n ავტომატურად ჩაირთვება\n ზონალურ პარკირებაზე.',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                            fontWeight: FontWeight.normal,
                            height: 1.3,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: 20),
                        Wrap(
                          alignment: WrapAlignment.center,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            Text(
                              '!',
                              style: TextStyle(
                                color: Colors.red,
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            Text(
                              'ყოველთვის გადაამოწმეთ\nლოტის ნომერი',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                              softWrap: true,
                            ),
                            Text(
                              '!',
                              style: TextStyle(
                                color: Colors.red,
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                ServiceButtons(
                  showButtons: _showButtons,
                  showSOSButtons: _showSOSButtons,
                  onShowButtonsChanged: (bool value) {
                    setState(() {
                      _showButtons = value;
                    });
                    _handleAction();
                  },
                  onShowSOSButtonsChanged: (bool value) {
                    setState(() {
                      _showSOSButtons = value;
                    });
                    _handleAction();
                  },
                ),
              ],
            ),
          ),
          if (ads) SafeArea(top: false, child: _bannerStrip(top: false)),
        ],
      ),
    );
  }

  Widget _circleIcon({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.5),
        shape: BoxShape.circle,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      ),
    );
  }

  void _minimizeApp() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).maybePop();
    } else {
      SystemNavigator.pop();
    }
  }

  void _terminateApp() {
    SystemNavigator.pop();
  }
}

// lib/screens/splash_screen.dart

import 'dart:async';
import 'dart:io';

import 'package:android_intent_plus/android_intent.dart';
import 'package:android_intent_plus/flag.dart';
import 'package:external_app_launcher/external_app_launcher.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:parking_reminder/config/ad_config.dart';
import 'package:parking_reminder/config/privacy.dart';
import 'package:parking_reminder/notifications/overlay_notification.dart';
import 'package:parking_reminder/screens/location_disclosure_screen.dart';
import 'package:parking_reminder/screens/auto_service_map_screen.dart';
import 'package:parking_reminder/screens/food_map_screen.dart';
import 'package:parking_reminder/screens/gas_station_map_screen.dart';
import 'package:parking_reminder/screens/pharmacy_map_screen.dart';
import 'package:parking_reminder/screens/police_map_screen.dart';
import 'package:parking_reminder/screens/shop_map_screen.dart';
import 'package:parking_reminder/screens/vulcanization_map_screen.dart';
import 'package:parking_reminder/services/notification_service.dart';
import 'package:parking_reminder/services/parking_monitor.dart';
import 'package:parking_reminder/services/parking_service.dart';
import 'package:parking_reminder/services/parking_session_tracker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:developer' as developer;

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  static void handleNotificationAction(String action, String? payload) {
    if (action == 'park') {
      developer.log('გადავდივართ პარკირების რეჟიმზე');
      final intent = AndroidIntent(
        action: 'action_view',
        package: 'ge.msda.parking',
      );
      intent.launch();
    } else if (action == 'cancel') {
      developer.log('მომხმარებელმა გააუქმა შეტყობინება');
    }
  }

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with WidgetsBindingObserver {
  static const _minimizeChannel = MethodChannel('com.lukacode.sosapp/minimize');
  final ParkingService _parkingService = ParkingService();
  late final ParkingSessionTracker _session;
  String? _activeLotLabel;
  bool _isLoading = true;
  StreamSubscription<MonitorEvent>? _monitorSub;
  String? _promptLots;
  double _promptLat = 0;
  double _promptLng = 0;
  DateTime? _lotStillSince;
  String? _lotStillKey;
  BannerAd? _banner;
  InterstitialAd? _interstitial;
  bool _bannerReady = false;
  bool _showButtons = false;
  bool _showSOSButtons = false;

  final List<Map<String, dynamic>> _serviceButtons = [
    {'icon': 'security-agent.png', 'title': 'პოლიცია'},
    {'icon': 'food.png', 'title': 'კვება'},
    {'icon': 'cart.png', 'title': 'მაღაზია'},
    {'icon': 'garage.png', 'title': 'ავტოსერვისი'},
    {'icon': 'tires.png', 'title': 'ვულკანიზაცია'},
    {'icon': 'pharmacy.png', 'title': 'აფთიაქი'},
    {'icon': 'gasstation.png', 'title': 'საწვავი'},
  ];

  final List<Map<String, dynamic>> _sosButtons = [
    {'title': '112', 'icon': 'security-agent.png', 'phone': '112'},
    {'title': 'დაზღვევა', 'icon': 'security-agent.png', 'phone': '0322422222'},
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _session = ParkingSessionTracker(onLeftLot: _onLeftActiveLot);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_initializeApp());
    });
  }

  Future<void> _initializeApp() async {
    setState(() => _isLoading = true);
    try {
      await NotificationService.initialize(onActionCallback: _onNotificationAction);
      await _session.restore();
      if (mounted && _session.activeLot != null) {
        setState(() => _activeLotLabel = _session.activeLot);
      }
      _loadBanner();
      _loadInterstitial();
      if (!await _ensureLocationPermission()) return;
      await _parkingService.getAllParkings();
      if (_session.activeLot == null) {
        await ParkingMonitor.instance.clearSession();
      }
      await ParkingMonitor.instance.start();
      _monitorSub ??= ParkingMonitor.instance.events.listen(_onMonitorEvent);
      await _consumePendingPrompt();
    } catch (e) {
      debugPrint('ERROR INITIALIZATION: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _loadBanner() {
    _banner = BannerAd(
      size: AdSize.banner,
      adUnitId: AdConfig.bannerId,
      listener: BannerAdListener(
        onAdLoaded: (Ad ad) {
          if (mounted) setState(() => _bannerReady = true);
        },
        onAdFailedToLoad: (Ad ad, LoadAdError error) => ad.dispose(),
      ),
      request: const AdRequest(),
    )..load();
  }

  void _loadInterstitial() {
    InterstitialAd.load(
      adUnitId: AdConfig.interstitialId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (InterstitialAd ad) {
          _interstitial = ad;
        },
        onAdFailedToLoad: (LoadAdError error) {
          _interstitial = null;
        },
      ),
    );
  }

  void _maybeShowInterstitial() {
    final InterstitialAd? ad = _interstitial;
    if (ad == null) return;
    _interstitial = null;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (InterstitialAd a) {
        a.dispose();
        _loadInterstitial();
      },
      onAdFailedToShowFullScreenContent: (InterstitialAd a, AdError error) {
        a.dispose();
        _loadInterstitial();
      },
    );
    unawaited(ad.show());
  }

  void _onMonitorEvent(MonitorEvent event) {
    unawaited(_session.processFix(
      latitude: event.latitude,
      longitude: event.longitude,
    ));
    if (_session.hasActiveSession) return;
    if (event.lots.isEmpty || event.speed >= 2.8) {
      _lotStillSince = null;
      _lotStillKey = null;
    } else {
      final String key = event.lots.join('|');
      if (key != _lotStillKey) {
        _lotStillKey = key;
        _lotStillSince = DateTime.now();
      }
    }
    if (event.type == 'prompt' && event.lots.isNotEmpty && mounted) {
      _promptLat = event.latitude;
      _promptLng = event.longitude;
      _showParkingNotification(event.lots.join(' ან '));
      return;
    }
    final DateTime? stillSince = _lotStillSince;
    if (mounted &&
        event.lots.isNotEmpty &&
        stillSince != null &&
        DateTime.now().difference(stillSince) >= const Duration(seconds: 5)) {
      _promptLat = event.latitude;
      _promptLng = event.longitude;
      _showParkingNotification(event.lots.join(' ან '));
    }
  }

  Future<void> _consumePendingPrompt() async {
    if (_session.hasActiveSession) return;
    final String? lots = await ParkingMonitor.instance.consumePendingPrompt();
    if (lots != null && lots.isNotEmpty && mounted) {
      _showParkingNotification(lots);
    }
  }

  void _onLeftActiveLot(String lot) {
    if (!mounted) return;
    setState(() => _activeLotLabel = null);
    OverlayNotification.show(
      context: context,
      title: 'დატოვეთ ლოტი № $lot',
      message:
          'გამორთეთ პარკირება ოფიციალურ აპში (MSDA / ge.msda.parking).',
      icon: const Icon(Icons.exit_to_app, color: Colors.white, size: 28),
      confirmLabel: 'გახსენით პარკირების აპი',
      cancelLabel: 'დახურვა',
      onConfirm: () => unawaited(_openParkingAppOrStore()),
      onCancel: () {},
      persistent: true,
    );
  }

  Future<bool> _ensureLocationPermission() async {
    if (!await _ensureLocationDisclosure()) return false;
    final LocationPermission existing = await Geolocator.checkPermission();
    if (existing == LocationPermission.deniedForever) {
      await _showAlwaysLocationDialog(deniedForever: true);
      return false;
    }
    if (existing == LocationPermission.denied) {
      final LocationPermission asked = await Geolocator.requestPermission();
      if (asked == LocationPermission.denied ||
          asked == LocationPermission.deniedForever) {
        await _showAlwaysLocationDialog(deniedForever: true);
        return false;
      }
    }
    if (Platform.isAndroid) {
      if (!await Geolocator.isLocationServiceEnabled()) {
        await Geolocator.openLocationSettings();
      }
      await Permission.notification.request();
      await Permission.activityRecognition.request();
      final bool always = await ParkingMonitor.instance.hasAlwaysLocation();
      if (!always) {
        final bool proceed = await _showAlwaysLocationDialog();
        if (proceed) {
          await Permission.locationAlways.request();
        }
      }
    }
    return true;
  }

  Future<bool> _ensureLocationDisclosure() async {
    if (!mounted) return false;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(PrivacyConfig.disclosureAcceptedKey) == true) {
      return true;
    }
    if (!mounted) return false;
    final bool accepted = await LocationDisclosureScreen.present(context);
    if (accepted) {
      await prefs.setBool(PrivacyConfig.disclosureAcceptedKey, true);
    }
    return accepted;
  }

  Future<void> _openPrivacyPolicy() async {
    await launchUrl(
      Uri.parse(PrivacyConfig.policyUrl),
      mode: LaunchMode.externalApplication,
    );
  }

  Future<bool> _showAlwaysLocationDialog({bool deniedForever = false}) async {
    if (!mounted) return false;
    final bool? ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('ყოველთვის ნებართვა'),
        content: Text(
          deniedForever
              ? 'ფონური შეხსენება საჭიროებს ლოკაციას „ყოველთვის“. გახსენით პარამეტრები და ჩართეთ.'
              : 'აპი ამოწმებს, ხართ თუ არა თბილისის ფასიან ლოტთან, როცა ჩაკეცილია. ამისთვის აირჩიეთ „ყოველთვის დაშვება“ (Allow all the time). მხოლოდ „აპის გამოყენებისას“ ფონური მონიტორინგი გაჩერდება.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ახლა არა'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(deniedForever ? 'პარამეტრები' : 'გაგრძელება'),
          ),
        ],
      ),
    );
    if (ok == true) {
      if (deniedForever) {
        await ParkingMonitor.instance.openLocationSettings();
      }
      return true;
    }
    return false;
  }

  void _showParkingNotification(String lotsText) async {
    if (OverlayNotification.isVisible || _session.hasActiveSession) return;
    _promptLots = lotsText;
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now().millisecondsSinceEpoch;
    
    // შევინახოთ პოპაპის ინფორმაცია
    await prefs.setString('lastPopupLots', lotsText);
    await prefs.setInt('lastPopupTimestamp', now);
    
    if (mounted) {
      OverlayNotification.show(
        context: context,
        title: 'ლოტი № $lotsText',
        message:
            'ფასიან პარკირების ადგილზე ხართ. გსურთ დარჩეთ და ოფიციალურ აპში ჩართოთ პარკირება?',
        duration: const Duration(seconds: 10),
        icon: const Icon(Icons.directions_car, color: Colors.white, size: 28),
        confirmLabel: 'გახსენით პარკირების აპი',
        cancelLabel: 'არ ვჩერდები',
        onConfirm: () => _startParking(lotsText),
        onCancel: () => _cancelParking(),
        onExit: () => _cancelParking(),
        persistent: true,
      );
    }
  }

  void _onNotificationAction(String action, String? payload) async {
    if (action == 'open_app') {
      // თუ აპლიკაცია ბექგრაუნდში იყო, ვხსნით მას
      if (ModalRoute.of(context)?.isCurrent != true) {
        final intent = AndroidIntent(
          action: 'android.intent.action.MAIN',
          category: 'android.intent.category.LAUNCHER',
          package: 'com.lukacode.sosapp',
          flags: [Flag.FLAG_ACTIVITY_NEW_TASK],
        );
        await intent.launch();
      }
      
      // ვაჩვენებთ პოპაპს პარკირების დასაწყებად
      if (mounted) {
        OverlayNotification.show(
          context: context,
          title: 'ლოტი № $payload',
          message:
              'ფასიან პარკირების ადგილზე ხართ. გსურთ დარჩეთ და ოფიციალურ აპში ჩართოთ პარკირება?',
          duration: const Duration(seconds: 10),
          icon: const Icon(Icons.directions_car, color: Colors.white, size: 28),
          confirmLabel: 'გახსენით პარკირების აპი',
          cancelLabel: 'არ ვჩერდები',
          onConfirm: () => _startParking(payload ?? ''),
          onCancel: () => _cancelParking(),
          onExit: () => _cancelParking(),
          persistent: true,
        );
      }
    } else if (action == 'open_official_app' || action == 'exit') {
      await _openParkingAppOrStore();
    } else if (action == 'cancel') {
      // ვაუქმებთ შეტყობინებას
      await NotificationService.cancelNotification(1);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(ParkingMonitor.instance.start());
      unawaited(_consumePendingPrompt());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_monitorSub?.cancel());
    _banner?.dispose();
    _interstitial?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // ფონი: დინამიური ან asset, ორივეს აქვს fallback და errorBuilder
          FutureBuilder<String?>(
            future: fetchBackgroundImageUrl(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final imageUrl = snapshot.data;
              if (imageUrl != null && imageUrl.isNotEmpty) {
                return Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                  errorBuilder: (context, error, stackTrace) {
                    return Image.asset(
                      'assets/background_image.jpg',
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(color: Colors.black);
                      },
                    );
                  },
                );
              }
              return Image.asset(
                'assets/background_image.jpg',
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
                errorBuilder: (context, error, stackTrace) {
                  return Container(color: Colors.black);
                },
              );
            },
          ),
          // გამჭვირვალე შავი ფენა ტექსტისთვის
          Container(
            color: Colors.black.withValues(alpha: 0.3),
            width: double.infinity,
            height: double.infinity,
          ),
          // ტექსტი Column-ში
          Positioned(
            top: 80,
            left: 0,
            right: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'ზონალური პარკირების',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    height: 1.2,
                  ),
                  textAlign: TextAlign.center,
                ),
                const Text(
                  'კონტროლის სისტემა',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    height: 1.2,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                const Text(
                  'აპლიკაცია შეგიძლიათ ჩაკეცოთ;\n ავტომატურად ჩაირთვება\n ზონალურ პარკირაზე.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    fontWeight: FontWeight.normal,
                    height: 1.3,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Text(
                      '!',
                      style: TextStyle(
                        color: Colors.red,
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'ყოველთვის გადაამოწმეთ\nლოტის ნომერი',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    SizedBox(width: 8),
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
                if (_activeLotLabel != null) ...[
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          Text(
                            'აქტიური ლოტი № $_activeLotLabel',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'პარკირება წუთებში ითვლება. ლოტიდან გასვლისას გამორთეთ ოფიციალურ აპში.',
                            style: TextStyle(color: Colors.white70, fontSize: 13),
                            textAlign: TextAlign.center,
                          ),
                          TextButton(
                            onPressed: () => unawaited(_openParkingAppOrStore()),
                            child: const Text('გახსენით პარკირების აპი'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 30),
                // SOS ღილაკი
                if (!_showButtons && !_showSOSButtons)
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          spreadRadius: 2,
                          blurRadius: 5,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            _showSOSButtons = true;
                          });
                        },
                        borderRadius: BorderRadius.circular(30),
                        child: const Center(
                          child: Text(
                            'SOS',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // ჩაკეცვის და გამორთვის ღილაკები
          Positioned(
            top: 40,
            right: 20,
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    shape: BoxShape.circle,
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => unawaited(_openPrivacyPolicy()),
                      borderRadius: BorderRadius.circular(20),
                      child: const Center(
                        child: Icon(
                          Icons.privacy_tip_outlined,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    shape: BoxShape.circle,
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _minimizeApp,
                      borderRadius: BorderRadius.circular(20),
                      child: const Tooltip(
                        message: 'ჩაკეცვა',
                        child: Center(
                          child: Icon(
                            Icons.minimize,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    shape: BoxShape.circle,
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _terminateApp,
                      borderRadius: BorderRadius.circular(20),
                      child: const Tooltip(
                        message: 'გათიშვა',
                        child: Center(
                          child: Icon(
                            Icons.close,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_bannerReady && _banner != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 78,
              child: SizedBox(
                height: 50,
                child: AdWidget(ad: _banner!),
              ),
            ),
          // სერვისების ღილაკი
          Positioned(
            left: 20,
            right: 20,
            bottom: 20,
            child: Container(
              height: 50,
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(25),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    spreadRadius: 2,
                    blurRadius: 5,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _showButtons = true;
                      _showSOSButtons = false;
                    });
                    _maybeShowInterstitial();
                  },
                  borderRadius: BorderRadius.circular(25),
                  child: const Center(
                    child: Text(
                      'სერვისები',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          // SOS ღილაკები
          if (_showSOSButtons)
            Positioned.fill(
              child: Container(
                color: Colors.black.withValues(alpha: 0.7),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'სასწრაფოდ დაკავშირება',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 40),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: _sosButtons.map((button) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(15),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.3),
                                  spreadRadius: 2,
                                  blurRadius: 5,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () async {
                                  final Uri url = Uri(
                                    scheme: 'tel',
                                    path: button['phone'],
                                  );
                                  if (await canLaunchUrl(url)) {
                                    await launchUrl(url);
                                  } else {
                                    throw 'Could not launch $url';
                                  }
                                },
                                borderRadius: BorderRadius.circular(15),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Image.asset(
                                      'assets/${button['icon']}',
                                      width: 40,
                                      height: 40,
                                      color: Colors.white,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      button['title'],
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 40),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _showSOSButtons = false;
                        });
                      },
                      child: const Text(
                        'დახურვა',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          // სერვისების ღილაკები
          if (_isLoading)
            const Positioned.fill(
              child: ColoredBox(
                color: Color(0x66000000),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
          if (_showButtons)
            Positioned.fill(
              child: Container(
                color: Colors.black.withValues(alpha: 0.7),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'აირჩიეთ სერვისი',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 40),
                    Expanded(
                      child: GridView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          childAspectRatio: 1,
                          crossAxisSpacing: 20,
                          mainAxisSpacing: 20,
                        ),
                        itemCount: _serviceButtons.length,
                        itemBuilder: (context, index) {
                          final service = _serviceButtons[index];
                          return Container(
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(15),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.3),
                                  spreadRadius: 2,
                                  blurRadius: 5,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () {
                                  if (service['title'] == 'აფთიაქი') {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => const PharmacyMapScreen(),
                                      ),
                                    );
                                  } else if (service['title'] == 'პოლიცია') {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => const PoliceMapScreen(),
                                      ),
                                    );
                                  } else if (service['title'] == 'კვება') {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => const FoodMapScreen(),
                                      ),
                                    );
                                  } else if (service['title'] == 'მაღაზია') {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => const ShopMapScreen(),
                                      ),
                                    );
                                  } else if (service['title'] == 'ავტოსერვისი') {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => const AutoServiceMapScreen(),
                                      ),
                                    );
                                  } else if (service['title'] == 'ვულკანიზაცია') {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => const VulcanizationMapScreen(),
                                      ),
                                    );
                                  } else if (service['title'] == 'საწვავი') {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => const GasStationMapScreen(),
                                      ),
                                    );
                                  }
                                },
                                borderRadius: BorderRadius.circular(15),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Image.asset(
                                      'assets/${service['icon']}',
                                      width: 40,
                                      height: 40,
                                      color: Colors.white,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      service['title'],
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _showButtons = false;
                        });
                      },
                      child: const Text(
                        'დახურვა',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _openParkingAppOrStore() async {
    const packageName = 'ge.msda.parking';
    try {
      final didLaunch = await LaunchApp.openApp(
        androidPackageName: packageName,
        openStore: false,
      );
      if (didLaunch != 1) {
        // თუ აპი არ არის, გავხსნათ Play Store
        final url = 'https://play.google.com/store/apps/details?id=ge.msda.parking';
        if (await canLaunchUrl(Uri.parse(url))) {
          await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
        }
      }
    } catch (e) {
      // fallback: გახსენი Play Store
      final url = 'https://play.google.com/store/apps/details?id=ge.msda.parking';
      if (await canLaunchUrl(Uri.parse(url))) {
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      }
    }
  }

  Future<void> _startParking(String lotNumber) async {
    try {
      // Get current position
      final position = await Geolocator.getCurrentPosition();
      
      // Save parking info
      final mainLot = lotNumber.split(' ან ').first;
      await _parkingService.saveUserParking(
        lotNumber: mainLot,
        latitude: position.latitude,
        longitude: position.longitude,
        startTime: DateTime.now(),
      );
      await _session.beginSession(
        lotNumber: mainLot,
        latitude: position.latitude,
        longitude: position.longitude,
      );
      if (mounted) setState(() => _activeLotLabel = mainLot);

      // Try to open parking app
      await _openParkingAppOrStore();
      
    } catch (e) {
      debugPrint('Error starting parking: $e');
    }
  }

  Future<void> _terminateApp() async {
    try {
      await _parkingService.endParking();
      await ParkingMonitor.instance.clearSession();
      await NotificationService.cancelAll();
      await ParkingMonitor.instance.shutdownAndExit();
    } catch (e) {
      debugPrint('Error terminating app: $e');
      exit(0);
    }
  }

  Future<void> _minimizeApp() async {
    try {
      if (Platform.isAndroid) {
        // გამოვიყენოთ Android-ის ნატიური მეთოდი აპლიკაციის მინიმიზაციისთვის
        await _minimizeChannel.invokeMethod('moveTaskToBack');
        await ParkingMonitor.instance.start();
      }
    } catch (e) {
      debugPrint('Error minimizing app: $e');
      await ParkingMonitor.instance.start();
    }
  }

  // Remote Config-დან სურათის URL-ის წამოღების ფუნქცია
  Future<String?> fetchBackgroundImageUrl() async {
    final remoteConfig = FirebaseRemoteConfig.instance;
    await remoteConfig.setConfigSettings(RemoteConfigSettings(
      fetchTimeout: const Duration(seconds: 10),
      minimumFetchInterval: const Duration(minutes: 5),
    ));
    await remoteConfig.fetchAndActivate();
    return remoteConfig.getString('background_image_url');
  }

  Future<void> _cancelParking() async {
    await NotificationService.cancelAll();
    OverlayNotification.dismiss();
    double lat = _promptLat;
    double lng = _promptLng;
    if (lat == 0 && lng == 0) {
      try {
        final Position pos = await Geolocator.getCurrentPosition();
        lat = pos.latitude;
        lng = pos.longitude;
      } catch (_) {}
    }
    await ParkingMonitor.instance.declinePrompt(
      lots: _promptLots ?? '',
      latitude: lat,
      longitude: lng,
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('არ ვჩერდებით — 10 წუთი აღარ შეგეკითხებით'),
          duration: Duration(seconds: 3),
        ),
      );
    }
  }
}

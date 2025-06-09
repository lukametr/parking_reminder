// lib/screens/splash_screen.dart

import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:geolocator/geolocator.dart';
import 'package:parking_reminder/firebase_options.dart';
import 'package:parking_reminder/services/background_service.dart';
import 'package:parking_reminder/services/location_service.dart';
import 'package:parking_reminder/services/notification_service.dart';
import 'package:parking_reminder/services/parking_service.dart';
import 'package:parking_reminder/notifications/overlay_notification.dart';
import 'package:external_app_launcher/external_app_launcher.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:parking_reminder/services/ad_manager.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with WidgetsBindingObserver {
  static const _minimizeChannel = MethodChannel('com.findall.ParkingReminder/minimize');
  final ParkingService _parkingService = ParkingService();
  bool _isLoading = true;
  late final AdManager _adManager;
  BannerAd? _bannerAd;
  Timer? _locationCheckTimer;
  String? _lastOverlayLots;
  Timer? _debounceTimer;
  List<String> _pendingLots = [];
  Position? _lastNotificationPosition;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _adManager = AdManager();
    _adManager.loadBannerAd();
    Future.delayed(const Duration(milliseconds: 500), () {
      setState(() {
        _bannerAd = _adManager.bannerAd;
      });
    });
    _initializeApp();
    _startForegroundLocationCheck();
  }

  Future<void> _initializeApp() async {
    setState(() => _isLoading = true);

    try {
      // 1. Firebase
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

      // 2. NOTIFICATIONS
      await NotificationService.initialize(onActionCallback: _onNotificationAction);

      // 3. BACKGROUND SERVICE
      await BackgroundService.initialize();
      await BackgroundService.start();

      // 4. REQUEST PERMISSIONS
      if (!await _ensureLocationPermission()) return;

      // 5. CURRENT POSITION (with Kalman filtering)
      final pos = await LocationService.getCurrentPosition(filtered: true);
      if (pos == null) return;

      // 6. Check proximity through ParkingService (3–5 m)
      double proximityRadius = 5;
      try {
        final stopped = LocationService.kalmanFilter.stoppedDuration;
        if (stopped.inSeconds > 5) proximityRadius = 10;
      } catch (_) {}
      final lots = await _parkingService.checkProximity(pos, proximityRadius: proximityRadius);
      if (lots.isNotEmpty && mounted) {
        _showParkingNotification(pos, lots);
      }


    } catch (e) {
      debugPrint('ERROR INITIALIZATION: $e');
      await _terminateApp();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<bool> _ensureLocationPermission() async {
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
      perm = await Geolocator.requestPermission();
    }
    if (Platform.isAndroid && await _isAndroid12Plus()) {
      if (perm == LocationPermission.whileInUse) {
        perm = await Geolocator.requestPermission();
      }
    }
    if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
      await showDialog(
        // ignore: use_build_context_synchronously
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          title: const Text('LOCATION REQUIRED'),
          content: const Text('Without access to location, the application will not work.'),
          actions: [
            TextButton(onPressed: () => SystemNavigator.pop(), child: const Text('დახურვა')),
          ],
        ),
      );
      return false;
    }
    if (Platform.isAndroid) {
      var enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) {
        await Geolocator.openLocationSettings();
        enabled = await Geolocator.isLocationServiceEnabled();
        if (!enabled) return false;
      }
    }
    return true;
  }

  Future<bool> _isAndroid12Plus() async {
    if (!Platform.isAndroid) return false;
    final sdk = await _minimizeChannel.invokeMethod<int>('getSDKVersion');
    return (sdk ?? 0) >= 31;
  }

  void _showParkingNotification(Position pos, List<String> lots) {
    final lotsText = lots.join(' ან ');
    OverlayNotification.show(
      context: context,
      title: 'ზონალური პარკირების ზონა № $lotsText',
      message: 'გსურთ პარკირების დაწყება?',
      duration: const Duration(seconds: 10),
      icon: const Icon(Icons.directions_car, color: Colors.white, size: 28),
      onConfirm: () => _onNotificationAction('park', lotsText),
      onCancel: () => _onNotificationAction('cancel', null),
      onExit: () => _onNotificationAction('exit', null),
      persistent: true,
    );
  }

  void _onNotificationAction(String action, String? payload) async {
    if (action == 'tap' || action == 'park') {
      // foreground-ზე ამოყვანა და overlay პოპაპის გამოჩენა
      if (!mounted) return;
      if (payload != null && payload.isNotEmpty) {
        await _startParking(payload);
      }
      return;
    }
    switch (action) {
      case 'cancel':
        // foreground-ში უარყოფის შემთხვევაში 30 წუთით დავბლოკოთ ეს ლოტი
        if (payload != null && payload.isNotEmpty) {
          final prefs = await SharedPreferences.getInstance();
          final blockedLots = prefs.getStringList('blockedLots') ?? [];
          final blockedTimes = prefs.getStringList('blockedTimes') ?? [];
          blockedLots.add(payload);
          blockedTimes.add(DateTime.now().millisecondsSinceEpoch.toString());
          await prefs.setStringList('blockedLots', blockedLots);
          await prefs.setStringList('blockedTimes', blockedTimes);
        }
        // overlay/system notification გაქრეს
        await NotificationService.cancelAll();
        break;
      case 'exit':
        _terminateApp();
        break;
    }
  }

  Future<void> _startParking(String lotNumber) async {
    final mainLot = lotNumber.split(' ან ').first;
    await _parkingService.saveUserParking(
      lotNumber: mainLot,
      latitude: 0, longitude: 0, startTime: DateTime.now(),
    );
    NotificationService.showSimpleNotification(
      title: 'პარკირება დაწყებულია',
      message: 'ლოტი ნომერი № $mainLot',
    );
    _openParkingAppOrStore();
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

  Future<void> _terminateApp() async {
    try {
      await BackgroundService.forceStop();
      await NotificationService.cancelAll();
      if (Platform.isAndroid) {
        SystemNavigator.pop(animated: true);
      } else {
        exit(0);
      }
    } catch (e) {
      exit(1);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) BackgroundService.start();
  }

  void _startForegroundLocationCheck() {
    _locationCheckTimer?.cancel();
    _locationCheckTimer = Timer.periodic(const Duration(seconds: 10), (timer) async {
      if (!mounted) return;
      if (ModalRoute.of(context)?.isCurrent != true) return;
      if (OverlayNotification.isVisible) return;
      final pos = await LocationService.getCurrentPosition(filtered: true);
      if (pos == null) return;
      double proximityRadius = 5;
      try {
        final stopped = LocationService.kalmanFilter.stoppedDuration;
        if (stopped.inSeconds > 5) proximityRadius = 10;
      } catch (_) {}
      final lots = await _parkingService.checkProximity(pos, proximityRadius: proximityRadius);
      if (lots.isNotEmpty) {
        if (_lastNotificationPosition != null) {
          final dist = Geolocator.distanceBetween(
            pos.latitude, pos.longitude,
            _lastNotificationPosition!.latitude, _lastNotificationPosition!.longitude,
          );
          if (dist < 50) return;
        }
        _pendingLots.addAll(lots);
        _pendingLots = _pendingLots.toSet().toList();
        _debounceTimer?.cancel();
        _debounceTimer = Timer(const Duration(seconds: 2), () {
          if (_pendingLots.isNotEmpty) {
            final lotsText = _pendingLots.join(' ან ');
            _lastOverlayLots = lotsText;
            _lastNotificationPosition = pos;
            _showParkingNotification(pos, _pendingLots);
            _pendingLots.clear();
          }
        });
      } else {
        _lastOverlayLots = null;
        _pendingLots.clear();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _adManager.disposeBanner();
    _locationCheckTimer?.cancel();
    _debounceTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // ignore: deprecated_member_use
    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          actions: [
            IconButton(
              icon: const Icon(Icons.info, color: Colors.white),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    title: const Text('ინფორმაცია', style: TextStyle(fontWeight: FontWeight.bold)),
                    content: const SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('• აპლიკაცია მუშაობს ფონურ რეჟიმში და საჭიროებს მუდმივ ლოკაციის წვდომას.'),
                          SizedBox(height: 8),
                          Text('• ყოველთვის გადაამოწმეთ ლოტის ნომერი, აპლიკაცია შეიძლება შეცდეს GPS ცდომილების გამო.'),
                          SizedBox(height: 8),
                          Text('• შეტყობინებები აუცილებელია, რომ არ გამოტოვოთ პარკინგის გაფრთხილება.'),
                          SizedBox(height: 8),
                          Text('• თუ აპი არ მუშაობს სწორად, გადაამოწმეთ ნებართვები და ჩართეთ "Location" და "Notifications".'),
                          SizedBox(height: 8),
                          Text('• პარკინგის დატოვებისას მიიღებთ დამატებით შეტყობინებას.'),
                          SizedBox(height: 8),
                          Text('• აპლიკაცია ჩართულ მდგომარეობაში 24 საათის განმრავლობაში იყენებს თქვენი ელემენტის 5-12% მაქსიმუმ.'),
                          SizedBox(height: 8),
                          Text('• აპი არ აგროვებს და არ ინახავს თქვენს პირად მონაცემებს.'),
                          SizedBox(height: 8),
                          Text('• რეკომენდირებულია ოფიციალური პარკინგის აპის დაყენება სწრაფი გადახდისთვის.'),
                          SizedBox(height: 16),
                          Divider(),
                          SizedBox(height: 8),
                          Text('პირადი მონაცემების დაცვის პოლიტიკა', style: TextStyle(fontWeight: FontWeight.bold)),
                          SizedBox(height: 4),
                          Text('აპლიკაცია იყენებს თქვენს ადგილმდებარეობას მხოლოდ პარკინგის სერვისის გასაუმჯობესებლად. თქვენი მონაცემები არ ინახება და არ გადაეცემა მესამე პირებს. აპლიკაცია ითხოვს მხოლოდ აუცილებელ ნებართვებს და იყენებს მათ მხოლოდ ფუნქციონალობისთვის.'),
                        ],
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('დახურვა'),
                      ),
                    ],
                  ),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.remove, color: Colors.white),
              onPressed: () async {
                try {
                  await _minimizeChannel.invokeMethod('moveTaskToBack');
                } catch (_) {
                  SystemNavigator.pop();
                }
              },
            ),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: _terminateApp,
            ),
          ],
        ),
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
                      // თუ ვერ ჩაიტვირთა დინამიური სურათი, ვაჩვენოთ asset
                      return Image.asset(
                        'assets/background_image.jpg',
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                        errorBuilder: (context, error, stackTrace) {
                          // თუ asset-იც ვერ ჩაიტვირთა, ვაჩვენოთ შავი ფონი
                          return Container(color: Colors.black);
                        },
                      );
                    },
                  );
                }
                // fallback: ლოკალური asset თუ URL ცარიელია
                return Image.asset(
                  'assets/background_image.jpg',
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                  errorBuilder: (context, error, stackTrace) {
                    // თუ asset-იც ვერ ჩაიტვირთა, ვაჩვენოთ შავი ფონი
                    return Container(color: Colors.black);
                  },
                );
              },
            ),
            // გამჭვირვალე შავი ფენა ტექსტისთვის, რომ ყოველთვის გამოჩნდეს
            Container(
              color: Colors.black.withOpacity(0.3),
              width: double.infinity,
              height: double.infinity,
            ),
            // ტექსტი Column-ში, უფრო მაღლა და სტილიზებული ! სიმბოლოები
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
                  // ქვედა ტექსტი უფრო პატარა
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
                  // ! სიმბოლოები სქელი და წითელი
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
                ],
              ),
            ),
            if (_isLoading)
              const Positioned(
                bottom: 40, left: 0, right: 0,
                child: Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.white))),
              ),
            if (_bannerAd != null)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: SizedBox(
                  height: _bannerAd!.size.height.toDouble(),
                  child: AdWidget(ad: _bannerAd!),
                ),
              ),
          ],
        ),
      ),
    );
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
}

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
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'package:android_intent_plus/flag.dart';
import 'package:external_app_launcher/external_app_launcher.dart';
import 'package:flutter/foundation.dart';
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
  static const _minimizeChannel = MethodChannel('com.findall.ParkingReminder/minimize');
  final ParkingService _parkingService = ParkingService();
  bool _isLoading = true;
  Timer? _locationCheckTimer;
  String? _lastOverlayLots;
  Timer? _debounceTimer;
  List<String> _pendingLots = [];
  Position? _lastNotificationPosition;
  bool _showButtons = false;
  bool _showSOSButtons = false;

  final List<Map<String, dynamic>> _serviceButtons = [
    {'icon': 'security-agent.png', 'title': 'უსაფრთხოება'},
    {'icon': 'food.png', 'title': 'კვება'},
    {'icon': 'cart.png', 'title': 'მაღაზია'},
    {'icon': 'garage.png', 'title': 'ავტოსერვისი'},
    {'icon': 'tires.png', 'title': 'საბურავები'},
    {'icon': 'pharmacy.png', 'title': 'აფთიაქი'},
    {'icon': 'gasstation.png', 'title': 'ბენზინგასამართი'},
  ];

  final List<Map<String, dynamic>> _sosButtons = [
    {'title': '112', 'icon': 'security-agent.png', 'phone': '112'},
    {'title': 'დაზღვევა', 'icon': 'security-agent.png', 'phone': '0322422222'},
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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
      double proximityRadius = 20;
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

  void _showParkingNotification(Position pos, List<String> lots) async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now().millisecondsSinceEpoch;
    final lastTime = prefs.getInt('lastPopupTime') ?? 0;
    if (now - lastTime < 60000) return; // თუ popup უკვე იყო ბოლო 1 წუთში, აღარ ვაჩვენებთ
    await prefs.setInt('lastPopupTime', now);
    final lotsText = lots.join(' ან ');

    // ვაჩვენებთ პოპაპს მხოლოდ თუ აპლიკაცია ფორეგრაუნდშია
    if (ModalRoute.of(context)?.isCurrent == true) {
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
    } else {
      // თუ აპლიკაცია ბექგრაუნდშია, ვაჩვენებთ სისტემურ შეტყობინებას
      await NotificationService.showParkingNotification(
        position: pos,
        lotNumber: lotsText,
      );
    }
  }

  void _onNotificationAction(String action, String? payload) async {
    if (action == 'park') {
      // თუ აპლიკაცია ბექგრაუნდში იყო, ვახსნით მას
      if (ModalRoute.of(context)?.isCurrent != true) {
        final intent = AndroidIntent(
          action: 'android.intent.action.MAIN',
          category: 'android.intent.category.LAUNCHER',
          package: 'com.findall.ParkingReminder',
          flags: [Flag.FLAG_ACTIVITY_NEW_TASK],
        );
        await intent.launch();
      }
      
      // ვაჩვენებთ პოპაპს პარკირების დასაწყებად
      if (mounted) {
        OverlayNotification.show(
          context: context,
          title: 'ზონალური პარკირების ზონა № $payload',
          message: 'გსურთ პარკირების დაწყება?',
          duration: const Duration(seconds: 10),
          icon: const Icon(Icons.directions_car, color: Colors.white, size: 28),
          onConfirm: () => _startParking(payload ?? ''),
          onCancel: () => _cancelParking(),
          onExit: () => _cancelParking(),
          persistent: true,
        );
      }
    } else if (action == 'cancel') {
      // ვაუქმებთ შეტყობინებას
      await NotificationService.cancelNotification(1);
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
      
      // შევამოწმოთ მიმდინარე პარკირება
      final currentParking = await _parkingService.getCurrentParking();
      if (currentParking != null) {
        final parkLat = currentParking['latitude'] as double?;
        final parkLng = currentParking['longitude'] as double?;
        if (parkLat != null && parkLng != null) {
          final dist = Geolocator.distanceBetween(
            pos.latitude, pos.longitude,
            parkLat, parkLng,
          );
          final prefs = await SharedPreferences.getInstance();
          bool leftZoneNotified = prefs.getBool('leftZoneNotified') ?? false;
          
          if (dist > 200 && !leftZoneNotified) {
            await NotificationService.showParkingNotification(
              position: pos,
              lotNumber: currentParking['lotNumber'],
              isLeavingZone: true,
            );
            await prefs.setBool('leftZoneNotified', true);
          }
        }
      }
      
      // შევამოწმოთ ახალი პარკირების ზონები
      double proximityRadius = 20;
      final lots = await _parkingService.checkProximity(pos, proximityRadius: proximityRadius);
      if (lots.isNotEmpty) {
        if (_lastNotificationPosition != null) {
          final dist = Geolocator.distanceBetween(
            pos.latitude, pos.longitude,
            _lastNotificationPosition!.latitude, _lastNotificationPosition!.longitude,
          );
          if (dist < 200) return;
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
    _locationCheckTimer?.cancel();
    _debounceTimer?.cancel();
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
            color: Colors.black.withOpacity(0.3),
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
                          color: Colors.black.withOpacity(0.3),
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
                    color: Colors.black.withOpacity(0.5),
                    shape: BoxShape.circle,
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _minimizeApp,
                      borderRadius: BorderRadius.circular(20),
                      child: const Center(
                        child: Icon(
                          Icons.minimize,
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
                    color: Colors.black.withOpacity(0.5),
                    shape: BoxShape.circle,
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _terminateApp,
                      borderRadius: BorderRadius.circular(20),
                      child: const Center(
                        child: Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
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
                    color: Colors.black.withOpacity(0.3),
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
                color: Colors.black.withOpacity(0.7),
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
                                  color: Colors.black.withOpacity(0.3),
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
          if (_showButtons)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.7),
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
                                  color: Colors.black.withOpacity(0.3),
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
                                  // აქ დავამატებთ ლოგიკას შემდეგში
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
      
      // Show notification
      await NotificationService.showParkingNotification(
        lotNumber: lotNumber,
        position: position,
      );
      
      // Try to open parking app
      await _openParkingAppOrStore();
      
    } catch (e) {
      print('Error starting parking: $e');
    }
  }

  Future<void> _terminateApp() async {
    try {
      // გავაჩეროთ ყველა სერვისი და შეტყობინება
      await BackgroundService.forceStop();
      await NotificationService.cancelAll();
      
      // დავრწმუნდეთ რომ ყველა სერვისი გაჩერებულია
      await Future.delayed(const Duration(milliseconds: 500));
      
      if (Platform.isAndroid) {
        // Android-ზე გამოვიყენოთ SystemNavigator
        await SystemNavigator.pop(animated: true);
      } else {
        // iOS-ზე გამოვიყენოთ exit
        exit(0);
      }
    } catch (e) {
      print('Error terminating app: $e');
      // თუ რაიმე შეცდომა მოხდა, მაინც დავხუროთ აპლიკაცია
      exit(1);
    }
  }

  Future<void> _minimizeApp() async {
    try {
      if (Platform.isAndroid) {
        // გამოვიყენოთ Android-ის ნატიური მეთოდი აპლიკაციის მინიმიზაციისთვის
        await const MethodChannel('com.findall.ParkingReminder/minimize')
            .invokeMethod('moveTaskToBack');
        
        // დავრწმუნდეთ რომ ფონური სერვისი მუშაობს
        await BackgroundService.start();
        
        // გავუშვათ შეტყობინება რომ აპლიკაცია მუშაობს ფონურ რეჟიმში
        NotificationService.showSimpleNotification(
          title: 'პარკირების კონტროლი',
          message: 'აპლიკაცია მუშაობს ფონურ რეჟიმში',
        );
      }
    } catch (e) {
      print('Error minimizing app: $e');
      // თუ მინიმიზაცია ვერ მოხერხდა, მაინც გავუშვათ ფონური სერვისი
      await BackgroundService.start();
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
    // ვაუქმებთ შეტყობინებებს
    await NotificationService.cancelAll();
    OverlayNotification.dismiss();
    
    // ვაგზავნით შეტყობინებას, რომ პარკირება გაუქმებულია
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('პარკირება გაუქმებულია'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }
}

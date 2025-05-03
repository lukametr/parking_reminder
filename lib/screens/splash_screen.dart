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
import 'package:parking_reminder/utils/zone_utils.dart';
import 'package:parking_reminder/notifications/overlay_notification.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with WidgetsBindingObserver {
  static const _minimizeChannel =
      MethodChannel('com.findall.ParkingReminder/minimize');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      // 1) Firebase
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );

      // 2) Фоновый сервис
      await BackgroundService.initialize();
      await BackgroundService.start();

      // 3) Запрос прав на геолокацию
      await _ensureLocationPermission();

      // 4) Получаем позицию
      final Position? pos = await LocationService.getCurrentPosition();

      // 5) Если в зоне парковки — показываем уведомление
      if (pos != null &&
          ZoneUtils.isInParkingZone(pos.latitude, pos.longitude)) {
        await NotificationService.showInit(pos);

        if (mounted) {
          OverlayNotification.show(
            context: context,
            title: 'პარკირების ზონა',
            message: 'გსურთ პარკირების დაწყება?',
            duration: const Duration(seconds: 10),
            icon: const Icon(
              Icons.directions_car,
              color: Colors.white,
              size: 28,
            ),
            onConfirm: () => NotificationService.handleAction('park'),
            onCancel: () => NotificationService.handleAction('cancel'),
            onExit: () => NotificationService.handleAction('exit'),
          );
        }
      }
    } catch (e) {
      debugPrint('Initialization error: $e');
      await _terminateApp();
    }
  }

  Future<void> _ensureLocationPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      permission = await Geolocator.requestPermission();
    }
    if (Platform.isAndroid && await _isAndroid12OrHigher()) {
      if (permission == LocationPermission.whileInUse) {
        permission = await Geolocator.requestPermission();
      }
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          title: const Text('გეოლოკაციაზე წვდომა აუცილებელია'),
          content: const Text(
            'აპლიკაციის გასაშვებად საჭიროა წვდომა გეოლოკაციაზე.',
          ),
          actions: [
            TextButton(
              onPressed: () => SystemNavigator.pop(),
              child: const Text('დახურვა'),
            ),
          ],
        ),
      );
      throw Exception('Location permission denied');
    }
    if (Platform.isAndroid) {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        await Geolocator.openAppSettings();
        serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (!serviceEnabled) throw Exception('Location services disabled');
      }
    }
  }

  Future<bool> _isAndroid12OrHigher() async {
    if (Platform.isAndroid) {
      final int? sdk =
          await _minimizeChannel.invokeMethod<int>('getSDKVersion');
      return (sdk ?? 0) >= 31;
    }
    return false;
  }

  Future<void> _terminateApp() async {
    try {
      BackgroundService.stop();
      await NotificationService.cancelAll();
      if (Platform.isAndroid) {
        SystemNavigator.pop(animated: true);
      } else {
        exit(0);
      }
    } catch (e) {
      debugPrint('Termination error: $e');
      exit(1);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      BackgroundService.start();
    } else {
      BackgroundService.stop();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.remove, color: Colors.white),
            onPressed: () async {
              try {
                await _minimizeChannel.invokeMethod('moveTaskToBack');
              } catch (_) {
                SystemNavigator.pop();
              }
            },
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: _terminateApp,
            ),
          ],
        ),
        body: Stack(
          children: [
            // Фоновое изображение
            Image.asset(
              'assets/background_image.jpg',
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
            ),
            // Центрированный грузинский текст
            const Center(
              child: Text(
                'ზონალური პარკირების\n'
                'კონტროლის სისტéma\n\n'
                'აპლიკაცია მუშაობს ფონურ რეჟიმში\n'
                'შეგიძლიათ დახუროთ და ავტომატურად\n'
                'ჩაირთვება ზონალურ პარკირებაზე დადგომისას.',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            // Спиннер внизу экрана
            const Positioned(
              bottom: 40,
              left: 0,
              right: 0,
              child: Center(
                child: CircularProgressIndicator(
                  valueColor:
                      AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

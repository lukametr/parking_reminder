import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:external_app_launcher/external_app_launcher.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'package:parking_reminder/firebase_options.dart';
import 'package:parking_reminder/background/background_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with WidgetsBindingObserver {
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initApp();
    _initializeNotifications();
  }

  Future<void> _initApp() async {
    WidgetsFlutterBinding.ensureInitialized();
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      await showDialog(
        // ignore: use_build_context_synchronously
        context: context,
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
      return;
    }

    if (Platform.isAndroid) {
      bool backAllowed = await Geolocator.isLocationServiceEnabled();
      if (!backAllowed) {
        await Geolocator.openAppSettings();
        backAllowed = await Geolocator.isLocationServiceEnabled();
        if (!backAllowed) return;
      }
    }

    await initializeBackgroundService();
  }

  Future<void> _initializeNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);

    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onNotificationResponse,
    );
  }

  void _onNotificationResponse(NotificationResponse response) async {
    if (response.payload == 'start_parking') {
      await LaunchApp.openApp(
        androidPackageName: 'com.example.parkingapp',
        openStore: true,
      );
    } else if (response.payload == 'cancel_parking') {
      await flutterLocalNotificationsPlugin.cancelAll();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final service = FlutterBackgroundService();
    service.invoke(
      'setForeground',
      {'value': state == AppLifecycleState.resumed},
    );
  }

  void _showInfoDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ℹ გამოყენების რჩევები'),
        content: const SingleChildScrollView(
          child: Text(
            '''
📌 აპლიკაციის გამართული მუშაობისთვის გთხოვთ:

• ჩართოთ Wi-Fi და მობილური ინტერნეტი
• ჩართოთ გეოლოკაცია (Location Services)  
• გამორთოთ ელემენტის დაზოგვის რეჟიმი  
• არ დახუროთ აპლიკაცია სრულად
• გადაამოწმოთ შეტყობინებების ჩართვა
            ''',
            style: TextStyle(fontSize: 16),
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
          leading: IconButton(
            icon: const Icon(Icons.remove, color: Colors.white),
            onPressed: () => SystemChannels.platform
                .invokeMethod('SystemNavigator.pop'),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.info_outline, color: Colors.white),
              onPressed: _showInfoDialog,
            ),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => SystemNavigator.pop(),
            ),
          ],
        ),
        body: Stack(
          children: [
            Image.asset(
              'assets/background_image.jpg',
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
            ),
            const Center(
              child: Text(
                'ზონალური პარკირების\nკონტროლის სისტემა\n\nაპლიკაცია მუშაობს ფონურ რეჟიმში\nშეგილიათ ჩახუროთ და ავტომატურად ჩაირთვება ზონალურ პარკირებაზე დადგომისას.',
                style: TextStyle(color: Colors.white, fontSize: 18),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

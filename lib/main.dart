import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:parking_reminder/firebase_options.dart';
import 'package:parking_reminder/services/notification_service.dart';
import 'package:parking_reminder/services/background_service.dart' as bg_service; // здесь ваш сервис
import 'package:parking_reminder/screens/splash_screen.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Инициализируем локальные уведомления
  await NotificationService.initialize();

  // Стартуем background-сервис
  await bg_service.BackgroundService.initialize();

  // Инициализируем Google Mobile Ads
  await MobileAds.instance.initialize();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: SplashScreen(),
    );
  }
}

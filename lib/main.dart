// lib/main.dart

import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:parking_reminder/firebase_options.dart';
import 'package:parking_reminder/screens/splash_screen.dart';
import 'package:parking_reminder/services/notification_service.dart';
import 'package:parking_reminder/services/background_service.dart' as bg_service;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1) Инициализация Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // 2) Инициализация локальных уведомлений
  // Передаём колбэк-заглушку, фактическую логику разбора действий
  // будем обрабатывать внутри SplashScreen через NotificationService.handleAction
  await NotificationService.initialize(
    onActionCallback: (String action, String? payload) {
      SplashScreen.handleNotificationAction(action, payload);
    },
  );

  // 3) Инициализация фонового сервиса
  await bg_service.BackgroundService.initialize();

  // 5) Запуск приложения
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

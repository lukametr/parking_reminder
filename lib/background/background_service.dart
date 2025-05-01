// lib/background/background_service.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:firebase_core/firebase_core.dart';

import 'package:parking_reminder/services/notification_service.dart';
import 'package:parking_reminder/services/parking_service.dart';
import 'package:parking_reminder/services/kalman_filter.dart'; // Импортируем наш фильтр

@pragma('vm:entry-point')
Future<void> onStart(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  // === State-переменные ДО подписок ===
  String?   currentLot;              // Текущий номер лота, если пользователь "паркуется"
  LatLng?   parkingLocation;         // Координаты парковки
  DateTime? skipUntil;               // Время до которого не искать новую парковку
  bool      initialNotified = false; // Флаг, что уведомление о начале парковки уже показано
  bool      leaveNotified   = false; // Флаг, что уведомление об отъезде уже показано

  LatLng?   lastPosition;            // Последняя отфильтрованная позиция
  DateTime  lastStillTime   = DateTime.now(); // Время начала неподвижности
  const Distance dist        = Distance();

  // Инициализация Калман‑фильтра
  final kalmanFilter = KalmanLocationFilter();

  // === Обработка кликов по уведомлениям ===
  service.on('notificationResponse').listen((event) async {
    final data    = event as Map<String, dynamic>;
    final payload = data['payload'] as String;
    final action  = data['action']   as String;

    if (payload.startsWith('init:')) {
      final lot = payload.split(':')[1];
      if (action == 'park') {
        currentLot      = lot;
        parkingLocation = lastPosition;
        initialNotified = true;
        leaveNotified   = false;
      } else if (action == 'cancel') {
        skipUntil = DateTime.now().add(const Duration(minutes: 10));
      }
    } else if (payload.startsWith('leave:') && currentLot != null) {
      final lot = payload.split(':')[1];
      if (action == 'yes') {
        await NotificationService.showFinal(lot);
        // Сброс состояния
        currentLot      = null;
        parkingLocation = null;
        initialNotified = false;
        leaveNotified   = false;
      }
      if (action == 'no') {
        // При повторном отъезде спросим снова
        leaveNotified = false;
      }
    }
  });

  // === Основной таймер: проверка местоположения каждые 5 секунд ===
  Timer.periodic(const Duration(seconds: 5), (timer) async {
    try {
      // 1) Получаем позицию с максимальной навигационной точностью
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.bestForNavigation,
      );

      // 2) Жёсткая фильтрация: пропускаем точки с погрешностью более 10 м
      if (pos.accuracy > 10) {
        return;
      }

      // 3) Преобразуем в LatLng
      final nowLatLng = LatLng(pos.latitude, pos.longitude);

      // 4) Применяем Калман‑фильтр для сглаживания шума
      final filteredLatLng = kalmanFilter.filter(nowLatLng);

      // 5) Сохраняем позицию для дальнейших проверок
      LatLng currentPosition = filteredLatLng;

      // Если это первая точка — просто сохраняем и ждём следующего таймера
      if (lastPosition == null) {
        lastPosition   = currentPosition;
        lastStillTime  = DateTime.now();
        return;
      }

      // Вычисляем пройденное расстояние от последней позиции
      final moved = dist(lastPosition!, currentPosition);
      lastPosition = currentPosition;

      // === Логика уведомлений ===

      // 1) Если пользователь в процессе парковки — проверяем отъезд (>200 м)
      if (currentLot != null && parkingLocation != null) {
        final fromPark = dist(parkingLocation!, currentPosition);
        if (fromPark > 200 && !leaveNotified) {
          leaveNotified = true;
          await NotificationService.showLeave(currentLot!);
        }
        return;
      }

      // 2) Период "не беспокоить"
      if (skipUntil != null && DateTime.now().isBefore(skipUntil!)) {
        return;
      }

      // 3) Если неподвижность >5 с и ещё не оповещали — ищем парковку
      if (moved < 1 &&
          DateTime.now().difference(lastStillTime).inSeconds >= 5 &&
          !initialNotified) {
        // Используем исходную позицию для proximity (pos), а не filteredLatLng
        final lot = await ParkingService().checkProximity(pos);
        if (lot != null) {
          initialNotified = true;
          await NotificationService.showInit(lot);
        }
      } else if (moved >= 1) {
        // Сброс таймера неподвижности
        lastStillTime = DateTime.now();
      }
    } catch (e) {
      debugPrint('ფონური სერვისის შეცდომა: $e');
    }
  });
}

/// Инициализация foreground‑background сервиса без изменений
Future<void> initializeBackgroundService() async {
  final service = FlutterBackgroundService();
  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: true,
      isForegroundMode: true,
      notificationChannelId: 'parking_chan',
      initialNotificationTitle: 'Parking Reminder',
      initialNotificationContent: 'აპლიკაცია მუშაობს',
      foregroundServiceNotificationId: 888,
    ),
    iosConfiguration: IosConfiguration(onForeground: onStart),
  );
  service.startService();
}

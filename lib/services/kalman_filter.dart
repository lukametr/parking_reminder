import 'dart:math';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:rxdart/rxdart.dart';

/// Класс KalmanLocationFilter использует фильтр Калмана для сглаживания данных геолокации
/// и обеспечения более точного определения местоположения, особенно когда пользователь
/// не движется в течение определенного времени.
class KalmanLocationFilter {
  // Параметры фильтра Калмана
  double _varGPS = 5.0; // Начальная дисперсия GPS (в метрах)
  final double _varSpeed = 0.05; // Дисперсия скорости (м/с^2)
  final double _timeThreshold = 5.0; // Порог времени для определения остановки (в секундах)
  
  // Состояние фильтра
  double _latitude = 0.0;
  double _longitude = 0.0;
  double _accuracy = 10.0; // Начальная точность в метрах
  double _variance = 10.0; // Начальная дисперсия оценки
  DateTime? _lastUpdateTime;
  DateTime? _stoppedTime;
  bool _isStopped = false;
  
  // Последнее полученное "лучшее" положение
  Position? _bestPosition;
  
  /// Получить текущее отфильтрованное местоположение
  Position? get bestPosition => _bestPosition;
  
  /// Получить флаг остановки
  bool get isStopped => _isStopped;
  
  /// Получить время, в течение которого пользователь находится в неподвижном состоянии
  Duration get stoppedDuration {
    if (_stoppedTime == null) return Duration.zero;
    return DateTime.now().difference(_stoppedTime!);
  }
  
  /// Инициализация фильтра с исходным положением
  void init(Position position) {
    _latitude = position.latitude;
    _longitude = position.longitude;
    _accuracy = position.accuracy;
    _variance = position.accuracy * position.accuracy;
    _lastUpdateTime = DateTime.now();
    _bestPosition = position;
    _varGPS = max(5.0, position.accuracy);
  }
  
  /// Обработка нового местоположения через фильтр Калмана
  /// и определение, находится ли пользователь в неподвижном состоянии
  Position process(Position position) {
    // Если фильтр еще не инициализирован
    if (_lastUpdateTime == null) {
      init(position);
      return position;
    }
    
    // Расчет времени с последнего обновления
    final DateTime now = DateTime.now();
    final double dt = _lastUpdateTime != null ? 
        now.difference(_lastUpdateTime!).inMilliseconds / 1000.0 : 0.0;
    _lastUpdateTime = now;
    
    // Обновляем дисперсию с учетом времени
    _variance += _varSpeed * dt;
    
    // Коэффициент Калмана (K)
    final double k = _variance / (_variance + _varGPS);
    
    // Обновляем положение с использованием фильтра Калмана
    _latitude += k * (position.latitude - _latitude);
    _longitude += k * (position.longitude - _longitude);
    
    // Обновляем дисперсию и точность
    _variance = (1 - k) * _variance;
    _accuracy = sqrt(_variance);
    
    // Создаем новую позицию с отфильтрованными координатами
    final Position filteredPosition = Position(
      latitude: _latitude,
      longitude: _longitude,
      timestamp: position.timestamp,
      accuracy: _accuracy,
      altitude: position.altitude,
      heading: position.heading,
      speed: position.speed,
      speedAccuracy: position.speedAccuracy,
      altitudeAccuracy: position.altitudeAccuracy,
      headingAccuracy: position.headingAccuracy,
    );
    
    // Проверяем, не остановился ли пользователь
    _detectStop(position, filteredPosition);
    
    // Если пользователь остановился на более чем _timeThreshold секунд,
    // используем усредненные данные для более точного определения местоположения
    if (_isStopped && stoppedDuration.inSeconds > _timeThreshold) {
      // Постепенно улучшаем точность, снижая дисперсию GPS
      _varGPS = max(1.0, _varGPS * 0.95);
      _bestPosition = filteredPosition;
    } else {
      _bestPosition = filteredPosition;
      // При движении увеличиваем дисперсию GPS
      _varGPS = max(5.0, position.accuracy);
    }
    
    return filteredPosition;
  }
  
  /// Определение, остановился ли пользователь
  void _detectStop(Position rawPosition, Position filteredPosition) {
    // Остановка определяется по низкой скорости
    final bool isCurrentlyStopped = rawPosition.speed < 0.5; // метров в секунду
    
    if (isCurrentlyStopped) {
      if (!_isStopped) {
        _isStopped = true;
        _stoppedTime = DateTime.now();
      }
    } else {
      _isStopped = false;
      _stoppedTime = null;
    }
  }
}

/// Менеджер для работы с геолокацией, использующий фильтр Калмана
class LocationManager {
  final KalmanLocationFilter _kalmanFilter = KalmanLocationFilter();
  
  // Контроллер для передачи обновлений местоположения
  final StreamController<Position> _locationController = StreamController<Position>.broadcast();
  Stream<Position> get locationStream => _locationController.stream;
  
  // Таймер для проверки длительности остановки
  Timer? _stopTimer;
  
  // Флаг для отслеживания, запущен ли процесс определения местоположения
  bool _isRunning = false;
  
  /// Получить последнее наилучшее положение
  Position? get currentBestLocation => _kalmanFilter.bestPosition;
  
  /// Запустить отслеживание местоположения с фильтром Калмана
  Future<void> startTracking() async {
    if (_isRunning) return;
    
    _isRunning = true;
    
    // Проверка и запрос разрешений на определение местоположения
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Разрешение на определение местоположения отклонено');
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      throw Exception('Разрешение на определение местоположения отклонено навсегда');
    }
    
    // Получение текущего местоположения для инициализации фильтра
    try {
      final Position initialPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      _kalmanFilter.init(initialPosition);
      _locationController.add(initialPosition);
      
      // Подписка на поток обновлений местоположения
      Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 1, // фильтр расстояния в метрах
        ),
      ).listen(_onLocationUpdate);
      
    } catch (e) {
      _isRunning = false;
      rethrow;
    }
    
    // Запускаем таймер для проверки длительности остановки
    _stopTimer = Timer.periodic(const Duration(seconds: 1), _checkStopDuration);
  }
  
  /// Остановить отслеживание местоположения
  void stopTracking() {
    _isRunning = false;
    _stopTimer?.cancel();
    _stopTimer = null;
  }
  
  /// Обработка новых данных о местоположении
  void _onLocationUpdate(Position position) {
    if (!_isRunning) return;
    
    // Применяем фильтр Калмана
    final Position filteredPosition = _kalmanFilter.process(position);
    
    // Отправляем отфильтрованное положение подписчикам
    _locationController.add(filteredPosition);
  }
  
  /// Проверка длительности остановки и уведомление о точном местоположении
  void _checkStopDuration(Timer timer) {
    if (!_isRunning || _kalmanFilter.bestPosition == null) return;
    
    if (_kalmanFilter.isStopped && 
        _kalmanFilter.stoppedDuration.inSeconds > 5 && 
        _kalmanFilter.bestPosition != null) {
      // Пользователь остановился более чем на 5 секунд
      // Отправляем наиболее точное местоположение
      _locationController.add(_kalmanFilter.bestPosition!);
    }
  }
  
  /// Закрыть менеджер и освободить ресурсы
  void dispose() {
    stopTracking();
    _locationController.close();
  }
}

/// Пример виджета для использования фильтра Калмана в Flutter приложении
class KalmanLocationWidget extends StatefulWidget {
  const KalmanLocationWidget({super.key});

  @override
  KalmanLocationWidgetState createState() => KalmanLocationWidgetState();
}

class KalmanLocationWidgetState extends State<KalmanLocationWidget> {
  final LocationManager _locationManager = LocationManager();
  Position? _currentPosition;
  bool _isStopped = false;
  int _stoppedSeconds = 0;

  @override
  void initState() {
    super.initState();
    _startLocationTracking();
    
    // Подписка на поток обновлений местоположения
    _locationManager.locationStream.debounceTime(const Duration(milliseconds: 500)).listen((position) {
      setState(() {
        _currentPosition = position;
        _isStopped = _locationManager._kalmanFilter.isStopped;
        _stoppedSeconds = _locationManager._kalmanFilter.stoppedDuration.inSeconds;
      });
    });
  }

  Future<void> _startLocationTracking() async {
    try {
      await _locationManager.startTracking();
    } catch (e) {
      debugPrint('Ошибка при запуске отслеживания местоположения: $e');
    }
  }

  @override
  void dispose() {
    _locationManager.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Информация о местоположении',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            if (_currentPosition != null) ...[
              _buildInfoRow('Широта', _currentPosition!.latitude.toStringAsFixed(6)),
              _buildInfoRow('Долгота', _currentPosition!.longitude.toStringAsFixed(6)),
              _buildInfoRow('Точность', '${_currentPosition!.accuracy.toStringAsFixed(2)} м'),
              _buildInfoRow('Скорость', '${_currentPosition!.speed.toStringAsFixed(2)} м/с'),
              _buildInfoRow('Статус', _isStopped ? 'Остановлен' : 'В движении'),
              if (_isStopped)
                _buildInfoRow('Время остановки', '$_stoppedSeconds сек'),
              const SizedBox(height: 8),
              if (_isStopped && _stoppedSeconds > 5)
                Container(
                  padding: const EdgeInsets.all(8),
                  // ignore: deprecated_member_use
                  color: Colors.green.withOpacity(0.2),
                  child: const Text(
                    'Получено наиболее точное местоположение',
                    style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                  ),
                ),
            ] else
              const Text('Получение местоположения...'),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '$label:',
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          Text(value),
        ],
      ),
    );
  }
}

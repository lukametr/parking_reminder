import 'dart:async';

import 'package:geolocator/geolocator.dart';

import '../database/parking_database.dart';
import '../models/parking_zone.dart';
import 'notification_service.dart';

/// ერთიანი ლოგიკა: გაჩერება ზონაში, ზონიდან გასვლა, შეტყობინებები.
class ParkingSessionTracker {
  ParkingSessionTracker._();
  static final ParkingSessionTracker instance = ParkingSessionTracker._();

  final ParkingDatabase _database = ParkingDatabase();

  /// ფასიან ზონაში „დაპარკვის“ სესია (გაჩერებული მდგომარეობა).
  String? _activePaidParkSessionZoneId;

  Timer? _paidReminderTimer;

  /// ყოველი ახალი ლოკაცია: გასვლა იჭერება ყოველთვის; შესვლა/ზონაში რჩენა — სტაციონარულობისას.
  Future<void> process(Position position, {required bool isStationary}) async {
    try {
      final List<ParkingZone> zones = await _database.getParkingZones();

      await _checkExitFromPaidZone(position, zones);

      if (!isStationary) return;

      await _handleStationaryInZones(position, zones);
    } catch (e) {
      // ignore: avoid_print
      print('ParkingSessionTracker: $e');
    }
  }

  Future<void> _checkExitFromPaidZone(
    Position position,
    List<ParkingZone> zones,
  ) async {
    if (_activePaidParkSessionZoneId == null) return;

    final ParkingZone? zone = _zoneById(zones, _activePaidParkSessionZoneId!);
    if (zone == null || !zone.isPaid) {
      _endPaidSession(clearThrottle: false);
      return;
    }

    if (zone.isPastExitBuffer(position)) {
      await NotificationService.instance.showServiceMessage(
        92001,
        'პარკინგის ზონა დატოვებულია',
        '${zone.name} — სესია დასრულებულია.',
      );
      _endPaidSession(clearThrottle: true);
    }
  }

  Future<void> _handleStationaryInZones(
    Position position,
    List<ParkingZone> zones,
  ) async {
    for (final ParkingZone zone in zones) {
      if (!zone.contains(position)) continue;

      if (zone.isPaid) {
        final bool newSession = _activePaidParkSessionZoneId != zone.id;
        if (newSession) {
          _activePaidParkSessionZoneId = zone.id;
          await NotificationService.instance.maybeNotifyPaidZone(
            zone.id,
            'ფასიანი პარკინგი',
            '${zone.name} — გადაამოწმეთ ლოტის ნომერი და საფასური.',
          );
          _schedulePaidReminder(zone);
        }
      } else {
        await NotificationService.instance.maybeNotifyFreeZone(
          zone.id,
          'უფასო პარკინგი',
          'ზონა: ${zone.name}',
        );
      }
      return;
    }
  }

  ParkingZone? _zoneById(List<ParkingZone> zones, String id) {
    for (final ParkingZone z in zones) {
      if (z.id == id) return z;
    }
    return null;
  }

  void _schedulePaidReminder(ParkingZone zone) {
    _paidReminderTimer?.cancel();
    _paidReminderTimer = Timer(const Duration(minutes: 55), () async {
      await NotificationService.instance.showServiceMessage(
        91002,
        'პარკინგის შეხსენება',
        '${zone.name} — გადაამოწმეთ პარკინგის დრო/ლოტი.',
      );
    });
  }

  void _endPaidSession({required bool clearThrottle}) {
    _activePaidParkSessionZoneId = null;
    _paidReminderTimer?.cancel();
    _paidReminderTimer = null;
    if (clearThrottle) {
      NotificationService.instance.clearPaidParkingThrottle();
    }
  }

  void cancelSession() {
    _endPaidSession(clearThrottle: false);
  }
}

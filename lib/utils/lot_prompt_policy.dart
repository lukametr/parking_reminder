import 'lot_index.dart';

/// Stay-prompt rules: 5s dwell is applied by the caller; this class is
/// global 10-minute cooldown + same-lot silence until the user leaves.
class LotPromptPolicy {
  LotPromptPolicy({
    this.globalCooldown = const Duration(minutes: 10),
    this.leaveMeters = 50,
  });

  final Duration globalCooldown;
  final double leaveMeters;

  DateTime? suppressUntil;
  final Set<String> declinedLots = <String>{};
  double? declinedLat;
  double? declinedLng;

  void decline({
    required Iterable<String> lots,
    required double latitude,
    required double longitude,
    DateTime? now,
  }) {
    final DateTime t = now ?? DateTime.now();
    suppressUntil = t.add(globalCooldown);
    declinedLots
      ..clear()
      ..addAll(lots.where((String e) => e.isNotEmpty));
    declinedLat = latitude;
    declinedLng = longitude;
  }

  /// Drop same-lot silence once the user has left those lots / that point.
  void noteFix({
    required List<String> nearbyLots,
    required double latitude,
    required double longitude,
  }) {
    if (declinedLots.isEmpty) return;
    final bool stillAtLot = nearbyLots.any(declinedLots.contains);
    final double dist = (declinedLat == null || declinedLng == null)
        ? double.infinity
        : LotIndex.haversineMeters(
            latitude,
            longitude,
            declinedLat!,
            declinedLng!,
          );
    if (!stillAtLot && dist > leaveMeters) {
      declinedLots.clear();
      declinedLat = null;
      declinedLng = null;
    }
  }

  bool inGlobalCooldown(DateTime now) {
    final DateTime? until = suppressUntil;
    return until != null && now.isBefore(until);
  }

  bool canPrompt({
    required List<String> lots,
    required double latitude,
    required double longitude,
    DateTime? now,
  }) {
    final DateTime t = now ?? DateTime.now();
    noteFix(nearbyLots: lots, latitude: latitude, longitude: longitude);
    if (lots.isEmpty) return false;
    if (inGlobalCooldown(t)) return false;
    if (lots.any(declinedLots.contains)) return false;
    return true;
  }
}

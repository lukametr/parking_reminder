import 'package:geolocator/geolocator.dart';

class ParkingZone {
  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final double radius; // ზონის რადიუსი მეტრებში
  final bool isPaid; // ფასიანია თუ უფასო
  final String? description;
  final double? pricePerHour; // ფასი საათში
  final DateTime? createdAt;

  ParkingZone({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.radius,
    required this.isPaid,
    this.description,
    this.pricePerHour,
    this.createdAt,
  });

  // კონვერტაცია Map-დან
  factory ParkingZone.fromMap(Map<String, dynamic> map) {
    return ParkingZone(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      latitude: map['latitude']?.toDouble() ?? 0.0,
      longitude: map['longitude']?.toDouble() ?? 0.0,
      radius: map['radius']?.toDouble() ?? 0.0,
      isPaid: map['is_paid'] == 1,
      description: map['description'],
      pricePerHour: map['price_per_hour']?.toDouble(),
      createdAt: map['created_at'] != null 
          ? DateTime.parse(map['created_at']) 
          : null,
    );
  }

  // კონვერტაცია Map-ში
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'latitude': latitude,
      'longitude': longitude,
      'radius': radius,
      'is_paid': isPaid ? 1 : 0,
      'description': description,
      'price_per_hour': pricePerHour,
      'created_at': createdAt?.toIso8601String(),
    };
  }

  double distanceMetersFrom(Position position) {
    return Geolocator.distanceBetween(
      latitude,
      longitude,
      position.latitude,
      position.longitude,
    );
  }

  /// ზონის ცენტრიდან [radius]-ში (შესვლა / პარკინგი).
  bool contains(Position position) => distanceMetersFrom(position) <= radius;

  /// GPS რყევისთვის: ზონიდან გასვლა — როცა ცენტრზე მანძილი > radius + buffer.
  bool isPastExitBuffer(Position position, {double bufferMeters = 38}) {
    return distanceMetersFrom(position) > radius + bufferMeters;
  }

  @override
  String toString() {
    return 'ParkingZone(id: $id, name: $name, isPaid: $isPaid)';
  }
}

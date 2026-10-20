class ParkingLot {
  const ParkingLot({
    required this.id,
    required this.lotNumber,
    required this.latitude,
    required this.longitude,
  });

  final String id;
  final String lotNumber;
  final double latitude;
  final double longitude;

  Map<String, dynamic> toNativeMap() => {
        'id': id,
        'lotNumber': lotNumber,
        'lat': latitude,
        'lng': longitude,
      };
}

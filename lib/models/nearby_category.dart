import 'package:flutter/material.dart';

/// A Services-screen category and the OpenStreetMap tags that define it.
class NearbyCategory {
  final String id;
  final String title;
  final String screenTitle;
  final String singular;
  final IconData icon;
  final Color color;

  /// Overpass tag filters, e.g. `["amenity"="police"]`. Each one is OR-ed.
  final List<String> osmFilters;

  /// Nominatim free-text queries used when Overpass is unavailable.
  final List<String> nominatimQueries;

  const NearbyCategory({
    required this.id,
    required this.title,
    required this.screenTitle,
    required this.singular,
    required this.icon,
    required this.color,
    required this.osmFilters,
    required this.nominatimQueries,
  });

  static const NearbyCategory police = NearbyCategory(
    id: 'police',
    title: 'პოლიცია',
    screenTitle: 'პოლიცია ახლოს',
    singular: 'პოლიციის განყოფილება',
    icon: Icons.local_police,
    color: Color(0xFF1565C0),
    osmFilters: ['["amenity"="police"]'],
    nominatimQueries: ['police'],
  );

  static const NearbyCategory food = NearbyCategory(
    id: 'food',
    title: 'კვება',
    screenTitle: 'კვების ობიექტები ახლოს',
    singular: 'კვების ობიექტი',
    icon: Icons.restaurant,
    color: Color(0xFFE65100),
    osmFilters: ['["amenity"~"^(restaurant|cafe|fast_food|food_court)\$"]'],
    nominatimQueries: ['restaurant', 'cafe', 'fast food'],
  );

  static const NearbyCategory shop = NearbyCategory(
    id: 'shop',
    title: 'მაღაზია',
    screenTitle: 'მაღაზიები ახლოს',
    singular: 'მაღაზია',
    icon: Icons.shopping_cart,
    color: Color(0xFF6A1B9A),
    osmFilters: [
      '["shop"~"^(supermarket|convenience|general|department_store|mall|greengrocer|grocery)\$"]',
    ],
    nominatimQueries: ['supermarket', 'convenience store'],
  );

  static const NearbyCategory autoService = NearbyCategory(
    id: 'auto_service',
    title: 'ავტოსერვისი',
    screenTitle: 'ავტოსერვისები ახლოს',
    singular: 'ავტოსერვისი',
    icon: Icons.build,
    color: Color(0xFF37474F),
    osmFilters: [
      '["shop"~"^(car_repair|car_parts)\$"]',
      '["craft"="car_repair"]',
    ],
    nominatimQueries: ['car repair', 'car parts'],
  );

  static const NearbyCategory vulcanization = NearbyCategory(
    id: 'vulcanization',
    title: 'ვულკანიზაცია',
    screenTitle: 'ვულკანიზაციები ახლოს',
    singular: 'ვულკანიზაცია',
    icon: Icons.tire_repair,
    color: Color(0xFF424242),
    osmFilters: [
      '["shop"="tyres"]',
      '["service:vehicle:tyres"="yes"]',
      '["shop"="car_repair"]["name"~"ვულკან|vulkan|vulcan|шином",i]',
    ],
    nominatimQueries: ['ვულკანიზაცია', 'vulcanization'],
  );

  static const NearbyCategory pharmacy = NearbyCategory(
    id: 'pharmacy',
    title: 'აფთიაქი',
    screenTitle: 'აფთიაქები ახლოს',
    singular: 'აფთიაქი',
    icon: Icons.local_pharmacy,
    color: Color(0xFF2E7D32),
    osmFilters: [
      '["amenity"="pharmacy"]',
      '["healthcare"="pharmacy"]',
    ],
    nominatimQueries: ['pharmacy'],
  );

  static const NearbyCategory fuel = NearbyCategory(
    id: 'fuel',
    title: 'საწვავი',
    screenTitle: 'ბენზინგასამართები ახლოს',
    singular: 'ბენზინგასამართი სადგური',
    icon: Icons.local_gas_station,
    color: Color(0xFFC62828),
    osmFilters: ['["amenity"="fuel"]'],
    nominatimQueries: ['fuel'],
  );

  static const List<NearbyCategory> all = [
    police,
    food,
    shop,
    autoService,
    vulcanization,
    pharmacy,
    fuel,
  ];

  static NearbyCategory? byTitle(String title) {
    for (final NearbyCategory c in all) {
      if (c.title == title) return c;
    }
    return null;
  }
}

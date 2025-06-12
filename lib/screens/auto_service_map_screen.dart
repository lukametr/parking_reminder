import 'package:flutter/material.dart';
import 'places_map_screen.dart';

class AutoServiceMapScreen extends StatelessWidget {
  const AutoServiceMapScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const PlacesMapScreen(
      title: 'ავტოსერვისები',
      placeType: 'car_repair',
      keyword: 'ავტოსერვისი',
      icon: Icons.build,
    );
  }
} 
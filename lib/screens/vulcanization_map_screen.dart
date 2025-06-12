import 'package:flutter/material.dart';
import 'places_map_screen.dart';

class VulcanizationMapScreen extends StatelessWidget {
  const VulcanizationMapScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const PlacesMapScreen(
      title: 'ვულკანიზაციები',
      placeType: 'tire_shop',
      keyword: 'ვულკანიზაცია',
      icon: Icons.tire_repair,
    );
  }
} 
import 'package:flutter/material.dart';
import 'places_map_screen.dart';

class FoodMapScreen extends StatelessWidget {
  const FoodMapScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const PlacesMapScreen(
      title: 'კვების ობიექტები',
      placeType: 'restaurant',
      keyword: 'რესტორანი',
      icon: Icons.restaurant,
    );
  }
} 
import 'package:flutter/material.dart';
import 'places_map_screen.dart';

class ShopMapScreen extends StatelessWidget {
  const ShopMapScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const PlacesMapScreen(
      title: 'მაღაზიები',
      placeType: 'store',
      keyword: 'მაღაზია',
      icon: Icons.shopping_bag,
    );
  }
} 
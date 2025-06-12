import 'package:flutter/material.dart';
import 'places_map_screen.dart';

class PoliceMapScreen extends StatelessWidget {
  const PoliceMapScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const PlacesMapScreen(
      title: 'პოლიციის ოფისები',
      placeType: 'police',
      keyword: 'პოლიცია',
      icon: Icons.local_police,
    );
  }
} 
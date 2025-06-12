import 'package:flutter/material.dart';
import 'places_map_screen.dart';

class GasStationMapScreen extends StatelessWidget {
  const GasStationMapScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const PlacesMapScreen(
      title: 'ბენზინგასამართი სადგურები',
      placeType: 'gas_station',
      keyword: 'ბენზინგასამართი',
      icon: Icons.local_gas_station,
    );
  }
} 
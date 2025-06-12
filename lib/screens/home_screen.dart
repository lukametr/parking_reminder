import 'police_map_screen.dart';
import 'food_map_screen.dart';
import 'shop_map_screen.dart';
import 'auto_service_map_screen.dart';
import 'vulcanization_map_screen.dart';
import 'gas_station_map_screen.dart';

Widget _buildMenuButton(String title, IconData icon, VoidCallback onTap) {
  return Card(
    elevation: 4,
    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, size: 32, color: Theme.of(context).primaryColor),
            const SizedBox(width: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Spacer(),
            const Icon(Icons.arrow_forward_ios),
          ],
        ),
      ),
    ),
  );
}

@override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(
      title: const Text('მთავარი მენიუ'),
      actions: [
        IconButton(
          icon: const Icon(Icons.settings),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const SettingsScreen()),
            );
          },
        ),
      ],
    ),
    body: ListView(
      children: [
        _buildMenuButton(
          'პოლიციის ოფისები',
          Icons.local_police,
          () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const PoliceMapScreen()),
            );
          },
        ),
        _buildMenuButton(
          'კვების ობიექტები',
          Icons.restaurant,
          () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const FoodMapScreen()),
            );
          },
        ),
        _buildMenuButton(
          'მაღაზიები',
          Icons.shopping_bag,
          () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ShopMapScreen()),
            );
          },
        ),
        _buildMenuButton(
          'ავტოსერვისები',
          Icons.build,
          () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const AutoServiceMapScreen()),
            );
          },
        ),
        _buildMenuButton(
          'ვულკანიზაციები',
          Icons.tire_repair,
          () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const VulcanizationMapScreen()),
            );
          },
        ),
        _buildMenuButton(
          'ბენზინგასამართი სადგურები',
          Icons.local_gas_station,
          () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const GasStationMapScreen()),
            );
          },
        ),
        _buildMenuButton(
          'აფთიაქები',
          Icons.local_pharmacy,
          () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const PharmacyMapScreen()),
            );
          },
        ),
      ],
    ),
  );
} 
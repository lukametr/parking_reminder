import 'package:url_launcher/url_launcher.dart';

/// სატელეფონო ნომერზე გადასვლა (SOS / დაზღვევა).
Future<void> dialNumber(String number) async {
  final String digits = number.replaceAll(RegExp(r'[^\d]'), '');
  if (digits.isEmpty) return;

  final Uri uri = Uri(scheme: 'tel', path: digits);
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}

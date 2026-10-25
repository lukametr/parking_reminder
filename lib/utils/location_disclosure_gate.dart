import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/privacy.dart';
import '../screens/location_disclosure_screen.dart';

/// Ensures Play Prominent Disclosure was accepted before any location API.
Future<bool> ensureLocationDisclosureAccepted(BuildContext context) async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  if (prefs.getBool(PrivacyConfig.disclosureAcceptedKey) == true) {
    return true;
  }
  if (!context.mounted) return false;
  final bool accepted = await LocationDisclosureScreen.present(context);
  if (accepted) {
    await prefs.setBool(PrivacyConfig.disclosureAcceptedKey, true);
  }
  return accepted;
}

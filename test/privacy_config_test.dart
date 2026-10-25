import 'package:flutter_test/flutter_test.dart';
import 'package:parking_reminder/config/privacy.dart';

void main() {
  test('Play privacy URL is Firebase Hosting', () {
    expect(
      PrivacyConfig.policyUrl,
      'https://parkingreminder-6466d.web.app/privacy/',
    );
  });

  test('disclosure key is versioned for Play re-review', () {
    expect(
      PrivacyConfig.disclosureAcceptedKey,
      'location_disclosure_accepted_v2',
    );
  });
}

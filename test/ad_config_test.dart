import 'package:flutter_test/flutter_test.dart';
import 'package:parking_reminder/config/ad_config.dart';

void main() {
  test('production banner is Standard Banner main-banner unit', () {
    expect(
      AdConfig.bannerAdUnitId,
      'ca-app-pub-8872582533953072/5359269234',
    );
    expect(AdConfig.bannerId, AdConfig.bannerAdUnitId);
  });

  test('banner id is not the old Native unit', () {
    expect(
      AdConfig.bannerAdUnitId,
      isNot('ca-app-pub-8872582533953072/4282381975'),
    );
  });
}

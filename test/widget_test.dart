import 'package:flutter_test/flutter_test.dart';
import 'package:parking_reminder/utils/lot_index.dart';

void main() {
  test('app module loads lot math', () {
    expect(LotIndex.haversineMeters(0, 0, 0, 0), 0);
  });
}

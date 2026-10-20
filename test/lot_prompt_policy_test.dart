import 'package:flutter_test/flutter_test.dart';
import 'package:parking_reminder/utils/lot_prompt_policy.dart';

void main() {
  test('decline suppresses every lot for 10 minutes', () {
    final LotPromptPolicy p = LotPromptPolicy();
    final DateTime t0 = DateTime.utc(2026, 1, 1);
    p.decline(
      lots: <String>['A'],
      latitude: 41.7,
      longitude: 44.8,
      now: t0,
    );
    expect(
      p.canPrompt(
        lots: <String>['B'],
        latitude: 41.71,
        longitude: 44.81,
        now: t0.add(const Duration(minutes: 9)),
      ),
      isFalse,
    );
    expect(
      p.canPrompt(
        lots: <String>['B'],
        latitude: 41.71,
        longitude: 44.81,
        now: t0.add(const Duration(minutes: 11)),
      ),
      isTrue,
    );
  });

  test('same lot stays silent after cooldown until user leaves', () {
    final LotPromptPolicy p = LotPromptPolicy();
    final DateTime t0 = DateTime.utc(2026, 1, 1);
    p.decline(
      lots: <String>['A'],
      latitude: 41.7,
      longitude: 44.8,
      now: t0,
    );
    expect(
      p.canPrompt(
        lots: <String>['A'],
        latitude: 41.70001,
        longitude: 44.80001,
        now: t0.add(const Duration(minutes: 11)),
      ),
      isFalse,
    );
    // Left the lot (~200 m).
    expect(
      p.canPrompt(
        lots: <String>['C'],
        latitude: 41.702,
        longitude: 44.8,
        now: t0.add(const Duration(minutes: 12)),
      ),
      isTrue,
    );
  });
}

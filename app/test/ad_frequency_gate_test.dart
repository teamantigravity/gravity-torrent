import 'package:flutter_test/flutter_test.dart';
import 'package:gravity_torrent/services/ads/ad_frequency_gate.dart';

void main() {
  group('FullScreenAdFrequencyGate', () {
    final now = DateTime(2026, 10, 24, 12);

    test('allows an impression when no previous impression is recorded', () {
      final gate = FullScreenAdFrequencyGate(clock: () => now);

      expect(gate.canShow, isTrue);
    });

    test('blocks impressions until the shared interval has elapsed', () {
      var currentTime = now;
      final gate = FullScreenAdFrequencyGate(clock: () => currentTime);
      gate.markShown();

      currentTime = now.add(const Duration(hours: 3, minutes: 59));
      expect(gate.canShow, isFalse);

      currentTime = now.add(const Duration(hours: 4));
      expect(gate.canShow, isTrue);
    });

    test('restores the previous impression time across app launches', () {
      var currentTime = now.add(const Duration(hours: 2));
      final gate = FullScreenAdFrequencyGate(clock: () => currentTime);
      gate.restore(now);

      expect(gate.canShow, isFalse);

      currentTime = now.add(const Duration(hours: 4));
      expect(gate.canShow, isTrue);
    });

    test('does not allow a future timestamp to bypass the interval', () {
      final gate = FullScreenAdFrequencyGate(clock: () => now);
      gate.restore(now.add(const Duration(minutes: 1)));

      expect(gate.canShow, isFalse);
    });
  });
}

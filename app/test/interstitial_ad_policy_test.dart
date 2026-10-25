import 'package:flutter_test/flutter_test.dart';
import 'package:gravity_torrent/services/ads/interstitial_ad_policy.dart';

void main() {
  test('first launch never requests or presents full-screen ads', () {
    final policy = InterstitialAdPolicy(isFirstSession: true);
    expect(policy.canRequestAd, isFalse);
    for (var i = 0; i < 10; i++) {
      expect(policy.onTorrentAdded(adReady: true, isForeground: true), isFalse);
    }
  });

  test('only the second completed task can reserve an ad on later launches',
      () {
    final policy = InterstitialAdPolicy(isFirstSession: false);
    expect(policy.canRequestAd, isTrue);
    expect(policy.onTorrentAdded(adReady: true, isForeground: true), isFalse);
    expect(policy.onTorrentAdded(adReady: true, isForeground: true), isTrue);
    expect(policy.canRequestAd, isFalse);
  });

  test('one presentation attempt per launch, including SDK show failures', () {
    final policy = InterstitialAdPolicy(isFirstSession: false);
    policy.onTorrentAdded(adReady: true, isForeground: true);
    expect(policy.onTorrentAdded(adReady: true, isForeground: true), isTrue);
    for (var i = 0; i < 10; i++) {
      expect(policy.onTorrentAdded(adReady: true, isForeground: true), isFalse);
    }
  });

  test('missed inventory waits for a new task and cannot show on ad load', () {
    final policy = InterstitialAdPolicy(isFirstSession: false);
    expect(policy.onTorrentAdded(adReady: false, isForeground: true), isFalse);
    expect(policy.onTorrentAdded(adReady: false, isForeground: true), isFalse);
    expect(policy.canRequestAd, isTrue);
    expect(policy.onTorrentAdded(adReady: true, isForeground: true), isTrue);
  });

  test('background completions neither show nor advance the task count', () {
    final policy = InterstitialAdPolicy(isFirstSession: false);
    for (var i = 0; i < 10; i++) {
      expect(
        policy.onTorrentAdded(adReady: true, isForeground: false),
        isFalse,
      );
    }
    expect(policy.onTorrentAdded(adReady: true, isForeground: true), isFalse);
    expect(policy.onTorrentAdded(adReady: true, isForeground: true), isTrue);
  });

  test('a new launch requires its own completed tasks', () {
    final previous = InterstitialAdPolicy(isFirstSession: false);
    previous.onTorrentAdded(adReady: true, isForeground: true);
    previous.onTorrentAdded(adReady: true, isForeground: true);
    final next = InterstitialAdPolicy(isFirstSession: false);
    expect(next.onTorrentAdded(adReady: true, isForeground: true), isFalse);
    expect(next.onTorrentAdded(adReady: true, isForeground: true), isTrue);
  });
}

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
// The SDK's test channel needs its private message codec/instance registry.
// ignore: implementation_imports
import 'package:google_mobile_ads/src/ad_instance_manager.dart';
import 'package:gravity_torrent/services/ads/ad_service_mobile.dart';
import 'package:gravity_torrent/services/remote_config/remote_config_service.dart';
import 'package:gravity_torrent/storage/shared_preferences.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  final calls = <MethodCall>[];
  final services = <AdServiceMobile>[];
  var failShow = false;

  Future<void> preferences({
    bool seenSession = true,
    bool adFree = false,
    bool adsEnabled = true,
  }) async {
    SharedPreferences.setMockInitialValues({
      'gravity_torrent_ads_has_started_session': seenSession,
      'gravity_torrent_ad_free': adFree,
      'gravity_torrent_remote_config_last_fetch':
          DateTime.now().millisecondsSinceEpoch,
      'gravity_torrent_remote_config_cache':
          jsonEncode({'show_ads': adsEnabled}),
    });
    SharedPrefsStorage.resetForTest();
    RemoteConfigService.instance.resetForTest();
  }

  Future<AdServiceMobile> start() async {
    final service = AdServiceMobile();
    services.add(service);
    await service.init();
    return service;
  }

  int count(String method) => calls.where((c) => c.method == method).length;

  Future<void> loaded() async {
    final call = calls.lastWhere((c) => c.method == 'loadInterstitialAd');
    final args = call.arguments as Map<dynamic, dynamic>;
    final message = instanceManager.channel.codec.encodeMethodCall(
      MethodCall(
        'onAdEvent',
        {'adId': args['adId'], 'eventName': 'onAdLoaded'},
      ),
    );
    // Simulate the native callback using the SDK's own wire codec.
    // ignore: deprecated_member_use
    await binding.defaultBinaryMessenger.handlePlatformMessage(
      instanceManager.channel.name,
      message,
      (_) {},
    );
  }

  setUp(() async {
    calls.clear();
    services.clear();
    failShow = false;
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    instanceManager = AdInstanceManager('plugins.flutter.io/google_mobile_ads');
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      instanceManager.channel,
      (call) async {
        calls.add(call);
        if (call.method == 'MobileAds#initialize') {
          return InitializationStatus({});
        }
        if (call.method == 'showAdWithoutView' && failShow) {
          throw PlatformException(code: 'test_show_failure');
        }
        return null;
      },
    );
    await preferences();
  });

  tearDown(() async {
    for (final service in services) {
      service.dispose();
    }
    await Future<void>.delayed(Duration.zero);
    binding.defaultBinaryMessenger
        .setMockMethodCallHandler(instanceManager.channel, null);
    debugDefaultTargetPlatformOverride = null;
  });

  test('first launch skips full-screen inventory and persists first-use state',
      () async {
    await preferences(seenSession: false);
    final first = await start();
    for (var i = 0; i < 5; i++) {
      first.onTorrentAdded();
    }
    expect(count('loadInterstitialAd'), 0);
    expect(count('showAdWithoutView'), 0);
    expect(
      (await SharedPreferences.getInstance())
          .getBool('gravity_torrent_ads_has_started_session'),
      isTrue,
    );
    first.dispose();
    await start();
    expect(count('loadInterstitialAd'), 1);
  });

  test('loaded ads and foregrounding never show; the second task shows once',
      () async {
    final service = await start();
    await loaded();
    binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    expect(count('showAdWithoutView'), 0);
    service.onTorrentAdded();
    expect(count('showAdWithoutView'), 0);
    service.onTorrentAdded();
    await Future<void>.delayed(Duration.zero);
    expect(count('showAdWithoutView'), 1);
    for (var i = 0; i < 5; i++) {
      service.onTorrentAdded();
    }
    expect(count('showAdWithoutView'), 1);
    expect(count('loadInterstitialAd'), 1);
    expect(count('loadAppOpenAd'), 0);
  });

  test('missing inventory cannot create a delayed surprise ad', () async {
    final service = await start();
    service.onTorrentAdded();
    service.onTorrentAdded();
    expect(count('showAdWithoutView'), 0);
    await loaded();
    expect(count('showAdWithoutView'), 0);
    service.onTorrentAdded();
    await Future<void>.delayed(Duration.zero);
    expect(count('showAdWithoutView'), 1);
  });

  test('overlapping playback scopes suppress ads and release idempotently',
      () async {
    final service = await start();
    await loaded();
    final releaseFirst = service.suppressFullScreenAds();
    final releaseSecond = service.suppressFullScreenAds();
    service.onTorrentAdded();
    service.onTorrentAdded();
    releaseFirst();
    releaseFirst();
    service.onTorrentAdded();
    expect(count('showAdWithoutView'), 0);
    releaseSecond();
    service.onTorrentAdded();
    expect(count('showAdWithoutView'), 0);
    service.onTorrentAdded();
    await Future<void>.delayed(Duration.zero);
    expect(count('showAdWithoutView'), 1);
  });

  test('background tasks do not count toward a later ad', () async {
    final service = await start();
    await loaded();
    binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    service.onTorrentAdded();
    service.onTorrentAdded();
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    service.onTorrentAdded();
    expect(count('showAdWithoutView'), 0);
    service.onTorrentAdded();
    await Future<void>.delayed(Duration.zero);
    expect(count('showAdWithoutView'), 1);
  });

  test('show failure consumes the launch cap and is disposed without retrying',
      () async {
    failShow = true;
    final service = await start();
    await loaded();
    service.onTorrentAdded();
    service.onTorrentAdded();
    await Future<void>.delayed(Duration.zero);
    service.onTorrentAdded();
    expect(count('showAdWithoutView'), 1);
    expect(count('disposeAd'), 1);
    expect(count('loadInterstitialAd'), 1);
  });

  test(
      'ad-free entitlement and remote kill switch prevent full-screen requests',
      () async {
    await preferences(adFree: true);
    final premium = await start();
    premium.onTorrentAdded();
    premium.onTorrentAdded();
    expect(count('loadInterstitialAd'), 0);
    expect(premium.canShowAds, isFalse);
    await preferences(adsEnabled: false);
    final disabled = await start();
    disabled.onTorrentAdded();
    disabled.onTorrentAdded();
    expect(count('loadInterstitialAd'), 0);
    expect(count('showAdWithoutView'), 0);
    expect(disabled.canShowAds, isFalse);
  });

  test('purchase suppresses inventory loaded after entitlement changes',
      () async {
    final service = await start();
    await service.setAdFree(true);
    await loaded();
    service.onTorrentAdded();
    service.onTorrentAdded();
    await Future<void>.delayed(Duration.zero);
    expect(service.isAdFree, isTrue);
    expect(count('showAdWithoutView'), 0);
    expect(count('disposeAd'), 1);
  });

  test('late loaded inventory after disposal is disposed without showing',
      () async {
    final service = await start();
    service.dispose();
    await loaded();
    await Future<void>.delayed(Duration.zero);
    expect(count('showAdWithoutView'), 0);
    expect(count('disposeAd'), 1);
  });
}

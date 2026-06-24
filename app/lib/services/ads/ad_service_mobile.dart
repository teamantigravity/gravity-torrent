import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:gravity_torrent/services/ads/ad_ids.dart';
import 'package:gravity_torrent/services/ads/ad_service.dart';
import 'package:gravity_torrent/services/remote_config/remote_config_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// AdMob-backed implementation. Only active on Android/iOS when remote config allows.
class AdServiceMobile implements AdService {
  bool _initialized = false;
  final ValueNotifier<bool> _adFreeNotifier = ValueNotifier<bool>(false);
  InterstitialAd? _interstitial;
  int _interstitialRetries = 0;

  static const _adFreeKey = 'gravity_torrent_ad_free';

  bool get _platformSupported =>
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  @override
  bool get isInitialized => _initialized;

  @override
  bool get isAdFree => _adFreeNotifier.value;

  @override
  ValueNotifier<bool> get adFreeNotifier => _adFreeNotifier;

  @override
  bool get canShowAds {
    if (!_platformSupported || !_initialized || _adFreeNotifier.value) return false;
    if (!RemoteConfigService.instance.showAds) return false;
    return AdIds.useTestIds || AdIds.hasValidProductionIds;
  }

  @override
  Future<void> init() async {
    if (!_platformSupported) {
      _initialized = true;
      return;
    }
    try {
      await RemoteConfigService.instance.refresh();
      final prefs = await SharedPreferences.getInstance();
      _adFreeNotifier.value = prefs.getBool(_adFreeKey) ?? false;
      if (_adFreeNotifier.value || !RemoteConfigService.instance.showAds) {
        _initialized = true;
        return;
      }
      await MobileAds.instance.initialize();
      _initialized = true;
      _preloadInterstitial();
    } catch (e) {
      debugPrint('[AdService] init failed (continuing without ads): $e');
      _initialized = false;
    }
  }

  @override
  Future<void> setAdFree(bool value) async {
    _adFreeNotifier.value = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_adFreeKey, value);
    if (value) {
      await _interstitial?.dispose();
      _interstitial = null;
    }
  }

  @override
  Widget? buildBanner({Key? key}) {
    if (!canShowAds) return null;
    return _BannerAdHost(key: key);
  }

  @override
  void showInterstitialIfReady() {
    if (!canShowAds || _interstitial == null) return;
    unawaited(_interstitial!.show());
  }

  void _preloadInterstitial() {
    if (!canShowAds || _interstitial != null) return;
    InterstitialAd.load(
      adUnitId: AdIds.interstitial,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitial = ad;
          _interstitialRetries = 0;
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              _interstitial = null;
              _preloadInterstitial();
            },
            onAdFailedToShowFullScreenContent: (ad, _) {
              ad.dispose();
              _interstitial = null;
              _preloadInterstitial();
            },
          );
        },
        onAdFailedToLoad: (_) {
          _interstitial = null;
          _interstitialRetries++;
          if (_interstitialRetries < 6) {
            final delay = Duration(seconds: 1 << _interstitialRetries);
            Future.delayed(delay, _preloadInterstitial);
          }
        },
      ),
    );
  }

  @override
  void dispose() {
    unawaited(_interstitial?.dispose());
    _interstitial = null;
  }
}

class _BannerAdHost extends StatefulWidget {
  const _BannerAdHost({super.key});

  @override
  State<_BannerAdHost> createState() => _BannerAdHostState();
}

class _BannerAdHostState extends State<_BannerAdHost> {
  BannerAd? _banner;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _banner = BannerAd(
      adUnitId: AdIds.banner,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) => setState(() => _loaded = true),
        onAdFailedToLoad: (ad, _) {
          ad.dispose();
          _banner = null;
        },
      ),
    )..load();
  }

  @override
  void dispose() {
    _banner?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded || _banner == null) return const SizedBox.shrink();
    return SizedBox(
      width: _banner!.size.width.toDouble(),
      height: _banner!.size.height.toDouble(),
      child: AdWidget(ad: _banner!),
    );
  }
}

AdService createAdService() => AdServiceMobile();

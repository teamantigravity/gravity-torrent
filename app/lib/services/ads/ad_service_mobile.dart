import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:gravity_torrent/services/ads/ad_ids.dart';
import 'package:gravity_torrent/services/ads/ad_service.dart';
import 'package:gravity_torrent/services/ads/interstitial_ad_policy.dart';
import 'package:gravity_torrent/services/remote_config/remote_config_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// AdMob banners and task-boundary interstitials. No launch/resume ads.
class AdServiceMobile implements AdService {
  bool _initialized = false;
  bool _disposed = false;
  bool _sdkReady = false;
  Future<void>? _initialization;
  Future<void>? _sdkInitialization;
  final ValueNotifier<bool> _adFreeNotifier = ValueNotifier<bool>(false);
  InterstitialAd? _interstitial;
  InterstitialAdPolicy? _policy;
  bool _preloadingInterstitial = false;
  int _interstitialRetries = 0;
  Timer? _interstitialRetryTimer;
  int _fullScreenAdSuppressions = 0;

  static const _adFreeKey = 'gravity_torrent_ad_free';
  static const _hasStartedSessionKey =
      'gravity_torrent_ads_has_started_session';

  bool get _platformSupported =>
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  @override
  bool get isInitialized => _initialized;

  @override
  bool get isAdFree => _disposed ? true : _adFreeNotifier.value;

  @override
  ValueNotifier<bool> get adFreeNotifier => _adFreeNotifier;

  @override
  bool get canShowAds =>
      !_disposed &&
      _platformSupported &&
      _initialized &&
      _sdkReady &&
      !_adFreeNotifier.value &&
      RemoteConfigService.instance.showAds &&
      AdIds.hasValidProductionIds;

  @override
  Future<void> init() => _initialization ??= _initialize();

  Future<void> _initialize() async {
    if (_disposed) return;
    if (!_platformSupported) {
      _initialized = true;
      return;
    }
    try {
      await RemoteConfigService.instance.refresh();
      if (_disposed) return;
      final prefs = await SharedPreferences.getInstance();
      if (_disposed) return;
      final hasStartedSession = prefs.getBool(_hasStartedSessionKey) ?? false;
      // Persist first-use protection before enabling any full-screen inventory.
      final saved = await prefs.setBool(_hasStartedSessionKey, true);
      if (_disposed) return;
      _policy = InterstitialAdPolicy(
        isFirstSession: !hasStartedSession || !saved,
      );
      _adFreeNotifier.value = prefs.getBool(_adFreeKey) ?? false;
      if (!_adFreeNotifier.value) await _initializeSdk();
      if (_disposed) return;
      _initialized = true;
      _preloadInterstitial();
    } catch (e) {
      if (kDebugMode) debugPrint('[AdService] init failed: $e');
    }
  }

  Future<void> _initializeSdk() async {
    await (_sdkInitialization ??=
        MobileAds.instance.initialize().then<void>((_) {}));
    if (!_disposed) _sdkReady = true;
  }

  @override
  Future<void> setAdFree(bool value) async {
    if (_disposed) return;
    _adFreeNotifier.value = value;
    if (value) {
      _interstitialRetryTimer?.cancel();
      _interstitialRetryTimer = null;
      final ad = _interstitial;
      _interstitial = null;
      if (ad != null) unawaited(_disposeInterstitial(ad));
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_disposed) return;
      await prefs.setBool(_adFreeKey, value);
      if (!value && _initialized) {
        await _initializeSdk();
        _preloadInterstitial();
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[AdService] ad-free setting failed: $e');
    }
  }

  @override
  Widget? buildBanner({Key? key}) {
    if (!canShowAds) return null;
    return _BannerAdHost(key: key);
  }

  @override
  VoidCallback suppressFullScreenAds() {
    if (_disposed) return () {};
    _fullScreenAdSuppressions++;
    var released = false;
    return () {
      if (released) return;
      released = true;
      _fullScreenAdSuppressions--;
    };
  }

  @override
  void onTorrentAdded() {
    if (!canShowAds) return;
    final eligible = _policy?.onTorrentAdded(
          adReady: _interstitial != null,
          isForeground: _fullScreenAdSuppressions == 0 &&
              WidgetsBinding.instance.lifecycleState ==
                  AppLifecycleState.resumed,
        ) ??
        false;
    if (!eligible) {
      _preloadInterstitial();
      return;
    }
    // The policy reserves the single attempt synchronously. Neither callbacks,
    // retry timers nor a late ad load may initiate another presentation.
    final ad = _interstitial!;
    _interstitial = null;
    unawaited(_showInterstitial(ad));
  }

  Future<void> _showInterstitial(InterstitialAd ad) async {
    try {
      await ad.show();
    } catch (e) {
      await _disposeInterstitial(ad);
      if (kDebugMode) debugPrint('[AdService] interstitial show failed: $e');
    }
  }

  void _preloadInterstitial() {
    if (_preloadingInterstitial ||
        !canShowAds ||
        !(_policy?.canRequestAd ?? false) ||
        _interstitial != null) {
      return;
    }
    _interstitialRetryTimer?.cancel();
    _interstitialRetryTimer = null;
    _preloadingInterstitial = true;
    InterstitialAd.load(
      adUnitId: AdIds.interstitial,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _preloadingInterstitial = false;
          if (!canShowAds || !(_policy?.canRequestAd ?? false)) {
            unawaited(_disposeInterstitial(ad));
            return;
          }
          _interstitial = ad;
          _interstitialRetries = 0;
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              unawaited(_disposeInterstitial(ad));
            },
            onAdFailedToShowFullScreenContent: (ad, _) {
              unawaited(_disposeInterstitial(ad));
            },
          );
          // Loading inventory must never show it outside a completed task.
        },
        onAdFailedToLoad: (_) {
          _preloadingInterstitial = false;
          _interstitialRetries++;
          if (canShowAds &&
              (_policy?.canRequestAd ?? false) &&
              _interstitialRetries < 6) {
            final delay = Duration(seconds: 1 << _interstitialRetries);
            _interstitialRetryTimer = Timer(delay, _preloadInterstitial);
          }
        },
      ),
    ).catchError((Object e) {
      _preloadingInterstitial = false;
      if (kDebugMode) debugPrint('[AdService] interstitial load failed: $e');
    });
  }

  Future<void> _disposeInterstitial(InterstitialAd ad) async {
    try {
      await ad.dispose();
    } catch (e) {
      if (kDebugMode) debugPrint('[AdService] interstitial dispose failed: $e');
    }
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _interstitialRetryTimer?.cancel();
    _interstitialRetryTimer = null;
    final ad = _interstitial;
    _interstitial = null;
    if (ad != null) unawaited(_disposeInterstitial(ad));
    _adFreeNotifier.dispose();
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
        onAdLoaded: (_) {
          if (mounted) setState(() => _loaded = true);
        },
        onAdFailedToLoad: (ad, _) {
          ad.dispose();
          _banner = null;
        },
      ),
    );
    unawaited(
      _banner!.load().catchError((Object e) {
        if (kDebugMode) debugPrint('AdServiceMobile banner load error: $e');
      }),
    );
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

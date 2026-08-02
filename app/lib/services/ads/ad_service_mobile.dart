import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:gravity_torrent/services/ads/ad_ids.dart';
import 'package:gravity_torrent/services/ads/ad_service.dart';
import 'package:gravity_torrent/services/remote_config/remote_config_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// AdMob-backed implementation. Only active on Android/iOS when remote config allows.
class AdServiceMobile with WidgetsBindingObserver implements AdService {
  bool _initialized = false;
  bool _disposed = false;
  final ValueNotifier<bool> _adFreeNotifier = ValueNotifier<bool>(false);
  InterstitialAd? _interstitial;
  int _interstitialRetries = 0;

  AppOpenAd? _appOpenAd;
  bool _isShowingAd = false;
  bool _firstAppOpenShown = false;
  bool _observerAdded = false;

  Timer? _interstitialRetryTimer;

  static const _adFreeKey = 'gravity_torrent_ad_free';

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
  bool get canShowAds {
    if (_disposed ||
        !_platformSupported ||
        !_initialized ||
        _adFreeNotifier.value) {
      return false;
    }
    if (!RemoteConfigService.instance.showAds) {
      return false;
    }
    return AdIds.hasValidProductionIds;
  }

  @override
  Future<void> init() async {
    if (_disposed) return;
    if (!_platformSupported || _initialized) {
      _initialized = true;
      return;
    }
    try {
      await RemoteConfigService.instance.refresh();
      if (_disposed) return;
      final prefs = await SharedPreferences.getInstance();
      if (_disposed) return;
      _adFreeNotifier.value = prefs.getBool(_adFreeKey) ?? false;
      if (_adFreeNotifier.value) {
        _initialized = true;
        return;
      }
      await MobileAds.instance.initialize();
      if (_disposed) return;
      _initialized = true;
      _observerAdded = true;
      WidgetsBinding.instance.addObserver(this);
      _preloadInterstitial();
      _preloadAppOpenAd();
    } catch (e) {
      debugPrint('[AdService] init failed (continuing without ads): $e');
      _initialized = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      showAppOpenAdIfReady();
    }
  }

  @override
  Future<void> setAdFree(bool value) async {
    if (_disposed) return;
    _adFreeNotifier.value = value;
    final prefs = await SharedPreferences.getInstance();
    if (_disposed) return;
    await prefs.setBool(_adFreeKey, value);
    if (value) {
      if (_observerAdded) {
        _observerAdded = false;
        WidgetsBinding.instance.removeObserver(this);
      }
      await _interstitial?.dispose();
      _interstitial = null;
      await _appOpenAd?.dispose();
      _appOpenAd = null;
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
    unawaited(
      _interstitial!.show().catchError((Object e) {
        if (kDebugMode) {
          debugPrint('AdServiceMobile interstitial show error: $e');
        }
      }),
    );
  }

  @override
  void showAppOpenAdIfReady() {
    if (!canShowAds || _appOpenAd == null || _isShowingAd) return;
    _firstAppOpenShown = true;
    _isShowingAd = true;
    unawaited(
      _appOpenAd!.show().catchError((Object e) {
        if (kDebugMode) {
          debugPrint('AdServiceMobile app open show error: $e');
        }
        _isShowingAd = false;
      }),
    );
  }

  bool _preloadingAppOpen = false;

  void _preloadAppOpenAd() {
    if (_preloadingAppOpen || _disposed || !canShowAds || _appOpenAd != null) {
      return;
    }
    _preloadingAppOpen = true;
    AppOpenAd.load(
      adUnitId: AdIds.appOpen,
      request: const AdRequest(),
      adLoadCallback: AppOpenAdLoadCallback(
        onAdLoaded: (ad) {
          _preloadingAppOpen = false;
          if (_disposed) {
            ad.dispose();
            return;
          }
          _appOpenAd = ad;
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdShowedFullScreenContent: (ad) {
              _isShowingAd = true;
            },
            onAdDismissedFullScreenContent: (ad) {
              _isShowingAd = false;
              ad.dispose();
              _appOpenAd = null;
              _preloadAppOpenAd();
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              _isShowingAd = false;
              ad.dispose();
              _appOpenAd = null;
              _preloadAppOpenAd();
            },
          );
          if (!_firstAppOpenShown) {
            showAppOpenAdIfReady();
          }
        },
        onAdFailedToLoad: (_) {
          _preloadingAppOpen = false;
          _appOpenAd = null;
        },
      ),
    );
  }

  bool _preloadingInterstitial = false;

  void _preloadInterstitial() {
    _interstitialRetryTimer?.cancel();
    _interstitialRetryTimer = null;

    if (_preloadingInterstitial ||
        _disposed ||
        !canShowAds ||
        _interstitial != null) {
      return;
    }
    _preloadingInterstitial = true;
    InterstitialAd.load(
      adUnitId: AdIds.interstitial,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _preloadingInterstitial = false;
          if (_disposed) {
            ad.dispose();
            return;
          }
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
          _preloadingInterstitial = false;
          _interstitial = null;
          _interstitialRetries++;
          if (!_disposed && _interstitialRetries < 6) {
            final delay = Duration(seconds: 1 << _interstitialRetries);
            _interstitialRetryTimer = Timer(delay, () {
              if (!_disposed) _preloadInterstitial();
            });
          }
        },
      ),
    );
  }

  @override
  void dispose() {
    _disposed = true;
    if (_observerAdded) {
      _observerAdded = false;
      WidgetsBinding.instance.removeObserver(this);
    }
    _interstitialRetryTimer?.cancel();
    _interstitialRetryTimer = null;
    unawaited(
      _interstitial?.dispose().catchError((Object e) {
        if (kDebugMode) {
          debugPrint('AdServiceMobile interstitial dispose error: $e');
        }
      }),
    );
    unawaited(
      _appOpenAd?.dispose().catchError((Object e) {
        if (kDebugMode) {
          debugPrint('AdServiceMobile app open dispose error: $e');
        }
      }),
    );
    _interstitial = null;
    _appOpenAd = null;
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

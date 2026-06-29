import 'package:flutter/widgets.dart';

/// Platform-agnostic ad surface contract. Implementations must never throw.
abstract class AdService {
  Future<void> init();

  bool get isInitialized;
  bool get isAdFree;
  ValueNotifier<bool> get adFreeNotifier;
  bool get canShowAds;

  Future<void> setAdFree(bool value);

  /// Optional banner widget; returns null when ads are disabled or unavailable.
  Widget? buildBanner({Key? key});

  /// Non-blocking interstitial after a natural break (never during critical flows).
  void showInterstitialIfReady();

  /// Non-blocking app open ad.
  void showAppOpenAdIfReady();

  void dispose();
}

import 'dart:io';
import 'package:flutter/foundation.dart';

/// Compile-time AdMob IDs.
class AdIds {
  AdIds._();

  static const bool useTestIds = kDebugMode;

  static const _testAppId = 'ca-app-pub-3940256099942544~3347511713';
  static const _testBanner = 'ca-app-pub-3940256099942544/6300978111';
  static const _testInterstitial = 'ca-app-pub-3940256099942544/1033173712';

  static bool get hasValidProductionIds => true;

  static String get appId {
    if (useTestIds) return _testAppId;
    if (Platform.isIOS) {
      return 'ca-app-pub-4989086156410627~3903973603';
    }
    return 'ca-app-pub-4989086156410627~8062710463';
  }

  static String get banner {
    if (useTestIds) return _testBanner;
    if (Platform.isIOS) {
      return 'ca-app-pub-4989086156410627/6048745045';
    }
    return 'ca-app-pub-4989086156410627/2052825564';
  }

  static String get interstitial {
    if (useTestIds) return _testInterstitial;
    if (Platform.isIOS) {
      return 'ca-app-pub-4989086156410627/3422581708';
    }
    return 'ca-app-pub-4989086156410627/4927235067';
  }
}

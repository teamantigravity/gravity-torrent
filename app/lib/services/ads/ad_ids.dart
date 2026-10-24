import 'dart:io';

/// Compile-time AdMob IDs.
class AdIds {
  AdIds._();

  static const _useTestIds = bool.fromEnvironment(
    'GRAVITY_TORRENT_AD_TEST_IDS',
    defaultValue: false,
  );
  static const _bannerOverride = String.fromEnvironment(
    'GRAVITY_TORRENT_ADMOB_BANNER',
  );
  static const _interstitialOverride = String.fromEnvironment(
    'GRAVITY_TORRENT_ADMOB_INTERSTITIAL',
  );

  static bool get hasValidProductionIds => true;

  static String get appId {
    if (Platform.isIOS) {
      return 'ca-app-pub-4989086156410627~3903973603';
    }
    return 'ca-app-pub-4989086156410627~8062710463';
  }

  static String get banner {
    if (_useTestIds) {
      return Platform.isIOS
          ? 'ca-app-pub-3940256099942544/2934735716'
          : 'ca-app-pub-3940256099942544/6300978111';
    }
    if (_bannerOverride.isNotEmpty) return _bannerOverride;
    if (Platform.isIOS) {
      return 'ca-app-pub-4989086156410627/6048745045';
    }
    return 'ca-app-pub-4989086156410627/2052825564';
  }

  static String get interstitial {
    if (_useTestIds) {
      return Platform.isIOS
          ? 'ca-app-pub-3940256099942544/4411468910'
          : 'ca-app-pub-3940256099942544/1033173712';
    }
    if (_interstitialOverride.isNotEmpty) return _interstitialOverride;
    if (Platform.isIOS) {
      return 'ca-app-pub-4989086156410627/3422581708';
    }
    return 'ca-app-pub-4989086156410627/4927235067';
  }

  static String get appOpen {
    if (_useTestIds) {
      return Platform.isIOS
          ? 'ca-app-pub-3940256099942544/5575463023'
          : 'ca-app-pub-3940256099942544/9257395921';
    }
    if (Platform.isIOS) {
      return 'ca-app-pub-4989086156410627/3365051003';
    }
    return 'ca-app-pub-4989086156410627/5347226833';
  }
}

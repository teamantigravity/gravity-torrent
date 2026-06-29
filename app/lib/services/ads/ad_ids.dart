import 'dart:io';

/// Compile-time AdMob IDs.
class AdIds {
  AdIds._();

  static bool get hasValidProductionIds => true;

  static String get appId {
    if (Platform.isIOS) {
      return 'ca-app-pub-4989086156410627~3903973603';
    }
    return 'ca-app-pub-4989086156410627~8062710463';
  }

  static String get banner {
    if (Platform.isIOS) {
      return 'ca-app-pub-4989086156410627/6048745045';
    }
    return 'ca-app-pub-4989086156410627/2052825564';
  }

  static String get interstitial {
    if (Platform.isIOS) {
      return 'ca-app-pub-4989086156410627/3422581708';
    }
    return 'ca-app-pub-4989086156410627/4927235067';
  }

  static String get appOpen {
    if (Platform.isIOS) {
      return 'ca-app-pub-4989086156410627/3365051003';
    }
    return 'ca-app-pub-4989086156410627/5347226833';
  }
}

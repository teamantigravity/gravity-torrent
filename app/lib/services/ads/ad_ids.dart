/// Compile-time AdMob IDs. Override in CI/release with --dart-define.
class AdIds {
  AdIds._();

  static const bool useTestIds = bool.fromEnvironment(
    'GRAVITY_TORRENT_AD_TEST_IDS',
    defaultValue: true,
  );

  static const String _prodAppId = String.fromEnvironment(
    'GRAVITY_TORRENT_ADMOB_APP_ID',
    defaultValue: '',
  );
  static const String _prodBanner = String.fromEnvironment(
    'GRAVITY_TORRENT_ADMOB_BANNER',
    defaultValue: '',
  );
  static const String _prodInterstitial = String.fromEnvironment(
    'GRAVITY_TORRENT_ADMOB_INTERSTITIAL',
    defaultValue: '',
  );

  static const _testAppId = 'ca-app-pub-3940256099942544~3347511713';
  static const _testBanner = 'ca-app-pub-3940256099942544/6300978111';
  static const _testInterstitial = 'ca-app-pub-3940256099942544/1033173712';

  static bool get hasValidProductionIds =>
      _prodAppId.isNotEmpty && _prodBanner.isNotEmpty;

  static String get appId =>
      useTestIds || !hasValidProductionIds ? _testAppId : _prodAppId;

  static String get banner =>
      useTestIds || !hasValidProductionIds ? _testBanner : _prodBanner;

  static String get interstitial => useTestIds || !hasValidProductionIds
      ? _testInterstitial
      : _prodInterstitial;
}

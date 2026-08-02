import 'package:gravity_torrent/storage/shared_preferences.dart';

class OnboardingService {
  OnboardingService._();

  static const _keyOnboardingComplete = 'onboarding_complete';
  static const _keyOnboardingVersion = 'onboarding_version';

  /// Increment when a new onboarding flow should be shown to existing users.
  static const int _currentVersion = 1;

  static bool get shouldShowOnboarding {
    final complete = SharedPrefs.getBool(_keyOnboardingComplete) ?? false;
    final version = SharedPrefs.getInt(_keyOnboardingVersion) ?? 0;
    return !complete || version < _currentVersion;
  }

  static Future<void> markComplete() async {
    await SharedPrefs.setBool(_keyOnboardingComplete, true);
    await SharedPrefs.setInt(_keyOnboardingVersion, _currentVersion);
  }

  static Future<void> reset() async {
    await SharedPrefs.setBool(_keyOnboardingComplete, false);
    await SharedPrefs.setInt(_keyOnboardingVersion, 0);
  }
}

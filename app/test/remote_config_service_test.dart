import 'package:flutter_test/flutter_test.dart';
import 'package:gravity_torrent/services/remote_config/remote_config_service.dart';
import 'package:gravity_torrent/storage/shared_preferences.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final service = RemoteConfigService.instance;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    SharedPrefsStorage.resetForTest();
    service.resetForTest();
  });

  test(
    'restores cached kill switches before applying the fetch throttle',
    () async {
      await SharedPrefsStorage.setString(
        'gravity_torrent_remote_config_cache',
        '{"show_ads":false,"sota_features":{"enableAnalytics":false}}',
      );
      await SharedPrefsStorage.setInt(
        'gravity_torrent_remote_config_last_fetch',
        DateTime.now().millisecondsSinceEpoch,
      );

      await service.refresh();

      expect(service.showAds, isFalse);
      expect(service.isFeatureEnabled('enableAnalytics'), isFalse);
    },
  );
}

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gravity_torrent/services/app_lock_service.dart';
import 'package:gravity_torrent/storage/secure_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    SecureStorage.enableTestMode();
    AppLockService.instance.setEnabled(false);
    await AppLockService.instance.clearPin();
    AppLockService.instance.setEnabled(false);
    await AppLockService.instance.load();
  });

  tearDown(() async {
    await AppLockService.instance.clearPin();
    await AppLockService.instance.setEnabled(false);
  });

  group('AppLockService', () {
    test('stores and verifies a PIN', () async {
      await AppLockService.instance.setPin('1234');
      expect(await AppLockService.instance.authenticateWithPin('1234'), isTrue);
      expect(
          await AppLockService.instance.authenticateWithPin('0000'), isFalse);
    });

    test('rejects an empty PIN', () async {
      await AppLockService.instance.setPin('5678');
      expect(await AppLockService.instance.authenticateWithPin(''), isFalse);
    });

    test('clearing the PIN makes authentication fail', () async {
      await AppLockService.instance.setPin('9999');
      await AppLockService.instance.clearPin();
      expect(
          await AppLockService.instance.authenticateWithPin('9999'), isFalse);
    });

    test('does not store the raw PIN in preferences', () async {
      await AppLockService.instance.setPin('1234');
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString('gravity_torrent_app_lock_pin');
      expect(stored, isNotNull);
      expect(stored, isNot(contains('1234')));
    });

    test('disabled app lock always authenticates', () async {
      await AppLockService.instance.setEnabled(false);
      expect(await AppLockService.instance.authenticate(pin: 'any'), isTrue);
    });

    test('enabled app lock without PIN requires a PIN', () async {
      await AppLockService.instance.setEnabled(true);
      await AppLockService.instance.clearPin();
      expect(await AppLockService.instance.authenticate(pin: null), isFalse);
    });

    test('enabled app lock with correct PIN authenticates', () async {
      await AppLockService.instance.setPin('1234');
      await AppLockService.instance.setEnabled(true);
      expect(await AppLockService.instance.authenticate(pin: '1234'), isTrue);
    });
  });
}

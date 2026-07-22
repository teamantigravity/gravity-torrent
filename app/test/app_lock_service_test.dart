import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gravity_torrent/services/app_lock_service.dart';
import 'package:gravity_torrent/storage/secure_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    SecureStorage.enableTestMode();
    await AppLockService.instance.setEnabled(false);
    await AppLockService.instance.clearPin();
    await AppLockService.instance.setEnabled(false);
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

    test('PIN hash is preserved when app lock is disabled', () async {
      // Regression: disabling app lock used to clear the PIN, forcing the
      // user to set a new one every time they re-enabled the feature.
      await AppLockService.instance.setPin('4321');
      expect(AppLockService.instance.hasPin, isTrue);

      await AppLockService.instance.setEnabled(false);
      // PIN must still be present in memory after disabling.
      expect(AppLockService.instance.hasPin, isTrue);
    });

    test('re-enabling app lock after disable authenticates with original PIN', () async {
      await AppLockService.instance.setPin('7777');
      await AppLockService.instance.setEnabled(true);

      // Simulate user disabling (no PIN erasure) then re-enabling.
      await AppLockService.instance.setEnabled(false);
      await AppLockService.instance.setEnabled(true);

      expect(await AppLockService.instance.authenticate(pin: '7777'), isTrue);
      expect(await AppLockService.instance.authenticate(pin: '0000'), isFalse);
    });
  });
}

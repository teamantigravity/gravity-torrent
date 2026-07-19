import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gravity_torrent/services/analytics_service.dart';
import 'package:gravity_torrent/services/app_lock_service.dart';
import 'package:gravity_torrent/services/quota_service.dart';
import 'package:gravity_torrent/services/remote_control_service.dart';
import 'package:gravity_torrent/services/rss_service.dart';
import 'package:gravity_torrent/services/scheduler_service.dart';
import 'package:gravity_torrent/storage/secure_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    SecureStorage.enableTestMode();
  });

  group('ScheduleTime', () {
    test('formats with leading zeros', () {
      const time = ScheduleTime(hour: 9, minute: 5);
      expect(time.toString(), '09:05');
    });

    test('formats midnight', () {
      const time = ScheduleTime(hour: 0, minute: 0);
      expect(time.toString(), '00:00');
    });
  });

  group('ScheduleWindow', () {
    test('is active when now falls inside the window', () {
      const window = ScheduleWindow(
        start: ScheduleTime(hour: 9, minute: 0),
        end: ScheduleTime(hour: 17, minute: 0),
      );
      final now = DateTime(2024, 1, 1, 12, 0);
      expect(window.isActiveAt(now), isTrue);
    });

    test('is inactive outside the window', () {
      const window = ScheduleWindow(
        start: ScheduleTime(hour: 9, minute: 0),
        end: ScheduleTime(hour: 17, minute: 0),
      );
      final now = DateTime(2024, 1, 1, 18, 0);
      expect(window.isActiveAt(now), isFalse);
    });

    test('wraps around midnight', () {
      const window = ScheduleWindow(
        start: ScheduleTime(hour: 23, minute: 0),
        end: ScheduleTime(hour: 7, minute: 0),
      );
      expect(window.isActiveAt(DateTime(2024, 1, 1, 2, 0)), isTrue);
      expect(window.isActiveAt(DateTime(2024, 1, 1, 12, 0)), isFalse);
    });

    test('respects the day bitmask', () {
      // Monday only (bit 0)
      const window = ScheduleWindow(
        start: ScheduleTime(hour: 0, minute: 0),
        end: ScheduleTime(hour: 23, minute: 59),
        dayBitmask: 1,
      );
      // 2024-01-01 is a Monday
      expect(window.isActiveAt(DateTime(2024, 1, 1, 12, 0)), isTrue);
      // 2024-01-02 is a Tuesday
      expect(window.isActiveAt(DateTime(2024, 1, 2, 12, 0)), isFalse);
    });

    test('allDays is true for the default bitmask', () {
      const window = ScheduleWindow(
        start: ScheduleTime(hour: 0, minute: 0),
        end: ScheduleTime(hour: 23, minute: 59),
      );
      expect(window.allDays, isTrue);
    });
  });

  group('RssFeed', () {
    test('round-trips through JSON', () {
      const feed = RssFeed(
        url: 'https://example.com/feed.xml',
        keyword: '1080p',
        enabled: false,
      );
      final json = feed.toJson();
      final restored = RssFeed.fromJson(json);

      expect(restored.url, feed.url);
      expect(restored.keyword, feed.keyword);
      expect(restored.enabled, feed.enabled);
    });

    test('uses sensible defaults', () {
      final feed = RssFeed.fromJson({'url': 'https://example.com/feed.xml'});
      expect(feed.keyword, '');
      expect(feed.enabled, isTrue);
    });
  });

  group('AppLockService', () {
    test('stores and verifies a PIN', () async {
      await AppLockService.instance.setPin('1234');
      expect(await AppLockService.instance.authenticateWithPin('1234'), isTrue);
      expect(
        await AppLockService.instance.authenticateWithPin('0000'),
        isFalse,
      );
    });

    test('rejects an empty PIN', () async {
      await AppLockService.instance.setPin('5678');
      expect(await AppLockService.instance.authenticateWithPin(''), isFalse);
    });

    test('clearing the PIN makes authentication fail', () async {
      await AppLockService.instance.setPin('9999');
      await AppLockService.instance.clearPin();
      expect(
        await AppLockService.instance.authenticateWithPin('9999'),
        isFalse,
      );
    });
  });

  group('QuotaService', () {
    test('reports ok, warning, and exceeded based on monthly usage', () async {
      await QuotaService.instance.setEnabled(true);
      await QuotaService.instance.setQuota(100);

      await AnalyticsService.instance.recordTotals(
        downloadedBytes: 50,
        uploadedBytes: 0,
      );
      await QuotaService.instance.load();
      expect(QuotaService.instance.status, QuotaStatus.ok);

      await AnalyticsService.instance.recordTotals(
        downloadedBytes: 90,
        uploadedBytes: 0,
      );
      expect(QuotaService.instance.status, QuotaStatus.warning);

      await AnalyticsService.instance.recordTotals(
        downloadedBytes: 110,
        uploadedBytes: 0,
      );
      expect(QuotaService.instance.status, QuotaStatus.exceeded);
    });

    test('returns ok when disabled', () async {
      await QuotaService.instance.setEnabled(false);
      await QuotaService.instance.setQuota(100);
      await QuotaService.instance.load();
      expect(QuotaService.instance.status, QuotaStatus.ok);
    });
  });

  group('RemoteControlService token', () {
    test('is generated with a cryptographically secure source', () {
      final token = generateSecureRandomToken();
      expect(token, isNotEmpty);
      expect(token.length, greaterThanOrEqualTo(32));
      expect(token, matches(r'^[A-Za-z0-9_-]+$'));
    });

    test('changes between invocations', () {
      final a = generateSecureRandomToken();
      final b = generateSecureRandomToken();
      expect(a, isNot(equals(b)));
    });
  });

  group('AnalyticsService history', () {
    test('trims to the configured max days window', () async {
      final today = DateTime.now();
      const days = 100;
      const maxDays = 90;
      final history = List.generate(days, (i) {
        final day = today.subtract(Duration(days: days - 1 - i));
        return {
          'day': DateTime(day.year, day.month, day.day).toIso8601String(),
          'downloadedBytes': 0,
          'uploadedBytes': 0,
        };
      });

      AnalyticsService.instance.reset();
      SharedPreferences.setMockInitialValues({
        'gravity_torrent_analytics_history': jsonEncode(history),
      });

      await AnalyticsService.instance.recordTotals(
        downloadedBytes: 0,
        uploadedBytes: 0,
      );

      expect(AnalyticsService.instance.history.length, maxDays);
    });
  });

  group('AppLockService PIN storage', () {
    test('does not store the raw PIN in preferences', () async {
      await AppLockService.instance.setPin('1234');
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString('gravity_torrent_app_lock_pin');
      expect(stored, isNotNull);
      expect(stored, isNot(contains('1234')));
    });
  });
}

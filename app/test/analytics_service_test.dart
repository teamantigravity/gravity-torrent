import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gravity_torrent/services/analytics_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AnalyticsService.instance.reset();
  });

  tearDown(() {
    AnalyticsService.instance.reset();
  });

  group('DataUsageSnapshot', () {
    test('round-trips through JSON', () {
      final snapshot = DataUsageSnapshot(
        day: DateTime(2024, 1, 1),
        downloadedBytes: 123,
        uploadedBytes: 456,
      );
      final json = snapshot.toJson();
      final restored = DataUsageSnapshot.fromJson(json);

      expect(restored.day, snapshot.day);
      expect(restored.downloadedBytes, snapshot.downloadedBytes);
      expect(restored.uploadedBytes, snapshot.uploadedBytes);
    });

    test('handles num values in JSON', () {
      final snapshot = DataUsageSnapshot.fromJson({
        'day': '2024-01-01T00:00:00.000',
        'downloadedBytes': 123.0,
        'uploadedBytes': 456.7,
      });

      expect(snapshot.downloadedBytes, 123);
      expect(snapshot.uploadedBytes, 456);
    });

    test('throws on malformed JSON', () {
      expect(
        () => DataUsageSnapshot.fromJson({
          'day': 'not-a-date',
          'downloadedBytes': 123,
          'uploadedBytes': 456,
        }),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('AnalyticsService', () {
    test('today returns null when history is empty', () async {
      await AnalyticsService.instance.load();
      expect(AnalyticsService.instance.today, isNull);
    });

    test('today returns the current day bucket', () async {
      await AnalyticsService.instance.recordTotals(
        downloadedBytes: 100,
        uploadedBytes: 50,
      );

      final today = AnalyticsService.instance.today;
      expect(today, isNotNull);
      expect(today!.downloadedBytes, 100);
      expect(today.uploadedBytes, 50);
    });

    test('today returns null when the last entry is not today', () async {
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      final history = [
        {
          'day': DateTime(yesterday.year, yesterday.month, yesterday.day)
              .toIso8601String(),
          'downloadedBytes': 100,
          'uploadedBytes': 50,
        },
      ];

      SharedPreferences.setMockInitialValues({
        'gravity_torrent_analytics_history': jsonEncode(history),
      });

      await AnalyticsService.instance.load();
      expect(AnalyticsService.instance.today, isNull);
    });

    test('getLastDays returns all history when count >= length', () async {
      await AnalyticsService.instance.recordTotals(
        downloadedBytes: 100,
        uploadedBytes: 50,
      );

      final result = AnalyticsService.instance.getLastDays(10);
      expect(result.length, 1);
    });

    test('getLastDays returns the last N days', () async {
      final today = DateTime.now();
      final history = List.generate(5, (i) {
        final day = today.subtract(Duration(days: 4 - i));
        return {
          'day': DateTime(day.year, day.month, day.day).toIso8601String(),
          'downloadedBytes': i,
          'uploadedBytes': i,
        };
      });

      SharedPreferences.setMockInitialValues({
        'gravity_torrent_analytics_history': jsonEncode(history),
      });

      await AnalyticsService.instance.load();
      final result = AnalyticsService.instance.getLastDays(3);
      expect(result.length, 3);
      expect(result.first.downloadedBytes, 2);
      expect(result.last.downloadedBytes, 4);
    });

    test('handles counter reset by treating the new total as fresh', () async {
      await AnalyticsService.instance.recordTotals(
        downloadedBytes: 100,
        uploadedBytes: 50,
      );

      // Simulate a counter reset (new total is lower than previous).
      await AnalyticsService.instance.recordTotals(
        downloadedBytes: 30,
        uploadedBytes: 20,
      );

      final today = AnalyticsService.instance.today;
      expect(today!.downloadedBytes, 130);
      expect(today.uploadedBytes, 70);
    });

    test('merges multiple samples for the same day', () async {
      await AnalyticsService.instance.recordTotals(
        downloadedBytes: 100,
        uploadedBytes: 50,
      );
      await AnalyticsService.instance.recordTotals(
        downloadedBytes: 150,
        uploadedBytes: 75,
      );

      final today = AnalyticsService.instance.today;
      expect(today!.downloadedBytes, 150);
      expect(today.uploadedBytes, 75);
    });

    test('trims history to the configured max days', () async {
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
}

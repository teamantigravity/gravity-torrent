import 'package:gravity_torrent/storage/shared_preferences.dart';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gravity_torrent/services/bandwidth_heatmap_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late BandwidthHeatmapService service;

  setUp(() async {
    SharedPrefsStorage.resetForTest();
    SharedPreferences.setMockInitialValues({});
    await (await SharedPreferences.getInstance()).reload();
    service = BandwidthHeatmapService();
    await service.load();
  });

  tearDown(() async {
    SharedPrefsStorage.resetForTest();
    await service.reset();
    service.dispose();
  });

  group('BandwidthHeatmapService', () {
    test('defaults to all unlimited', () {
      for (var d = 0; d < 7; d++) {
        for (var h = 0; h < 24; h++) {
          expect(service.schedule[d][h], 0);
        }
      }
    });

    test('setScheduleLimit updates grid and persists', () async {
      service.setScheduleLimit(0, 14, -1);
      expect(service.schedule[0][14], -1);

      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString('gravity_torrent_bandwidth_heatmap');
      expect(stored, isNotNull);

      final decoded = jsonDecode(stored!) as List<dynamic>;
      expect(decoded.length, 7);
      expect((decoded[0] as List<dynamic>)[14] as int, -1);
    });

    test('load restores persisted schedule', () async {
      final payload = List.generate(
        7,
        (d) => List.generate(24, (h) => (d == 2 && h == 3) ? 500 : 0),
      );
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'gravity_torrent_bandwidth_heatmap',
        jsonEncode(payload),
      );

      final newService = BandwidthHeatmapService();
      await newService.load();

      expect(newService.schedule[2][3], 500);
      newService.dispose();
    });

    test('ignores malformed persisted schedule', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'gravity_torrent_bandwidth_heatmap',
        'not-valid-json',
      );

      final newService = BandwidthHeatmapService();
      await newService.load();

      expect(newService.schedule[0][0], 0);
      newService.dispose();
    });

    test('ignores out-of-bounds writes', () {
      service.setScheduleLimit(7, 0, -1);
      service.setScheduleLimit(0, 24, -1);
      service.setScheduleLimit(-1, 0, -1);
      service.setScheduleLimit(0, -1, -1);

      for (var d = 0; d < 7; d++) {
        for (var h = 0; h < 24; h++) {
          expect(service.schedule[d][h], 0);
        }
      }
    });

    test('getLimitForCurrentTime returns current slot', () {
      final now = DateTime.now();
      final day = now.weekday - 1;
      final hour = now.hour;

      service.setScheduleLimit(day, hour, -1);
      expect(service.getLimitForCurrentTime(), -1);
    });
  });
}

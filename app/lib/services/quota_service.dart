import 'package:gravity_torrent/services/analytics_service.dart';
import 'package:gravity_torrent/storage/shared_preferences.dart';

enum QuotaStatus { ok, warning, exceeded }

/// Monthly bandwidth quota manager.
///
/// Users can set a monthly data cap (in bytes). The service tracks actual usage
/// via [AnalyticsService] and raises warnings as the quota approaches. All data
/// is local — nothing is uploaded to any server.
class QuotaService {
  QuotaService._();
  static final QuotaService instance = QuotaService._();

  static const _quotaKey = 'gravity_torrent_quota_bytes';
  static const _enabledKey = 'gravity_torrent_quota_enabled';

  /// Default: 100 GB
  static const int defaultQuotaBytes = 100 * 1024 * 1024 * 1024;

  /// Warning threshold: 80 % of quota.
  static const double warningThreshold = 0.80;

  int _quotaBytes = defaultQuotaBytes;
  bool _enabled = false;
  bool _loaded = false;

  bool get enabled => _enabled;
  int get quotaBytes => _quotaBytes;

  Future<void> load() async {
    if (_loaded) return;
    _enabled = await SharedPrefsStorage.getBool(_enabledKey) ?? false;
    final raw = await SharedPrefsStorage.getString(_quotaKey);
    if (raw != null) {
      _quotaBytes = int.tryParse(raw) ?? defaultQuotaBytes;
    }
    // Quota depends on analytics history; make sure it is loaded too.
    await AnalyticsService.instance.load();
    _loaded = true;
  }

  Future<void> setEnabled(bool value) async {
    _enabled = value;
    await SharedPrefsStorage.setBool(_enabledKey, value);
  }

  Future<void> setQuota(int bytes) async {
    _quotaBytes = bytes;
    await SharedPrefsStorage.setString(_quotaKey, bytes.toString());
  }

  /// Returns the number of bytes used this calendar month.
  int usedThisMonth() {
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    int total = 0;
    for (final snapshot in AnalyticsService.instance.history) {
      if (!snapshot.day.isBefore(monthStart)) {
        total += snapshot.downloadedBytes + snapshot.uploadedBytes;
      }
    }
    return total;
  }

  /// Returns what fraction of the quota has been consumed (0.0–1.0+).
  double usageRatio() {
    if (_quotaBytes <= 0) return 0;
    return usedThisMonth() / _quotaBytes;
  }

  QuotaStatus get status {
    if (!_enabled) return QuotaStatus.ok;
    final ratio = usageRatio();
    if (ratio >= 1.0) return QuotaStatus.exceeded;
    if (ratio >= warningThreshold) return QuotaStatus.warning;
    return QuotaStatus.ok;
  }

  /// Returns `false` when the quota is enabled and exceeded.
  /// All add-torrent paths should call this to avoid bypassing the monthly cap.
  Future<bool> canAddTorrent() async {
    await load();
    if (!_enabled) return true;
    return status != QuotaStatus.exceeded;
  }
}

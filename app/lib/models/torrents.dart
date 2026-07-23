import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:fuzzywuzzy/fuzzywuzzy.dart';
import 'package:gravity_torrent/engine/engine.dart';
import 'package:gravity_torrent/engine/session.dart';
import 'package:gravity_torrent/engine/torrent.dart';
import 'package:gravity_torrent/main.dart';
import 'package:gravity_torrent/models/feature_flags.dart';
import 'package:gravity_torrent/services/analytics_service.dart';
import 'package:gravity_torrent/services/quota_service.dart';
import 'package:gravity_torrent/storage/shared_preferences.dart';
import 'package:gravity_torrent/utils/notifications.dart';
import 'package:gravity_torrent/services/seed_ratio_service.dart';
import 'package:gravity_torrent/services/speed_history_service.dart';
import 'package:gravity_torrent/services/torrent_favorites_service.dart';

const refreshIntervalSeconds = 5;

enum Sort { addedDate, progress, size, name, status, eta }

class Filters {
  Set<String> labels = {};

  Filters({required this.labels});

  bool get enabled {
    return labels.isNotEmpty;
  }

  Filters.copy(Filters other) : this(labels: Set.from(other.labels));

  void addLabel(String label) {
    labels.add(label);
  }

  void removeLabel(String label) {
    labels.remove(label);
  }
}

class TorrentsModel extends ChangeNotifier {
  // All loaded torrents
  List<Torrent> torrents = [];
  List<Torrent> displayedTorrents = []; // filtered & sorted
  // All torrents labels
  List<String> labels = [];
  String filterText = '';
  bool hasLoaded = false;
  Sort sort = Sort.addedDate;
  bool reverseSort = true;
  Filters filters = Filters(labels: {});
  Set<int> _favorites = {};
  Timer? _timer;
  Timer? _searchDebounceTimer;
  bool _isFetching = false; // mutex to prevent concurrent fetches
  bool _disposed = false;

  FeatureFlagsModel? _featureFlags;

  /// When ON (default), any torrent that reaches [TorrentStatus.seeding]
  /// will be automatically stopped so the device does not upload indefinitely.
  bool stopSeedingWhenComplete = true;

  TorrentsModel({FeatureFlagsModel? featureFlags}) {
    _featureFlags = featureFlags;
    _init();
  }

  Future<void> _init() async {
    await _loadSettings();
    if (_disposed) return;
    await fetchTorrents();
    // Indefinitely refresh
    _timer = Timer.periodic(
      const Duration(seconds: refreshIntervalSeconds),
      (timer) {
        if (_disposed) {
          timer.cancel();
          return;
        }
        fetchTorrents();
      },
    );
  }

  void stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _timer = null;
    _searchDebounceTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    var sortName = await SharedPrefsStorage.getString('sort') ?? sort.name;
    sort = Sort.values.firstWhere(
      (e) => e.name == sortName,
      orElse: () => sort,
    );
    reverseSort =
        await SharedPrefsStorage.getBool('reverseSort') ?? reverseSort;
    stopSeedingWhenComplete =
        await SharedPrefsStorage.getBool('stopSeedingWhenComplete') ??
            stopSeedingWhenComplete;
    await _loadFavorites();

    try {
      final session = await engine.fetchSession();
      await session.update(
        SessionBase(
          seedRatioLimited: stopSeedingWhenComplete,
          seedRatioLimit: stopSeedingWhenComplete ? 0.0 : null,
        ),
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Failed to set seedRatioLimited in transmission: $e');
      }
    }
  }

  /// Persist and apply the stop-seeding preference.
  Future<void> setStopSeedingWhenComplete(bool value) async {
    await SharedPrefsStorage.setBool('stopSeedingWhenComplete', value);
    stopSeedingWhenComplete = value;

    try {
      final session = await engine.fetchSession();
      await session.update(
        SessionBase(
          seedRatioLimited: value,
          seedRatioLimit: value ? 0.0 : null,
        ),
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Failed to set seedRatioLimited in transmission: $e');
      }
    }

    // If turning on, immediately pause any currently-seeding torrents
    if (value) {
      final seedingIds = torrents
          .where((t) => t.status == TorrentStatus.seeding)
          .map((t) => t.id)
          .toList();
      if (seedingIds.isNotEmpty) {
        try {
          await engine.pauseTorrents(seedingIds);
        } catch (e) {
          if (kDebugMode) debugPrint('Failed to pause seeding torrents: $e');
        }
      }
    }

    if (_disposed) return;
    notifyListeners();
    // Refresh after state change
    unawaited(fetchTorrents());
  }

  List<Torrent> _filterTorrentsName(List<Torrent> torrents) {
    if (filterText.isEmpty) return torrents;
    final choices = List<Torrent>.unmodifiable(torrents);
    return extractAllSorted(
      query: filterText,
      choices: choices,
      getter: (t) => t.name,
      cutoff: 60,
    ).map((result) => choices[result.index]).toList();
  }

  List<Torrent> _filterTorrents(List<Torrent> torrents) {
    if (filters.labels.isEmpty) return torrents;

    return torrents.where((t) {
      // Safely handle null labels
      final torrentLabels = t.labels ?? [];
      return filters.labels.every((l) => torrentLabels.contains(l));
    }).toList();
  }

  List<Torrent> _sortTorrents(List<Torrent> torrents) {
    final pinned =
        torrents.where((t) => _favorites.contains(t.id)).toList();
    final unpinned =
        torrents.where((t) => !_favorites.contains(t.id)).toList();

    int comparator(Torrent a, Torrent b) {
      switch (sort) {
        case Sort.addedDate:
          return a.addedDate.compareTo(b.addedDate);
        case Sort.progress:
          return a.progress.compareTo(b.progress);
        case Sort.size:
          return a.size.compareTo(b.size);
        case Sort.name:
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        case Sort.status:
          return a.status.index.compareTo(b.status.index);
        case Sort.eta:
          final etaA = a.eta < 0 ? double.infinity : a.eta;
          final etaB = b.eta < 0 ? double.infinity : b.eta;
          return etaA.compareTo(etaB);
      }
    }

    int compare(Torrent a, Torrent b) {
      final result = comparator(a, b);
      return result == 0 ? a.id.compareTo(b.id) : result;
    }

    pinned.sort(compare);
    unpinned.sort(compare);

    final sorted = reverseSort
        ? [...pinned.reversed, ...unpinned.reversed]
        : [...pinned, ...unpinned];

    return sorted;
  }

  Future<void> _loadFavorites() async {
    try {
      await TorrentFavoritesService.instance.load();
      _favorites = Set.from(TorrentFavoritesService.instance.favoriteIds);
    } catch (e) {
      if (kDebugMode) debugPrint('TorrentFavoritesService load failed: $e');
    }
  }

  bool isFavorite(int torrentId) => _favorites.contains(torrentId);

  Future<void> toggleFavorite(int torrentId) async {
    try {
      final newState = await TorrentFavoritesService.instance.toggle(torrentId);
      if (newState) {
        _favorites.add(torrentId);
      } else {
        _favorites.remove(torrentId);
      }
      processDisplayedTorrents();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('TorrentFavoritesService toggle failed: $e');
      }
    }
  }

  Future<TorrentAddedResponse> addTorrent(
    String? filename,
    String? metainfo,
    String? downloadDir,
  ) async {
    if (!(await QuotaService.instance.canAddTorrent())) {
      throw TorrentAddError('Monthly bandwidth quota exceeded');
    }

    final response = await engine.addTorrent(filename, metainfo, downloadDir);
    if (response == TorrentAddedResponse.added) {
      await fetchTorrents();
    }
    return response;
  }

  Future<void> removeAllTorrents(List<int> torrentIds, bool withData) async {
    await engine.removeTorrents(torrentIds, withData);
    await fetchTorrents();
  }

  Future<void> pauseSelected(Set<int> ids) async {
    if (ids.isEmpty) return;
    final toPause = torrents
        .where(
          (t) => ids.contains(t.id) && t.status != TorrentStatus.stopped,
        )
        .map((t) => t.id)
        .toList();
    if (toPause.isEmpty) return;
    try {
      await engine.pauseTorrents(toPause);
    } catch (e) {
      if (kDebugMode) debugPrint('Failed to pause selected torrents: $e');
    }
    unawaited(fetchTorrents());
  }

  Future<void> resumeSelected(Set<int> ids) async {
    if (ids.isEmpty) return;
    final toResume = torrents
        .where(
          (t) => ids.contains(t.id) && t.status == TorrentStatus.stopped,
        )
        .map((t) => t.id)
        .toList();
    if (toResume.isEmpty) return;
    try {
      await engine.resumeTorrents(toResume);
    } catch (e) {
      if (kDebugMode) debugPrint('Failed to resume selected torrents: $e');
    }
    unawaited(fetchTorrents());
  }

  Future<void> pauseAllTorrents() async {
    final toPause = torrents
        .where((t) => t.status != TorrentStatus.stopped)
        .map((t) => t.id)
        .toList();
    if (toPause.isEmpty) return;
    try {
      await engine.pauseTorrents(toPause);
    } catch (e) {
      if (kDebugMode) debugPrint('Failed to pause all torrents: $e');
    }
    unawaited(fetchTorrents());
  }

  Future<void> resumeAllTorrents() async {
    final toResume = torrents
        .where((t) => t.status == TorrentStatus.stopped)
        .map((t) => t.id)
        .toList();
    if (toResume.isEmpty) return;
    try {
      await engine.resumeTorrents(toResume);
    } catch (e) {
      if (kDebugMode) debugPrint('Failed to resume all torrents: $e');
    }
    unawaited(fetchTorrents());
  }

  Future<void> fetchTorrents() async {
    // Bail out early if the model has been disposed.
    if (_disposed) return;
    // Prevent concurrent fetches overlapping
    if (_isFetching) return;
    _isFetching = true;

    try {
      final DateTime now = DateTime.now();
      final List<Torrent> fetched = await engine.fetchTorrents();

      // Update the persistent Android foreground service notification with live
      // progress and speed on every refresh.
      final downloading =
          fetched.where((t) => t.status == TorrentStatus.downloading).toList();

      if (downloading.isNotEmpty) {
        final totalProgress =
            downloading.fold<double>(0, (sum, t) => sum + t.progress) /
                downloading.length;
        final rateDown = downloading.fold<int>(
          0,
          (sum, t) => sum + t.rateDownload,
        );
        await updateForegroundNotification(
          progress: (totalProgress * 100).toInt(),
          count: downloading.length,
          rateDownBytes: rateDown,
        );

        if (_featureFlags?.useEnhancedNotifications ?? true) {
          await showDownloadProgressNotification(
            progress: (totalProgress * 100).toInt(),
            count: downloading.length,
            rateDownBytes: rateDown,
          );
        }
      } else {
        await updateForegroundNotification(
          progress: 0,
          count: 0,
          rateDownBytes: 0,
        );

        if (_featureFlags?.useEnhancedNotifications ?? true) {
          await cancelDownloadProgressNotification();
        }
      }

      // Display notification for torrents completed during last refresh
      if (_featureFlags?.useEnhancedNotifications ?? true) {
        for (final torrent in fetched) {
          if (torrent.progress >= 1.0 && torrent.doneDate.year > 1970) {
            final diff = now.difference(torrent.doneDate).inSeconds;
            if (diff >= 0 && diff < refreshIntervalSeconds) {
              final addedDate =
                  DateTime.fromMillisecondsSinceEpoch(torrent.addedDate * 1000);
              final duration = addedDate.year > 2000
                  ? torrent.doneDate.difference(addedDate)
                  : null;
              await showCompletedNotification(
                torrent.name,
                id: torrent.id + 1000,
                duration: duration,
              );
            }
          }
        }
      }

      // Auto-pause seeding torrents if user has that preference on
      if (stopSeedingWhenComplete) {
        final seedingIds = fetched
            .where((t) => t.status == TorrentStatus.seeding)
            .map((t) => t.id)
            .toList();
        if (seedingIds.isNotEmpty) {
          try {
            await engine.pauseTorrents(seedingIds);
          } catch (e) {
            if (kDebugMode) debugPrint('Failed to pause seeding torrents: $e');
          }
        }
      }

      // Enforce monthly bandwidth quota by pausing active torrents
      if (_featureFlags?.enableQuota ?? false) {
        final quotaStatus = QuotaService.instance.status;
        if (quotaStatus == QuotaStatus.exceeded) {
          final activeIds = fetched
              .where(
                (t) =>
                    t.status == TorrentStatus.downloading ||
                    t.status == TorrentStatus.seeding,
              )
              .map((t) => t.id)
              .toList();
          if (activeIds.isNotEmpty) {
            try {
              await engine.pauseTorrents(activeIds);
              if (kDebugMode) {
                debugPrint(
                  'QuotaService: paused active torrents, quota exceeded',
                );
              }
            } catch (e) {
              if (kDebugMode) {
                debugPrint('Failed to pause torrents for quota: $e');
              }
            }
          }
        }
      }

      torrents = fetched;

      labels = {
        for (final t in torrents)
          if (t.labels != null) ...t.labels!,
      }.toList();

      // Remove filtered labels that do not exist anymore
      for (final label in List<String>.from(filters.labels)) {
        if (!labels.contains(label)) {
          filters.removeLabel(label);
        }
      }

      if (!hasLoaded) {
        hasLoaded = true;
      }

      // Record data usage analytics for the dashboard
      if (_featureFlags?.enableAnalytics ?? false) {
        _safeRecordAnalytics(fetched);
      }

      await SeedRatioService.instance.checkAndStop(torrents);

      for (final t in torrents) {
        SpeedHistoryService.instance.record(t.id, t.rateDownload.toDouble());
      }

      processDisplayedTorrents();
    } catch (e, stack) {
      if (kDebugMode) debugPrint('fetchTorrents error: $e\n$stack');
      // Still call processDisplayedTorrents so UI doesn't freeze
      processDisplayedTorrents();
    } finally {
      _isFetching = false;
    }
  }

  void processDisplayedTorrents() {
    if (_disposed) return;
    displayedTorrents = _filterTorrents(
      _filterTorrentsName(_sortTorrents(torrents)),
    );
    notifyListeners();
  }

  void _safeRecordAnalytics(List<Torrent> torrents) {
    unawaited(
      AnalyticsService.instance
          .recordTorrentStats(torrents)
          .catchError((Object e, StackTrace s) {
        if (kDebugMode) debugPrint('Analytics error: $e\n$s');
      })
          .whenComplete(() {
        if (!_disposed) notifyListeners();
      }),
    );
  }

  void setFilterText(String value) {
    filterText = value;
    _searchDebounceTimer?.cancel();
    _searchDebounceTimer = Timer(
      const Duration(milliseconds: 200),
      processDisplayedTorrents,
    );
  }

  Future<void> setSort(Sort value, bool reverse) async {
    await SharedPrefsStorage.setString('sort', value.name);
    await SharedPrefsStorage.setBool('reverseSort', reverse);
    sort = value;
    reverseSort = reverse;
    processDisplayedTorrents();
  }

  Future<void> setFilters(Filters updatedFilters) async {
    filters = updatedFilters;
    processDisplayedTorrents();
  }

  Future<void> refreshFavorites() async {
    await _loadFavorites();
    processDisplayedTorrents();
  }
}

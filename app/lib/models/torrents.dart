import 'dart:async';

import 'package:flutter/material.dart';
import 'package:fuzzywuzzy/fuzzywuzzy.dart';
import 'package:gravity_torrent/engine/engine.dart';
import 'package:gravity_torrent/engine/session.dart';
import 'package:gravity_torrent/engine/torrent.dart';
import 'package:gravity_torrent/main.dart';
import 'package:gravity_torrent/storage/shared_preferences.dart';
import 'package:gravity_torrent/utils/notifications.dart';

const refreshIntervalSeconds = 5;

enum Sort { addedDate, progress, size }

class Filters {
  Set<String> labels = {};

  Filters({required this.labels});

  bool get enabled {
    return labels.isNotEmpty;
  }

  Filters.copy(Filters other) : this(labels: Set.from(other.labels));

  addLabel(String label) {
    labels.add(label);
  }

  removeLabel(String label) {
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
  Timer? _timer;
  bool _isFetching = false; // mutex to prevent concurrent fetches
  bool _disposed = false;

  /// When ON (default), any torrent that reaches [TorrentStatus.seeding]
  /// will be automatically stopped so the device does not upload indefinitely.
  bool stopSeedingWhenComplete = true;

  TorrentsModel() {
    _init();
  }

  _init() async {
    await _loadSettings();
    if (_disposed) return;
    fetchTorrents();
    // Indefinitely refresh
    _timer = Timer.periodic(const Duration(seconds: refreshIntervalSeconds),
        (timer) => fetchTorrents());
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
    super.dispose();
  }

  _loadSettings() async {
    var sortName = await SharedPrefsStorage.getString('sort') ?? sort.name;
    sort =
        Sort.values.firstWhere((e) => e.name == sortName, orElse: () => sort);
    reverseSort =
        await SharedPrefsStorage.getBool('reverseSort') ?? reverseSort;
    stopSeedingWhenComplete =
        await SharedPrefsStorage.getBool('stopSeedingWhenComplete') ??
            stopSeedingWhenComplete;

    try {
      final session = await engine.fetchSession();
      await session.update(SessionBase(
        seedRatioLimited: stopSeedingWhenComplete,
        seedRatioLimit: stopSeedingWhenComplete ? 0.0 : null,
      ));
    } catch (e) {
      debugPrint('Failed to set seedRatioLimited in transmission: $e');
    }
  }

  /// Persist and apply the stop-seeding preference.
  Future<void> setStopSeedingWhenComplete(bool value) async {
    await SharedPrefsStorage.setBool('stopSeedingWhenComplete', value);
    stopSeedingWhenComplete = value;

    try {
      final session = await engine.fetchSession();
      await session.update(SessionBase(
        seedRatioLimited: value,
        seedRatioLimit: value ? 0.0 : null,
      ));
    } catch (e) {
      debugPrint('Failed to set seedRatioLimited in transmission: $e');
    }

    // If turning on, immediately pause any currently-seeding torrents
    if (value) {
      for (final torrent in List<Torrent>.from(torrents)) {
        if (torrent.status == TorrentStatus.seeding) {
          try {
            await engine.pauseTorrent(torrent.id);
          } catch (e) {
            debugPrint('Failed to pause seeding torrent ${torrent.id}: $e');
          }
        }
      }
    }

    if (_disposed) return;
    notifyListeners();
    // Refresh after state change
    fetchTorrents();
  }

  List<Torrent> _filterTorrentsName(List<Torrent> torrents) {
    return filterText.isNotEmpty
        ? extractAllSorted(
                query: filterText,
                choices: torrents.toList(),
                getter: (t) => t.name,
                cutoff: 60)
            .map((result) => torrents[result.index])
            .toList()
        : torrents;
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
    List<Torrent> torrentsSorted = List.from(torrents);

    switch (sort) {
      case Sort.addedDate:
        torrentsSorted.sort((a, b) => a.addedDate.compareTo(b.addedDate));
      case Sort.progress:
        torrentsSorted.sort((a, b) => a.progress.compareTo(b.progress));
      case Sort.size:
        torrentsSorted.sort((a, b) => a.size.compareTo(b.size));
    }

    return reverseSort ? torrentsSorted.reversed.toList() : torrentsSorted;
  }

  Future<TorrentAddedResponse> addTorrent(
      String? filename, String? metainfo, String? downloadDir) async {
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

  Future<void> fetchTorrents() async {
    // Bail out early if the model has been disposed.
    if (_disposed) return;
    // Prevent concurrent fetches overlapping
    if (_isFetching) return;
    _isFetching = true;

    try {
      final DateTime now = DateTime.now();
      final List<Torrent> fetched = await engine.fetchTorrents();

      // Display notification for torrents completed during last refresh
      for (final torrent in fetched) {
        final diff = now.difference(torrent.doneDate).inSeconds;
        if (diff >= 0 && diff < refreshIntervalSeconds) {
          showNotification(
              title: 'Download completed',
              body: torrent.name,
              notificationsDetailsType: NotificationsDetailsTypes
                  .downloadsCompletedAndroidNotificationDetails);
        }
      }

      // Auto-pause seeding torrents if user has that preference on
      if (stopSeedingWhenComplete) {
        for (final torrent in fetched) {
          if (torrent.status == TorrentStatus.seeding) {
            try {
              await engine.pauseTorrent(torrent.id);
            } catch (e) {
              debugPrint('Failed to pause seeding torrent ${torrent.id}: $e');
            }
          }
        }
      }

      torrents = fetched;

      labels = torrents
          .fold<List<String>>(
              [],
              (previousValue, element) =>
                  previousValue..addAll(element.labels ?? []))
          .toSet()
          .toList();

      // Remove filtered labels that do not exist anymore
      for (final label in List<String>.from(filters.labels)) {
        if (!labels.contains(label)) {
          filters.removeLabel(label);
        }
      }

      if (!hasLoaded) {
        hasLoaded = true;
      }

      processDisplayedTorrents();
    } catch (e, stack) {
      debugPrint('fetchTorrents error: $e\n$stack');
      // Still call processDisplayedTorrents so UI doesn't freeze
      processDisplayedTorrents();
    } finally {
      _isFetching = false;
    }
  }

  processDisplayedTorrents() {
    if (_disposed) return;
    displayedTorrents =
        _filterTorrents(_filterTorrentsName(_sortTorrents(torrents)));
    notifyListeners();
  }

  setFilterText(String value) {
    filterText = value;
    processDisplayedTorrents();
  }

  setSort(Sort value, bool reverse) async {
    SharedPrefsStorage.setString('sort', value.name);
    SharedPrefsStorage.setBool('reverseSort', reverse);
    sort = value;
    reverseSort = reverse;
    processDisplayedTorrents();
  }

  setFilters(Filters updatedFilters) async {
    filters = updatedFilters;
    processDisplayedTorrents();
  }
}

import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:gravity_torrent/engine/engine.dart';
import 'package:gravity_torrent/engine/torrent.dart';
import 'package:gravity_torrent/services/service_locator.dart';
import 'package:gravity_torrent/storage/shared_preferences.dart';

/// Guard mode for [WifiGuardService].
enum WifiGuardMode {
  /// Pause downloads whenever the device is not on WiFi.
  wifiOnly,

  /// Pause downloads whenever the network interface IP address changes
  /// (e.g. VPN disconnects and ISP IP is exposed).
  vpnKillSwitch,
}

/// Service that pauses all active torrents when the network leaves WiFi
/// (WiFi-only mode) or when the bound network interface changes (VPN kill
/// switch mode).
///
/// Follows the same singleton / SharedPrefs pattern as [SchedulerService].
class WifiGuardService {
  WifiGuardService._();
  static final WifiGuardService instance = WifiGuardService._();

  static const _enabledKey = 'gravity_torrent_wifi_guard_enabled';
  static const _modeKey = 'gravity_torrent_wifi_guard_mode';

  bool _enabled = false;
  bool _loaded = false;
  WifiGuardMode _mode = WifiGuardMode.wifiOnly;

  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  final Set<int> _pausedByGuard = {};

  /// The last known list of local IP addresses, used to detect interface changes.
  List<String> _lastIpAddresses = [];

  bool get isEnabled => _enabled;
  WifiGuardMode get mode => _mode;

  Future<void> load() async {
    if (_loaded) return;
    _enabled = await SharedPrefsStorage.getBool(_enabledKey) ?? false;
    final modeStr = await SharedPrefsStorage.getString(_modeKey);
    _mode = modeStr == 'vpnKillSwitch'
        ? WifiGuardMode.vpnKillSwitch
        : WifiGuardMode.wifiOnly;
    _loaded = true;
    if (_enabled) _subscribe();
  }

  Future<void> setEnabled(bool value) async {
    _enabled = value;
    await SharedPrefsStorage.setBool(_enabledKey, value);
    if (value) {
      _subscribe();
    } else {
      _unsubscribe();
      await _resumeAll();
    }
  }

  Future<void> setMode(WifiGuardMode mode) async {
    _mode = mode;
    await SharedPrefsStorage.setString(
      _modeKey,
      mode == WifiGuardMode.vpnKillSwitch ? 'vpnKillSwitch' : 'wifiOnly',
    );
    // Re-seed the IP snapshot when switching modes.
    _lastIpAddresses = await _currentIpAddresses();
    _pausedByGuard.clear();
  }

  void _subscribe() {
    _unsubscribe();
    // Seed initial IP list for kill-switch comparison.
    _currentIpAddresses().then((ips) => _lastIpAddresses = ips);
    _connectivitySub =
        Connectivity().onConnectivityChanged.listen(_onConnectivityChanged);
  }

  void _unsubscribe() {
    _connectivitySub?.cancel();
    _connectivitySub = null;
  }

  Future<void> _onConnectivityChanged(
    List<ConnectivityResult> results,
  ) async {
    if (!_enabled) return;
    final hasWifi = results.contains(ConnectivityResult.wifi);
    final hasAny = results.isNotEmpty &&
        !results.every((r) => r == ConnectivityResult.none);

    if (_mode == WifiGuardMode.wifiOnly) {
      if (!hasWifi) {
        await _pauseAll();
      } else {
        await _resumeAll();
      }
    } else {
      // VPN kill switch: pause on any IP address change.
      if (!hasAny) {
        // No network at all — definitely pause.
        await _pauseAll();
        _lastIpAddresses = [];
      } else {
        final currentIps = await _currentIpAddresses();
        final changed = !_ipListsEqual(_lastIpAddresses, currentIps);
        if (changed && _lastIpAddresses.isNotEmpty) {
          // Interface change detected.
          if (kDebugMode) {
            debugPrint(
              'WifiGuardService: interface change detected '
              '$_lastIpAddresses -> $currentIps',
            );
          }
          await _pauseAll();
        }
        _lastIpAddresses = currentIps;
      }
    }
  }

  Future<List<String>> _currentIpAddresses() async {
    try {
      final interfaces = await NetworkInterface.list(
        includeLinkLocal: false,
        type: InternetAddressType.IPv4,
      );
      return interfaces
          .expand((iface) => iface.addresses)
          .map((addr) => addr.address)
          .where((ip) => !ip.startsWith('127.'))
          .toList()
        ..sort();
    } catch (e) {
      if (kDebugMode) debugPrint('WifiGuardService: failed to list IPs: $e');
      return [];
    }
  }

  bool _ipListsEqual(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  Future<void> _pauseAll() async {
    try {
      if (!getIt.isRegistered<Engine>()) return;
      final engine = getIt<Engine>();
      final torrents = await engine.fetchTorrents();
      for (final torrent in torrents) {
        if (torrent.status == TorrentStatus.downloading ||
            torrent.status == TorrentStatus.seeding ||
            torrent.status == TorrentStatus.queuedToDownload ||
            torrent.status == TorrentStatus.queuedToSeed ||
            torrent.status == TorrentStatus.queuedToCheck ||
            torrent.status == TorrentStatus.checking) {
          try {
            await engine.pauseTorrent(torrent.id);
            _pausedByGuard.add(torrent.id);
          } catch (e) {
            if (kDebugMode) {
              debugPrint('WifiGuardService: failed to pause ${torrent.id}: $e');
            }
          }
        }
      }
      if (kDebugMode) {
        debugPrint(
          'WifiGuardService: paused ${_pausedByGuard.length} torrents',
        );
      }
    } catch (e) {
      if (kDebugMode) debugPrint('WifiGuardService _pauseAll error: $e');
    }
  }

  Future<void> _resumeAll() async {
    if (_pausedByGuard.isEmpty) return;
    if (!getIt.isRegistered<Engine>()) {
      _pausedByGuard.clear();
      return;
    }
    try {
      final engine = getIt<Engine>();
      final torrents = await engine.fetchTorrents();
      final existingIds = {for (final t in torrents) t.id};
      for (final id in List<int>.from(_pausedByGuard)) {
        if (!existingIds.contains(id)) {
          _pausedByGuard.remove(id);
          continue;
        }
          try {
            await engine.resumeTorrent(id);
            _pausedByGuard.remove(id);
          } catch (e) {
          if (kDebugMode) {
            debugPrint('WifiGuardService: failed to resume $id: $e');
          }
        }
      }
      if (kDebugMode) {
        debugPrint(
          'WifiGuardService: resumed ${_pausedByGuard.length} torrents',
        );
      }
    } catch (e) {
      if (kDebugMode) debugPrint('WifiGuardService _resumeAll error: $e');
    }
  }

  void dispose() {
    _unsubscribe();
  }
}

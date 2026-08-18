import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:gravity_torrent/storage/shared_preferences.dart';
import 'package:path/path.dart' as p;

class AutoStartService {
  AutoStartService._();

  static const _keyEnabled = 'auto_start_enabled';

  static bool get isEnabled => SharedPrefs.getBool(_keyEnabled) ?? false;

  static bool get isSupported {
    if (kIsWeb) return false;
    return Platform.isAndroid || Platform.isWindows || Platform.isLinux;
  }

  static Future<void> setEnabled(bool enabled) async {
    await SharedPrefs.setBool(_keyEnabled, enabled);

    if (!kIsWeb) {
      if (Platform.isWindows) {
        await _setWindowsAutoStart(enabled);
      } else if (Platform.isLinux) {
        await _setLinuxAutoStart(enabled);
      }
      // Android auto-start is handled by BootCompletedReceiver in the Android
      // manifest, which checks the auto_start_enabled shared preference flag.
    }
  }

  // ── Windows ──────────────────────────────────────────────────────────────

  static Future<void> _setWindowsAutoStart(bool enabled) async {
    try {
      final exePath = Platform.resolvedExecutable;
      const appName = 'GravityTorrent';

      if (enabled) {
        // Add to HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Run
        await Process.run('reg', [
          'add',
          r'HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Run',
          '/v',
          appName,
          '/t',
          'REG_SZ',
          '/d',
          '"$exePath" --autostart',
          '/f',
        ]);
      } else {
        await Process.run('reg', [
          'delete',
          r'HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Run',
          '/v',
          appName,
          '/f',
        ]);
      }
    } catch (e) {
      debugPrint('AutoStartService: Windows auto-start failed — $e');
    }
  }

  // ── Linux ────────────────────────────────────────────────────────────────

  static Future<void> _setLinuxAutoStart(bool enabled) async {
    try {
      final home = Platform.environment['HOME'];
      if (home == null) return;

      final autostartDir = Directory(p.join(home, '.config', 'autostart'));
      final desktopFile = File(
        p.join(autostartDir.path, 'gravity-torrent.desktop'),
      );

      if (enabled) {
        if (!autostartDir.existsSync()) {
          autostartDir.createSync(recursive: true);
        }

        final exePath = Platform.resolvedExecutable;
        final escapedPath = exePath.replaceAll('"', '\\"');
        final content = '''[Desktop Entry]
Type=Application
Name=Gravity Torrent
Exec="$escapedPath" --autostart
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
Comment=BitTorrent client
''';
        desktopFile.writeAsStringSync(content);
      } else {
        if (desktopFile.existsSync()) {
          desktopFile.deleteSync();
        }
      }
    } catch (e) {
      debugPrint('AutoStartService: Linux auto-start failed — $e');
    }
  }
}

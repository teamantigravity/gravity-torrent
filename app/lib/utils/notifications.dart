import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:pretty_bytes/pretty_bytes.dart';
import 'package:gravity_torrent/engine/engine.dart';
import 'package:gravity_torrent/engine/torrent.dart';
import 'package:gravity_torrent/platforms/android/foreground_service.dart'
    as foreground;
import 'package:gravity_torrent/services/service_locator.dart';
import 'package:gravity_torrent/utils/device.dart';
import 'package:gravity_torrent/storage/shared_preferences.dart';

enum NotificationsDetailsTypes { downloadsCompletedAndroidNotificationDetails }

const _completedNotificationId = 0;
// Keep the progress notification separate from the Android foreground service notification.
const _progressNotificationId = 2;
const _pendingNotificationActionKey =
    'gravity_torrent_pending_notification_action';

const downloadsCompletedAndroidNotificationDetails = AndroidNotificationDetails(
  'downloads_completed',
  'Downloads completed',
  channelDescription:
      'This channel is used for downloads completed notifications.',
);

FlutterLocalNotificationsPlugin get flutterLocalNotificationsPlugin =>
    foreground.flutterLocalNotificationsPlugin;

_removeNotificationChannels() async {
  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.deleteNotificationChannel(channelId: 'downloads_completed');
}

Future<void> initializeNotifications() async {
  await _removeNotificationChannels();
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('ic_stat_name');

  final List<DarwinNotificationCategory> darwinNotificationCategories =
      <DarwinNotificationCategory>[
    DarwinNotificationCategory(
      'download_progress',
      actions: <DarwinNotificationAction>[
        DarwinNotificationAction.plain('pause_all', 'Pause all'),
        DarwinNotificationAction.plain('resume_all', 'Resume all'),
      ],
    ),
  ];

  final DarwinInitializationSettings initializationSettingsDarwin =
      DarwinInitializationSettings(
    requestAlertPermission: true,
    requestBadgePermission: false,
    requestSoundPermission: false,
    notificationCategories: darwinNotificationCategories,
  );

  final LinuxInitializationSettings initializationSettingsLinux =
      LinuxInitializationSettings(
    defaultActionName: 'Open notification',
    defaultIcon: isFlatpak()
        ? ThemeLinuxIcon('com.teamantigravity.gravitytorrent')
        : AssetsLinuxIcon('assets/tray_icon.png'),
  );

  final InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
    iOS: initializationSettingsDarwin,
    macOS: initializationSettingsDarwin,
    linux: initializationSettingsLinux,
    windows: const WindowsInitializationSettings(
      appName: 'Gravity Torrent',
      appUserModelId: 'com.teamantigravity.gravitytorrent',
      iconPath: 'assets/tray_icon.ico',
      guid: '967649c9-c508-4d91-b3e4-5e65610b6cb7',
    ),
  );

  await flutterLocalNotificationsPlugin.initialize(
    settings: initializationSettings,
    onDidReceiveNotificationResponse: onForegroundNotificationResponse,
    onDidReceiveBackgroundNotificationResponse:
        onBackgroundNotificationResponse,
  );
}

showNotification({
  int id = _completedNotificationId,
  required String title,
  required String body,
  String? payload,
  NotificationsDetailsTypes? notificationsDetailsType,
}) async {
  final androidNotificationDetails = switch (notificationsDetailsType) {
    NotificationsDetailsTypes.downloadsCompletedAndroidNotificationDetails =>
      downloadsCompletedAndroidNotificationDetails,
    _ => null,
  };

  final NotificationDetails notificationDetails = NotificationDetails(
    android: androidNotificationDetails,
  );

  await flutterLocalNotificationsPlugin.show(
    id: id,
    title: title,
    body: body,
    notificationDetails: notificationDetails,
    payload: payload,
  );
}

showCompletedNotification(String name, {int? id, Duration? duration}) async {
  String body = name;
  if (duration != null) {
    body += '\nCompleted in ${duration.inMinutes}m ${duration.inSeconds % 60}s';
  }
  await showNotification(
    id: id ?? _completedNotificationId,
    title: 'Download completed',
    body: body,
    payload: 'completed',
    notificationsDetailsType:
        NotificationsDetailsTypes.downloadsCompletedAndroidNotificationDetails,
  );
}

/// Updates the Android foreground service notification with the current
/// download progress and speed. On other platforms this is a no-op.
Future<void> updateForegroundNotification({
  required int progress,
  required int count,
  int? rateDownBytes,
}) async {
  if (defaultTargetPlatform == TargetPlatform.android) {
    await foreground.updateForegroundServiceNotification(
      progress: progress,
      count: count,
      rateDownBytes: rateDownBytes,
    );
  }
}

showDownloadProgressNotification({
  required int progress,
  required int count,
  int? rateDownBytes,
}) async {
  // On Android the persistent foreground service notification already shows
  // progress and speed, so avoid posting a duplicate notification.
  if (defaultTargetPlatform == TargetPlatform.android) {
    return;
  }

  final buffer = StringBuffer();
  buffer.write('$count download${count == 1 ? '' : 's'} in progress');
  if (count > 0) {
    buffer.write(
      ' · ${prettyBytes((rateDownBytes ?? 0).toDouble())}/s',
    );
  }

  const NotificationDetails notificationDetails = NotificationDetails(
    iOS: DarwinNotificationDetails(
      categoryIdentifier: 'download_progress',
    ),
    macOS: DarwinNotificationDetails(
      categoryIdentifier: 'download_progress',
    ),
  );

  await flutterLocalNotificationsPlugin.show(
    id: _progressNotificationId,
    title: 'Downloading',
    body: buffer.toString(),
    notificationDetails: notificationDetails,
    payload: 'progress',
  );
}

Future<void> cancelDownloadProgressNotification() async {
  // The progress notification is only used on non-Android platforms.
  if (defaultTargetPlatform == TargetPlatform.android) {
    return;
  }
  await (flutterLocalNotificationsPlugin as dynamic)
      .cancel(_progressNotificationId);
}

Future<void> _handleNotificationResponse(NotificationResponse response) async {
  WidgetsFlutterBinding.ensureInitialized();
  final actionId = response.actionId ?? response.payload;
  if (actionId == null) return;

  // Body taps just open the app; no action needs to be handled here.
  if (actionId == 'progress' || actionId == 'completed') {
    return;
  }

  if (!getIt.isRegistered<Engine>()) {
    if (kDebugMode) {
      debugPrint(
        'Engine not registered, queueing notification action: $actionId',
      );
    }
    await _storePendingNotificationAction(actionId);
    return;
  }

  final engine = getIt<Engine>();
  await _executeNotificationAction(actionId, engine);
}

Future<void> _storePendingNotificationAction(String actionId) async {
  await SharedPrefsStorage.setString(_pendingNotificationActionKey, actionId);
}

Future<void> _executeNotificationAction(String actionId, Engine engine) async {
  if (actionId == 'exit') {
    if (defaultTargetPlatform == TargetPlatform.android) {
      await foreground.stopForegroundService();
    }
    await SystemNavigator.pop();
    return;
  }

  try {
    final torrents = await engine.fetchTorrents();
    switch (actionId) {
      case 'pause_all':
        for (final torrent in torrents) {
          if (torrent.status == TorrentStatus.downloading ||
              torrent.status == TorrentStatus.seeding) {
            await engine.pauseTorrent(torrent.id);
          }
        }
        break;
      case 'resume_all':
        for (final torrent in torrents) {
          if (torrent.status == TorrentStatus.stopped) {
            await engine.resumeTorrent(torrent.id);
          }
        }
        break;
      default:
        break;
    }
  } catch (e) {
    if (kDebugMode) debugPrint('Notification action failed: $e');
  }
}

/// Processes a notification action that was queued while the engine was not
/// available (e.g. in the background notification isolate).
Future<void> processPendingNotificationAction() async {
  final actionId = await SharedPrefsStorage.getString(
    _pendingNotificationActionKey,
  );
  if (actionId == null || actionId.isEmpty) return;
  await SharedPrefsStorage.remove(_pendingNotificationActionKey);

  if (!getIt.isRegistered<Engine>()) {
    if (kDebugMode) {
      debugPrint('Engine still not registered, cannot process pending action');
    }
    return;
  }

  final engine = getIt<Engine>();
  await _executeNotificationAction(actionId, engine);
}

void onForegroundNotificationResponse(NotificationResponse response) {
  unawaited(_handleNotificationResponse(response));
}

@pragma('vm:entry-point')
void onBackgroundNotificationResponse(NotificationResponse response) {
  WidgetsFlutterBinding.ensureInitialized();
  unawaited(_handleNotificationResponse(response));
}

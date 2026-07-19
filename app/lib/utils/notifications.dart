import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:gravity_torrent/engine/engine.dart';
import 'package:gravity_torrent/engine/torrent.dart';
import 'package:gravity_torrent/services/service_locator.dart';
import 'package:gravity_torrent/utils/device.dart';

enum NotificationsDetailsTypes { downloadsCompletedAndroidNotificationDetails }

const _completedNotificationId = 0;
const _progressNotificationId = 1;

const downloadsCompletedAndroidNotificationDetails = AndroidNotificationDetails(
  'downloads_completed',
  'Downloads completed',
  channelDescription:
      'This channel is used for downloads completed notifications.',
);

AndroidNotificationDetails _buildProgressAndroidNotificationDetails(
  int progress,
) =>
    AndroidNotificationDetails(
      'downloads_progress',
      'Downloads in progress',
      channelDescription:
          'This channel is used for downloads progress notifications.',
      importance: Importance.low,
      priority: Priority.low,
      onlyAlertOnce: true,
      ongoing: true,
      showProgress: true,
      maxProgress: 100,
      progress: progress,
      actions: const <AndroidNotificationAction>[
        AndroidNotificationAction('pause_all', 'Pause all'),
        AndroidNotificationAction('resume_all', 'Resume all'),
      ],
    );

FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

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

showCompletedNotification(String name, {int? id}) async {
  await showNotification(
    id: id ?? _completedNotificationId,
    title: 'Download completed',
    body: name,
    payload: 'completed',
    notificationsDetailsType:
        NotificationsDetailsTypes.downloadsCompletedAndroidNotificationDetails,
  );
}

showDownloadProgressNotification({
  required int progress,
  required int count,
  int? rateDownBytes,
}) async {
  final buffer = StringBuffer();
  buffer.write('$count download${count == 1 ? '' : 's'} in progress');
  if (rateDownBytes != null && rateDownBytes > 0) {
    buffer
        .write(' · ${(rateDownBytes / (1024 * 1024)).toStringAsFixed(1)} MB/s');
  }

  final NotificationDetails notificationDetails = NotificationDetails(
    android: _buildProgressAndroidNotificationDetails(progress),
    iOS: const DarwinNotificationDetails(
      categoryIdentifier: 'download_progress',
    ),
    macOS: const DarwinNotificationDetails(
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
  await flutterLocalNotificationsPlugin.cancel(id: _progressNotificationId);
}

Future<void> _handleNotificationResponse(NotificationResponse response) async {
  final actionId = response.actionId ?? response.payload;
  if (actionId == null) return;

  if (!getIt.isRegistered<Engine>()) {
    if (kDebugMode) {
      debugPrint('Engine not registered, ignoring notification action');
    }
    return;
  }

  final engine = getIt<Engine>();

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
      case 'resume_all':
        for (final torrent in torrents) {
          if (torrent.status == TorrentStatus.stopped) {
            await engine.resumeTorrent(torrent.id);
          }
        }
      default:
        break;
    }
  } catch (e) {
    if (kDebugMode) debugPrint('Notification action failed: $e');
  }
}

void onForegroundNotificationResponse(NotificationResponse response) {
  unawaited(_handleNotificationResponse(response));
}

@pragma('vm:entry-point')
void onBackgroundNotificationResponse(NotificationResponse response) {
  unawaited(_handleNotificationResponse(response));
}

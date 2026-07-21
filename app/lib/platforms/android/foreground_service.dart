import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:pretty_bytes/pretty_bytes.dart';

const foregroundNotificationId = 1;

FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

bool _foregroundServiceStarted = false;

const androidNotificationDetails = AndroidNotificationDetails(
  'foreground_service_channel',
  'Foreground Service Channel',
  channelDescription:
      'This channel is used for foreground service notifications.',
  importance: Importance.low,
  silent: true,
  ongoing: true,
  actions: [
    AndroidNotificationAction('exit', 'Exit', showsUserInterface: true),
  ],
);

Future<void> createForegroundService() async {
  final androidPlugin = flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

  // Request runtime notifications permissions (Android 13+)
  final allowed = await androidPlugin?.requestNotificationsPermission();
  if (allowed == false) {
    if (kDebugMode) {
      debugPrint(
        'Notification permission not granted; foreground service not started.',
      );
    }
    _foregroundServiceStarted = false;
    return;
  }

  await _startOrUpdateForegroundService('Running in the background...');
  _foregroundServiceStarted = true;
}

Future<void> stopForegroundService() async {
  _foregroundServiceStarted = false;
  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.stopForegroundService();
}

Future<void> _startOrUpdateForegroundService(String body) async {
  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.startForegroundService(
        id: foregroundNotificationId,
        title: 'Gravity Torrent',
        body: body,
        notificationDetails: androidNotificationDetails,
        startType: AndroidServiceStartType.startRedeliverIntent,
      );
}

/// Updates the foreground service notification with the current download
/// progress and speed.
///
/// This should be called after [createForegroundService] has started the
/// service. It uses the same notification id so it replaces the foreground
/// notification instead of creating a new one.
Future<void> updateForegroundServiceNotification({
  required int progress,
  required int count,
  int? rateDownBytes,
}) async {
  if (!_foregroundServiceStarted) {
    if (kDebugMode) {
      debugPrint('Foreground service not running; skipping notification update.');
    }
    return;
  }

  final buffer = StringBuffer();
  buffer.write('$count download${count == 1 ? '' : 's'} in progress');
  if (count > 0) {
    buffer.write(
      ' · ${prettyBytes((rateDownBytes ?? 0).toDouble())}/s',
    );
  }

  final androidDetails = AndroidNotificationDetails(
    'foreground_service_channel',
    'Foreground Service Channel',
    channelDescription:
        'This channel is used for foreground service notifications.',
    importance: Importance.low,
    silent: true,
    onlyAlertOnce: true,
    ongoing: true,
    showProgress: count > 0,
    maxProgress: 100,
    progress: progress,
    actions: const <AndroidNotificationAction>[
      AndroidNotificationAction('pause_all', 'Pause all'),
      AndroidNotificationAction('resume_all', 'Resume all'),
      AndroidNotificationAction('exit', 'Exit', showsUserInterface: true),
    ],
  );

  try {
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.startForegroundService(
          id: foregroundNotificationId,
          title: 'Gravity Torrent',
          body: buffer.toString(),
          notificationDetails: androidDetails,
          startType: AndroidServiceStartType.startRedeliverIntent,
          payload: 'progress',
        );
  } on PlatformException catch (e) {
    _foregroundServiceStarted = false;
    if (kDebugMode) {
      debugPrint('Foreground service notification update failed: $e');
    }
  }
}

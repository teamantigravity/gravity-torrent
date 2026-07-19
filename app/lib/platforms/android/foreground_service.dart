import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:gravity_torrent/navigation/router.dart';

const foregroundNotificationId = 1;

FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

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

void _onDidReceiveNotificationResponse(
  NotificationResponse notificationResponse,
) async {
  if (notificationResponse.actionId == 'exit') {
    rootNavigatorKey.currentState?.maybePop();
  }
}

createForegroundService() async {
  // Request runtime notifications permissions
  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.requestNotificationsPermission();

  const initializationSettings = InitializationSettings(
    android: AndroidInitializationSettings('ic_stat_name'),
  );

  await flutterLocalNotificationsPlugin.initialize(
    settings: initializationSettings,
    onDidReceiveNotificationResponse: _onDidReceiveNotificationResponse,
  );

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.stopForegroundService();

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.deleteNotificationChannel(channelId: 'foreground_service_channel');

  await _startOrUpdateForegroundService('Running in the background...');
}

stopForegroundService() async {
  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.stopForegroundService();
}

_startOrUpdateForegroundService(String body) async {
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

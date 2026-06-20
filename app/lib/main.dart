import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:gravity_torrent/engine/engine.dart';
import 'package:gravity_torrent/engine/transmission/transmission.dart';
import 'package:gravity_torrent/l10n/app_localizations.dart';
import 'package:gravity_torrent/models/app.dart';
import 'package:gravity_torrent/models/session.dart';
import 'package:gravity_torrent/models/torrents.dart';
import 'package:gravity_torrent/navigation/router.dart';
import 'package:gravity_torrent/platforms/android/foreground_service.dart';
import 'package:gravity_torrent/platforms/windows/register_app.dart';
import 'package:gravity_torrent/services/ads/ad_service_provider.dart';
import 'package:gravity_torrent/services/purchase/purchase_service_provider.dart';
import 'package:gravity_torrent/utils/device.dart';
import 'package:gravity_torrent/utils/migrations.dart';
import 'package:gravity_torrent/utils/notifications.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';
import 'package:yaru/yaru.dart';
import 'package:media_kit/media_kit.dart';

final lightColorScheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF4285F4),
    brightness: Brightness.light,
    dynamicSchemeVariant: DynamicSchemeVariant.rainbow);

final darkColorScheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF4285F4),
    brightness: Brightness.dark,
    dynamicSchemeVariant: DynamicSchemeVariant.rainbow);

final _lightTheme = ThemeData(
    colorScheme: lightColorScheme,
    useMaterial3: true,
    navigationBarTheme: const NavigationBarThemeData(
        backgroundColor: Colors.transparent,
        indicatorColor: Colors.transparent),
    navigationRailTheme:
        const NavigationRailThemeData(indicatorColor: Colors.transparent),
    bottomSheetTheme:
        BottomSheetThemeData(backgroundColor: lightColorScheme.surface),
    chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(32.0), // Adjust the radius as needed
    )));

final _darkTheme = ThemeData(
    colorScheme: darkColorScheme,
    useMaterial3: true,
    navigationBarTheme: const NavigationBarThemeData(
        backgroundColor: Colors.transparent,
        indicatorColor: Colors.transparent),
    navigationRailTheme:
        const NavigationRailThemeData(indicatorColor: Colors.transparent),
    bottomSheetTheme:
        BottomSheetThemeData(backgroundColor: darkColorScheme.surface),
    chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(32.0), // Adjust the radius as needed
    )));

// Initialize torrents engine, we use transmission
Engine engine = TransmissionEngine();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

  initializeNotifications();

  unawaited(AdServiceProvider.instance.init());
  PurchaseServiceProvider.wirePurchaseStream();

  if (isDesktop()) {
    await YaruWindowTitleBar.ensureInitialized();
    // Must add this line.
    await windowManager.ensureInitialized();

    WindowOptions windowOptions =
        const WindowOptions(minimumSize: Size(360, 360));

    windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }

  await engine.init();

  // Run migrations for app updates
  await runMigrations();

  if (Platform.isAndroid) {
    try {
      await createForegroundService();
    } catch (e) {
      // Android does not allow to start a foreground service
      // while app is in background. This can happen in development
      // when live reloading.
      debugPrint(e.toString());
    }
  } else if (Platform.isWindows) {
    registerAppInRegistry();
  }

  runApp(const GravityTorrent());
}

class GravityTorrent extends StatelessWidget {
  const GravityTorrent({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => AppModel()),
        ChangeNotifierProvider(create: (context) => TorrentsModel()),
        ChangeNotifierProvider(create: (context) => SessionModel())
      ],
      child: const GravityTorrentApp(),
    );
  }
}

class GravityTorrentApp extends StatelessWidget {
  const GravityTorrentApp({super.key});

  // App root
  @override
  Widget build(BuildContext context) {
    return Consumer<AppModel>(builder: (context, app, child) {
      final (languageCode, countryCode) = switch (app.locale.split('_')) {
        [final lang, final country] => (lang, country),
        [final lang] => (lang, ''),
        _ => ('', ''),
      };

      return MaterialApp.router(
        title: 'Gravity Torrent',
        theme: _lightTheme,
        darkTheme: _darkTheme,
        themeMode: app.theme,
        routerConfig: router,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: Locale(languageCode, countryCode),
        debugShowCheckedModeBanner: false,
      );
    });
  }
}

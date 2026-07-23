import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
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
import 'package:gravity_torrent/services/audio_handler.dart';
import 'package:gravity_torrent/services/purchase/purchase_service_provider.dart';
import 'package:gravity_torrent/utils/device.dart';
import 'package:gravity_torrent/services/service_locator.dart';
import 'package:gravity_torrent/utils/migrations.dart';
import 'package:gravity_torrent/utils/notifications.dart';
import 'package:audio_service/audio_service.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';
import 'package:yaru/yaru.dart';
import 'package:media_kit/media_kit.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:gravity_torrent/models/feature_flags.dart';
import 'package:gravity_torrent/screens/lock/lock_screen.dart';
import 'package:gravity_torrent/services/app_lock_service.dart';
import 'package:gravity_torrent/services/haptic_service.dart';
import 'package:gravity_torrent/services/quota_service.dart';
import 'package:gravity_torrent/services/remote_control_service.dart';
import 'package:gravity_torrent/services/rss_service.dart';
import 'package:gravity_torrent/services/scheduler_service.dart';
import 'package:gravity_torrent/services/wifi_guard_service.dart';
import 'package:gravity_torrent/services/battery_service.dart';
import 'package:gravity_torrent/services/seed_ratio_service.dart';
import 'package:gravity_torrent/services/analytics_service.dart';
import 'package:gravity_torrent/services/blocklist_service.dart';

ColorScheme _buildColorScheme(Brightness brightness, ColorScheme? dynamic) {
  return dynamic ??
      ColorScheme.fromSeed(
        seedColor: const Color(0xFF4285F4),
        brightness: brightness,
        dynamicSchemeVariant: DynamicSchemeVariant.rainbow,
      );
}

ThemeData _buildTheme(ColorScheme colorScheme, {bool trueBlack = false}) {
  final adjustedScheme = trueBlack && colorScheme.brightness == Brightness.dark
      ? colorScheme.copyWith(surface: Colors.black)
      : colorScheme;

  return ThemeData(
    colorScheme: adjustedScheme,
    scaffoldBackgroundColor:
        trueBlack && colorScheme.brightness == Brightness.dark
            ? Colors.black
            : adjustedScheme.surface,
    useMaterial3: true,
    navigationBarTheme: const NavigationBarThemeData(
      backgroundColor: Colors.transparent,
      indicatorColor: Colors.transparent,
    ),
    navigationRailTheme: const NavigationRailThemeData(
      indicatorColor: Colors.transparent,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: adjustedScheme.surface,
    ),
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32.0)),
    ),
  );
}

// Initialize torrents engine, we use transmission
Engine engine = TransmissionEngine();

/// Starts the background SOTA services that depend on the loaded feature flags.
/// Should be called after the engine is initialized and migrations have run.
Future<void> startServices(FeatureFlagsModel flags) async {
  HapticService.setEnabled(flags.enableHaptic);

  try {
    await WifiGuardService.instance.load();
    await WifiGuardService.instance.setEnabled(flags.enableWifiOnly);
  } catch (e) {
    if (kDebugMode) debugPrint('WifiGuardService init failed: $e');
  }

  try {
    await SeedRatioService.instance.load();
  } catch (e) {
    if (kDebugMode) debugPrint('SeedRatioService init failed: $e');
  }

  try {
    if (isMobile()) {
      await BatteryService.instance.load();
      await BatteryService.instance.setEnabled(flags.enableBatterySaver);
    }
  } catch (e) {
    if (kDebugMode) debugPrint('BatteryService init failed: $e');
  }

  try {
    await SchedulerService.instance.load();
    await SchedulerService.instance.setEnabled(flags.enableScheduler);
  } catch (e) {
    if (kDebugMode) debugPrint('SchedulerService init failed: $e');
  }

  try {
    await RssService.instance.load();
    if (flags.enableRssAutoDownload) {
      RssService.instance.startPolling();
    }
  } catch (e) {
    if (kDebugMode) debugPrint('RssService init failed: $e');
  }

  try {
    await QuotaService.instance.load();
  } catch (e) {
    if (kDebugMode) debugPrint('QuotaService init failed: $e');
  }

  try {
    await AppLockService.instance.load();
  } catch (e) {
    if (kDebugMode) debugPrint('AppLockService init failed: $e');
  }

  try {
    await AnalyticsService.instance.load();
  } catch (e) {
    if (kDebugMode) debugPrint('AnalyticsService init failed: $e');
  }

  try {
    await BlocklistService.instance.load();
  } catch (e) {
    if (kDebugMode) debugPrint('BlocklistService init failed: $e');
  }

  try {
    if (flags.enableRemoteControl) {
      await RemoteControlService.instance.start();
    }
  } catch (e) {
    if (kDebugMode) debugPrint('RemoteControlService init failed: $e');
  }
}

/// Stops background services before the engine shuts down.
Future<void> stopServices() async {
  SchedulerService.instance.dispose();
  RssService.instance.stopPolling();
  WifiGuardService.instance.dispose();
  if (isMobile()) {
    BatteryService.instance.dispose();
  }
  await RemoteControlService.instance.stop();
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

  await initializeNotifications();

  unawaited(
    AdServiceProvider.instance.init().catchError((e) {
      if (kDebugMode) debugPrint('AdService init failed: $e');
      return null;
    }),
  );
  PurchaseServiceProvider.wirePurchaseStream();

  if (isDesktop()) {
    await YaruWindowTitleBar.ensureInitialized();
    // Must add this line.
    await windowManager.ensureInitialized();

    WindowOptions windowOptions = const WindowOptions(
      minimumSize: Size(360, 360),
    );

    windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }

  getIt.registerSingleton<Engine>(engine);

  await engine.init();

  // Initialize the media session for background audio on supported platforms.
  if (Platform.isAndroid || Platform.isIOS || Platform.isMacOS) {
    try {
      await AudioService.init<MediaKitAudioHandler>(
        builder: () => MediaKitAudioHandler(),
        config: const AudioServiceConfig(
          androidNotificationChannelId:
              'com.teamantigravity.gravitytorrent.media',
          androidNotificationChannelName: 'Media playback',
          androidNotificationChannelDescription:
              'Media playback controls and background audio',
          androidNotificationIcon: 'mipmap/ic_launcher',
          androidStopForegroundOnPause: true,
          fastForwardInterval: Duration(seconds: 10),
          rewindInterval: Duration(seconds: 10),
        ),
      );
    } catch (e) {
      if (kDebugMode) debugPrint('AudioService init failed: $e');
    }
  }

  // Run migrations for app updates
  await runMigrations();

  // Load feature flags and remote config before starting any SOTA services so
  // remote kill switches are respected and the correct service state is restored.
  final featureFlags = FeatureFlagsModel();
  await featureFlags.initialization;

  // Start background SOTA services based on the loaded flags.
  await startServices(featureFlags);

  if (Platform.isAndroid) {
    try {
      await createForegroundService();
    } catch (e) {
      // Android does not allow to start a foreground service
      // while app is in background. This can happen in development
      // when live reloading.
      if (kDebugMode) debugPrint(e.toString());
    }
  } else if (Platform.isWindows) {
    registerAppInRegistry();
  }

  runApp(GravityTorrent(featureFlags: featureFlags));
}

class GravityTorrent extends StatelessWidget {
  final FeatureFlagsModel featureFlags;

  const GravityTorrent({super.key, required this.featureFlags});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => AppModel()),
        ChangeNotifierProvider.value(value: featureFlags),
        ChangeNotifierProvider(
          create: (context) => TorrentsModel(
            featureFlags: Provider.of<FeatureFlagsModel>(
              context,
              listen: false,
            ),
          ),
        ),
        ChangeNotifierProvider(create: (context) => SessionModel()),
      ],
      child: const GravityTorrentApp(),
    );
  }
}

class GravityTorrentApp extends StatefulWidget {
  const GravityTorrentApp({super.key});

  @override
  State<GravityTorrentApp> createState() => _GravityTorrentAppState();
}

class _GravityTorrentAppState extends State<GravityTorrentApp>
    with WidgetsBindingObserver, WindowListener {
  bool _unlocked = false;
  bool _wasLocked = false;
  Timer? _lockDebounceTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (isDesktop()) {
      windowManager.addListener(this);
    }
  }

  @override
  void dispose() {
    _lockDebounceTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    if (isDesktop()) {
      windowManager.removeListener(this);
    }
    super.dispose();
  }

  Future<void> _shutdownServices() async {
    await stopServices();
    await engine.shutdown();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateLockState();
  }

  void _updateLockState() {
    final flags = Provider.of<FeatureFlagsModel>(context, listen: false);
    final isLockEnabled = flags.enableAppLock &&
        AppLockService.instance.enabled &&
        AppLockService.instance.hasPin;

    if (!isLockEnabled) {
      _unlocked = false;
      _wasLocked = false;
    } else {
      if (!_wasLocked) {
        // Lock just became active for the first time this session
        // (e.g. user just finished setting up their PIN). Grant the
        // current session access so the user isn't immediately locked
        // out right after enabling the feature.
        _unlocked = true;
      }
      _wasLocked = true;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted) return;

    switch (state) {
      case AppLifecycleState.resumed:
        _lockDebounceTimer?.cancel();
        if (kDebugMode) debugPrint("Application resumed");
        unawaited(processPendingNotificationAction());
        break;

      case AppLifecycleState.inactive:
        break;

      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
        if (_unlocked) {
          _lockDebounceTimer?.cancel();
          _lockDebounceTimer = Timer(const Duration(seconds: 5), () {
            if (mounted) setState(() => _unlocked = false);
          });
        }
        break;

      case AppLifecycleState.detached:
        _lockDebounceTimer?.cancel();
        unawaited(_shutdownServices());
        break;
    }
  }

  @override
  void onWindowClose() {
    if (mounted && _unlocked) {
      setState(() => _unlocked = false);
    }
  }

  // App root
  @override
  Widget build(BuildContext context) {
    return Consumer<AppModel>(
      builder: (context, app, child) {
        final (languageCode, countryCode) = switch (app.locale.split('_')) {
          [final lang, final country] => (lang, country),
          [final lang] when lang.isNotEmpty => (lang, ''),
          _ => ('en', ''),
        };

        return Consumer<FeatureFlagsModel>(
          builder: (context, flags, child) {
            final isLockEnabled = flags.enableAppLock &&
                AppLockService.instance.enabled &&
                AppLockService.instance.hasPin;
            final shouldLock = isLockEnabled && !_unlocked;

            return DynamicColorBuilder(
              builder: (lightDynamic, darkDynamic) {
                final lightColorScheme = _buildColorScheme(
                  Brightness.light,
                  flags.loaded && flags.useDynamicColor ? lightDynamic : null,
                );
                final darkColorScheme = _buildColorScheme(
                  Brightness.dark,
                  flags.loaded && flags.useDynamicColor ? darkDynamic : null,
                );

                return MaterialApp.router(
                  title: 'Gravity Torrent',
                  theme:
                      _buildTheme(lightColorScheme, trueBlack: app.amoledBlack),
                  darkTheme:
                      _buildTheme(darkColorScheme, trueBlack: app.amoledBlack),
                  themeMode: app.theme,
                  routerConfig: router,
                  localizationsDelegates:
                      AppLocalizations.localizationsDelegates,
                  supportedLocales: AppLocalizations.supportedLocales,
                  locale: Locale(languageCode, countryCode),
                  debugShowCheckedModeBanner: false,
                  builder: (context, child) {
                    if (shouldLock) {
                      return LockScreen(
                        onUnlocked: () => setState(() => _unlocked = true),
                      );
                    }
                    return child!;
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}

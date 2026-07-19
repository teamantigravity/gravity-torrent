import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:gravity_torrent/constants/locales.dart';
import 'package:gravity_torrent/services/ads/ad_service_provider.dart';
import 'package:gravity_torrent/services/app_lock_service.dart';
import 'package:gravity_torrent/dialogs/reusable/number_input.dart';
import 'package:gravity_torrent/engine/session.dart';
import 'package:gravity_torrent/main.dart';
import 'package:gravity_torrent/models/app.dart';
import 'package:gravity_torrent/models/feature_flags.dart';
import 'package:gravity_torrent/models/session.dart';
import 'package:gravity_torrent/models/torrents.dart';
import 'package:gravity_torrent/screens/settings/dialogs/blocklist_url.dart';
import 'package:gravity_torrent/screens/settings/dialogs/encryption_selector.dart';
import 'package:gravity_torrent/screens/settings/dialogs/locale_selector.dart';
import 'package:gravity_torrent/screens/settings/dialogs/maximum_active_downloads_editor.dart';
import 'package:gravity_torrent/screens/settings/dialogs/peer_port.dart';
import 'package:gravity_torrent/screens/settings/dialogs/ratio_input.dart';
import 'package:gravity_torrent/screens/settings/dialogs/reset_torrent_settings.dart';
import 'package:gravity_torrent/screens/settings/dialogs/theme_selector.dart';
import 'package:gravity_torrent/screens/settings/dialogs/turtle_schedule_dialog.dart';
import 'package:gravity_torrent/widgets/ad_banner_slot.dart';
import 'package:gravity_torrent/utils/device.dart';
import 'package:gravity_torrent/utils/string_extensions.dart';
import 'package:gravity_torrent/utils/update.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:gravity_torrent/l10n/app_localizations.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool canCheckForUpdate = false;
  bool showAdvancedSettings = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  _init() async {
    bool isFromAppStore = await isDistributedFromAppStore();
    if (!mounted) return;
    setState(() {
      canCheckForUpdate = !isFromAppStore;
    });
  }

  // Handlers
  void handlePickFolder(BuildContext context) async {
    String? selectedDirectory = await FilePicker.getDirectoryPath(
      dialogTitle: 'Download directory picker',
    );

    if (selectedDirectory == null) return;

    var sessionUpdate = SessionBase(downloadDir: selectedDirectory);
    if (context.mounted) {
      var sessionModel = Provider.of<SessionModel>(context, listen: false);
      await sessionModel.session?.update(sessionUpdate);
      await sessionModel.fetchSession();
    }
  }

  void handleMaximumActiveDownloadsSave(BuildContext context, int value) async {
    var sessionUpdate = SessionBase(downloadQueueSize: value);
    if (context.mounted) {
      var sessionModel = Provider.of<SessionModel>(context, listen: false);
      await sessionModel.session?.update(sessionUpdate);
      await sessionModel.fetchSession();
    }
  }

  void handlePeerPortSave(BuildContext context, int value) async {
    var sessionUpdate = SessionBase(peerPort: value);
    if (context.mounted) {
      var sessionModel = Provider.of<SessionModel>(context, listen: false);
      await sessionModel.session?.update(sessionUpdate);
      await sessionModel.fetchSession();
    }
  }

  void handleSpeedLimitDownSave(BuildContext context, int value) async {
    var sessionUpdate = SessionBase(speedLimitDown: value);
    if (context.mounted) {
      var sessionModel = Provider.of<SessionModel>(context, listen: false);
      await sessionModel.session?.update(sessionUpdate);
      await sessionModel.fetchSession();
    }
  }

  void handleSpeedLimitUpSave(BuildContext context, int value) async {
    var sessionUpdate = SessionBase(speedLimitUp: value);
    if (context.mounted) {
      var sessionModel = Provider.of<SessionModel>(context, listen: false);
      await sessionModel.session?.update(sessionUpdate);
      await sessionModel.fetchSession();
    }
  }

  void handleResetTorrentsSettings(BuildContext context) async {
    await engine.resetSettings();
    if (context.mounted) {
      var sessionModel = Provider.of<SessionModel>(context, listen: false);
      await sessionModel.fetchSession();
    }
  }

  void _handleEnableSpeedLimits(bool value) async {
    var sessionUpdate = SessionBase(
      speedLimitDownEnabled: value,
      speedLimitUpEnabled: value,
    );
    if (context.mounted) {
      var sessionModel = Provider.of<SessionModel>(context, listen: false);
      await sessionModel.session?.update(sessionUpdate);
      await sessionModel.fetchSession();
    }
  }

  // SOTA feature toggle subtitle
  Widget? _featureSubtitle(String key, FeatureFlagsModel flags) {
    if (flags.isRemotelyDisabled(key)) {
      return Text(
        AppLocalizations.of(context)!.disabledByRemoteConfig,
        style: const TextStyle(color: Colors.orange),
      );
    }
    return null;
  }

  // Privacy & security
  Future<void> _updateSession(SessionBase update) async {
    if (!mounted) return;
    final sessionModel = Provider.of<SessionModel>(context, listen: false);
    await sessionModel.session?.update(update);
    await sessionModel.fetchSession();
  }

  void _handleEncryptionChange(EncryptionMode mode) =>
      _updateSession(SessionBase(encryption: mode));

  void _handleBlocklistToggle(bool value) =>
      _updateSession(SessionBase(blocklistEnabled: value));

  void _handleBlocklistUrlSave(String url) => _updateSession(
        SessionBase(blocklistUrl: url, blocklistEnabled: url.isNotEmpty),
      );

  void _handleDhtToggle(bool value) =>
      _updateSession(SessionBase(dhtEnabled: value));

  void _handlePexToggle(bool value) =>
      _updateSession(SessionBase(pexEnabled: value));

  void _handleLpdToggle(bool value) =>
      _updateSession(SessionBase(lpdEnabled: value));

  void _handleUtpToggle(bool value) =>
      _updateSession(SessionBase(utpEnabled: value));

  void showEncryptionDialog() {
    final localizations = AppLocalizations.of(context)!;
    final session = Provider.of<SessionModel>(context, listen: false).session;
    showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(localizations.encryption),
          content: EncryptionSelector(
            currentValue: session?.encryption ?? EncryptionMode.preferred,
            onChanged: (mode) {
              Navigator.of(context).pop();
              _handleEncryptionChange(mode);
            },
          ),
          actions: <Widget>[
            TextButton(
              child: Text(localizations.cancel),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        );
      },
    );
  }

  void showBlocklistUrlDialog() {
    final session = Provider.of<SessionModel>(context, listen: false).session;
    showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return BlocklistUrlDialog(
          currentValue: session?.blocklistUrl ?? '',
          onSave: _handleBlocklistUrlSave,
        );
      },
    );
  }

  String _encryptionLabel(AppLocalizations localizations, EncryptionMode mode) {
    return switch (mode) {
      EncryptionMode.preferred => localizations.encryptionPreferred,
      EncryptionMode.required => localizations.encryptionRequired,
      EncryptionMode.tolerated => localizations.encryptionTolerated,
    };
  }

  // Scheduling & seeding limits
  void _handleTurtleToggle(bool value) =>
      _updateSession(SessionBase(altSpeedEnabled: value));

  void _handleTurtleScheduleToggle(bool value) =>
      _updateSession(SessionBase(altSpeedTimeEnabled: value));

  void _handleSeedRatioToggle(bool value) =>
      _updateSession(SessionBase(seedRatioLimited: value));

  void _handleIdleSeedingToggle(bool value) =>
      _updateSession(SessionBase(idleSeedingLimitEnabled: value));

  void showAltSpeedDownDialog() {
    final localizations = AppLocalizations.of(context)!;
    final session = Provider.of<SessionModel>(context, listen: false).session;
    showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return NumberInputDialog(
          title:
              '${localizations.turtleDownloadLimit} ${localizations.kilobytesPerSecond}',
          currentValue: session?.altSpeedDown ?? 0,
          onSave: (value) => _updateSession(SessionBase(altSpeedDown: value)),
        );
      },
    );
  }

  void showAltSpeedUpDialog() {
    final localizations = AppLocalizations.of(context)!;
    final session = Provider.of<SessionModel>(context, listen: false).session;
    showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return NumberInputDialog(
          title:
              '${localizations.turtleUploadLimit} ${localizations.kilobytesPerSecond}',
          currentValue: session?.altSpeedUp ?? 0,
          onSave: (value) => _updateSession(SessionBase(altSpeedUp: value)),
        );
      },
    );
  }

  void showTurtleScheduleDialog() {
    final session = Provider.of<SessionModel>(context, listen: false).session;
    showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return TurtleScheduleDialog(
          beginMinutes: session?.altSpeedTimeBegin ?? 540,
          endMinutes: session?.altSpeedTimeEnd ?? 1020,
          dayBitfield: session?.altSpeedTimeDay ?? 127,
          onSave: (begin, end, day) => _updateSession(
            SessionBase(
              altSpeedTimeBegin: begin,
              altSpeedTimeEnd: end,
              altSpeedTimeDay: day,
            ),
          ),
        );
      },
    );
  }

  void showSeedRatioDialog() {
    final session = Provider.of<SessionModel>(context, listen: false).session;
    showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return RatioInputDialog(
          currentValue: session?.seedRatioLimit ?? 0,
          onSave: (value) => _updateSession(
            SessionBase(seedRatioLimit: value, seedRatioLimited: true),
          ),
        );
      },
    );
  }

  void showIdleSeedingDialog() {
    final localizations = AppLocalizations.of(context)!;
    final session = Provider.of<SessionModel>(context, listen: false).session;
    showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return NumberInputDialog(
          title: localizations.idleSeedingLimit,
          currentValue: session?.idleSeedingLimit ?? 30,
          onSave: (value) => _updateSession(
            SessionBase(idleSeedingLimit: value, idleSeedingLimitEnabled: true),
          ),
        );
      },
    );
  }

  String _formatSchedule(int begin, int end) {
    String fmt(int minutes) {
      final t = TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60);
      return MaterialLocalizations.of(context).formatTimeOfDay(t);
    }

    return '${fmt(begin)} – ${fmt(end)}';
  }

  // Dialogs
  void showThemeDialog(context) {
    final localizations = AppLocalizations.of(context)!;

    showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(localizations.theme),
          content: const ThemeSelector(),
          actions: <Widget>[
            TextButton(
              child: Text(localizations.cancel),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void showLocaleDialog(context) {
    final localizations = AppLocalizations.of(context)!;

    showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(AppLocalizations.of(context)!.language),
          content: const LocaleSelector(),
          actions: <Widget>[
            TextButton(
              child: Text(localizations.cancel),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void showMaximumActiveDownloadDialog() {
    final session = Provider.of<SessionModel>(context, listen: false).session;
    showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return MaximumActiveDownloadEditorDialog(
          currentValue: session?.downloadQueueSize ?? 0,
          onSave: (value) => handleMaximumActiveDownloadsSave(context, value),
        );
      },
    );
  }

  void showPeerPortDialog() {
    final session = Provider.of<SessionModel>(context, listen: false).session;
    showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return PeerPortDialog(
          currentValue: session?.peerPort ?? 0,
          onSave: (value) => handlePeerPortSave(context, value),
        );
      },
    );
  }

  void showSpeedLimitDownDialog() {
    final localizations = AppLocalizations.of(context)!;
    final session = Provider.of<SessionModel>(context, listen: false).session;
    showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return NumberInputDialog(
          title:
              '${localizations.downloadSpeed} ${localizations.kilobytesPerSecond}',
          currentValue: session?.speedLimitDown ?? 0,
          onSave: (value) => handleSpeedLimitDownSave(context, value),
        );
      },
    );
  }

  void showSpeedLimitUpDialog() {
    final localizations = AppLocalizations.of(context)!;
    final session = Provider.of<SessionModel>(context, listen: false).session;
    showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return NumberInputDialog(
          title:
              '${localizations.uploadSpeed} ${localizations.kilobytesPerSecond}',
          currentValue: session?.speedLimitUp ?? 0,
          onSave: (value) => handleSpeedLimitUpSave(context, value),
        );
      },
    );
  }

  void showResetTorrentsSettingsDialog() {
    showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return ResetTorrentsSettingsDialog(
          onOK: () => handleResetTorrentsSettings(context),
        );
      },
    );
  }

  void _handleCheckForUpdateToggle(bool value) {
    var appModel = Provider.of<AppModel>(context, listen: false);
    appModel.setCheckForUpdate(value);
  }

  void _handleAppLockToggle(bool value, FeatureFlagsModel flags) async {
    if (value) {
      if (!AppLockService.instance.hasPin) {
        await context.push('/privacy-vault');
        if (!mounted || !AppLockService.instance.hasPin) return;
      }
      await flags.setEnableAppLock(true);
    } else {
      await flags.setEnableAppLock(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return Consumer3<AppModel, SessionModel, FeatureFlagsModel>(
      builder: (context, app, sessionModel, flags, child) {
        final downloadDir = sessionModel.session?.downloadDir ?? '';
        final downloadQueueSize = sessionModel.session?.downloadQueueSize ?? '';
        final peerPort = sessionModel.session?.peerPort ?? '';
        final isSpeedLimitEnabled =
            sessionModel.session?.speedLimitDownEnabled == true ||
                sessionModel.session?.speedLimitUpEnabled == true;
        final encryptionMode =
            sessionModel.session?.encryption ?? EncryptionMode.preferred;
        final blocklistEnabled =
            sessionModel.session?.blocklistEnabled ?? false;
        final blocklistUrl = sessionModel.session?.blocklistUrl ?? '';
        final blocklistSize = sessionModel.session?.blocklistSize ?? 0;
        final dhtEnabled = sessionModel.session?.dhtEnabled ?? true;
        final pexEnabled = sessionModel.session?.pexEnabled ?? true;
        final lpdEnabled = sessionModel.session?.lpdEnabled ?? false;
        final utpEnabled = sessionModel.session?.utpEnabled ?? true;
        final turtleEnabled = sessionModel.session?.altSpeedEnabled ?? false;
        final turtleDown = sessionModel.session?.altSpeedDown ?? 0;
        final turtleUp = sessionModel.session?.altSpeedUp ?? 0;
        final turtleScheduleEnabled =
            sessionModel.session?.altSpeedTimeEnabled ?? false;
        final turtleBegin = sessionModel.session?.altSpeedTimeBegin ?? 540;
        final turtleEnd = sessionModel.session?.altSpeedTimeEnd ?? 1020;
        final seedRatioLimited =
            sessionModel.session?.seedRatioLimited ?? false;
        final seedRatioLimit = sessionModel.session?.seedRatioLimit ?? 0;
        final idleSeedingEnabled =
            sessionModel.session?.idleSeedingLimitEnabled ?? false;
        final idleSeedingLimit = sessionModel.session?.idleSeedingLimit ?? 0;

        return Column(
          children: [
            Expanded(
              child: ListView(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 16.0),
                    child: Text(
                      localizations.appSettings,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  ListTile(
                    onTap: () => showThemeDialog(context),
                    leading: const Icon(Icons.dark_mode),
                    title: Text(localizations.theme),
                    subtitle: Text(app.theme.name.capitalize()),
                  ),
                  SwitchListTile(
                    secondary: const Icon(Icons.color_lens),
                    title: Text(localizations.dynamicColor),
                    subtitle: _featureSubtitle('useDynamicColor', flags),
                    value: flags.useDynamicColor,
                    onChanged: (v) => flags.setUseDynamicColor(v),
                  ),
                  ListTile(
                    onTap: () => showLocaleDialog(context),
                    leading: const Icon(Icons.language),
                    title: Text(localizations.language),
                    subtitle: Text(localeNames[app.locale] ?? app.locale),
                  ),
                  // Hide update check option if app is distributed through an app store
                  if (canCheckForUpdate)
                    ListTile(
                      leading: const Icon(Icons.update),
                      title: Text(localizations.checkForUpdates),
                      trailing: Switch(
                        value: app.checkForUpdate,
                        onChanged: _handleCheckForUpdateToggle,
                      ),
                      subtitle: Text(localizations.checkForUpdatesDescription),
                    ),
                  // ── Enhanced notifications & haptic (App Settings) ──────────
                  SwitchListTile(
                    secondary: const Icon(Icons.notifications_active),
                    title: Text(localizations.enhancedNotifications),
                    subtitle: _featureSubtitle(
                      'useEnhancedNotifications',
                      flags,
                    ),
                    value: flags.useEnhancedNotifications,
                    onChanged: (v) => flags.setUseEnhancedNotifications(v),
                  ),
                  SwitchListTile(
                    secondary: const Icon(Icons.picture_in_picture_alt),
                    title: Text(localizations.backgroundAudioPip),
                    subtitle: _featureSubtitle('usePipBackgroundAudio', flags),
                    value: flags.usePipBackgroundAudio,
                    onChanged: (v) => flags.setUsePipBackgroundAudio(v),
                  ),
                  SwitchListTile(
                    secondary: const Icon(Icons.vibration),
                    title: Text(localizations.hapticFeedback),
                    subtitle: _featureSubtitle('enableHaptic', flags),
                    value: flags.enableHaptic,
                    onChanged: (v) => flags.setEnableHaptic(v),
                  ),
                  SwitchListTile(
                    secondary: const Icon(Icons.shortcut),
                    title: Text(localizations.appShortcuts),
                    subtitle: _featureSubtitle('enableShortcuts', flags),
                    value: flags.enableShortcuts,
                    onChanged: (v) => flags.setEnableShortcuts(v),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 16.0, top: 16),
                    child: Text(
                      localizations.torrentsSettings,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  ListTile(
                    onTap: isMobile() ? null : () => handlePickFolder(context),
                    leading: const Icon(Icons.folder_open),
                    title: Text(localizations.downloadDirectory),
                    subtitle: Text(downloadDir),
                  ),
                  ListTile(
                    onTap: showMaximumActiveDownloadDialog,
                    leading: const Icon(Icons.downloading),
                    title: Text(localizations.maxActiveDownloads),
                    subtitle: Text(downloadQueueSize.toString()),
                  ),
                  ListTile(
                    leading: const Icon(Icons.speed),
                    title: Text(localizations.enableSpeedLimits),
                    subtitle: Text(
                      localizations.speedLimitsDescription,
                      style: isSpeedLimitEnabled
                          ? const TextStyle(color: Color(0xFF4285F4))
                          : null,
                    ),
                    trailing: Switch(
                      value: isSpeedLimitEnabled,
                      onChanged: (bool _) {
                        _handleEnableSpeedLimits(!isSpeedLimitEnabled);
                      },
                    ),
                  ),
                  ListTile(
                    enabled: isSpeedLimitEnabled,
                    onTap: showSpeedLimitDownDialog,
                    leading: const Icon(Icons.arrow_circle_down),
                    title: Text(localizations.downloadSpeedLimit),
                    subtitle: Text(
                      '${sessionModel.session?.speedLimitDown.toString()} ${localizations.kilobytesPerSecond}',
                    ),
                  ),
                  ListTile(
                    enabled: isSpeedLimitEnabled,
                    onTap: showSpeedLimitUpDialog,
                    leading: const Icon(Icons.arrow_circle_up),
                    title: Text(localizations.uploadSpeedLimit),
                    subtitle: Text(
                      '${sessionModel.session?.speedLimitUp.toString()} ${localizations.kilobytesPerSecond}',
                    ),
                  ),
                  // Stop seeding when complete toggle
                  Consumer<TorrentsModel>(
                    builder: (context, torrentsModel, _) => SwitchListTile(
                      secondary: const Icon(Icons.stop_circle_outlined),
                      title: Text(localizations.stopSeedingWhenComplete),
                      subtitle: Text(
                        localizations.stopSeedingWhenCompleteDescription,
                      ),
                      value: torrentsModel.stopSeedingWhenComplete,
                      onChanged: (v) =>
                          torrentsModel.setStopSeedingWhenComplete(v),
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.settings),
                    trailing: Switch(
                      value: showAdvancedSettings,
                      onChanged: (v) {
                        setState(() {
                          showAdvancedSettings = v;
                        });
                      },
                    ),
                    title: Text(localizations.showAdvancedSettings),
                  ),
                  if (showAdvancedSettings) ...[
                    ListTile(
                      onTap: showPeerPortDialog,
                      leading: const Icon(Icons.arrow_right_alt),
                      title: Text(localizations.listeningPort),
                      subtitle: Text(peerPort.toString()),
                    ),
                    // ── Advanced cross-platform features ──────────────────────
                    SwitchListTile(
                      secondary: const Icon(Icons.data_usage),
                      title: Text(localizations.dataUsageAnalytics),
                      subtitle: _featureSubtitle('enableAnalytics', flags),
                      value: flags.enableAnalytics,
                      onChanged: (v) => flags.setEnableAnalytics(v),
                    ),
                    if (flags.enableAnalytics)
                      ListTile(
                        leading: const Icon(Icons.bar_chart),
                        title: Text(localizations.dataUsageDashboard),
                        onTap: () => context.push('/analytics'),
                      ),
                    SwitchListTile(
                      secondary: const Icon(Icons.wifi_tethering),
                      title: Text(localizations.localRemoteControl),
                      subtitle: _featureSubtitle('enableRemoteControl', flags),
                      value: flags.enableRemoteControl,
                      onChanged: (v) => flags.setEnableRemoteControl(v),
                    ),
                    if (flags.enableRemoteControl)
                      ListTile(
                        leading: const Icon(Icons.qr_code),
                        title: Text(localizations.remoteControl),
                        onTap: () => context.push('/remote-control'),
                      ),
                    SwitchListTile(
                      secondary: const Icon(Icons.schedule),
                      title: Text(localizations.smartDownloadScheduler),
                      subtitle: _featureSubtitle('enableScheduler', flags),
                      value: flags.enableScheduler,
                      onChanged: (v) => flags.setEnableScheduler(v),
                    ),
                    if (flags.enableScheduler)
                      ListTile(
                        leading: const Icon(Icons.access_alarms),
                        title: Text(localizations.downloadSchedule),
                        onTap: () => context.push('/scheduler'),
                      ),
                    SwitchListTile(
                      secondary: const Icon(Icons.data_saver_on),
                      title: Text(localizations.monthlyBandwidthQuota),
                      subtitle: _featureSubtitle('enableQuota', flags),
                      value: flags.enableQuota,
                      onChanged: (v) => flags.setEnableQuota(v),
                    ),
                    if (flags.enableQuota)
                      ListTile(
                        leading: const Icon(Icons.storage),
                        title: Text(localizations.bandwidthQuotaSettings),
                        onTap: () => context.push('/quota'),
                      ),
                    SwitchListTile(
                      secondary: const Icon(Icons.rss_feed),
                      title: Text(localizations.rssAutoDownload),
                      subtitle: _featureSubtitle(
                        'enableRssAutoDownload',
                        flags,
                      ),
                      value: flags.enableRssAutoDownload,
                      onChanged: (v) => flags.setEnableRssAutoDownload(v),
                    ),
                    if (flags.enableRssAutoDownload)
                      ListTile(
                        leading: const Icon(Icons.feed),
                        title: Text(localizations.rssFeeds),
                        onTap: () => context.push('/rss'),
                      ),
                  ],
                  ListTile(
                    onTap: showResetTorrentsSettingsDialog,
                    leading: const Icon(Icons.settings_backup_restore),
                    title: Text(localizations.resetTorrentsSettings),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 16.0, top: 16),
                    child: Text(
                      localizations.privacyAndSecurity,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  // ── Privacy vault / app lock ─────────────────────────────
                  SwitchListTile(
                    secondary: const Icon(Icons.lock),
                    title: Text(localizations.appLock),
                    subtitle: _featureSubtitle('enableAppLock', flags),
                    value: flags.enableAppLock,
                    onChanged: (v) => _handleAppLockToggle(v, flags),
                  ),
                  if (flags.enableAppLock)
                    ListTile(
                      leading: const Icon(Icons.shield),
                      title: Text(localizations.privacyVault),
                      subtitle: Text(localizations.privacyVaultSubtitle),
                      onTap: () => context.push('/privacy-vault'),
                    ),
                  ListTile(
                    onTap: showEncryptionDialog,
                    leading: const Icon(Icons.lock_outline),
                    title: Text(localizations.encryption),
                    subtitle: Text(
                      _encryptionLabel(localizations, encryptionMode),
                    ),
                  ),
                  SwitchListTile(
                    secondary: const Icon(Icons.block),
                    title: Text(localizations.blocklist),
                    subtitle: Text(
                      blocklistEnabled && blocklistSize > 0
                          ? localizations.blocklistRulesCount(blocklistSize)
                          : localizations.blocklistDescription,
                    ),
                    value: blocklistEnabled,
                    onChanged: _handleBlocklistToggle,
                  ),
                  ListTile(
                    enabled: blocklistEnabled,
                    onTap: showBlocklistUrlDialog,
                    leading: const Icon(Icons.link),
                    title: Text(localizations.blocklistUrl),
                    subtitle: Text(
                      blocklistUrl.isEmpty
                          ? localizations.blocklistUrlNotSet
                          : blocklistUrl,
                    ),
                  ),
                  SwitchListTile(
                    secondary: const Icon(Icons.hub_outlined),
                    title: Text(localizations.dht),
                    subtitle: Text(localizations.dhtDescription),
                    value: dhtEnabled,
                    onChanged: _handleDhtToggle,
                  ),
                  SwitchListTile(
                    secondary: const Icon(Icons.people_outline),
                    title: Text(localizations.pex),
                    subtitle: Text(localizations.pexDescription),
                    value: pexEnabled,
                    onChanged: _handlePexToggle,
                  ),
                  SwitchListTile(
                    secondary: const Icon(Icons.lan_outlined),
                    title: Text(localizations.lpd),
                    subtitle: Text(localizations.lpdDescription),
                    value: lpdEnabled,
                    onChanged: _handleLpdToggle,
                  ),
                  SwitchListTile(
                    secondary: const Icon(Icons.bolt_outlined),
                    title: Text(localizations.utp),
                    subtitle: Text(localizations.utpDescription),
                    value: utpEnabled,
                    onChanged: _handleUtpToggle,
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 16.0, top: 16),
                    child: Text(
                      localizations.schedulingAndLimits,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  SwitchListTile(
                    secondary: const Icon(Icons.hourglass_bottom),
                    title: Text(localizations.turtleMode),
                    subtitle: Text(localizations.turtleModeDescription),
                    value: turtleEnabled,
                    onChanged: _handleTurtleToggle,
                  ),
                  ListTile(
                    onTap: showAltSpeedDownDialog,
                    leading: const Icon(Icons.arrow_circle_down_outlined),
                    title: Text(localizations.turtleDownloadLimit),
                    subtitle: Text(
                      '$turtleDown ${localizations.kilobytesPerSecond}',
                    ),
                  ),
                  ListTile(
                    onTap: showAltSpeedUpDialog,
                    leading: const Icon(Icons.arrow_circle_up_outlined),
                    title: Text(localizations.turtleUploadLimit),
                    subtitle: Text(
                      '$turtleUp ${localizations.kilobytesPerSecond}',
                    ),
                  ),
                  SwitchListTile(
                    secondary: const Icon(Icons.schedule),
                    title: Text(localizations.turtleSchedule),
                    subtitle: Text(localizations.turtleScheduleDescription),
                    value: turtleScheduleEnabled,
                    onChanged: _handleTurtleScheduleToggle,
                  ),
                  ListTile(
                    enabled: turtleScheduleEnabled,
                    onTap: showTurtleScheduleDialog,
                    leading: const Icon(Icons.access_time),
                    title: Text(localizations.scheduledHours),
                    subtitle: Text(_formatSchedule(turtleBegin, turtleEnd)),
                  ),
                  SwitchListTile(
                    secondary: const Icon(Icons.data_usage),
                    title: Text(localizations.seedRatioLimitEnable),
                    subtitle: Text(localizations.seedRatioLimitDescription),
                    value: seedRatioLimited,
                    onChanged: _handleSeedRatioToggle,
                  ),
                  ListTile(
                    enabled: seedRatioLimited,
                    onTap: showSeedRatioDialog,
                    leading: const Icon(Icons.percent),
                    title: Text(localizations.seedRatioLimit),
                    subtitle: Text(
                      seedRatioLimit > 0
                          ? seedRatioLimit.toStringAsFixed(2)
                          : localizations.notSet,
                    ),
                  ),
                  SwitchListTile(
                    secondary: const Icon(Icons.timer_off_outlined),
                    title: Text(localizations.idleSeedingLimitEnable),
                    subtitle: Text(localizations.idleSeedingLimitDescription),
                    value: idleSeedingEnabled,
                    onChanged: _handleIdleSeedingToggle,
                  ),
                  ListTile(
                    enabled: idleSeedingEnabled,
                    onTap: showIdleSeedingDialog,
                    leading: const Icon(Icons.hourglass_disabled),
                    title: Text(localizations.idleSeedingLimit),
                    subtitle: Text(
                      idleSeedingLimit > 0
                          ? localizations.minutesValue(idleSeedingLimit)
                          : localizations.notSet,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 16.0, top: 16),
                    child: Text(
                      localizations.about,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.bolt),
                    title: Text(localizations.version),
                    subtitle: Text(app.version),
                  ),
                  ValueListenableBuilder<bool>(
                    valueListenable: AdServiceProvider.instance.adFreeNotifier,
                    builder: (context, isAdFree, child) {
                      if (isAdFree) return const SizedBox.shrink();
                      return ListTile(
                        leading: const Icon(Icons.workspace_premium_outlined),
                        title: Text(localizations.removeAds),
                        subtitle: Text(localizations.premiumSubtitle),
                        onTap: () => context.push('/upgrade'),
                      );
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.bug_report),
                    title: Text(localizations.reportBug),
                    onTap: () async {
                      final result = await launchUrl(
                        Uri.parse(
                          'https://github.com/teamantigravity/gravity-torrent/issues/new/choose',
                        ),
                        mode: LaunchMode.externalApplication,
                      );
                      if (!context.mounted) return;
                      if (!result) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Could not open the bug report page'),
                            backgroundColor: Colors.orange,
                          ),
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
            const AdBannerSlot(),
          ],
        );
      },
    );
  }
}

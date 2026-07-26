import 'package:flutter/material.dart';
import 'package:gravity_torrent/l10n/app_localizations.dart';
import 'package:gravity_torrent/services/notification_channel_service.dart';

class NotificationSettingsSection extends StatefulWidget {
  const NotificationSettingsSection({super.key});

  @override
  State<NotificationSettingsSection> createState() =>
      _NotificationSettingsSectionState();
}

class _NotificationSettingsSectionState
    extends State<NotificationSettingsSection> {
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            l.notifications,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        SwitchListTile.adaptive(
          secondary: const Icon(Icons.do_not_disturb_on),
          title: Text(l.respectDnd),
          subtitle: Text(l.respectDndSubtitle),
          value: NotificationChannelService.dndRespect,
          onChanged: (v) {
            NotificationChannelService.setDndRespect(v);
            setState(() {});
          },
        ),
        SwitchListTile.adaptive(
          secondary: const Icon(Icons.downloading),
          title: Text(l.progressNotifications),
          value: NotificationChannelService.progressEnabled,
          onChanged: (v) {
            NotificationChannelService.setProgressEnabled(v);
            setState(() {});
          },
        ),
        SwitchListTile.adaptive(
          secondary: const Icon(Icons.download_done),
          title: Text(l.completionNotifications),
          value: NotificationChannelService.completionEnabled,
          onChanged: (v) {
            NotificationChannelService.setCompletionEnabled(v);
            setState(() {});
          },
        ),
        SwitchListTile.adaptive(
          secondary: const Icon(Icons.error_outline),
          title: Text(l.errorNotifications),
          value: NotificationChannelService.errorEnabled,
          onChanged: (v) {
            NotificationChannelService.setErrorEnabled(v);
            setState(() {});
          },
        ),
        SwitchListTile.adaptive(
          secondary: const Icon(Icons.data_usage),
          title: Text(l.dataUsageNotifications),
          value: NotificationChannelService.dataUsageEnabled,
          onChanged: (v) {
            NotificationChannelService.setDataUsageEnabled(v);
            setState(() {});
          },
        ),
      ],
    );
  }
}

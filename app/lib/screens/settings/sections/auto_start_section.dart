import 'package:flutter/material.dart';
import 'package:gravity_torrent/l10n/app_localizations.dart';
import 'package:gravity_torrent/services/auto_start_service.dart';

class AutoStartSection extends StatefulWidget {
  const AutoStartSection({super.key});

  @override
  State<AutoStartSection> createState() => _AutoStartSectionState();
}

class _AutoStartSectionState extends State<AutoStartSection> {
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return SwitchListTile.adaptive(
      secondary: const Icon(Icons.power_settings_new),
      title: Text(l.autoStart),
      subtitle: Text(l.autoStartSubtitle),
      value: AutoStartService.isEnabled,
      onChanged: AutoStartService.isSupported
          ? (v) {
              AutoStartService.setEnabled(v);
              setState(() {});
            }
          : null,
    );
  }
}

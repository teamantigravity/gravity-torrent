import 'package:flutter/material.dart';
import 'package:gravity_torrent/l10n/app_localizations.dart';
import 'package:gravity_torrent/services/player_enhancements_service.dart';
import 'package:provider/provider.dart';

class SpeedSelector extends StatelessWidget {
  const SpeedSelector({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<PlayerEnhancementsService>(
      builder: (context, svc, _) {
        final l = AppLocalizations.of(context);
        final speedLabel = '${svc.speed}x';
        return PopupMenuButton<double>(
          initialValue: svc.speed,
          onSelected: svc.setSpeed,
          tooltip: l.playbackSpeed,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Text(
              speedLabel,
              style: Theme.of(context).textTheme.labelLarge,
              semanticsLabel: '${l.playbackSpeed} $speedLabel',
            ),
          ),
          itemBuilder: (_) => PlayerEnhancementsService.speeds
              .map((s) => PopupMenuItem(value: s, child: Text('${s}x')))
              .toList(),
        );
      },
    );
  }
}

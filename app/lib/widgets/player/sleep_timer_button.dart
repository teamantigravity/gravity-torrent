import 'package:flutter/material.dart';
import 'package:gravity_torrent/l10n/app_localizations.dart';
import 'package:gravity_torrent/services/player_enhancements_service.dart';
import 'package:provider/provider.dart';

class SleepTimerButton extends StatelessWidget {
  const SleepTimerButton({super.key});

  static const _presets = [
    Duration(minutes: 5),
    Duration(minutes: 15),
    Duration(minutes: 30),
    Duration(minutes: 60),
    Duration(minutes: 120),
  ];

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Consumer<PlayerEnhancementsService>(
      builder: (context, svc, _) {
        return PopupMenuButton<Duration?>(
          tooltip: l.sleepTimer,
          icon: Icon(
            svc.sleepTimerActive
                ? Icons.bedtime_rounded
                : Icons.bedtime_outlined,
            semanticLabel: l.sleepTimer,
          ),
          onSelected: (d) {
            if (d == null) {
              svc.cancelSleepTimer();
            } else {
              svc.startSleepTimer(d);
            }
          },
          itemBuilder: (_) => [
            ..._presets.map(
              (d) => PopupMenuItem(
                value: d,
                child: Text(
                  '${d.inMinutes} '
                  '${d.inMinutes == 1 ? l.minute : l.minutes}',
                ),
              ),
            ),
            if (svc.sleepTimerActive)
              PopupMenuItem(
                value: null,
                child: Text(
                  l.cancelSleepTimer,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

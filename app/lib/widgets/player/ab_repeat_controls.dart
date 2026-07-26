import 'package:flutter/material.dart';
import 'package:gravity_torrent/l10n/app_localizations.dart';
import 'package:gravity_torrent/services/player_enhancements_service.dart';
import 'package:provider/provider.dart';

class ABRepeatControls extends StatelessWidget {
  const ABRepeatControls({super.key});

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PlayerEnhancementsService>(
      builder: (context, svc, _) {
        final l = AppLocalizations.of(context);
        final ab = svc.abRepeat;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextButton(
              onPressed: svc.setA,
              child: Text(ab.a != null ? 'A: ${_fmt(ab.a!)}' : l.setA),
            ),
            TextButton(
              onPressed: svc.setB,
              child: Text(ab.b != null ? 'B: ${_fmt(ab.b!)}' : l.setB),
            ),
            if (ab.isActive)
              IconButton(
                icon: const Icon(Icons.clear),
                onPressed: svc.clearABRepeat,
                tooltip: l.clearAB,
              ),
          ],
        );
      },
    );
  }
}

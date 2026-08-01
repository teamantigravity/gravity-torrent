import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:gravity_torrent/l10n/app_localizations.dart';
import 'package:gravity_torrent/services/bandwidth_heatmap_service.dart';

class BandwidthHeatmapWidget extends StatelessWidget {
  const BandwidthHeatmapWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final service = context.watch<BandwidthHeatmapService>();
    final days = [
      localizations.mondayShort,
      localizations.tuesdayShort,
      localizations.wednesdayShort,
      localizations.thursdayShort,
      localizations.fridayShort,
      localizations.saturdayShort,
      localizations.sundayShort,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          localizations.bandwidthScheduleHeatmap,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            final availableWidth =
                constraints.maxWidth.isFinite ? constraints.maxWidth : 360.0;
            final cellWidth = availableWidth / 25;
            return Column(
              children: [
                Row(
                  children: [
                    SizedBox(width: cellWidth),
                    for (int i = 0; i < 24; i++)
                      SizedBox(
                        width: cellWidth,
                        child: Text(
                          '$i',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 10),
                          overflow: TextOverflow.clip,
                          softWrap: false,
                        ),
                      ),
                  ],
                ),
                for (int d = 0; d < 7; d++)
                  Row(
                    children: [
                      SizedBox(
                        width: cellWidth,
                        child: Text(
                          days[d],
                          style: const TextStyle(fontSize: 10),
                          overflow: TextOverflow.clip,
                          softWrap: false,
                        ),
                      ),
                      for (int h = 0; h < 24; h++)
                        Semantics(
                          label:
                              '${days[d]} $h:00 - ${_getLimitLabel(service.schedule[d][h], localizations)}',
                          button: true,
                          child: GestureDetector(
                            onTap: () {
                              final currentLimit = service.schedule[d][h];
                              final newLimit = currentLimit == 0 ? -1 : 0;
                              service.setScheduleLimit(d, h, newLimit);
                            },
                            child: Container(
                              width: math.max(0.0, cellWidth - 2), // Account for margin
                              height: math.max(0.0, cellWidth - 2), // Account for margin
                              margin: const EdgeInsets.all(1),
                              color: _getColorForLimit(
                                service.schedule[d][h],
                                context,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  String _getLimitLabel(int limit, AppLocalizations localizations) {
    if (limit == -1) return localizations.paused;
    if (limit == 0) return 'Unlimited';
    return '$limit ${localizations.kilobytesPerSecond}';
  }

  Color _getColorForLimit(int limit, BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    if (limit == -1) return colorScheme.error; // Paused
    if (limit == 0) return colorScheme.primary; // Unlimited
    return colorScheme.tertiary; // Throttled
  }
}

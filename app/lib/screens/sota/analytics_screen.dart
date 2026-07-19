import 'dart:math';

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:gravity_torrent/l10n/app_localizations.dart';
import 'package:gravity_torrent/models/torrents.dart';
import 'package:gravity_torrent/services/analytics_service.dart';
import 'package:gravity_torrent/utils/device.dart';
import 'package:gravity_torrent/widgets/window_title_bar.dart';
import 'package:pretty_bytes/pretty_bytes.dart';
import 'package:provider/provider.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await AnalyticsService.instance.load();
    if (mounted) setState(() => _loaded = true);
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final history = AnalyticsService.instance.getLastDays(7);

    return Scaffold(
      appBar: isDesktop()
          ? const WindowTitleBar()
          : AppBar(title: Text(localizations.dataUsageDashboard)),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : history.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.bar_chart,
                        size: 64,
                        color: Theme.of(context).colorScheme.outline,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        localizations.analyticsNoDataYet,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        localizations.analyticsEnableDescription,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              : _buildContent(context, history),
    );
  }

  Widget _buildContent(BuildContext context, List<DataUsageSnapshot> history) {
    final localizations = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;

    // Auto-scale chart values to the most readable unit (GB/MB/KB/B).
    final maxBytes =
        history.map((s) => max(s.downloadedBytes, s.uploadedBytes)).reduce(max);
    double divisor = 1.0;
    if (maxBytes > 1e9) {
      divisor = 1e9;
    } else if (maxBytes > 1e6) {
      divisor = 1e6;
    } else if (maxBytes > 1e3) {
      divisor = 1e3;
    }

    final spots = history
        .asMap()
        .entries
        .map(
          (e) => FlSpot(e.key.toDouble(), e.value.downloadedBytes / divisor),
        )
        .toList();
    final uploadSpots = history
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), e.value.uploadedBytes / divisor))
        .toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(localizations.analyticsLast7Days,
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          SizedBox(
            height: 240,
            child: LineChart(
              LineChartData(
                gridData: const FlGridData(show: true),
                titlesData: const FlTitlesData(show: false),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: colorScheme.primary,
                    barWidth: 3,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: colorScheme.primary.withAlpha(30),
                    ),
                  ),
                  LineChartBarData(
                    spots: uploadSpots,
                    isCurved: true,
                    color: colorScheme.secondary,
                    barWidth: 3,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: colorScheme.secondary.withAlpha(30),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          _buildLegend(colorScheme, localizations),
          const SizedBox(height: 24),
          Text(
            localizations.analyticsPerTorrentTotals,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Consumer<TorrentsModel>(
            builder: (context, model, _) {
              final sorted = List.of(model.torrents)
                ..sort(
                  (a, b) => (b.downloadedEver + b.uploadedEver).compareTo(
                    a.downloadedEver + a.uploadedEver,
                  ),
                );
              return Column(
                children: sorted
                    .take(10)
                    .map(
                      (t) => ListTile(
                        title: Text(
                          t.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text('${t.peersConnected} peers'),
                        trailing: Text(
                          '${prettyBytes(t.downloadedEver.toDouble(), locale: 'en')}\u2193\n${prettyBytes(t.uploadedEver.toDouble(), locale: 'en')}\u2191',
                          textAlign: TextAlign.end,
                        ),
                      ),
                    )
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLegend(ColorScheme colorScheme, AppLocalizations localizations) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _legendItem(colorScheme.primary, localizations.analyticsDownloaded),
        const SizedBox(width: 24),
        _legendItem(colorScheme.secondary, localizations.analyticsUploaded),
      ],
    );
  }

  Widget _legendItem(Color color, String label) {
    return Row(
      children: [
        Container(width: 12, height: 12, color: color),
        const SizedBox(width: 6),
        Text(label),
      ],
    );
  }
}

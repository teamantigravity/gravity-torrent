import 'dart:math';

import 'package:flutter/foundation.dart';
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
  int _days = 7;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      await AnalyticsService.instance.load();
    } catch (e, s) {
      if (kDebugMode) debugPrint('Failed to load analytics: $e\n$s');
    }
    if (mounted) setState(() => _loaded = true);
  }

  Future<void> _refresh() async {
    final model = context.read<TorrentsModel>();
    await model.fetchTorrents();
    await AnalyticsService.instance.load();
    if (mounted) setState(() {});
  }

  Future<void> _clearHistory() async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.clearHistory),
        content: Text(l10n.clearHistoryConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.clear),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await AnalyticsService.instance.clearHistory();
    if (mounted) setState(() {});
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.historyCleared)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    // Rebuild when torrent/analytics data changes so charts stay live.
    final _ = context.watch<TorrentsModel>();
    final history = AnalyticsService.instance.getLastDays(_days);

    return Scaffold(
      appBar: isDesktop()
          ? const WindowTitleBar()
          : AppBar(
              title: Text(localizations.dataUsageDashboard),
              actions: [
                IconButton(
                  icon: const Icon(Icons.delete_sweep),
                  tooltip: localizations.clearHistory,
                  onPressed: _clearHistory,
                ),
              ],
            ),
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
              : RefreshIndicator.adaptive(
                  onRefresh: _refresh,
                  child: _buildContent(context, history),
                ),
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
          Row(
            children: [
              Expanded(
                child: Text(
                  _days == 7
                      ? localizations.analyticsLast7Days
                      : localizations.analyticsLast30Days,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              SegmentedButton<int>(
                segments: [
                  ButtonSegment(
                    value: 7,
                    label: Text(localizations.analytics7Days),
                  ),
                  ButtonSegment(
                    value: 30,
                    label: Text(localizations.analytics30Days),
                  ),
                ],
                selected: {_days},
                onSelectionChanged: (selected) {
                  setState(() => _days = selected.first);
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildSummaryCards(context, history),
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
                          '${prettyBytes(t.downloadedEver.toDouble(), locale: localizations.localeName)}\u2193\n${prettyBytes(t.uploadedEver.toDouble(), locale: localizations.localeName)}\u2191',
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

  Widget _buildSummaryCards(BuildContext context, List<DataUsageSnapshot> history) {
    final localizations = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final totalDown = history.fold<int>(
      0,
      (sum, s) => sum + s.downloadedBytes,
    );
    final totalUp = history.fold<int>(
      0,
      (sum, s) => sum + s.uploadedBytes,
    );

    return Row(
      children: [
        Expanded(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    localizations.analyticsDownloaded,
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    prettyBytes(
                      totalDown.toDouble(),
                      locale: localizations.localeName,
                    ),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    localizations.analyticsUploaded,
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    prettyBytes(
                      totalUp.toDouble(),
                      locale: localizations.localeName,
                    ),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: colorScheme.secondary,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
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

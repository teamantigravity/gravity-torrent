import 'package:flutter/material.dart';
import 'package:gravity_torrent/services/analytics_service.dart';
import 'package:gravity_torrent/services/quota_service.dart';
import 'package:gravity_torrent/utils/device.dart';
import 'package:gravity_torrent/widgets/window_title_bar.dart';
import 'package:pretty_bytes/pretty_bytes.dart';

class QuotaScreen extends StatefulWidget {
  const QuotaScreen({super.key});

  @override
  State<QuotaScreen> createState() => _QuotaScreenState();
}

class _QuotaScreenState extends State<QuotaScreen> {
  bool _loaded = false;

  /// Quota in GiB (float for the slider)
  double _quotaGb = 100;

  static const double _minGb = 1;
  static const double _maxGb = 2000;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await QuotaService.instance.load();
    await AnalyticsService.instance.load();
    if (mounted) {
      setState(() {
        _quotaGb = (QuotaService.instance.quotaBytes / (1024 * 1024 * 1024))
            .clamp(_minGb, _maxGb);
        _loaded = true;
      });
    }
  }

  Future<void> _save() async {
    final bytes = (_quotaGb * 1024 * 1024 * 1024).round();
    await QuotaService.instance.setQuota(bytes);
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Quota saved')));
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: isDesktop()
          ? const WindowTitleBar()
          : AppBar(title: const Text('Bandwidth quota')),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Monthly bandwidth quota',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Set a monthly data cap. You will receive a warning when '
                    '80 % of the quota is reached. All tracking is local — '
                    'no data leaves your device.',
                  ),
                  const SizedBox(height: 24),
                  _buildUsageCard(colorScheme),
                  const SizedBox(height: 24),
                  Text(
                    'Monthly cap',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Slider(
                          value: _quotaGb,
                          min: _minGb,
                          max: _maxGb,
                          divisions: 399,
                          label: '${_quotaGb.round()} GB',
                          onChanged: (v) => setState(() => _quotaGb = v),
                        ),
                      ),
                      SizedBox(
                        width: 72,
                        child: Text(
                          '${_quotaGb.round()} GB',
                          textAlign: TextAlign.end,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${_minGb.round()} GB',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      Text(
                        '${_maxGb.round()} GB',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _save,
                      icon: const Icon(Icons.save),
                      label: const Text('Save quota'),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildMonthlyBreakdown(colorScheme),
                ],
              ),
            ),
    );
  }

  Widget _buildUsageCard(ColorScheme colorScheme) {
    final usedBytes = QuotaService.instance.usedThisMonth();
    final quotaBytes = QuotaService.instance.quotaBytes;
    final ratio = QuotaService.instance.usageRatio().clamp(0.0, 1.0);
    final status = QuotaService.instance.status;

    final Color statusColor = switch (status) {
      QuotaStatus.exceeded => colorScheme.error,
      QuotaStatus.warning => Colors.orange,
      QuotaStatus.ok => colorScheme.primary,
    };

    final String statusLabel = switch (status) {
      QuotaStatus.exceeded => 'Quota exceeded',
      QuotaStatus.warning => 'Approaching limit',
      QuotaStatus.ok => 'Within limit',
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.data_saver_on, color: statusColor),
                const SizedBox(width: 8),
                Text(
                  statusLabel,
                  style: Theme.of(
                    context,
                  ).textTheme.titleMedium?.copyWith(color: statusColor),
                ),
                const Spacer(),
                Text(
                  '${prettyBytes(usedBytes.toDouble(), locale: 'en')} / '
                  '${prettyBytes(quotaBytes.toDouble(), locale: 'en')}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: ratio,
                minHeight: 12,
                color: statusColor,
                backgroundColor: colorScheme.surfaceContainerHighest,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${(ratio * 100).toStringAsFixed(1)} % used this month',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthlyBreakdown(ColorScheme colorScheme) {
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    final days = AnalyticsService.instance.history
        .where((s) => !s.day.isBefore(monthStart))
        .toList();

    if (days.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'This month — day by day',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        ...days.map(
          (s) => ListTile(
            dense: true,
            leading: const Icon(Icons.calendar_today, size: 16),
            title: Text('${s.day.day}/${s.day.month}/${s.day.year}'),
            trailing: Text(
              '↓ ${prettyBytes(s.downloadedBytes.toDouble(), locale: 'en')} '
              '↑ ${prettyBytes(s.uploadedBytes.toDouble(), locale: 'en')}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ),
      ],
    );
  }
}

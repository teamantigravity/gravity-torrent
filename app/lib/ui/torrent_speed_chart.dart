import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

/// Compact sparkline chart that displays a torrent's recent download speed
/// history. Renders a filled line chart using [fl_chart].
class TorrentSpeedChart extends StatelessWidget {
  /// Speed readings in bytes/sec, oldest first. Empty list shows a flat line.
  final List<double> speeds;

  /// Chart height in logical pixels.
  final double height;

  const TorrentSpeedChart({
    super.key,
    required this.speeds,
    this.height = 80,
  });

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    final spots = _buildSpots();

    return SizedBox(
      height: height,
      child: LineChart(
        LineChartData(
          gridData: const FlGridData(show: false),
          titlesData: const FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
          lineTouchData: const LineTouchData(enabled: false),
          minX: 0,
          maxX: (spots.length - 1).toDouble().clamp(1, double.infinity),
          minY: 0,
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: color,
              barWidth: 2,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  colors: [
                    color.withAlpha(77),
                    color.withAlpha(0),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ],
        ),
        duration: const Duration(milliseconds: 250),
      ),
    );
  }

  List<FlSpot> _buildSpots() {
    if (speeds.isEmpty) {
      return [const FlSpot(0, 0), const FlSpot(1, 0)];
    }
    return List.generate(
      speeds.length,
      (i) => FlSpot(i.toDouble(), speeds[i]),
    );
  }
}

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:gravity_torrent/models/app.dart';
import 'package:gravity_torrent/models/feature_flags.dart';
import 'package:provider/provider.dart';

class AnalyticsOptInDialog extends StatelessWidget {
  const AnalyticsOptInDialog({super.key});

  void _handleRefuseClick(BuildContext context) {
    Provider.of<AppModel>(context, listen: false).setAnalyticsOptInDisplayed(true);
    unawaited(Provider.of<FeatureFlagsModel>(context, listen: false).setEnableAnalytics(false));
    Navigator.of(context).pop();
  }

  void _handleAcceptClick(BuildContext context) {
    Provider.of<AppModel>(context, listen: false).setAnalyticsOptInDisplayed(true);
    unawaited(Provider.of<FeatureFlagsModel>(context, listen: false).setEnableAnalytics(true));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Local data usage dashboard'),
      content: const Text(
        'Gravity Torrent can show a data usage dashboard with download and upload totals. '
        'This information is stored on your device only and is not uploaded or shared. '
        'You can change this later in Settings.',
      ),
      actions: [
        TextButton(
          onPressed: () => _handleRefuseClick(context), 
          child: const Text('Not now')
        ),
        FilledButton(
          onPressed: () => _handleAcceptClick(context),
          child: const Text('Enable'),
        ),
      ],
    );
  }
}

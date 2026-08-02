import 'package:flutter/material.dart';
import 'package:gravity_torrent/l10n/app_localizations.dart';

/// A local, on-device dialog shown once after the app is updated to a new
/// version. It does not fetch any remote content and keeps data fully local.
class WhatsNewDialog extends StatelessWidget {
  final String version;

  const WhatsNewDialog({super.key, required this.version});

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);

    return AlertDialog(
      title: Text('${localizations.whatsNew} -- $version'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: localizations.whatsNewBody
              .split('\n')
              .where((line) => line.trim().isNotEmpty)
              .map(
                (line) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('• ', style: TextStyle(fontSize: 16)),
                      Expanded(child: Text(line.trim())),
                    ],
                  ),
                ),
              )
              .toList(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(localizations.whatsNewGotIt),
        ),
      ],
    );
  }
}

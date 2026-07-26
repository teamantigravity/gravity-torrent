import 'package:flutter/material.dart';
import 'package:gravity_torrent/l10n/app_localizations.dart';
import 'package:url_launcher/url_launcher.dart';

final Uri url = Uri.parse(
  'https://github.com/teamantigravity/gravity-torrent/releases',
);

class UpdateAvailableDialog extends StatelessWidget {
  final String latestVersion;

  const UpdateAvailableDialog({super.key, required this.latestVersion});

  void _handleIgnoreClick(BuildContext context) {
    if (!context.mounted) return;
    Navigator.pop(context);
  }

  Future<void> _handleDownloadClick(BuildContext context) async {
    final result = await launchUrl(url, mode: LaunchMode.externalApplication);
    if (!context.mounted) return;
    if (!result) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).couldNotOpenReleasePage),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Update available'),
      content: Text('A new version is available: $latestVersion'),
      actions: [
        TextButton(
          onPressed: () => _handleIgnoreClick(context),
          child: const Text('Ignore'),
        ),
        TextButton(
          onPressed: () => _handleDownloadClick(context),
          child: const Text('Download'),
        ),
      ],
    );
  }
}

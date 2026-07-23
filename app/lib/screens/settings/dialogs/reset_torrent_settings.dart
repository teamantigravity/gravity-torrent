import 'package:flutter/material.dart';
import 'package:gravity_torrent/l10n/app_localizations.dart';

class ResetTorrentsSettingsDialog extends StatelessWidget {
  final void Function() onOK;

  const ResetTorrentsSettingsDialog({super.key, required this.onOK});

  void handleOK() {
    onOK();
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return AlertDialog(
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[Text(localizations.resetTorrentsSettingsWarning)],
      ),
      actions: <Widget>[
        TextButton(
          child: Text(localizations.cancel),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
        TextButton(
          child: Text(localizations.reset),
          onPressed: () {
            Navigator.of(context).pop();
            handleOK();
          },
        ),
      ],
    );
  }
}

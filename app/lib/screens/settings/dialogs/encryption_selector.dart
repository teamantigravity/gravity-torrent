// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:gravity_torrent/engine/session.dart';
import 'package:gravity_torrent/l10n/app_localizations.dart';

/// Lets the user choose the peer protocol encryption preference.
class EncryptionSelector extends StatelessWidget {
  final EncryptionMode currentValue;
  final ValueChanged<EncryptionMode> onChanged;

  const EncryptionSelector(
      {super.key, required this.currentValue, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        RadioListTile<EncryptionMode>(
            title: Text(localizations.encryptionPreferred),
            subtitle: Text(localizations.encryptionPreferredDescription),
            value: EncryptionMode.preferred,
            groupValue: currentValue,
            onChanged: _handle),
        RadioListTile<EncryptionMode>(
            title: Text(localizations.encryptionRequired),
            subtitle: Text(localizations.encryptionRequiredDescription),
            value: EncryptionMode.required,
            groupValue: currentValue,
            onChanged: _handle),
        RadioListTile<EncryptionMode>(
            title: Text(localizations.encryptionTolerated),
            subtitle: Text(localizations.encryptionToleratedDescription),
            value: EncryptionMode.tolerated,
            groupValue: currentValue,
            onChanged: _handle),
      ],
    );
  }

  void _handle(EncryptionMode? value) {
    if (value == null) return;
    onChanged(value);
  }
}

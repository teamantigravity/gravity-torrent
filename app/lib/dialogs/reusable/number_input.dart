import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gravity_torrent/l10n/app_localizations.dart';

class NumberInputDialog extends StatefulWidget {
  final void Function(int) onSave;
  final int currentValue;
  final String title;

  const NumberInputDialog({
    super.key,
    required this.onSave,
    required this.currentValue,
    required this.title,
  });

  @override
  State<NumberInputDialog> createState() => _NumberInputDialogState();
}

class _NumberInputDialogState extends State<NumberInputDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController number;

  @override
  void initState() {
    super.initState();
    number = TextEditingController.fromValue(
      TextEditingValue(text: widget.currentValue.toString()),
    );
  }

  @override
  void dispose() {
    number.dispose();
    super.dispose();
  }

  void handleSave() {
    if (_formKey.currentState?.validate() != true) return;
    final parsed = int.tryParse(number.text);
    if (parsed == null) return;
    Navigator.of(context).pop();
    widget.onSave(parsed);
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);

    return AlertDialog(
      title: Text(widget.title),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            TextFormField(
              controller: number,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(labelText: localizations.enterNumber),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return localizations.emptyNumber;
                }
                if (int.tryParse(value) == null) {
                  return localizations.invalidNumber;
                }
                return null;
              },
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          child: Text(localizations.cancel),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
        TextButton(
          onPressed: handleSave,
          child: Text(localizations.save),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gravity_torrent/l10n/app_localizations.dart';

/// Dialog to edit the global seed ratio limit (a decimal value).
class RatioInputDialog extends StatefulWidget {
  final void Function(double) onSave;
  final double currentValue;

  const RatioInputDialog({
    super.key,
    required this.onSave,
    required this.currentValue,
  });

  @override
  State<RatioInputDialog> createState() => _RatioInputDialogState();
}

class _RatioInputDialogState extends State<RatioInputDialog> {
  late TextEditingController _controller;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.currentValue > 0 ? widget.currentValue.toString() : '2.0',
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(localizations.seedRatioLimit),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            TextFormField(
              controller: _controller,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*$')),
              ],
              decoration: InputDecoration(labelText: localizations.ratio),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return localizations.emptyNumber;
                }
                final parsed = double.tryParse(value);
                if (parsed == null || parsed <= 0) {
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
          onPressed: () => Navigator.of(context).pop(),
        ),
        TextButton(
          child: Text(localizations.save),
          onPressed: () {
            if (_formKey.currentState?.validate() != true) return;
            Navigator.of(context).pop();
            widget.onSave(double.parse(_controller.text));
          },
        ),
      ],
    );
  }
}

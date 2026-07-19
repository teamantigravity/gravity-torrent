import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
  late TextEditingController number;

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
              decoration: const InputDecoration(labelText: 'Enter a number'),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a number';
                }
                if (int.tryParse(value) == null) {
                  return 'Please enter a valid number';
                }
                return null; // Return null if the input is valid
              },
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          child: const Text('Cancel'),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
        TextButton(onPressed: handleSave, child: const Text('Save')),
      ],
    );
  }
}

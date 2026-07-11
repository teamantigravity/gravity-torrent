import 'package:flutter/material.dart';
import 'package:gravity_torrent/l10n/app_localizations.dart';

/// Dialog to edit the peer blocklist URL (a P2P range list such as a
/// gzip-compressed `.p2p` list). An empty value clears the URL.
class BlocklistUrlDialog extends StatefulWidget {
  final void Function(String) onSave;
  final String currentValue;

  const BlocklistUrlDialog(
      {super.key, required this.onSave, required this.currentValue});

  @override
  State<BlocklistUrlDialog> createState() => _BlocklistUrlDialogState();
}

class _BlocklistUrlDialogState extends State<BlocklistUrlDialog> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.currentValue);
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
      title: Text(localizations.blocklistUrl),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          TextFormField(
            controller: _controller,
            keyboardType: TextInputType.url,
            autocorrect: false,
            decoration: const InputDecoration(
              hintText: 'https://example.com/blocklist.gz',
            ),
          ),
          const SizedBox(height: 8),
          Text(localizations.blocklistUrlDescription,
              style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
      actions: <Widget>[
        TextButton(
          child: Text(localizations.cancel),
          onPressed: () => Navigator.of(context).pop(),
        ),
        TextButton(
          child: Text(localizations.save),
          onPressed: () {
            Navigator.of(context).pop();
            widget.onSave(_controller.text.trim());
          },
        ),
      ],
    );
  }
}

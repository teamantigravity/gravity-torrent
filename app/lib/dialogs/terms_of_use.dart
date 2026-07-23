import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gravity_torrent/models/app.dart';
import 'package:provider/provider.dart';

class TermsOfUseDialog extends StatefulWidget {
  const TermsOfUseDialog({super.key});

  @override
  State<TermsOfUseDialog> createState() => _TermsOfUseDialogState();
}

class _TermsOfUseDialogState extends State<TermsOfUseDialog> {
  bool _is18 = false;
  bool _willNotPirate = false;

  void _handleRefuseClick() {
    SystemNavigator.pop();
  }

  void _handleAcceptClick() {
    Provider.of<AppModel>(context, listen: false).setTermsOfUseAccepted(true);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Terms of use'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'By using Gravity Torrent, you accept that the content you download or share is your sole responsibility.',
          ),
          const SizedBox(height: 16),
          CheckboxListTile(
            title: const Text('I am 18 years of age or older.'),
            value: _is18,
            onChanged: (val) {
              setState(() {
                _is18 = val ?? false;
              });
            },
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
          ),
          CheckboxListTile(
            title: const Text('I agree not to use this app for downloading or sharing illegal or copyrighted material.'),
            value: _willNotPirate,
            onChanged: (val) {
              setState(() {
                _willNotPirate = val ?? false;
              });
            },
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: _handleRefuseClick, child: const Text('Refuse')),
        TextButton(
          onPressed: (_is18 && _willNotPirate) ? _handleAcceptClick : null,
          child: const Text('Accept'),
        ),
      ],
    );
  }
}

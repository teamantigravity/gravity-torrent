import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gravity_torrent/l10n/app_localizations.dart';
import 'package:gravity_torrent/models/app.dart';
import 'package:provider/provider.dart';

class TermsOfUseDialog extends StatefulWidget {
  const TermsOfUseDialog({super.key});

  @override
  State<TermsOfUseDialog> createState() => _TermsOfUseDialogState();
}

class _TermsOfUseDialogState extends State<TermsOfUseDialog> {
  Future<void> _handleRefuseClick() async {
    final localizations = AppLocalizations.of(context);
    final shouldExit = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(localizations.confirmExit),
        content: Text(localizations.refuseTermsExitWarning),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(localizations.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(localizations.exit),
          ),
        ],
      ),
    );
    if (shouldExit == true) {
      await SystemNavigator.pop();
    }
  }

  void _handleAcceptClick() {
    Provider.of<AppModel>(context, listen: false).setTermsOfUseAccepted(true);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);

    return AlertDialog(
      title: Text(localizations.termsOfUse),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Statement(localizations.iAmOver18),
            _Statement(localizations.willNotPirate),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => unawaited(_handleRefuseClick()),
          child: Text(localizations.refuse),
        ),
        TextButton(
          onPressed: _handleAcceptClick,
          child: Text(localizations.accept),
        ),
      ],
    );
  }
}

class _Statement extends StatelessWidget {
  final String text;

  const _Statement(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.check,
            size: 18,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

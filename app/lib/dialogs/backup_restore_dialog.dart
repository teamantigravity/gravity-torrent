import 'package:flutter/material.dart';
import 'package:gravity_torrent/l10n/app_localizations.dart';
import 'package:gravity_torrent/services/backup_service.dart';

class BackupRestoreDialog extends StatefulWidget {
  const BackupRestoreDialog({super.key});

  @override
  State<BackupRestoreDialog> createState() => _BackupRestoreDialogState();
}

class _BackupRestoreDialogState extends State<BackupRestoreDialog> {
  final _passphraseCtrl = TextEditingController();
  bool _useEncryption = false;
  bool _working = false;
  BackupRestoreResult? _result;
  bool _obscure = true;

  @override
  void dispose() {
    _passphraseCtrl.dispose();
    super.dispose();
  }

  Future<void> _export() async {
    setState(() {
      _working = true;
      _result = null;
    });

    final result = await BackupService.export(
      passphrase: _useEncryption ? _passphraseCtrl.text : null,
    );

    if (mounted) {
      setState(() {
        _working = false;
        _result = result;
      });

      if (result.success) {
        final share = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(AppLocalizations.of(ctx).backupCreated),
            content: Text(AppLocalizations.of(ctx).shareBackupPrompt),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(AppLocalizations.of(ctx).no),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(AppLocalizations.of(ctx).share),
              ),
            ],
          ),
        );
        if (share == true) {
          await BackupService.shareBackup(result);
        }
      }
    }
  }

  Future<void> _import() async {
    setState(() {
      _working = true;
      _result = null;
    });

    final result = await BackupService.import(
      passphrase: _useEncryption ? _passphraseCtrl.text : null,
    );

    if (mounted) {
      setState(() {
        _working = false;
        _result = result;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l.backupRestore),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l.backupDescription,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),

              // Encryption toggle
              SwitchListTile.adaptive(
                title: Text(l.encryptBackup),
                subtitle: Text(l.encryptBackupSubtitle),
                value: _useEncryption,
                onChanged:
                    _working ? null : (v) => setState(() => _useEncryption = v),
                contentPadding: EdgeInsets.zero,
              ),

              // Passphrase field
              if (_useEncryption) ...[
                const SizedBox(height: 8),
                TextField(
                  controller: _passphraseCtrl,
                  decoration: InputDecoration(
                    labelText: l.passphrase,
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      tooltip: _obscure ? 'Show passphrase' : 'Hide passphrase',
                      icon: Icon(
                        _obscure ? Icons.visibility_off : Icons.visibility,
                      ),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                  obscureText: _obscure,
                  enabled: !_working,
                ),
              ],

              const SizedBox(height: 16),

              // Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.upload_file),
                      label: Text(l.exportBackup),
                      onPressed: _working ? null : _export,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.download),
                      label: Text(l.importBackup),
                      onPressed: _working ? null : _import,
                    ),
                  ),
                ],
              ),

              if (_working) ...[
                const SizedBox(height: 16),
                const LinearProgressIndicator(),
              ],

              // Result
              if (_result != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _result!.success
                        ? Theme.of(context).colorScheme.primaryContainer
                        : Theme.of(context).colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _result!.success ? Icons.check_circle : Icons.error,
                        color: _result!.success
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.error,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(_result!.message),
                      ),
                    ],
                  ),
                ),
                if (_result!.metadata != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'App version: ${_result!.metadata!.appVersion}\n'
                    'Created: ${_result!.metadata!.createdAt.toLocal()}\n'
                    'Platform: ${_result!.metadata!.platform}\n'
                    'Settings: ${_result!.metadata!.settingsCount}\n'
                    'Torrents: ${_result!.metadata!.torrentCount}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
      actions: [
        FilledButton(
          onPressed: _working ? null : () => Navigator.of(context).pop(),
          child: Text(l.close),
        ),
      ],
    );
  }
}

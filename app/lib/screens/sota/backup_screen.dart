import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:gravity_torrent/services/backup_service.dart';
import 'package:gravity_torrent/widgets/window_title_bar.dart';
import 'package:gravity_torrent/utils/device.dart';
import 'package:gravity_torrent/l10n/app_localizations.dart';

/// Screen for exporting and importing Gravity Torrent settings.
class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  bool _busy = false;
  String? _statusMessage;
  bool _isError = false;

  Future<void> _export() async {
    setState(() {
      _busy = true;
      _statusMessage = null;
    });
    try {
      await BackupService.instance.export();
      if (mounted) {
        setState(() {
          _statusMessage = 'Settings exported successfully.';
          _isError = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _statusMessage = 'Export failed: $e';
          _isError = true;
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _import() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      dialogTitle: 'Select backup file',
    );
    if (result == null || result.files.single.path == null) return;
    final path = result.files.single.path!;

    // Confirm dialog
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.warning_amber_rounded),
        title: const Text('Import settings?'),
        content: const Text(
          'This will overwrite all current settings with the backup. '
          'The app will need to be restarted for all changes to take effect.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(AppLocalizations.of(context)!.importAction),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() {
      _busy = true;
      _statusMessage = null;
    });
    try {
      final restored = await BackupService.instance.import(path);
      if (mounted) {
        setState(() {
          _statusMessage =
              'Restored ${restored.length} settings. Restart the app to apply all changes.';
          _isError = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _statusMessage = 'Import failed: $e';
          _isError = true;
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: isDesktop()
          ? const WindowTitleBar()
          : AppBar(title: Text(localizations.backupAndRestore)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Backup & Restore',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            const Text(
              'Export your settings and preferences to a file so you can '
              'restore them on a new device or after reinstalling.',
            ),
            const SizedBox(height: 32),
            // Export card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.upload, color: colorScheme.primary),
                        const SizedBox(width: 12),
                        Text(
                          'Export settings',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Saves all toggles, schedule, quota, RSS feeds, '
                      'and other preferences to a JSON file.',
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      icon: const Icon(Icons.save_alt),
                      label: Text(localizations.export),
                      onPressed: _busy ? null : _export,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Import card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.download, color: colorScheme.secondary),
                        const SizedBox(width: 12),
                        Text(
                          'Import settings',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Pick a previously exported backup file. '
                      'All current settings will be replaced.',
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: colorScheme.errorContainer.withAlpha(80),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.warning_amber_rounded,
                            size: 16,
                            color: colorScheme.error,
                          ),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'This overwrites all current settings.',
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.folder_open),
                      label: Text(localizations.pickBackupFile),
                      onPressed: _busy ? null : _import,
                    ),
                  ],
                ),
              ),
            ),
            if (_busy) ...[
              const SizedBox(height: 24),
              const Center(child: CircularProgressIndicator()),
            ],
            if (_statusMessage != null) ...[
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _isError
                      ? colorScheme.errorContainer
                      : colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      _isError ? Icons.error : Icons.check_circle,
                      color: _isError ? colorScheme.error : colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_statusMessage!)),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 32),
            Text(
              'What is included in the backup',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            const _IncludedItem(
                icon: Icons.toggle_on,
                label:
                    'Feature toggles (WiFi-only, scheduler, quota, RSS, etc.)'),
            const _IncludedItem(
                icon: Icons.schedule, label: 'Download schedule windows'),
            const _IncludedItem(
                icon: Icons.data_saver_on,
                label: 'Monthly bandwidth quota settings'),
            const _IncludedItem(icon: Icons.rss_feed, label: 'RSS feed URLs'),
            const _IncludedItem(
                icon: Icons.palette, label: 'Theme and language preferences'),
            const SizedBox(height: 8),
            Text(
              'Not included: torrent files, downloaded content, or PIN codes.',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: colorScheme.outline),
            ),
          ],
        ),
      ),
    );
  }
}

class _IncludedItem extends StatelessWidget {
  final IconData icon;
  final String label;
  const _IncludedItem({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Theme.of(context).colorScheme.outline),
          const SizedBox(width: 8),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }
}

import 'dart:convert';
import 'dart:io';

import 'package:content_resolver/content_resolver.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gravity_torrent/engine/engine.dart';
import 'package:gravity_torrent/l10n/app_localizations.dart';
import 'package:gravity_torrent/models/session.dart';
import 'package:gravity_torrent/models/torrents.dart';
import 'package:gravity_torrent/services/recent_download_directories_service.dart';
import 'package:gravity_torrent/utils/app_links.dart';
import 'package:gravity_torrent/utils/device.dart';
import 'package:provider/provider.dart';
import 'package:gravity_torrent/services/ads/ad_service_provider.dart';
import 'package:path_provider/path_provider.dart';

class AddTorrentDialog extends StatefulWidget {
  final String? initialMagnetLink;
  final String? initialContentPath;

  const AddTorrentDialog({
    super.key,
    this.initialMagnetLink,
    this.initialContentPath,
  });

  @override
  State<AddTorrentDialog> createState() => _AddTorrentDialogState();
}

class _AddTorrentDialogState extends State<AddTorrentDialog> {
  late TextEditingController _torrentLinkController;
  String? _filename;
  String? pickedDownloadDir;
  String _torrentLink = ''; // Track a state to trigger updates
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _torrentLinkController = TextEditingController();

    _torrentLinkController.addListener(() {
      setState(() {
        _torrentLink = _torrentLinkController.text;
      });
    });

    if (widget.initialMagnetLink != null) {
      _torrentLinkController.text = widget.initialMagnetLink!;
    }

    setState(() {
      _filename = widget.initialContentPath;
    });
  }

  @override
  void dispose() {
    _torrentLinkController.dispose();
    super.dispose();
  }

  void _handleAddTorrent(context) async {
    try {
      String? metainfo;
      if (_filename != null) {
        // From a .torrent file
        if (_filename!.startsWith('content:')) {
          // Android
          final Content content = await ContentResolver.resolveContent(
            _filename!,
          );
          metainfo = base64Encode(content.data);
        } else {
          final file = File(_filename!);
          final content = await file.readAsBytes();
          metainfo = base64Encode(content);
        }

        if (metainfo.isEmpty) {
          throw TorrentAddError();
        }
      }

      String? magnet;
      if (_filename == null) {
        // From a link (either app link or magnet)
        magnet = isAppLink(_torrentLinkController.text)
            ? getTorrentLink(_torrentLinkController.text)
            : _torrentLinkController.text;
        if (magnet == null || magnet.isEmpty) {
          throw TorrentAddError();
        }
      }

      String? downloadDirToCheck = pickedDownloadDir ??
          Provider.of<SessionModel>(context, listen: false)
              .session
              ?.downloadDir;
      if (downloadDirToCheck == null || downloadDirToCheck.isEmpty) {
        try {
          final dir = await getApplicationDocumentsDirectory();
          downloadDirToCheck = dir.path;
        } catch (_) {}
      }

      int freeSpace = 0;
      if (downloadDirToCheck != null) {
        try {
          if (Platform.isWindows && downloadDirToCheck.length >= 2) {
            final drive = downloadDirToCheck.substring(0, 2);
            final result = await Process.run('wmic', [
              'logicaldisk',
              'where',
              'deviceid="$drive"',
              'get',
              'freespace'
            ]);
            final lines = result.stdout.toString().split('\n');
            if (lines.length > 1) {
              freeSpace = int.tryParse(lines[1].trim()) ?? 0;
            }
          } else if (Platform.isLinux || Platform.isMacOS) {
            final result = await Process.run('df', ['-k', downloadDirToCheck]);
            final lines = result.stdout.toString().split('\n');
            if (lines.length > 1) {
              final parts = lines[1].trim().split(RegExp(r'\s+'));
              if (parts.length > 3) {
                freeSpace = (int.tryParse(parts[3]) ?? 0) * 1024;
              }
            }
          }
        } catch (_) {}
      }

      int predictedSize = 500 * 1024 * 1024; // Fallback dummy size
      if (metainfo != null) {
        predictedSize = metainfo.length * 1000;
      }

      if (freeSpace > 0 && freeSpace < predictedSize) {
        final proceed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Low Storage Warning'),
            content: const Text(
                'Free space may be insufficient for this torrent. Proceed anyway?'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel')),
              TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Proceed')),
            ],
          ),
        );
        if (proceed != true) return;
      }

      if (!mounted) return;
      final localizations = AppLocalizations.of(context)!;
      final status = await Provider.of<TorrentsModel>(
        context,
        listen: false,
      ).addTorrent(magnet, metainfo, pickedDownloadDir);

      if (pickedDownloadDir?.isNotEmpty == true) {
        await RecentDownloadDirectoriesService.instance.add(pickedDownloadDir!);
      }

      if (!mounted) return;

      if (status == TorrentAddedResponse.duplicated) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(localizations.torrentAlreadyAdded),
            backgroundColor: Colors.lightGreen,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(localizations.torrentAdded),
            backgroundColor: Colors.lightGreen,
          ),
        );
        // Show an interstitial ad occasionally when a torrent is added successfully
        AdServiceProvider.instance.showInterstitialIfReady();
      }
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      final localizations = AppLocalizations.of(context)!;
      final message =
          (e is TorrentAddError && e.message != null && e.message!.isNotEmpty)
              ? e.message!
              : localizations.invalidTorrent;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.orange),
      );
    }
  }

  void _handleSelectTorrentFile(context) async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['torrent'],
    );
    if (file?.path == null) return;

    if (!mounted) return;
    setState(() {
      _filename = file!.path;
    });
  }

  void _handlePickDirectory() async {
    final localizations = AppLocalizations.of(context)!;
    String? selectedDirectory = await FilePicker.getDirectoryPath(
      dialogTitle: localizations.downloadDirectoryPickerTitle,
    );

    if (selectedDirectory == null) return;
    await RecentDownloadDirectoriesService.instance.add(selectedDirectory);
    if (!mounted) return;
    setState(() {
      pickedDownloadDir = selectedDirectory;
    });
  }

  Future<void> _handlePasteFromClipboard() async {
    final localizations = AppLocalizations.of(context)!;
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final text = data?.text;
      if (text == null || text.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(localizations.clipboardEmpty),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
      _torrentLinkController.text = text.trim();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(localizations.clipboardEmpty),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  Widget _buildRecentDirectoriesChipRow() {
    final localizations = AppLocalizations.of(context)!;
    final recentDirs = RecentDownloadDirectoriesService.instance.directories;

    if (recentDirs.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(localizations.recentDownloadDirectories),
        const SizedBox(height: 4),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: recentDirs.map((dir) {
            return ActionChip(
              label: Text(
                dir,
                overflow: TextOverflow.ellipsis,
              ),
              onPressed: () {
                setState(() {
                  pickedDownloadDir = dir;
                });
              },
              visualDensity: VisualDensity.compact,
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildTorrentLinkInput() {
    final localizations = AppLocalizations.of(context)!;
    return TextFormField(
      enabled: _filename == null || _filename!.isEmpty,
      controller: _torrentLinkController,
      decoration: InputDecoration(
        prefixIcon: const Icon(Icons.link),
        hintText: localizations.torrentLinkHint,
        label: Text(localizations.torrentLinkLabel),
        suffixIcon: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: localizations.pasteTorrentLink,
              onPressed: _handlePasteFromClipboard,
              icon: const Icon(Icons.paste),
            ),
            if (_torrentLinkController.text.isNotEmpty)
              IconButton(
                onPressed: () => _torrentLinkController.clear(),
                icon: const Icon(Icons.clear),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFileInput(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    return Row(
      children: [
        Expanded(
          child: FilledButton(
            onPressed: _torrentLink.isEmpty
                ? () => _handleSelectTorrentFile(context)
                : null,
            child: Text(
              _filename != null ? _filename! : localizations.selectTorrentFile,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        if (_filename != null)
          Row(
            children: [
              const SizedBox(width: 8),
              IconButton(
                onPressed: () {
                  setState(() {
                    _filename = null;
                  });
                },
                icon: const Icon(Icons.clear),
              ),
            ],
          ),
      ],
    );
  }

  _buildInputsSeparator() {
    final localizations = AppLocalizations.of(context)!;
    return Column(
      children: [
        const SizedBox(height: 16),
        Text(localizations.addTorrentOr),
        const SizedBox(height: 16),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    var downloadDir = pickedDownloadDir ??
        Provider.of<SessionModel>(context, listen: true).session?.downloadDir ??
        '';

    final String? decodedLink =
        isAppLink(_torrentLink) ? getTorrentLink(_torrentLink) : null;
    final String? link = isAppLink(_torrentLink) ? decodedLink : _torrentLink;
    final effectiveLink = _filename ?? link;
    var isValid = effectiveLink != null && effectiveLink.isNotEmpty;

    return AlertDialog(
      title: Text(localizations.addTorrentTitle),
      content: SizedBox(
        width: 480,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildTorrentLinkInput(),
              _buildInputsSeparator(),
              _buildFileInput(context),
              if (!isMobile()) const SizedBox(height: 16),
              if (!isMobile())
                Row(
                  children: [
                    Text(localizations.addTorrentDestination),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextButton(
                        onPressed: _handlePickDirectory,
                        child: Text(
                          downloadDir,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ),
              if (!isMobile()) const SizedBox(height: 8),
              if (!isMobile()) _buildRecentDirectoriesChipRow(),
            ],
          ),
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
          onPressed: isValid
              ? () {
                  if (_formKey.currentState!.validate()) {
                    _handleAddTorrent(context);
                  }
                }
              : null,
          child: Text(localizations.download),
        ),
      ],
    );
  }
}

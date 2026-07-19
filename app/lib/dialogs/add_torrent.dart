import 'dart:convert';
import 'dart:io';

import 'package:content_resolver/content_resolver.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:gravity_torrent/engine/engine.dart';
import 'package:gravity_torrent/l10n/app_localizations.dart';
import 'package:gravity_torrent/models/session.dart';
import 'package:gravity_torrent/models/torrents.dart';
import 'package:gravity_torrent/utils/app_links.dart';
import 'package:gravity_torrent/utils/device.dart';
import 'package:provider/provider.dart';
import 'package:gravity_torrent/services/ads/ad_service_provider.dart';

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

      final localizations = AppLocalizations.of(context)!;
      final status = await Provider.of<TorrentsModel>(
        context,
        listen: false,
      ).addTorrent(magnet, metainfo, pickedDownloadDir);

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

    if (!mounted) return;
    Navigator.of(context).pop();
  }

  void _handleSelectTorrentFile(context) async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['torrent'],
    );
    if (file?.path == null) return;

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
    setState(() {
      pickedDownloadDir = selectedDirectory;
    });
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
        suffixIcon: _torrentLinkController.text.isNotEmpty
            ? IconButton(
                onPressed: () => _torrentLinkController.clear(),
                icon: const Icon(Icons.clear),
              )
            : null,
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

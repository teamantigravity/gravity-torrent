import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:gravity_torrent/engine/file.dart';
import 'package:gravity_torrent/engine/torrent.dart';
import 'package:gravity_torrent/l10n/app_localizations.dart';
import 'package:gravity_torrent/models/torrents.dart';
import 'package:gravity_torrent/widgets/torrent_player/torrent_player.dart';
import 'package:pretty_bytes/pretty_bytes.dart';
import 'package:open_file/open_file.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path/path.dart' as path;
import 'package:provider/provider.dart';
import 'package:mime/mime.dart';

class FilesTab extends StatefulWidget {
  final Torrent torrent;
  final String location;
  final bool showOnlyPlayable;

  const FilesTab({
    super.key,
    required this.torrent,
    required this.location,
    this.showOnlyPlayable = false,
  });

  @override
  State<FilesTab> createState() => _FilesTabState();
}

class _FilesTabState extends State<FilesTab> {
  late bool _showOnlyPlayable;

  @override
  void initState() {
    super.initState();
    _showOnlyPlayable = widget.showOnlyPlayable;
  }

  bool _isFilePlayable(String filename) {
    var mimeType = lookupMimeType(filename);
    return mimeType != null &&
        (mimeType.startsWith('video') || mimeType.startsWith('audio'));
  }

  Future<void> _openFile(String filepath) async {
    try {
      final result = await OpenFile.open(path.join(widget.location, filepath));
      if (!mounted) return;
      if (result.type != ResultType.done) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Could not open file: ${result.message.isNotEmpty ? result.message : 'Unknown error'}',
            ),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not open file: $e'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  _handleWantedChange(BuildContext context, int fileIndex, bool wanted) async {
    await widget.torrent.toggleFileWanted(fileIndex, wanted);
    if (context.mounted) {
      // Refresh torrents
      await Provider.of<TorrentsModel>(context, listen: false).fetchTorrents();
    }
  }

  _handleAllWantedChange(BuildContext context, bool wanted) async {
    await widget.torrent.toggleAllFilesWanted(wanted);
    if (context.mounted) {
      // Refresh torrents
      await Provider.of<TorrentsModel>(context, listen: false).fetchTorrents();
    }
  }

  // See docs/streaming.md
  _handlePlayClick(BuildContext context, File file) {
    String filePath = path.join(widget.location, file.name);

    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
        settings: const RouteSettings(name: 'player'),
        builder: (BuildContext context) {
          return TorrentPlayer(
            filePath: filePath,
            torrent: widget.torrent,
            file: file,
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    var files = widget.torrent.files;

    var displayedFiles = _showOnlyPlayable
        ? files.where((f) => _isFilePlayable(f.name)).toList()
        : files;

    bool areAllFilesWanted = files.every((f) => f.wanted);
    bool areAllFilesSkipped = files.none((f) => f.wanted);
    final globalWantedState = areAllFilesWanted
        ? true
        : areAllFilesSkipped
            ? false
            : null;

    return Column(
      children: [
        if (files.isNotEmpty)
          ListTile(
            leading: const Icon(Icons.play_circle_outlined),
            title: Text(localizations.showOnlyPlayableFiles),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Switch(
                  value: _showOnlyPlayable,
                  onChanged: (value) {
                    setState(() {
                      _showOnlyPlayable = value;
                    });
                  },
                ),
              ],
            ),
          ),
        if (files.isNotEmpty)
          ListTile(
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Checkbox(
                  value: globalWantedState,
                  tristate: true,
                  onChanged: (_) =>
                      _handleAllWantedChange(context, !areAllFilesWanted),
                ),
              ],
            ),
          ),
        Expanded(
          child: ListView.builder(
            itemCount: displayedFiles.length,
            itemBuilder: (context, index) {
              var file = displayedFiles[index];

              final percent = file.length > 0
                  ? (file.bytesCompleted / file.length * 100).floor()
                  : null;

              var completed = file.bytesCompleted == file.length;

              bool isPlayable = _isFilePlayable(file.name);

              // Get the original index in the full files list
              var originalIndex = files.indexOf(file);

              return ListTile(
                leading: Icon(getFileIcon(file.name)),
                title: Text(file.name),
                subtitle: Row(
                  children: [
                    percent == null
                        ? const Text('—')
                        : percent < 100
                            ? Text('${percent.toString()} %')
                            : const Icon(Icons.download_done, size: 16),
                    Text(' • ${prettyBytes(file.length.toDouble())}'),
                  ],
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  spacing: 8,
                  children: [
                    if (isPlayable)
                      IconButton(
                        onPressed: () {
                          _handlePlayClick(context, file);
                        },
                        icon: const Icon(Icons.play_circle_outlined),
                        tooltip: localizations.play,
                      ),
                    if (completed)
                      PopupMenuButton<String>(
                        onSelected: (value) async {
                          final filePath =
                              path.join(widget.location, file.name);
                          if (value == 'open') {
                            await _openFile(file.name);
                          } else if (value == 'share') {
                            // ignore: deprecated_member_use
                            await Share.shareXFiles([XFile(filePath)]);
                          } else if (value == 'play_in_app') {
                            _handlePlayClick(context, file);
                          }
                        },
                        itemBuilder: (context) {
                          return [
                            const PopupMenuItem(
                              value: 'open',
                              child: Text('Open externally'),
                            ),
                            const PopupMenuItem(
                              value: 'share',
                              child: Text('Share'),
                            ),
                            if (lookupMimeType(file.name)
                                    ?.startsWith('video/') ==
                                true)
                              const PopupMenuItem(
                                value: 'play_in_app',
                                child: Text('Play in app'),
                              ),
                          ];
                        },
                      ),
                    Checkbox(
                      value: file.wanted,
                      onChanged: file.bytesCompleted == file.length
                          ? null
                          : (_) => _handleWantedChange(
                                context,
                                originalIndex,
                                !file.wanted,
                              ),
                    ),
                  ],
                ),
                onTap: completed ? () => unawaited(_openFile(file.name)) : null,
              );
            },
          ),
        ),
      ],
    );
  }
}

IconData getFileIcon(String filename) {
  var mimeType = lookupMimeType(filename);

  if (mimeType != null) {
    if (mimeType.startsWith('video')) {
      return Icons.movie;
    }

    if (mimeType.startsWith('image')) {
      return Icons.image;
    }

    if (mimeType.startsWith('audio')) {
      return Icons.audiotrack;
    }
  }

  return Icons.description;
}

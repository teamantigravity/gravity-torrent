import 'package:flutter/material.dart';
import 'package:gravity_torrent/engine/torrent.dart';
import 'package:gravity_torrent/l10n/app_localizations.dart';
import 'package:gravity_torrent/models/torrents.dart';
import 'package:provider/provider.dart';

/// Per-torrent bandwidth and download mode controls.
class TorrentControlsTab extends StatefulWidget {
  const TorrentControlsTab({super.key, required this.torrent});

  final Torrent torrent;

  @override
  State<TorrentControlsTab> createState() => _TorrentControlsTabState();
}

class _TorrentControlsTabState extends State<TorrentControlsTab> {
  late bool _sequential;
  late bool _downLimitEnabled;
  late bool _upLimitEnabled;
  late TextEditingController _downController;
  late TextEditingController _upController;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _syncFromTorrent(widget.torrent);
  }

  @override
  void didUpdateWidget(covariant TorrentControlsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.torrent.id != widget.torrent.id) {
      _syncFromTorrent(widget.torrent);
    }
  }

  void _syncFromTorrent(Torrent torrent) {
    _sequential = torrent.sequentialDownload;
    _downLimitEnabled = torrent.speedLimitDownEnabled;
    _upLimitEnabled = torrent.speedLimitUpEnabled;
    _downController = TextEditingController(
      text: torrent.speedLimitDown > 0 ? '${torrent.speedLimitDown}' : '',
    );
    _upController = TextEditingController(
      text: torrent.speedLimitUp > 0 ? '${torrent.speedLimitUp}' : '',
    );
  }

  @override
  void dispose() {
    _downController.dispose();
    _upController.dispose();
    super.dispose();
  }

  int? _parseLimit(String raw, AppLocalizations l10n) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    final value = int.tryParse(trimmed);
    if (value == null || value < 1) {
      throw FormatException(l10n.invalidNumber);
    }
    return value;
  }

  Future<void> _applySpeedLimits() async {
    final l10n = AppLocalizations.of(context)!;
    try {
      int? down;
      int? up;
      if (_downLimitEnabled) {
        down = _parseLimit(_downController.text, l10n);
        if (down == null) throw FormatException(l10n.emptyNumber);
      }
      if (_upLimitEnabled) {
        up = _parseLimit(_upController.text, l10n);
        if (up == null) throw FormatException(l10n.emptyNumber);
      }
      setState(() => _saving = true);
      await widget.torrent.setSpeedLimits(
        downloadEnabled: _downLimitEnabled,
        uploadEnabled: _upLimitEnabled,
        downloadLimitKbps: down,
        uploadLimitKbps: up,
      );
      if (mounted) {
        final messenger = ScaffoldMessenger.of(context);
        await context.read<TorrentsModel>().fetchTorrents();
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.speedLimitsApplied)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e is FormatException ? e.message : l10n.error),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _toggleSequential(bool value) async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _sequential = value);
    try {
      await widget.torrent.setSequentialDownload(value);
      if (mounted) {
        final messenger = ScaffoldMessenger.of(context);
        await context.read<TorrentsModel>().fetchTorrents();
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              value ? l10n.sequentialDownloadEnabled : l10n.sequentialDownloadDisabled,
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _sequential = !value);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.sequentialDownloadFailed)),
        );
      }
    }
  }

  Future<void> _togglePause() async {
    final torrent = widget.torrent;
    if (torrent.status == TorrentStatus.stopped) {
      torrent.start();
    } else {
      await torrent.stop();
    }
    if (mounted) await context.read<TorrentsModel>().fetchTorrents();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final torrent = widget.torrent;
    final isPaused = torrent.status == TorrentStatus.stopped;

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        ListTile(
          leading: Icon(isPaused ? Icons.play_arrow : Icons.pause),
          title: Text(isPaused ? l10n.download : l10n.pause),
          subtitle: Text(l10n.torrentControlPauseHint),
          trailing: FilledButton.tonal(
            onPressed: _saving ? null : _togglePause,
            child: Text(isPaused ? l10n.download : l10n.pause),
          ),
        ),
        SwitchListTile(
          title: Text(l10n.sequentialDownload),
          subtitle: Text(
            _sequential ? l10n.sequentialDownloadActive : l10n.sequentialDownloadInactive,
          ),
          value: _sequential,
          onChanged: _saving ? null : _toggleSequential,
        ),
        const Divider(),
        SwitchListTile(
          title: Text(l10n.perTorrentDownloadLimit),
          subtitle: Text(l10n.perTorrentDownloadLimitHint),
          value: _downLimitEnabled,
          onChanged: _saving
              ? null
              : (v) => setState(() {
                    _downLimitEnabled = v;
                    if (!v) _downController.clear();
                  }),
        ),
        if (_downLimitEnabled)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _downController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: l10n.downloadSpeedLimit,
                suffixText: l10n.kilobytesPerSecond,
              ),
            ),
          ),
        SwitchListTile(
          title: Text(l10n.perTorrentUploadLimit),
          value: _upLimitEnabled,
          onChanged: _saving
              ? null
              : (v) => setState(() {
                    _upLimitEnabled = v;
                    if (!v) _upController.clear();
                  }),
        ),
        if (_upLimitEnabled)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _upController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: l10n.uploadSpeedLimit,
                suffixText: l10n.kilobytesPerSecond,
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton(
            onPressed: _saving ? null : _applySpeedLimits,
            child: _saving
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(l10n.applySpeedLimits),
          ),
        ),
        if (_downLimitEnabled || _upLimitEnabled)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              l10n.perTorrentLimitsActive,
              style: TextStyle(color: Theme.of(context).colorScheme.primary),
            ),
          ),
      ],
    );
  }
}

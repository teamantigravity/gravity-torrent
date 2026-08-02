import 'package:flutter/material.dart';
import 'package:gravity_torrent/l10n/app_localizations.dart';
import 'package:media_kit/media_kit.dart';

String getTitle(BuildContext context, AudioTrack track) {
  final l = AppLocalizations.of(context);
  if (track.id == 'auto') {
    return l.auto;
  }

  if (track.id == 'no') {
    return l.noAudio;
  }

  return track.title ?? l.unknown;
}

class AudioTrackSelectorDialog extends StatefulWidget {
  final List<AudioTrack> tracks;
  final Function(AudioTrack) onTrackSelected;
  final String currentValue;
  const AudioTrackSelectorDialog({
    super.key,
    required this.onTrackSelected,
    required this.currentValue,
    required this.tracks,
  });

  @override
  State<AudioTrackSelectorDialog> createState() =>
      _AudioTrackSelectorDialogState();
}

class _AudioTrackSelectorDialogState extends State<AudioTrackSelectorDialog> {
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l.audioTracks),
      content: SingleChildScrollView(
        child: RadioGroup<String>(
          groupValue: widget.currentValue,
          onChanged: (id) {
            final track = widget.tracks.firstWhere((t) => t.id == id);
            widget.onTrackSelected(track);
            Navigator.of(context).pop();
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ...widget.tracks.map((track) {
                return RadioListTile<String>(
                  title: Text(getTitle(context, track)),
                  value: track.id,
                );
              }),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          child: Text(l.cancel),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
      ],
    );
  }
}

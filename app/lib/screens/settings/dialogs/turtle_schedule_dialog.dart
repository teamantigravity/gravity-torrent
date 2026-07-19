import 'package:flutter/material.dart';
import 'package:gravity_torrent/l10n/app_localizations.dart';

/// Bit values used by Transmission's `alt-speed-time-day` bitfield.
/// Sunday is the least-significant bit.
const List<int> _dayBits = <int>[1, 2, 4, 8, 16, 32, 64];

/// Configures the scheduled window during which the alternative ("turtle")
/// speed limits are automatically applied.
class TurtleScheduleDialog extends StatefulWidget {
  final int beginMinutes;
  final int endMinutes;
  final int dayBitfield;
  final void Function(int begin, int end, int day) onSave;

  const TurtleScheduleDialog({
    super.key,
    required this.beginMinutes,
    required this.endMinutes,
    required this.dayBitfield,
    required this.onSave,
  });

  @override
  State<TurtleScheduleDialog> createState() => _TurtleScheduleDialogState();
}

class _TurtleScheduleDialogState extends State<TurtleScheduleDialog> {
  late int _begin;
  late int _end;
  late int _day;

  @override
  void initState() {
    super.initState();
    _begin = widget.beginMinutes.clamp(0, 1439);
    _end = widget.endMinutes.clamp(0, 1439);
    _day = widget.dayBitfield == 0 ? 127 : widget.dayBitfield;
  }

  TimeOfDay _toTimeOfDay(int minutes) =>
      TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60);

  Future<void> _pickTime({required bool isBegin}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _toTimeOfDay(isBegin ? _begin : _end),
    );
    if (picked == null) return;
    setState(() {
      final value = picked.hour * 60 + picked.minute;
      if (isBegin) {
        _begin = value;
      } else {
        _end = value;
      }
    });
  }

  String _formatMinutes(int minutes) {
    final t = _toTimeOfDay(minutes);
    return MaterialLocalizations.of(context).formatTimeOfDay(t);
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final dayLabels = <String>[
      localizations.daySun,
      localizations.dayMon,
      localizations.dayTue,
      localizations.dayWed,
      localizations.dayThu,
      localizations.dayFri,
      localizations.daySat,
    ];

    return AlertDialog(
      title: Text(localizations.turtleSchedule),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.play_circle_outline),
              title: Text(localizations.scheduleFrom),
              trailing: Text(_formatMinutes(_begin)),
              onTap: () => _pickTime(isBegin: true),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.stop_circle_outlined),
              title: Text(localizations.scheduleTo),
              trailing: Text(_formatMinutes(_end)),
              onTap: () => _pickTime(isBegin: false),
            ),
            const SizedBox(height: 12),
            Text(
              localizations.scheduleDays,
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              children: List.generate(7, (i) {
                final selected = (_day & _dayBits[i]) != 0;
                return FilterChip(
                  label: Text(dayLabels[i]),
                  selected: selected,
                  onSelected: (value) {
                    setState(() {
                      if (value) {
                        _day |= _dayBits[i];
                      } else {
                        _day &= ~_dayBits[i];
                      }
                    });
                  },
                );
              }),
            ),
          ],
        ),
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
            // Fall back to everyday if the user cleared all days.
            widget.onSave(_begin, _end, _day == 0 ? 127 : _day);
          },
        ),
      ],
    );
  }
}

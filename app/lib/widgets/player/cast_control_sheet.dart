import 'dart:async';

import 'package:flutter/material.dart';
import 'package:gravity_torrent/l10n/app_localizations.dart';
import 'package:gravity_torrent/services/casting_service.dart';
import 'package:gravity_torrent/services/haptic_service.dart';

/// Transport controls for the renderer currently being cast to.
///
/// Shown instead of immediately disconnecting when the cast button is pressed
/// during an active session, so users can pause, adjust volume, or stop.
class CastControlSheet extends StatefulWidget {
  const CastControlSheet({super.key});

  @override
  State<CastControlSheet> createState() => _CastControlSheetState();
}

class _CastControlSheetState extends State<CastControlSheet> {
  /// UPnP exposes no way to read the renderer's volume without subscribing to
  /// its event service, so the slider starts at a neutral value and only
  /// reflects changes made from here.
  double _volume = 50;

  Timer? _volumeDebounce;

  @override
  void dispose() {
    _volumeDebounce?.cancel();
    super.dispose();
  }

  void _onVolumeChanged(double value) {
    setState(() => _volume = value);
    // Dragging a slider emits a change per frame; sending one SOAP call each
    // would flood the renderer, so the final value wins.
    _volumeDebounce?.cancel();
    _volumeDebounce = Timer(const Duration(milliseconds: 250), () {
      unawaited(CastingService.instance.setVolume(value.round()));
    });
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);

    return SafeArea(
      child: ListenableBuilder(
        listenable: CastingService.instance,
        builder: (context, _) {
          final casting = CastingService.instance;
          final device = casting.selectedDevice;

          // The session can end while the sheet is open (for example when the
          // player is closed), so close rather than show dead controls.
          if (!casting.isCasting || device == null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (context.mounted && Navigator.canPop(context)) {
                Navigator.pop(context);
              }
            });
            return const SizedBox.shrink();
          }

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.cast_connected),
                title: Text(device.name),
                subtitle: Text(localizations.castControls),
              ),
              const Divider(height: 1),
              ListTile(
                leading: Icon(
                  casting.isPaused ? Icons.play_arrow : Icons.pause,
                ),
                title: Text(
                  casting.isPaused
                      ? localizations.castResume
                      : localizations.castPause,
                ),
                onTap: () {
                  HapticService.light();
                  unawaited(
                    casting.isPaused ? casting.resume() : casting.pause(),
                  );
                },
              ),
              if (device.renderingControlUrl != null)
                ListTile(
                  leading: const Icon(Icons.volume_up),
                  title: Text(localizations.castVolume),
                  subtitle: Slider(
                    value: _volume,
                    max: 100,
                    divisions: 20,
                    label: '${_volume.round()}',
                    onChanged: _onVolumeChanged,
                  ),
                ),
              ListTile(
                leading: const Icon(Icons.stop_circle_outlined),
                title: Text(localizations.castStopCasting),
                onTap: () async {
                  HapticService.medium();
                  await casting.stopCasting();
                  if (context.mounted) Navigator.pop(context);
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

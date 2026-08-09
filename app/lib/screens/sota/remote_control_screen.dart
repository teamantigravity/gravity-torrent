import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gravity_torrent/services/remote_control_service.dart';
import 'package:gravity_torrent/utils/device.dart';
import 'package:gravity_torrent/widgets/window_title_bar.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:gravity_torrent/l10n/app_localizations.dart';

class RemoteControlScreen extends StatefulWidget {
  const RemoteControlScreen({super.key});

  @override
  State<RemoteControlScreen> createState() => _RemoteControlScreenState();
}

class _RemoteControlScreenState extends State<RemoteControlScreen> {
  bool _running = false;
  String _address = '';
  String _token = '';
  String _qr = '';
  bool _tokenVisible = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    if (!mounted) return;
    setState(() {
      _running = RemoteControlService.instance.isRunning;
      _address = _running ? RemoteControlService.instance.localAddress : '';
      _token = RemoteControlService.instance.token;
      _qr = _running ? RemoteControlService.instance.qrPayload : '';
    });
  }

  Future<void> _toggle() async {
    if (RemoteControlService.instance.isRunning) {
      await RemoteControlService.instance.stop();
    } else {
      await RemoteControlService.instance.start();
    }
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    return Scaffold(
      appBar: isDesktop()
          ? const WindowTitleBar()
          : AppBar(title: Text(localizations.localRemoteControl)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              localizations.localRemoteControl,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(localizations.remoteControlDescription),
            const SizedBox(height: 24),
            SwitchListTile(
              secondary: const Icon(Icons.wifi_tethering),
              title: Text(localizations.remoteControlServer),
              subtitle: Text(
                _running
                    ? localizations.runningOn(_address)
                    : localizations.serverOff,
              ),
              value: _running,
              onChanged: (v) => _toggle(),
            ),
            if (_running) ...[
              const SizedBox(height: 16),
              Center(
                child: QrImageView(
                  data: _qr,
                  size: 240,
                  backgroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: SelectableText(
                      'Token: ${_tokenVisible ? _token : '•' * 16}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      _tokenVisible ? Icons.visibility_off : Icons.visibility,
                      size: 16,
                    ),
                    tooltip: _tokenVisible
                        ? localizations.hideToken
                        : localizations.showToken,
                    onPressed: () =>
                        setState(() => _tokenVisible = !_tokenVisible),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy, size: 16),
                    tooltip: localizations.copyToken,
                    onPressed: () async {
                      try {
                        await Clipboard.setData(ClipboardData(text: _token));
                      } catch (_) {
                        return;
                      }
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(localizations.tokenCopied),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ],
            if (!isMobile())
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: Text(
                  localizations.qrScanningMobileOnly,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

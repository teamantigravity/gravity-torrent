import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gravity_torrent/services/remote_control_service.dart';
import 'package:gravity_torrent/utils/device.dart';
import 'package:gravity_torrent/widgets/window_title_bar.dart';
import 'package:qr_flutter/qr_flutter.dart';

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
    return Scaffold(
      appBar: isDesktop()
          ? const WindowTitleBar()
          : AppBar(title: const Text('Local remote control')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Local remote control',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            const Text(
              'Control this device from another phone or computer on the same Wi-Fi network. '
              'The connection is local-only and protected by a token.',
            ),
            const SizedBox(height: 24),
            SwitchListTile(
              secondary: const Icon(Icons.wifi_tethering),
              title: const Text('Remote control server'),
              subtitle: Text(
                _running ? 'Running on $_address' : 'Server is off',
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
                    icon: Icon(_tokenVisible ? Icons.visibility_off : Icons.visibility, size: 16),
                    tooltip: _tokenVisible ? 'Hide token' : 'Show token',
                    onPressed: () => setState(() => _tokenVisible = !_tokenVisible),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy, size: 16),
                    tooltip: 'Copy token',
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: _token));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Token copied to clipboard'),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ],
            if (!isMobile())
              const Padding(
                padding: EdgeInsets.only(top: 16.0),
                child: Text(
                  'Note: camera-based QR scanning is available on mobile devices.',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

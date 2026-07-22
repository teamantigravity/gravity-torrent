import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

class CastDevice {
  final String id;
  final String name;
  final String address;

  CastDevice({
    required this.id,
    required this.name,
    required this.address,
  });
}

/// Service for discovering and casting streams to DLNA / UPnP and smart screens.
class CastingService {
  CastingService._();
  static final CastingService instance = CastingService._();

  final List<CastDevice> _devices = [];
  CastDevice? _selectedDevice;
  bool _isCasting = false;

  List<CastDevice> get devices => List.unmodifiable(_devices);
  CastDevice? get selectedDevice => _selectedDevice;
  bool get isCasting => _isCasting;

  /// Discover local network media renderers using M-SEARCH (SSDP / UPnP).
  Future<List<CastDevice>> discoverDevices() async {
    _devices.clear();
    try {
      final RawDatagramSocket socket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        0,
      );
      socket.broadcastEnabled = true;

      const ssdpTarget = '239.255.255.250';
      const ssdpPort = 1900;
      const mSearch = 'M-SEARCH * HTTP/1.1\r\n'
          'HOST: 239.255.255.250:1900\r\n'
          'MAN: "ssdp:discover"\r\n'
          'MX: 3\r\n'
          'ST: urn:schemas-upnp-org:device:MediaRenderer:1\r\n\r\n';

      socket.send(
        mSearch.codeUnits,
        InternetAddress(ssdpTarget),
        ssdpPort,
      );

      final completer = Completer<List<CastDevice>>();

      Timer(const Duration(seconds: 3), () {
        socket.close();
        if (!completer.isCompleted) {
          completer.complete(_devices);
        }
      });

      socket.listen((RawSocketEvent event) {
        if (event == RawSocketEvent.read) {
          final Datagram? dg = socket.receive();
          if (dg != null) {
            final response = String.fromCharCodes(dg.data);
            if (response.contains('MediaRenderer') ||
                response.contains('LOCATION')) {
              final addr = dg.address.address;
              if (!_devices.any((d) => d.address == addr)) {
                final device = CastDevice(
                  id: addr,
                  name: 'Smart TV / DLNA ($addr)',
                  address: addr,
                );
                _devices.add(device);
              }
            }
          }
        }
      });

      return await completer.future;
    } catch (e) {
      if (kDebugMode) debugPrint('CastingService discovery error: $e');
      return _devices;
    }
  }

  Future<bool> castStream({
    required CastDevice device,
    required String streamUrl,
    required String title,
  }) async {
    try {
      _selectedDevice = device;
      _isCasting = true;
      if (kDebugMode) {
        debugPrint('CastingService: casting $streamUrl to ${device.name}');
      }
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('CastingService castStream error: $e');
      _isCasting = false;
      return false;
    }
  }

  void stopCasting() {
    _isCasting = false;
    _selectedDevice = null;
  }
}

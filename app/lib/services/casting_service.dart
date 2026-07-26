import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'package:gravity_torrent/services/dlna/dlna_protocol.dart';

export 'package:gravity_torrent/services/dlna/dlna_protocol.dart'
    show CastDevice;

/// Discovers UPnP/DLNA media renderers on the local network and drives them
/// through the standard `AVTransport:1` and `RenderingControl:1` services.
///
/// Everything happens on the local network: the renderer fetches the media
/// straight from the app's own streaming server, so no stream data is ever
/// routed through a third party.
class CastingService extends ChangeNotifier {
  CastingService._();
  static final CastingService instance = CastingService._();

  bool _disposed = false;

  void _safeNotify() {
    if (!_disposed) super.notifyListeners();
  }

  /// How long to listen for SSDP replies before giving up.
  static const Duration discoveryTimeout = Duration(seconds: 4);

  /// Timeout applied to every HTTP/SOAP call to a renderer.
  static const Duration requestTimeout = Duration(seconds: 8);

  static const String _ssdpAddress = '239.255.255.250';
  static const int _ssdpPort = 1900;

  final List<CastDevice> _devices = [];
  CastDevice? _selectedDevice;
  bool _isCasting = false;
  bool _isPaused = false;
  bool _isDiscovering = false;
  String? _lastError;

  http.Client _client = http.Client();

  List<CastDevice> get devices => List.unmodifiable(_devices);
  CastDevice? get selectedDevice => _selectedDevice;
  bool get isCasting => _isCasting;
  bool get isPaused => _isPaused;
  bool get isDiscovering => _isDiscovering;

  /// Human-readable reason the last cast attempt failed, or `null` on success.
  String? get lastError => _lastError;

  /// Overrides the HTTP client used for device description and SOAP calls.
  @visibleForTesting
  void setClientForTesting(http.Client client) => _client = client;

  /// Replaces the discovered device list without running discovery.
  @visibleForTesting
  void setDevicesForTesting(List<CastDevice> devices) {
    _devices
      ..clear()
      ..addAll(devices);
  }

  /// A renderer on another host can never fetch a loopback URL — it would
  /// resolve to the TV itself. Detect this early so the user gets a real error
  /// instead of a silent failure.
  @visibleForTesting
  static bool isUnreachableForRenderer(String streamUrl) {
    final uri = Uri.tryParse(streamUrl);
    if (uri == null || uri.host.isEmpty) return true;
    final address = InternetAddress.tryParse(uri.host);
    if (address != null) return address.isLoopback;
    return uri.host.toLowerCase() == 'localhost';
  }

  /// Discovers media renderers on the local network via SSDP `M-SEARCH`, then
  /// fetches each device description to resolve its friendly name and
  /// `AVTransport` control endpoint.
  ///
  /// Only renderers that actually expose `AVTransport:1` are returned, because
  /// anything else cannot be told to play a stream.
  Future<List<CastDevice>> discoverDevices() async {
    if (_isDiscovering || kIsWeb) return devices;
    _isDiscovering = true;
    _safeNotify();

    final locations = <Uri>{};
    RawDatagramSocket? socket;
    StreamSubscription<RawSocketEvent>? subscription;

    try {
      socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      final boundSocket = socket;
      boundSocket.joinMulticast(InternetAddress(_ssdpAddress));
      boundSocket.broadcastEnabled = true;

      subscription = boundSocket.listen(
        (RawSocketEvent event) {
          if (event != RawSocketEvent.read) return;
          final Datagram? datagram = boundSocket.receive();
          if (datagram == null) return;
          final response = utf8.decode(datagram.data, allowMalformed: true);
          final location = parseSsdpLocation(response);
          if (location != null) locations.add(location);
        },
        onError: (Object e) {
          if (kDebugMode) debugPrint('CastingService socket error: $e');
        },
      );

      // SSDP runs over UDP, which is lossy and often dropped by Wi-Fi access
      // points, so the search is repeated a few times.
      final message = _buildMSearch();
      for (var attempt = 0; attempt < 3; attempt++) {
        boundSocket.send(
          message,
          InternetAddress(_ssdpAddress),
          _ssdpPort,
        );
        await Future<void>.delayed(const Duration(milliseconds: 400));
      }
      await Future<void>.delayed(discoveryTimeout);
    } catch (e) {
      if (kDebugMode) debugPrint('CastingService discovery error: $e');
    } finally {
      await subscription?.cancel();
      socket?.close();
    }

    // Descriptions are fetched concurrently so a single unresponsive device
    // cannot stall the whole scan.
    final described = await Future.wait(locations.map(_describeDevice));

    if (_disposed) return const [];

    final byId = <String, CastDevice>{};
    for (final device in described) {
      if (device != null) byId[device.id] = device;
    }

    _devices
      ..clear()
      ..addAll(byId.values);
    _isDiscovering = false;
    _safeNotify();
    return devices;
  }

  List<int> _buildMSearch() {
    return utf8.encode(
      'M-SEARCH * HTTP/1.1\r\n'
      'HOST: $_ssdpAddress:$_ssdpPort\r\n'
      'MAN: "ssdp:discover"\r\n'
      'MX: 3\r\n'
      'ST: urn:schemas-upnp-org:device:MediaRenderer:1\r\n'
      '\r\n',
    );
  }

  Future<CastDevice?> _describeDevice(Uri location) async {
    try {
      final response = await _client.get(location).timeout(requestTimeout);
      if (response.statusCode != HttpStatus.ok) return null;
      final body = utf8.decode(response.bodyBytes, allowMalformed: true);
      return parseDeviceDescription(body, location);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('CastingService: failed to describe $location: $e');
      }
      return null;
    }
  }

  /// Points [device] at [streamUrl] and starts playback.
  ///
  /// Returns `true` only once the renderer has accepted both the
  /// `SetAVTransportURI` and `Play` actions; [lastError] explains any failure.
  Future<bool> castStream({
    required CastDevice device,
    required String streamUrl,
    required String title,
  }) async {
    _lastError = null;

    if (streamUrl.isEmpty) {
      _lastError = 'No stream URL available yet.';
      _safeNotify();
      return false;
    }

    if (isUnreachableForRenderer(streamUrl)) {
      _lastError =
          'The stream is only reachable on this device. Enable LAN streaming '
          'so the renderer can reach it.';
      _safeNotify();
      return false;
    }

    final metadata = buildDidlMetadata(title: title, streamUrl: streamUrl);
    final accepted = await _avTransportAction(
      device,
      'SetAVTransportURI',
      innerXml: '<CurrentURI>${escapeXml(streamUrl)}</CurrentURI>'
          '<CurrentURIMetaData>${escapeXml(metadata)}</CurrentURIMetaData>',
    );

    if (_disposed) return false;
    if (!accepted) {
      _isCasting = false;
      _selectedDevice = null;
      _lastError ??= 'The renderer rejected the stream.';
      _safeNotify();
      return false;
    }

    final playing = await _avTransportAction(
      device,
      'Play',
      innerXml: '<Speed>1</Speed>',
    );

    if (_disposed) return false;
    _isCasting = playing;
    _isPaused = false;
    _selectedDevice = playing ? device : null;
    if (!playing) _lastError ??= 'The renderer refused to start playback.';
    _safeNotify();
    return playing;
  }

  /// Pauses playback on the active renderer.
  Future<bool> pause() async {
    if (_disposed) return false;
    final device = _selectedDevice;
    if (device == null || !_isCasting) return false;
    final ok = await _avTransportAction(device, 'Pause');
    if (_disposed) return false;
    if (ok) {
      _isPaused = true;
      _safeNotify();
    }
    return ok;
  }

  /// Resumes playback on the active renderer.
  Future<bool> resume() async {
    if (_disposed) return false;
    final device = _selectedDevice;
    if (device == null || !_isCasting) return false;
    final ok = await _avTransportAction(
      device,
      'Play',
      innerXml: '<Speed>1</Speed>',
    );
    if (_disposed) return false;
    if (ok) {
      _isPaused = false;
      _safeNotify();
    }
    return ok;
  }

  /// Seeks the active renderer to [position].
  Future<bool> seek(Duration position) async {
    if (_disposed) return false;
    final device = _selectedDevice;
    if (device == null || !_isCasting) return false;
    final ok = await _avTransportAction(
      device,
      'Seek',
      innerXml: '<Unit>REL_TIME</Unit>'
          '<Target>${formatUpnpDuration(position)}</Target>',
    );
    return _disposed ? false : ok;
  }

  /// Sets the renderer volume to [percent] (0-100).
  ///
  /// Returns `false` when the renderer does not advertise a
  /// `RenderingControl:1` service.
  Future<bool> setVolume(int percent) async {
    if (_disposed) return false;
    final device = _selectedDevice;
    final controlUrl = device?.renderingControlUrl;
    if (device == null || controlUrl == null || !_isCasting) return false;
    final ok = await _soapAction(
      controlUrl: controlUrl,
      serviceType: renderingControlServiceType,
      action: 'SetVolume',
      innerXml: '<Channel>Master</Channel>'
          '<DesiredVolume>${percent.clamp(0, 100)}</DesiredVolume>',
    );
    return _disposed ? false : ok;
  }

  /// Stops playback on the renderer and clears the casting state.
  ///
  /// The local state is always cleared, even when the renderer is unreachable,
  /// so the UI can never get stuck showing an active cast session.
  Future<bool> stopCasting() async {
    if (_disposed) return false;
    final device = _selectedDevice;
    var stopped = true;
    if (device != null && _isCasting) {
      stopped = await _avTransportAction(device, 'Stop');
    }
    if (_disposed) return false;
    _isCasting = false;
    _isPaused = false;
    _selectedDevice = null;
    _safeNotify();
    return stopped;
  }

  Future<bool> _avTransportAction(
    CastDevice device,
    String action, {
    String innerXml = '',
  }) {
    return _soapAction(
      controlUrl: device.controlUrl,
      serviceType: avTransportServiceType,
      action: action,
      innerXml: innerXml,
    );
  }

  Future<bool> _soapAction({
    required Uri controlUrl,
    required String serviceType,
    required String action,
    String innerXml = '',
  }) async {
    try {
      final response = await _client
          .post(
            controlUrl,
            headers: {
              'Content-Type': 'text/xml; charset="utf-8"',
              'SOAPAction': '"$serviceType#$action"',
              'Connection': 'close',
            },
            body: utf8.encode(
              buildSoapEnvelope(
                serviceType: serviceType,
                action: action,
                innerXml: innerXml,
              ),
            ),
          )
          .timeout(requestTimeout);

      if (response.statusCode == HttpStatus.ok) return true;
      _lastError = 'Renderer returned HTTP ${response.statusCode} for $action.';
      if (kDebugMode) {
        debugPrint('CastingService: $action failed -> ${response.statusCode}');
      }
      return false;
    } on TimeoutException {
      _lastError = 'The renderer did not respond in time.';
      return false;
    } catch (e) {
      _lastError = 'Could not reach the renderer.';
      if (kDebugMode) debugPrint('CastingService: $action error: $e');
      return false;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _client.close();
    super.dispose();
  }
}

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:gravity_torrent/services/casting_service.dart';
import 'package:gravity_torrent/services/dlna/dlna_protocol.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

CastDevice _device() => CastDevice(
      id: 'uuid:test',
      name: 'Test TV',
      address: '192.168.1.50',
      controlUrl: Uri.parse('http://192.168.1.50:8200/ctl/transport'),
      renderingControlUrl: Uri.parse('http://192.168.1.50:8200/ctl/rendering'),
    );

void main() {
  final service = CastingService.instance;

  tearDown(() async {
    service.setClientForTesting(
      MockClient((_) async => http.Response('', 500)),
    );
    await service.stopCasting();
  });

  group('isUnreachableForRenderer', () {
    test('rejects loopback and localhost URLs', () {
      expect(
        CastingService.isUnreachableForRenderer('http://127.0.0.1:8080/tok'),
        isTrue,
      );
      expect(
        CastingService.isUnreachableForRenderer('http://localhost:8080/tok'),
        isTrue,
      );
      expect(
        CastingService.isUnreachableForRenderer('http://[::1]:8080/tok'),
        isTrue,
      );
    });

    test('accepts a routable LAN address', () {
      expect(
        CastingService.isUnreachableForRenderer('http://192.168.1.20:8080/tok'),
        isFalse,
      );
    });

    test('rejects empty and unparseable URLs', () {
      expect(CastingService.isUnreachableForRenderer(''), isTrue);
      expect(CastingService.isUnreachableForRenderer('not a url'), isTrue);
    });
  });

  group('castStream', () {
    test('sends SetAVTransportURI then Play and reports success', () async {
      final actions = <String>[];
      final bodies = <String>[];

      service.setClientForTesting(
        MockClient((request) async {
          actions.add(request.headers['SOAPAction'] ?? '');
          bodies.add(utf8.decode(request.bodyBytes));
          return http.Response('<s:Envelope/>', 200);
        }),
      );

      final ok = await service.castStream(
        device: _device(),
        streamUrl: 'http://192.168.1.20:8080/secret',
        title: 'Episode 1.mkv',
      );

      expect(ok, isTrue);
      expect(service.isCasting, isTrue);
      expect(service.selectedDevice?.id, 'uuid:test');
      expect(actions, [
        '"$avTransportServiceType#SetAVTransportURI"',
        '"$avTransportServiceType#Play"',
      ]);
      expect(bodies.first, contains('<CurrentURI>'));
      expect(bodies.first, contains('http://192.168.1.20:8080/secret'));
      // The DIDL document is embedded as escaped XML inside the SOAP body.
      expect(bodies.first, contains('&lt;DIDL-Lite'));
    });

    test(
      'fails fast on a loopback URL without contacting the renderer',
      () async {
        var calls = 0;
        service.setClientForTesting(
          MockClient((_) async {
            calls++;
            return http.Response('', 200);
          }),
        );

        final ok = await service.castStream(
          device: _device(),
          streamUrl: 'http://127.0.0.1:8080/secret',
          title: 'Episode 1.mkv',
        );

        expect(ok, isFalse);
        expect(calls, 0);
        expect(service.isCasting, isFalse);
        expect(service.lastError, isNotNull);
      },
    );

    test('does not report casting when the renderer rejects the URI', () async {
      service.setClientForTesting(
        MockClient((_) async => http.Response('error', 500)),
      );

      final ok = await service.castStream(
        device: _device(),
        streamUrl: 'http://192.168.1.20:8080/secret',
        title: 'Episode 1.mkv',
      );

      expect(ok, isFalse);
      expect(service.isCasting, isFalse);
      expect(service.selectedDevice, isNull);
      expect(service.lastError, contains('500'));
    });

    test('does not report casting when Play is refused', () async {
      var call = 0;
      service.setClientForTesting(
        MockClient((_) async {
          call++;
          // SetAVTransportURI succeeds, Play fails.
          return http.Response('', call == 1 ? 200 : 500);
        }),
      );

      final ok = await service.castStream(
        device: _device(),
        streamUrl: 'http://192.168.1.20:8080/secret',
        title: 'Episode 1.mkv',
      );

      expect(ok, isFalse);
      expect(service.isCasting, isFalse);
    });

    test('rejects an empty stream URL', () async {
      final ok = await service.castStream(
        device: _device(),
        streamUrl: '',
        title: 'Episode 1.mkv',
      );
      expect(ok, isFalse);
      expect(service.isCasting, isFalse);
    });
  });

  group('transport controls', () {
    Future<void> startCast() async {
      service.setClientForTesting(
        MockClient((_) async => http.Response('', 200)),
      );
      await service.castStream(
        device: _device(),
        streamUrl: 'http://192.168.1.20:8080/secret',
        title: 'Episode 1.mkv',
      );
    }

    test('pause and resume toggle the paused state', () async {
      await startCast();

      expect(await service.pause(), isTrue);
      expect(service.isPaused, isTrue);

      expect(await service.resume(), isTrue);
      expect(service.isPaused, isFalse);
    });

    test('seek sends a REL_TIME target', () async {
      await startCast();

      String? body;
      service.setClientForTesting(
        MockClient((request) async {
          body = utf8.decode(request.bodyBytes);
          return http.Response('', 200);
        }),
      );

      expect(
        await service.seek(const Duration(minutes: 3, seconds: 4)),
        isTrue,
      );
      expect(body, contains('<Unit>REL_TIME</Unit>'));
      expect(body, contains('<Target>00:03:04</Target>'));
    });

    test('setVolume clamps out-of-range values', () async {
      await startCast();

      String? body;
      service.setClientForTesting(
        MockClient((request) async {
          body = utf8.decode(request.bodyBytes);
          return http.Response('', 200);
        }),
      );

      expect(await service.setVolume(500), isTrue);
      expect(body, contains('<DesiredVolume>100</DesiredVolume>'));
    });

    test('controls are no-ops when nothing is casting', () async {
      expect(await service.pause(), isFalse);
      expect(await service.resume(), isFalse);
      expect(await service.seek(Duration.zero), isFalse);
      expect(await service.setVolume(50), isFalse);
    });

    test(
      'stopCasting clears state even when the renderer is unreachable',
      () async {
        await startCast();
        expect(service.isCasting, isTrue);

        service.setClientForTesting(
          MockClient((_) async => throw const HttpException('offline')),
        );

        expect(await service.stopCasting(), isFalse);
        expect(service.isCasting, isFalse);
        expect(service.selectedDevice, isNull);
      },
    );
  });
}

class HttpException implements Exception {
  const HttpException(this.message);
  final String message;
}

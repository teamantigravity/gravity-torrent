import 'package:flutter_test/flutter_test.dart';
import 'package:gravity_torrent/services/dlna/dlna_protocol.dart';

const _rendererDescription = '''
<?xml version="1.0"?>
<root xmlns="urn:schemas-upnp-org:device-1-0">
  <device>
    <deviceType>urn:schemas-upnp-org:device:MediaRenderer:1</deviceType>
    <friendlyName>Living Room TV</friendlyName>
    <UDN>uuid:1234-5678</UDN>
    <serviceList>
      <service>
        <serviceType>urn:schemas-upnp-org:service:RenderingControl:1</serviceType>
        <controlURL>/upnp/control/rendering</controlURL>
      </service>
      <service>
        <serviceType>urn:schemas-upnp-org:service:AVTransport:1</serviceType>
        <controlURL>/upnp/control/transport</controlURL>
      </service>
    </serviceList>
  </device>
</root>
''';

void main() {
  group('parseSsdpLocation', () {
    test('reads the LOCATION header case-insensitively', () {
      const response = 'HTTP/1.1 200 OK\r\n'
          'CACHE-CONTROL: max-age=1800\r\n'
          'location: http://192.168.1.50:8200/desc.xml\r\n'
          'ST: urn:schemas-upnp-org:device:MediaRenderer:1\r\n\r\n';
      expect(
        parseSsdpLocation(response),
        Uri.parse('http://192.168.1.50:8200/desc.xml'),
      );
    });

    test('returns null when no LOCATION header is present', () {
      expect(parseSsdpLocation('HTTP/1.1 200 OK\r\nST: foo\r\n\r\n'), isNull);
    });

    test('returns null for a malformed location value', () {
      expect(
        parseSsdpLocation('HTTP/1.1 200 OK\r\nLOCATION: \r\n\r\n'),
        isNull,
      );
      expect(
        parseSsdpLocation('HTTP/1.1 200 OK\r\nLOCATION: not-a-url\r\n\r\n'),
        isNull,
      );
    });
  });

  group('parseSsdpUsn', () {
    test('reads the USN header', () {
      expect(
        parseSsdpUsn(
          'HTTP/1.1 200 OK\r\nUSN: uuid:abc::upnp:rootdevice\r\n\r\n',
        ),
        'uuid:abc::upnp:rootdevice',
      );
    });

    test('returns null when absent', () {
      expect(parseSsdpUsn('HTTP/1.1 200 OK\r\n\r\n'), isNull);
    });
  });

  group('parseDeviceDescription', () {
    final location = Uri.parse('http://192.168.1.50:8200/desc.xml');

    test('resolves friendly name, identity and both control URLs', () {
      final device = parseDeviceDescription(_rendererDescription, location);

      expect(device, isNotNull);
      expect(device!.name, 'Living Room TV');
      expect(device.id, 'uuid:1234-5678');
      expect(device.address, '192.168.1.50');
      expect(
        device.controlUrl,
        Uri.parse('http://192.168.1.50:8200/upnp/control/transport'),
      );
      expect(
        device.renderingControlUrl,
        Uri.parse('http://192.168.1.50:8200/upnp/control/rendering'),
      );
    });

    test('honours an explicit URLBase when resolving control URLs', () {
      const withBase = '''
<?xml version="1.0"?>
<root xmlns="urn:schemas-upnp-org:device-1-0">
  <URLBase>http://192.168.1.50:9000/</URLBase>
  <device>
    <friendlyName>Base TV</friendlyName>
    <UDN>uuid:base</UDN>
    <serviceList>
      <service>
        <serviceType>urn:schemas-upnp-org:service:AVTransport:1</serviceType>
        <controlURL>ctl/transport</controlURL>
      </service>
    </serviceList>
  </device>
</root>
''';
      final device = parseDeviceDescription(withBase, location);
      expect(
        device!.controlUrl,
        Uri.parse('http://192.168.1.50:9000/ctl/transport'),
      );
    });

    test('rejects a device without an AVTransport service', () {
      const noTransport = '''
<?xml version="1.0"?>
<root>
  <device>
    <friendlyName>Speaker</friendlyName>
    <serviceList>
      <service>
        <serviceType>urn:schemas-upnp-org:service:RenderingControl:1</serviceType>
        <controlURL>/rc</controlURL>
      </service>
    </serviceList>
  </device>
</root>
''';
      expect(parseDeviceDescription(noTransport, location), isNull);
    });

    test('returns null instead of throwing on malformed XML', () {
      expect(parseDeviceDescription('<root><device>', location), isNull);
      expect(parseDeviceDescription('', location), isNull);
    });

    test('falls back to the host when no friendly name is advertised', () {
      const noName = '''
<?xml version="1.0"?>
<root>
  <device>
    <serviceList>
      <service>
        <serviceType>urn:schemas-upnp-org:service:AVTransport:1</serviceType>
        <controlURL>/t</controlURL>
      </service>
    </serviceList>
  </device>
</root>
''';
      final device = parseDeviceDescription(noName, location);
      expect(device!.name, '192.168.1.50');
      expect(device.id, location.toString());
    });
  });

  group('escapeXml', () {
    test('escapes every XML metacharacter', () {
      expect(
        escapeXml('''a&b<c>d"e'f'''),
        'a&amp;b&lt;c&gt;d&quot;e&apos;f',
      );
    });

    test('escapes ampersands before the entities it introduces', () {
      // A naive implementation that escapes '<' first would produce
      // '&amp;lt;' here, corrupting the payload.
      expect(escapeXml('<'), '&lt;');
      expect(escapeXml('&lt;'), '&amp;lt;');
    });
  });

  group('buildDidlMetadata', () {
    test('derives the MIME type and upnp class from the file name', () {
      final metadata = buildDidlMetadata(
        title: 'Episode.mkv',
        streamUrl: 'http://192.168.1.2:8080/token',
      );
      expect(metadata, contains('object.item.videoItem'));
      expect(metadata, contains('video/x-matroska'));
      expect(metadata, contains('http://192.168.1.2:8080/token'));
    });

    test('classifies audio files as music tracks', () {
      final metadata = buildDidlMetadata(
        title: 'Song.mp3',
        streamUrl: 'http://192.168.1.2:8080/token',
      );
      expect(metadata, contains('object.item.audioItem.musicTrack'));
    });

    test('escapes titles so they cannot break out of the document', () {
      final metadata = buildDidlMetadata(
        title: 'Tom & Jerry <hack>.mp4',
        streamUrl: 'http://host/a?b=1&c=2',
      );
      expect(
          metadata, contains('Tom &amp;amp; Jerry &amp;lt;hack&amp;gt;.mp4'),);
      expect(metadata, isNot(contains('<hack>')));
      expect(metadata, contains('http://host/a?b=1&amp;amp;c=2'));
    });
  });

  group('buildSoapEnvelope', () {
    test('wraps the action with its service namespace and instance id', () {
      final envelope = buildSoapEnvelope(
        serviceType: avTransportServiceType,
        action: 'Play',
        innerXml: '<Speed>1</Speed>',
      );
      expect(envelope, contains('<u:Play xmlns:u="$avTransportServiceType">'));
      expect(envelope, contains('<InstanceID>0</InstanceID>'));
      expect(envelope, contains('<Speed>1</Speed>'));
      expect(envelope, contains('</s:Envelope>'));
    });
  });

  group('formatUpnpDuration', () {
    test('formats as HH:MM:SS', () {
      expect(formatUpnpDuration(Duration.zero), '00:00:00');
      expect(
        formatUpnpDuration(
          const Duration(hours: 1, minutes: 2, seconds: 3, milliseconds: 40),
        ),
        '01:02:03',
      );
    });

    test('does not roll hours over at 24', () {
      expect(formatUpnpDuration(const Duration(hours: 30)), '30:00:00');
    });

    test('clamps negative positions to zero', () {
      expect(formatUpnpDuration(const Duration(seconds: -5)), '00:00:00');
    });
  });
}

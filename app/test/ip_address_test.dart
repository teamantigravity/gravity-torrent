import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gravity_torrent/utils/ip_address.dart';

Future<List<InternetAddress>> _resolve(String host) async {
  final base = InternetAddress.tryParse(host);
  if (base != null) return [base];
  // Resolve shorthand / hex forms to their canonical loopback form, mirroring
  // the OS resolver behaviour we are hardening against.
  if (host == '127.1') return [InternetAddress.loopbackIPv4];
  if (host == '0x7f.0.0.1' || host == '0127.0.0.1') {
    return [InternetAddress.loopbackIPv4];
  }
  if (host == 'localhost' || host == 'localhost.') {
    return [InternetAddress.loopbackIPv4];
  }
  if (host == 'localtest.me') return [InternetAddress.loopbackIPv4];
  if (host == 'example.com') return [InternetAddress('8.8.8.8')];
  throw const SocketException('unknown');
}

void main() {
  group('IpAddressScope classification', () {
    test('detects IPv4 private ranges', () {
      expect(IpAddressScope.isPrivate(InternetAddress('10.0.0.1')), isTrue);
      expect(IpAddressScope.isPrivate(InternetAddress('172.16.0.1')), isTrue);
      expect(
        IpAddressScope.isPrivate(InternetAddress('172.31.255.255')),
        isTrue,
      );
      expect(IpAddressScope.isPrivate(InternetAddress('192.168.1.1')), isTrue);
      expect(IpAddressScope.isPrivate(InternetAddress('127.0.0.1')), isTrue);
      expect(IpAddressScope.isPrivate(InternetAddress('169.254.1.1')), isTrue);
      expect(IpAddressScope.isPrivate(InternetAddress('100.64.0.1')), isTrue);
      expect(IpAddressScope.isPrivate(InternetAddress('8.8.8.8')), isFalse);
      expect(
        IpAddressScope.isPrivate(InternetAddress('::ffff:192.168.1.1')),
        isTrue,
      );
      expect(
        IpAddressScope.isPrivate(InternetAddress('::ffff:127.0.0.1')),
        isTrue,
      );
    });

    test('detects IPv6 private/reserved ranges', () {
      expect(IpAddressScope.isPrivate(InternetAddress('::1')), isTrue);
      expect(IpAddressScope.isPrivate(InternetAddress('fe80::1')), isTrue);
      expect(IpAddressScope.isPrivate(InternetAddress('fc00::1')), isTrue);
      expect(IpAddressScope.isPrivate(InternetAddress('fd00::1')), isTrue);
      expect(
        IpAddressScope.isPrivate(InternetAddress('2001:4860:4860::8888')),
        isFalse,
      );
    });

    test('rejects reserved and documentation ranges', () {
      expect(
        IpAddressScope.isPubliclyRoutable(InternetAddress('0.0.0.0')),
        isFalse,
      );
      expect(
        IpAddressScope.isPubliclyRoutable(InternetAddress('255.255.255.255')),
        isFalse,
      );
      expect(
        IpAddressScope.isPubliclyRoutable(InternetAddress('224.0.0.1')),
        isFalse,
      );
      expect(
        IpAddressScope.isPubliclyRoutable(InternetAddress('240.0.0.1')),
        isFalse,
      );
      expect(
        IpAddressScope.isPubliclyRoutable(InternetAddress('198.18.0.1')),
        isFalse,
      );
      expect(
        IpAddressScope.isPubliclyRoutable(InternetAddress('192.0.2.1')),
        isFalse,
      );
      expect(
        IpAddressScope.isPubliclyRoutable(InternetAddress('203.0.113.1')),
        isFalse,
      );
      expect(
        IpAddressScope.isPubliclyRoutable(InternetAddress('::')),
        isFalse,
      );
      expect(
        IpAddressScope.isPubliclyRoutable(InternetAddress('2001:db8::1')),
        isFalse,
      );
      expect(
        IpAddressScope.isPubliclyRoutable(InternetAddress('ff02::1')),
        isFalse,
      );
    });
  });

  group('IpAddressScope.isPubliclyRoutableHost', () {
    test('rejects literal private and malformed IPv4 addresses', () async {
      expect(
        await IpAddressScope.isPubliclyRoutableHost('127.0.0.1'),
        isFalse,
      );
      expect(
        await IpAddressScope.isPubliclyRoutableHost('10.0.0.1'),
        isFalse,
      );
      expect(
        await IpAddressScope.isPubliclyRoutableHost('192.168.1.1'),
        isFalse,
      );
      expect(
        await IpAddressScope.isPubliclyRoutableHost('172.16.0.1'),
        isFalse,
      );
      expect(
        await IpAddressScope.isPubliclyRoutableHost('100.64.0.1'),
        isFalse,
      );
      expect(
        await IpAddressScope.isPubliclyRoutableHost('169.254.1.1'),
        isFalse,
      );
      expect(
        await IpAddressScope.isPubliclyRoutableHost('0.0.0.0'),
        isFalse,
      );
      expect(
        await IpAddressScope.isPubliclyRoutableHost('255.255.255.255'),
        isFalse,
      );
    });

    test('rejects malformed IPv4 shorthand and encodings', () async {
      // These forms are understood by gethostbyname/inet_aton but rejected by
      // Dart's strict parser; we must not let them through either.
      expect(
        await IpAddressScope.isPubliclyRoutableHost('127.1'),
        isFalse,
      );
      expect(
        await IpAddressScope.isPubliclyRoutableHost('0x7f.0.0.1'),
        isFalse,
      );
      expect(
        await IpAddressScope.isPubliclyRoutableHost('0127.0.0.1'),
        isFalse,
      );
      expect(
        await IpAddressScope.isPubliclyRoutableHost('256.0.0.1'),
        isFalse,
      );
    });

    test('rejects localhost and .local names', () async {
      expect(
        await IpAddressScope.isPubliclyRoutableHost('localhost'),
        isFalse,
      );
      expect(
        await IpAddressScope.isPubliclyRoutableHost('localhost.'),
        isFalse,
      );
      expect(
        await IpAddressScope.isPubliclyRoutableHost('myhost.local'),
        isFalse,
      );
      expect(
        await IpAddressScope.isPubliclyRoutableHost('myhost.local.'),
        isFalse,
      );
    });

    test('rejects IPv6 private/reserved literals', () async {
      expect(
        await IpAddressScope.isPubliclyRoutableHost('::1'),
        isFalse,
      );
      expect(
        await IpAddressScope.isPubliclyRoutableHost('::'),
        isFalse,
      );
      expect(
        await IpAddressScope.isPubliclyRoutableHost('fe80::1'),
        isFalse,
      );
      expect(
        await IpAddressScope.isPubliclyRoutableHost('fc00::1'),
        isFalse,
      );
      expect(
        await IpAddressScope.isPubliclyRoutableHost('ff02::1'),
        isFalse,
      );
      expect(
        await IpAddressScope.isPubliclyRoutableHost('2001:db8::1'),
        isFalse,
      );
      expect(
        await IpAddressScope.isPubliclyRoutableHost('::ffff:127.0.0.1'),
        isFalse,
      );
      expect(
        await IpAddressScope.isPubliclyRoutableHost('::ffff:192.168.1.1'),
        isFalse,
      );
      expect(
        await IpAddressScope.isPubliclyRoutableHost('::ffff:10.0.0.1'),
        isFalse,
      );
    });

    test('rejects hostnames that resolve to loopback', () async {
      expect(
        await IpAddressScope.isPubliclyRoutableHost(
          'localtest.me',
          lookup: _resolve,
        ),
        isFalse,
      );
      expect(
        await IpAddressScope.isPubliclyRoutableHost(
          '127.1',
          lookup: _resolve,
        ),
        isFalse,
      );
    });

    test('accepts hostnames that resolve to public addresses', () async {
      expect(
        await IpAddressScope.isPubliclyRoutableHost(
          'example.com',
          lookup: _resolve,
        ),
        isTrue,
      );
    });

    test('accepts public IP literals', () async {
      expect(
        await IpAddressScope.isPubliclyRoutableHost('8.8.8.8'),
        isTrue,
      );
      expect(
        await IpAddressScope.isPubliclyRoutableHost('2001:4860:4860::8888'),
        isTrue,
      );
      expect(
        await IpAddressScope.isPubliclyRoutableHost('::ffff:8.8.8.8'),
        isTrue,
      );
    });
  });

  group('IpAddressScope.isPubliclyRoutableLink', () {
    test('accepts public .torrent URLs', () async {
      expect(
        await IpAddressScope.isPubliclyRoutableLink(
          'https://example.com/file.torrent',
          lookup: _resolve,
        ),
        isTrue,
      );
    });

    test('rejects .torrent URLs with private hosts', () async {
      expect(
        await IpAddressScope.isPubliclyRoutableLink(
          'http://192.168.1.1/seed.torrent',
        ),
        isFalse,
      );
      expect(
        await IpAddressScope.isPubliclyRoutableLink(
          'http://[::ffff:127.0.0.1]/seed.torrent',
        ),
        isFalse,
      );
      expect(
        await IpAddressScope.isPubliclyRoutableLink(
          'http://127.1/seed.torrent',
        ),
        isFalse,
      );
    });

    test('rejects malformed schemes and missing extensions', () async {
      expect(
        await IpAddressScope.isPubliclyRoutableLink(
          'ftp://example.com/seed.torrent',
        ),
        isFalse,
      );
      expect(
        await IpAddressScope.isPubliclyRoutableLink(
          'https://example.com/seed.zip',
        ),
        isFalse,
      );
    });

    test('validates magnet tracker hosts', () async {
      expect(
        await IpAddressScope.isPubliclyRoutableLink(
          'magnet:?xt=urn:btih:abc&dn=foo',
        ),
        isTrue,
      );
      expect(
        await IpAddressScope.isPubliclyRoutableLink(
          'magnet:?xt=urn:btih:abc&tr=http%3A%2F%2Fexample.com%2Fannounce',
          lookup: _resolve,
        ),
        isTrue,
      );
      expect(
        await IpAddressScope.isPubliclyRoutableLink(
          'magnet:?xt=urn:btih:abc&tr=http%3A%2F%2F127.0.0.1%2Fannounce',
        ),
        isFalse,
      );
      expect(
        await IpAddressScope.isPubliclyRoutableLink(
          'magnet:?xt=urn:btih:abc&tr=udp%3A%2F%2F192.168.1.1%3A1337',
        ),
        isFalse,
      );
    });
  });
}

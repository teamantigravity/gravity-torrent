import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gravity_torrent/services/blocklist_service.dart';

Future<List<InternetAddress>> _lookup(String host) async {
  final address = InternetAddress.tryParse(host);
  if (address != null) return [address];
  if (host == 'example.com') return [InternetAddress('8.8.8.8')];
  if (host == 'localtest.me') return [InternetAddress.loopbackIPv4];
  throw const SocketException('unknown host');
}

void main() {
  group('BlocklistService.isValidBlocklistUrl', () {
    test('accepts empty URL (disabled)', () async {
      expect(await BlocklistService.isValidBlocklistUrl(''), isTrue);
    });

    test('accepts public HTTPS URL', () async {
      expect(
        await BlocklistService.isValidBlocklistUrl(
          'https://example.com/blocklist.txt',
          lookup: _lookup,
        ),
        isTrue,
      );
    });

    test('rejects non-http schemes', () async {
      expect(
        await BlocklistService.isValidBlocklistUrl(
          'ftp://example.com/list.txt',
        ),
        isFalse,
      );
    });

    test('rejects localhost', () async {
      expect(
        await BlocklistService.isValidBlocklistUrl(
          'http://localhost/list.txt',
        ),
        isFalse,
      );
    });

    test('rejects private 10.x.x.x', () async {
      expect(
        await BlocklistService.isValidBlocklistUrl(
          'http://10.0.0.1/blocklist.txt',
        ),
        isFalse,
      );
    });

    test('rejects private 192.168.x.x', () async {
      expect(
        await BlocklistService.isValidBlocklistUrl(
          'http://192.168.1.1/blocklist.txt',
        ),
        isFalse,
      );
    });

    test('rejects private 172.16/12 range', () async {
      expect(
        await BlocklistService.isValidBlocklistUrl(
          'http://172.16.0.1/blocklist.txt',
        ),
        isFalse,
      );
      expect(
        await BlocklistService.isValidBlocklistUrl(
          'http://172.31.255.255/blocklist.txt',
        ),
        isFalse,
      );
    });

    test('accepts public 172.x addresses outside 172.16/12', () async {
      // This is the regression case: the old prefix check rejected all 172.* hosts.
      expect(
        await BlocklistService.isValidBlocklistUrl(
          'http://172.217.0.0/blocklist.txt',
        ),
        isTrue,
      );
    });

    test('rejects 169.254 link-local range', () async {
      expect(
        await BlocklistService.isValidBlocklistUrl(
          'http://169.254.1.1/blocklist.txt',
        ),
        isFalse,
      );
    });

    test('rejects IPv6 loopback', () async {
      expect(
        await BlocklistService.isValidBlocklistUrl(
            'http://[::1]/blocklist.txt',),
        isFalse,
      );
    });

    test('rejects IPv6 unique-local', () async {
      expect(
        await BlocklistService.isValidBlocklistUrl(
          'http://[fc00::1]/blocklist.txt',
        ),
        isFalse,
      );
    });

    test('rejects IPv6 link-local', () async {
      expect(
        await BlocklistService.isValidBlocklistUrl(
          'http://[fe80::1]/blocklist.txt',
        ),
        isFalse,
      );
    });

    test('rejects IPv4-mapped private IPv6', () async {
      expect(
        await BlocklistService.isValidBlocklistUrl(
          'http://[::ffff:192.168.1.1]/blocklist.txt',
        ),
        isFalse,
      );
      expect(
        await BlocklistService.isValidBlocklistUrl(
          'http://[::ffff:10.0.0.1]/blocklist.txt',
        ),
        isFalse,
      );
      expect(
        await BlocklistService.isValidBlocklistUrl(
          'http://[::ffff:127.0.0.1]/blocklist.txt',
        ),
        isFalse,
      );
    });

    test('rejects CGNAT and unspecified ranges', () async {
      expect(
        await BlocklistService.isValidBlocklistUrl(
          'http://100.64.0.1/blocklist.txt',
        ),
        isFalse,
      );
      expect(
        await BlocklistService.isValidBlocklistUrl(
          'http://0.0.0.0/blocklist.txt',
        ),
        isFalse,
      );
    });

    test('rejects IPv6 documentation, multicast and unspecified', () async {
      expect(
        await BlocklistService.isValidBlocklistUrl(
          'http://[::]/blocklist.txt',
        ),
        isFalse,
      );
      expect(
        await BlocklistService.isValidBlocklistUrl(
          'http://[ff02::1]/blocklist.txt',
        ),
        isFalse,
      );
      expect(
        await BlocklistService.isValidBlocklistUrl(
          'http://[2001:db8::1]/blocklist.txt',
        ),
        isFalse,
      );
    });

    test('rejects hostnames that resolve to loopback', () async {
      expect(
        await BlocklistService.isValidBlocklistUrl(
          'http://localtest.me/blocklist.txt',
          lookup: _lookup,
        ),
        isFalse,
      );
    });

    test('rejects userinfo in URLs', () async {
      expect(
        await BlocklistService.isValidBlocklistUrl(
          'http://user:pass@example.com/blocklist.txt',
          lookup: _lookup,
        ),
        isFalse,
      );
    });
  });
}

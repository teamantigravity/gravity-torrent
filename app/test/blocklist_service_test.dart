import 'package:flutter_test/flutter_test.dart';
import 'package:gravity_torrent/services/blocklist_service.dart';

void main() {
  group('BlocklistService.isValidBlocklistUrl', () {
    test('accepts empty URL (disabled)', () {
      expect(BlocklistService.isValidBlocklistUrl(''), isTrue);
    });

    test('accepts public HTTPS URL', () {
      expect(
        BlocklistService.isValidBlocklistUrl(
          'https://example.com/blocklist.txt',
        ),
        isTrue,
      );
    });

    test('rejects non-http schemes', () {
      expect(
        BlocklistService.isValidBlocklistUrl('ftp://example.com/list.txt'),
        isFalse,
      );
    });

    test('rejects localhost', () {
      expect(
        BlocklistService.isValidBlocklistUrl('http://localhost/list.txt'),
        isFalse,
      );
    });

    test('rejects private 10.x.x.x', () {
      expect(
        BlocklistService.isValidBlocklistUrl(
          'http://10.0.0.1/blocklist.txt',
        ),
        isFalse,
      );
    });

    test('rejects private 192.168.x.x', () {
      expect(
        BlocklistService.isValidBlocklistUrl(
          'http://192.168.1.1/blocklist.txt',
        ),
        isFalse,
      );
    });

    test('rejects private 172.16/12 range', () {
      expect(
        BlocklistService.isValidBlocklistUrl(
          'http://172.16.0.1/blocklist.txt',
        ),
        isFalse,
      );
      expect(
        BlocklistService.isValidBlocklistUrl(
          'http://172.31.255.255/blocklist.txt',
        ),
        isFalse,
      );
    });

    test('accepts public 172.x addresses outside 172.16/12', () {
      // This is the regression case: the old prefix check rejected all 172.* hosts.
      expect(
        BlocklistService.isValidBlocklistUrl(
          'http://172.217.0.0/blocklist.txt',
        ),
        isTrue,
      );
    });

    test('rejects 169.254 link-local range', () {
      expect(
        BlocklistService.isValidBlocklistUrl(
          'http://169.254.1.1/blocklist.txt',
        ),
        isFalse,
      );
    });

    test('rejects IPv6 loopback', () {
      expect(
        BlocklistService.isValidBlocklistUrl('http://[::1]/blocklist.txt'),
        isFalse,
      );
    });

    test('rejects IPv6 unique-local', () {
      expect(
        BlocklistService.isValidBlocklistUrl(
          'http://[fc00::1]/blocklist.txt',
        ),
        isFalse,
      );
    });

    test('rejects IPv6 link-local', () {
      expect(
        BlocklistService.isValidBlocklistUrl(
          'http://[fe80::1]/blocklist.txt',
        ),
        isFalse,
      );
    });
  });
}

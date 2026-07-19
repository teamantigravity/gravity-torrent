import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gravity_torrent/services/remote_control_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('generateSecureRandomToken', () {
    test('is generated with a cryptographically secure source', () {
      final token = generateSecureRandomToken();
      expect(token, isNotEmpty);
      expect(token.length, greaterThanOrEqualTo(32));
      expect(token, matches(r'^[A-Za-z0-9_-]+$'));
    });

    test('changes between invocations', () {
      final a = generateSecureRandomToken();
      final b = generateSecureRandomToken();
      expect(a, isNot(equals(b)));
    });
  });

  group('RemoteControlService IP helpers', () {
    test('formatHostForUrl wraps IPv6 in brackets', () {
      final service = RemoteControlService.instance;
      expect(service.formatHostForUrl('192.168.1.10'), '192.168.1.10');
      expect(
        service.formatHostForUrl('fe80::1'),
        '[fe80::1]',
      );
    });

    test('isPrivateIp recognizes IPv4 private ranges', () {
      final service = RemoteControlService.instance;
      expect(service.isPrivateIp(InternetAddress('10.0.0.1')), isTrue);
      expect(service.isPrivateIp(InternetAddress('172.16.0.1')), isTrue);
      expect(service.isPrivateIp(InternetAddress('172.31.255.255')), isTrue);
      expect(service.isPrivateIp(InternetAddress('192.168.1.1')), isTrue);
      expect(service.isPrivateIp(InternetAddress('8.8.8.8')), isFalse);
      expect(service.isPrivateIp(InternetAddress('127.0.0.1')), isTrue);
    });

    test('isPrivateIp recognizes IPv6 private ranges', () {
      final service = RemoteControlService.instance;
      expect(service.isPrivateIp(InternetAddress('fe80::1')), isTrue);
      expect(service.isPrivateIp(InternetAddress('fd00::1')), isTrue);
      expect(service.isPrivateIp(InternetAddress('fc00::1')), isTrue);
      expect(service.isPrivateIp(InternetAddress('::1')), isTrue);
      expect(service.isPrivateIp(InternetAddress('2001:4860:4860::8888')),
          isFalse);
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:gravity_torrent/engine/session.dart';
import 'package:gravity_torrent/engine/transmission/models/session_set_request.dart';

void main() {
  group('session-set encoding', () {
    test('encodes privacy & security fields with correct RPC keys', () {
      final request = SessionSetRequest(
        arguments: SessionSetRequestArguments(
          encryption: EncryptionMode.required.rpcValue,
          blocklistEnabled: true,
          blocklistUrl: 'https://example.com/list.gz',
          dhtEnabled: false,
          pexEnabled: false,
          lpdEnabled: true,
          utpEnabled: false,
        ),
      );

      final json = request.toJson()['arguments'] as Map<String, dynamic>;
      expect(json['encryption'], 'required');
      expect(json['blocklist-enabled'], isTrue);
      expect(json['blocklist-url'], 'https://example.com/list.gz');
      expect(json['dht-enabled'], isFalse);
      expect(json['pex-enabled'], isFalse);
      expect(json['lpd-enabled'], isTrue);
      expect(json['utp-enabled'], isFalse);
    });

    test('encodes alt-speed (turtle) scheduler fields', () {
      final request = SessionSetRequest(
        arguments: SessionSetRequestArguments(
          altSpeedEnabled: true,
          altSpeedDown: 100,
          altSpeedUp: 50,
          altSpeedTimeEnabled: true,
          altSpeedTimeBegin: 540,
          altSpeedTimeEnd: 1020,
          altSpeedTimeDay: 127,
        ),
      );

      final json = request.toJson()['arguments'] as Map<String, dynamic>;
      expect(json['alt-speed-enabled'], isTrue);
      expect(json['alt-speed-down'], 100);
      expect(json['alt-speed-up'], 50);
      expect(json['alt-speed-time-enabled'], isTrue);
      expect(json['alt-speed-time-begin'], 540);
      expect(json['alt-speed-time-end'], 1020);
      expect(json['alt-speed-time-day'], 127);
    });

    test('encodes seeding limits', () {
      final request = SessionSetRequest(
        arguments: SessionSetRequestArguments(
          seedRatioLimit: 2.5,
          seedRatioLimited: true,
          idleSeedingLimit: 30,
          idleSeedingLimitEnabled: true,
        ),
      );

      final json = request.toJson()['arguments'] as Map<String, dynamic>;
      expect(json['seedRatioLimit'], 2.5);
      expect(json['seedRatioLimited'], isTrue);
      expect(json['idle-seeding-limit'], 30);
      expect(json['idle-seeding-limit-enabled'], isTrue);
    });

    test('omits null fields from the payload', () {
      final request =
          SessionSetRequest(arguments: SessionSetRequestArguments());
      final json = request.toJson()['arguments'] as Map<String, dynamic>;
      expect(json.isEmpty, isTrue);
    });
  });

  group('EncryptionMode', () {
    test('round-trips RPC values', () {
      for (final mode in EncryptionMode.values) {
        expect(EncryptionMode.fromRpcValue(mode.rpcValue), mode);
      }
    });

    test('defaults to preferred for unknown values', () {
      expect(EncryptionMode.fromRpcValue(null), EncryptionMode.preferred);
      expect(EncryptionMode.fromRpcValue('bogus'), EncryptionMode.preferred);
    });
  });
}

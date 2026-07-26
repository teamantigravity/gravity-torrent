import 'package:flutter_test/flutter_test.dart';
import 'package:gravity_torrent/utils/secure_token.dart';

void main() {
  group('generateSecureRandomToken', () {
    test('is URL safe and long enough to be unguessable', () {
      final token = generateSecureRandomToken();
      expect(token, matches(r'^[A-Za-z0-9_-]+$'));
      expect(token.length, greaterThanOrEqualTo(32));
    });

    test('honours the requested byte length', () {
      expect(
        generateSecureRandomToken(length: 16).length,
        greaterThanOrEqualTo(16),
      );
    });

    test('changes between invocations', () {
      expect(
        generateSecureRandomToken(),
        isNot(equals(generateSecureRandomToken())),
      );
    });
  });

  group('pathCarriesToken', () {
    const token = 'abc123';

    test('accepts the token as the first path segment', () {
      expect(pathCarriesToken('/$token', token), isTrue);
      expect(pathCarriesToken(token, token), isTrue);
      expect(pathCarriesToken('/$token/file.mkv', token), isTrue);
      expect(pathCarriesToken('//$token', token), isTrue);
    });

    test('rejects a prefix or suffix of the token', () {
      expect(pathCarriesToken('/abc', token), isFalse);
      expect(pathCarriesToken('/abc123x', token), isFalse);
      expect(pathCarriesToken('/xabc123', token), isFalse);
    });

    test('rejects the token in a later segment', () {
      expect(pathCarriesToken('/other/$token', token), isFalse);
    });

    test('rejects an empty request path', () {
      expect(pathCarriesToken('', token), isFalse);
      expect(pathCarriesToken('/', token), isFalse);
    });

    test('never authorises when the token is empty', () {
      expect(pathCarriesToken('/', ''), isFalse);
      expect(pathCarriesToken('', ''), isFalse);
      expect(pathCarriesToken('/anything', ''), isFalse);
    });
  });
}

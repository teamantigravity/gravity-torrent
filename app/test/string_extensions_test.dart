import 'package:flutter_test/flutter_test.dart';
import 'package:gravity_torrent/utils/string_extensions.dart';

void main() {
  group('String.capitalize', () {
    test('capitalizes the first letter', () {
      expect('hello'.capitalize(), 'Hello');
    });

    test('leaves already-capitalized strings unchanged', () {
      expect('World'.capitalize(), 'World');
    });

    test('handles single-character strings', () {
      expect('a'.capitalize(), 'A');
    });

    test('returns empty string unchanged instead of throwing', () {
      expect(''.capitalize(), '');
    });
  });
}

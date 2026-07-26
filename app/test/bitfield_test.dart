import 'dart:typed_data';

import 'package:gravity_torrent/utils/bitfield.dart';
import 'package:test/test.dart';

void main() {
  group('convertBitfieldToBoolList', () {
    test('full bitfield', () {
      final Uint8List bitfield = Uint8List.fromList([255, 255]);
      const int pieceCount = 16;
      final List<bool> expected = List.filled(16, true);

      expect(convertBitfieldToBoolList(bitfield, pieceCount), equals(expected));
    });

    test('partial bitfield', () {
      final Uint8List bitfield =
          Uint8List.fromList([192, 0]); // 11000000 00000000
      const int pieceCount = 16;
      final List<bool> expected = [
        true,
        true,
        false,
        false,
        false,
        false,
        false,
        false,
        false,
        false,
        false,
        false,
        false,
        false,
        false,
        false,
      ];

      expect(convertBitfieldToBoolList(bitfield, pieceCount), equals(expected));
    });

    test('bitfield with fewer pieces than available bits', () {
      final Uint8List bitfield = Uint8List.fromList([255, 255]);
      const int pieceCount = 10;
      final List<bool> expected = List.filled(10, true);

      expect(convertBitfieldToBoolList(bitfield, pieceCount), equals(expected));
    });

    test('empty bitfield pads to pieceCount with false', () {
      final Uint8List bitfield = Uint8List.fromList([]);
      const int pieceCount = 10;
      final List<bool> expected = List.filled(10, false);

      expect(convertBitfieldToBoolList(bitfield, pieceCount), equals(expected));
    });

    test('one byte bitfield, some missing', () {
      final Uint8List bitfield = Uint8List.fromList([170]); // 10101010
      const int pieceCount = 8;
      final List<bool> expected = [
        true,
        false,
        true,
        false,
        true,
        false,
        true,
        false,
      ];

      expect(convertBitfieldToBoolList(bitfield, pieceCount), equals(expected));
    });

    test('pieceCount greater than bitfield length pads missing pieces', () {
      final Uint8List bitfield = Uint8List.fromList([255]);
      const int pieceCount = 9;
      final List<bool> expected = [
        true,
        true,
        true,
        true,
        true,
        true,
        true,
        true,
        false,
      ];

      expect(convertBitfieldToBoolList(bitfield, pieceCount), equals(expected));
      expect(
        convertBitfieldToBoolList(bitfield, pieceCount).length,
        pieceCount,
      );
    });
  });
}

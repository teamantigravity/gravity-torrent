import 'dart:typed_data';

/// Converts a Transmission piece bitfield into a list of booleans of exactly
/// [pieceCount] entries. Any pieces not covered by [bitfield] (e.g. a truncated
/// or empty bitfield) default to `false` so callers can safely index the full
/// [pieceCount] range without a [RangeError].
List<bool> convertBitfieldToBoolList(Uint8List bitfield, int pieceCount) {
  final List<bool> piecesAsBool = List<bool>.filled(pieceCount, false);
  int pieceIndex = 0;

  for (final int byte in bitfield) {
    for (int bitIndex = 7; bitIndex >= 0; bitIndex--) {
      if (pieceIndex >= pieceCount) {
        return piecesAsBool; // Stop once all pieces are filled
      }

      final int bit = (byte >> bitIndex) & 1;
      piecesAsBool[pieceIndex] = bit == 1;
      pieceIndex++;
    }
  }

  return piecesAsBool;
}

/// Which characters a font can draw, read from its `cmap` table, and the
/// same-width placeholder used for the rest. Pure Dart; no Flutter imports.
///
/// The reader never lets the system substitute a fallback font: a fallback
/// glyph has its own width and would shift every column after it.
library;

import 'dart:typed_data';

class GlyphCoverage {
  GlyphCoverage(Set<int> codePoints)
    : codePoints = Set.unmodifiable(codePoints),
      placeholder = _placeholderCandidates.firstWhere(
        codePoints.contains,
        orElse: () => 0x3F,
      );

  /// Reads the Unicode subtables (formats 4 and 12) of a TrueType or
  /// OpenType font. Throws [FormatException] if the font has no usable cmap.
  factory GlyphCoverage.fromFontBytes(Uint8List font) =>
      GlyphCoverage(readCmapCodePoints(font));

  final Set<int> codePoints;

  /// Drawn in place of characters the font lacks: a middle dot where the
  /// font has one, else `?`. It is a glyph of this font, so it is exactly
  /// one column wide.
  final int placeholder;

  bool covers(int codePoint) => codePoints.contains(codePoint);

  /// Characters in [inventory] this font cannot draw.
  List<int> missing(Iterable<int> inventory) => [
    for (final c in inventory)
      if (!codePoints.contains(c)) c,
  ];

  bool coversAll(Iterable<int> inventory) =>
      inventory.every(codePoints.contains);

  /// [line] with every character this font lacks replaced by
  /// [placeholder]: one code point for one, so columns never move.
  String substitute(String line) {
    if (line.runes.every(codePoints.contains)) return line;
    return String.fromCharCodes([
      for (final r in line.runes) codePoints.contains(r) ? r : placeholder,
    ]);
  }
}

// U+00B7 MIDDLE DOT, else '?'. Not U+2219: some retro fonts (C64 Pro Mono)
// draw it as a heavy disc, indistinguishable from real bullets in the text.
const _placeholderCandidates = [0xB7];

Set<int> readCmapCodePoints(Uint8List font) {
  final data = ByteData.sublistView(font);
  int u16(int at) => data.getUint16(at);
  int u32(int at) => data.getUint32(at);
  try {
    final numTables = u16(4);
    int? cmap;
    for (var i = 0; i < numTables; i++) {
      final record = 12 + i * 16;
      if (String.fromCharCodes(font.sublist(record, record + 4)) == 'cmap') {
        cmap = u32(record + 8);
      }
    }
    if (cmap == null) throw const FormatException('font has no cmap table');

    final codePoints = <int>{};
    final subtables = u16(cmap + 2);
    for (var i = 0; i < subtables; i++) {
      final record = cmap + 4 + i * 8;
      final platform = u16(record);
      final encoding = u16(record + 2);
      final isUnicode =
          platform == 0 || (platform == 3 && (encoding == 1 || encoding == 10));
      if (!isUnicode) continue;
      final table = cmap + u32(record + 4);
      switch (u16(table)) {
        case 4:
          _readFormat4(data, table, codePoints);
        case 12:
          _readFormat12(data, table, codePoints);
      }
    }
    if (codePoints.isEmpty) {
      throw const FormatException('font has no Unicode cmap subtable');
    }
    return codePoints;
  } on RangeError {
    throw const FormatException('font file is truncated or malformed');
  }
}

void _readFormat4(ByteData data, int table, Set<int> out) {
  final segments = data.getUint16(table + 6) ~/ 2;
  final ends = table + 14;
  final starts = ends + segments * 2 + 2;
  final deltas = starts + segments * 2;
  final rangeOffsets = deltas + segments * 2;
  for (var s = 0; s < segments; s++) {
    final end = data.getUint16(ends + s * 2);
    final start = data.getUint16(starts + s * 2);
    final delta = data.getUint16(deltas + s * 2);
    final rangeOffsetAt = rangeOffsets + s * 2;
    final rangeOffset = data.getUint16(rangeOffsetAt);
    for (var c = start; c <= end && c != 0xFFFF; c++) {
      int glyph;
      if (rangeOffset == 0) {
        glyph = (c + delta) & 0xFFFF;
      } else {
        glyph = data.getUint16(rangeOffsetAt + rangeOffset + (c - start) * 2);
        if (glyph != 0) glyph = (glyph + delta) & 0xFFFF;
      }
      if (glyph != 0) out.add(c);
    }
  }
}

void _readFormat12(ByteData data, int table, Set<int> out) {
  final groups = data.getUint32(table + 12);
  for (var g = 0; g < groups; g++) {
    final group = table + 16 + g * 12;
    final start = data.getUint32(group);
    final end = data.getUint32(group + 4);
    final firstGlyph = data.getUint32(group + 8);
    for (var c = start; c <= end; c++) {
      if (firstGlyph + (c - start) != 0) out.add(c);
    }
  }
}

import 'package:atdt/layout/reading_position.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ReadingPosition.fromOffsets', () {
    test('splits a vertical offset into line index and fraction', () {
      final p = ReadingPosition.fromOffsets(
        verticalOffset: 105,
        horizontalOffset: 0,
        lineHeight: 10,
        glyphAdvance: 5,
      );

      expect(p.topLineIndex, 10);
      expect(p.fractionIntoLine, closeTo(0.5, 1e-9));
      expect(p.columnOffset, 0);
    });

    test('expresses horizontal offset in columns', () {
      final p = ReadingPosition.fromOffsets(
        verticalOffset: 0,
        horizontalOffset: 26,
        lineHeight: 10,
        glyphAdvance: 4,
      );

      expect(p.columnOffset, closeTo(6.5, 1e-9));
    });

    test('negative overscroll clamps to the top', () {
      final p = ReadingPosition.fromOffsets(
        verticalOffset: -40,
        horizontalOffset: -3,
        lineHeight: 10,
        glyphAdvance: 4,
      );

      expect(p, const ReadingPosition.top());
    });
  });

  group('round trip through a metrics change', () {
    test('rotation keeps the same top line and column', () {
      // Portrait: small glyphs.
      final before = ReadingPosition.fromOffsets(
        verticalOffset: 4321.7,
        horizontalOffset: 120,
        lineHeight: 9.6,
        glyphAdvance: 4.8,
      );

      // Landscape: bigger glyphs.
      const lineHeight = 21.0;
      const advance = 10.5;
      final v = before.verticalOffset(lineHeight);
      final h = before.horizontalOffset(advance);
      final after = ReadingPosition.fromOffsets(
        verticalOffset: v,
        horizontalOffset: h,
        lineHeight: lineHeight,
        glyphAdvance: advance,
      );

      expect(after.topLineIndex, before.topLineIndex);
      expect(after.fractionIntoLine, closeTo(before.fractionIntoLine, 1e-9));
      expect(after.columnOffset, closeTo(before.columnOffset, 1e-9));
    });

    // Each pair is a line index and a snapped line height (29/3 is the 3x
    // vector-font height; 32/2.75 is a 2.75x pixel-font height) for which
    // (n * h) / h comes back just below n in floating point.
    const boundaryCases = [(7, 29 / 3), (3, 32 / 2.75), (13, 21.7)];
    for (final (line, height) in boundaryCases) {
      test(
        'line $line at height $height does not slip to line ${line - 1}',
        () {
          final p = ReadingPosition.fromOffsets(
            verticalOffset: ReadingPosition(
              topLineIndex: line,
              fractionIntoLine: 0,
              columnOffset: 0,
            ).verticalOffset(height),
            horizontalOffset: 0,
            lineHeight: height,
            glyphAdvance: 1,
          );

          expect(p.topLineIndex, line);
          expect(p.fractionIntoLine, 0);
        },
      );
    }
  });

  group('offsets', () {
    test('vertical offset is (line + fraction) * lineHeight', () {
      const p = ReadingPosition(
        topLineIndex: 7,
        fractionIntoLine: 0.25,
        columnOffset: 3,
      );

      expect(p.verticalOffset(12), closeTo(87, 1e-9));
      expect(p.horizontalOffset(5), closeTo(15, 1e-9));
    });
  });
}

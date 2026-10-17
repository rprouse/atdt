import 'dart:io';
import 'dart:typed_data';

import 'package:atdt/fonts/glyph_coverage.dart';
import 'package:flutter_test/flutter_test.dart';

GlyphCoverage _font(String file) => GlyphCoverage.fromFontBytes(
  File('assets/fonts/files/$file').readAsBytesSync(),
);

void main() {
  group('reading cmap', () {
    // Counts from fontTools (union of Unicode subtables, .notdef excluded):
    // an independent implementation checking ours.
    const expected = {
      'BigBlue_TerminalPlus.TTF': 781,
      'C64_Pro_Mono-STYLE.ttf': 1496,
      'IBMPlexMono-Regular.ttf': 930,
      'JetBrainsMono-Regular.ttf': 1363, // formats 4 and 12
      'TerminusTTF-4.49.3.ttf': 1356,
    };
    for (final MapEntry(key: file, value: count) in expected.entries) {
      test('$file has $count code points', () {
        expect(_font(file).codePoints, hasLength(count));
      });
    }

    test('known coverage facts', () {
      final jbm = _font('JetBrainsMono-Regular.ttf');
      expect(jbm.coversAll([for (var c = 0x2500; c <= 0x257F; c++) c]), isTrue);
      expect(jbm.covers(0x2665), isFalse, reason: 'no ♥');
      final c64 = _font('C64_Pro_Mono-STYLE.ttf');
      expect(c64.covers(0xE9), isFalse, reason: 'no é');
      final terminus = _font('TerminusTTF-4.49.3.ttf');
      expect(terminus.coversAll('♥☺⌠⌡ⁿ╔═╗'.runes), isTrue);
    });

    test('rejects data that is not a font', () {
      expect(
        () => GlyphCoverage.fromFontBytes(Uint8List.fromList([1, 2, 3])),
        throwsFormatException,
      );
    });
  });

  group('placeholder', () {
    test('prefers a middle dot the font actually has', () {
      expect(_font('JetBrainsMono-Regular.ttf').placeholder, 0xB7);
      // C64 Pro Mono has no U+00B7; its U+2219 is a heavy disc that reads
      // as content, so it gets '?'.
      expect(_font('C64_Pro_Mono-STYLE.ttf').placeholder, 0x3F);
      expect(GlyphCoverage({0x41}).placeholder, 0x3F);
    });

    test('every bundled font draws its own placeholder', () {
      for (final file in Directory('assets/fonts/files').listSync()) {
        final coverage = GlyphCoverage.fromFontBytes(
          (file as File).readAsBytesSync(),
        );
        expect(
          coverage.covers(coverage.placeholder),
          isTrue,
          reason: file.path,
        );
      }
    });
  });

  group('substitute', () {
    final coverage = GlyphCoverage({...'ab ?'.runes, 0xB7});

    test('replaces missing characters one for one', () {
      final out = coverage.substitute('a♥b é');
      expect(out, 'a·b ·');
      expect(out.runes.length, 'a♥b é'.runes.length);
    });

    test('returns the same string when everything is covered', () {
      const line = 'ab ab';
      expect(identical(coverage.substitute(line), line), isTrue);
    });

    test('a character outside the BMP is one column, one placeholder', () {
      expect(coverage.substitute('a\u{1F600}b'), 'a·b');
    });

    test('missing lists the inventory the font cannot draw', () {
      expect(coverage.missing('ab♥é'.runes), [0x2665, 0xE9]);
      expect(coverage.coversAll('ba'.runes), isTrue);
    });
  });
}

import 'dart:convert';

import 'package:atdt/ingest/code_pages.dart';
import 'package:atdt/ingest/decode.dart';
import 'package:atdt/ingest/front_matter.dart';
import 'package:atdt/ingest/normalize.dart';
import 'package:atdt/ingest/phile_text.dart';
import 'package:flutter_test/flutter_test.dart';

List<String> _lines(String text, [TextEncoding enc = TextEncoding.utf8]) =>
    normalizeText(text, encoding: enc).lines;

void main() {
  group('decodeBytes', () {
    test('strips a UTF-8 byte order mark', () {
      final d = decodeBytes([0xEF, 0xBB, 0xBF, ...utf8.encode('hi')]);
      expect(d.text, 'hi');
      expect(d.encoding, TextEncoding.utf8);
    });

    test('pure ASCII is UTF-8', () {
      expect(decodeBytes(ascii.encode('plain')).encoding, TextEncoding.utf8);
    });

    test('box-drawing runs vote CP437', () {
      final d = decodeBytes([0xDA, 0xC4, 0xC4, 0xBF, 0x20, 0x41]);
      expect(d.encoding, TextEncoding.cp437);
      expect(d.text, '┌──┐ A');
      expect(d.ambiguous, isFalse);
    });

    test('accented letters inside words vote Latin-1', () {
      final d = decodeBytes(latin1.encode('déjà vu, naïve, señor'));
      expect(d.encoding, TextEncoding.latin1);
      expect(d.ambiguous, isFalse);
    });

    test('CP437 accented letters with no other evidence lean CP437', () {
      // "café" in CP437 (0x82 = é); in Windows-1252 0x82 is a low quote.
      final d = decodeBytes([...ascii.encode('caf'), 0x82]);
      expect(d.encoding, TextEncoding.cp437);
      expect(d.text, 'café');
      expect(d.ambiguous, isTrue);
    });

    test('Windows-1252 punctuation alone means Windows-1252', () {
      final d = decodeBytes([
        ...ascii.encode('it'),
        0x92,
        ...ascii.encode('s'),
      ]);
      expect(d.encoding, TextEncoding.windows1252);
      expect(d.text, 'it’s');
    });
  });

  group('splitFrontMatter', () {
    List<int> b(String s) => utf8.encode(s);

    test('parses keys and strips quotes', () {
      final r = splitFrontMatter(
        b('---\ntitle: \'Quoted\'\nauthor: "A \\"B\\" C"\n---\nbody\n'),
      )!;
      expect(r.fields, {'title': 'Quoted', 'author': 'A "B" C'});
      expect(utf8.decode(r.body), 'body\n');
    });

    test('accepts CRLF line endings', () {
      final r = splitFrontMatter(b('---\r\ntitle: X\r\n---\r\nbody'))!;
      expect(r.fields, {'title': 'X'});
      expect(utf8.decode(r.body), 'body');
    });

    test('rejects blocks that are not key: value lines', () {
      expect(splitFrontMatter(b('---\nnot yaml\n---\nbody')), isNull);
      expect(splitFrontMatter(b('---\n---\nbody')), isNull);
      expect(splitFrontMatter(b('--- title: x\n---\n')), isNull);
    });

    test('rejects a block with no closing line', () {
      expect(splitFrontMatter(b('---\ntitle: x\nbody text\n')), isNull);
    });

    test('ignores text that does not start with ---', () {
      expect(splitFrontMatter(b('title: x\n---\n')), isNull);
    });
  });

  group('normalizeText', () {
    test('form feed in the middle of a line', () {
      expect(_lines('abc\fdef\n'), ['abc', '', 'def']);
      expect(_lines('\fstart\n'), ['', 'start']);
      expect(_lines('end\f\n'), ['end', '']);
    });

    test('preserves trailing whitespace', () {
      expect(_lines('trailing   \nnext\n'), ['trailing   ', 'next']);
    });

    test('keeps a final empty line that is really there', () {
      expect(_lines('a\n\n'), ['a', '']);
      expect(_lines('a'), ['a']);
    });

    test('a lone ESC that starts no sequence becomes a placeholder', () {
      final r = normalizeText('x\x1Bqy\n', encoding: TextEncoding.utf8);
      expect(r.lines, ['x${controlPlaceholder}qy']);
      expect(r.controls.ansiSequences, 0);
    });

    test('in CP437 files a lone ESC is the left-arrow glyph', () {
      expect(_lines('x\x1Bqy\n', TextEncoding.cp437), ['x←qy']);
    });

    test('C1 controls become placeholders', () {
      expect(_lines('a\u0085b\n'), ['a${controlPlaceholder}b']);
    });

    test('columns count code points, not UTF-16 units', () {
      final r = normalizeText('\u{1F600}\tx\n', encoding: TextEncoding.utf8);
      expect(r.lines.single, '\u{1F600}       x');
      expect(r.longestLineColumns, 9);
    });

    test('only trailing ^Z and NUL are padding', () {
      final r = normalizeText(
        'a\x1Ab\n\x1A\x00\x1A',
        encoding: TextEncoding.cp437,
      );
      expect(r.lines, ['a→b']);
      expect(r.controls.eofPadding, 3);
    });
  });
}

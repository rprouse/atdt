import 'dart:io';

import 'package:atdt/ingest/spike_text.dart';
import 'package:flutter_test/flutter_test.dart';

PhileText _fixture(String name) =>
    PhileText.fromBytes(File('test/fixtures/$name').readAsBytesSync());

void main() {
  group('expandTabs', () {
    test('expands to 8-column stops', () {
      expect(expandTabs('\tx'), '${' ' * 8}x');
      expect(expandTabs('x\ty'), 'x${' ' * 7}y');
      expect(expandTabs('xxxxxxx\ty'), 'xxxxxxx y');
      expect(expandTabs('xxxxxxxx\ty'), 'xxxxxxxx${' ' * 8}y');
      expect(expandTabs('\t\tz'), '${' ' * 16}z');
    });

    test('leaves tab-free lines untouched', () {
      expect(expandTabs('no tabs'), 'no tabs');
    });
  });

  group('line endings', () {
    const expected = ['first line', 'second line', '', 'fourth line'];

    for (final name in ['lf.txt', 'crlf.txt', 'lone_cr.txt']) {
      test('$name splits into the same lines', () {
        expect(_fixture(name).lines, expected);
      });
    }
  });

  group('decoding', () {
    test('valid UTF-8 decodes as UTF-8', () {
      final text = _fixture('box_drawing.txt');
      expect(text.lines.first, startsWith('┌──'));
      expect(text.encoding, 'utf-8');
    });

    test('invalid UTF-8 falls back to Latin-1', () {
      final text = _fixture('latin1_accented.txt');
      expect(text.lines.single, startsWith('Café, naïve'));
      expect(text.encoding, 'latin-1');
    });
  });

  group('stats', () {
    test('longest line counts columns after tab expansion', () {
      final text = _fixture('tabs_code.txt');
      // '\t\t\tprintf(...)' is 24 columns of indent plus the call.
      expect(
        text.longestLineColumns,
        24 + 'printf("%d\\t%s\\n", i, argv[i]);'.length,
      );
    });

    test('the 132-column fixture reports 132', () {
      expect(_fixture('widths_79_132.txt').longestLineColumns, 132);
    });

    test('the large fixture has 10,000 lines', () {
      final text = _fixture('ten_thousand_lines.txt');
      expect(text.lines, hasLength(10000));
      expect(text.longestLineColumns, 132);
    });

    test('an empty file has no lines', () {
      final text = _fixture('empty.txt');
      expect(text.lines, isEmpty);
      expect(text.longestLineColumns, 0);
    });
  });
}

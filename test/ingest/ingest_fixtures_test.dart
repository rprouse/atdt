// One test per synthetic fixture (Stage B acceptance), plus idempotence:
// normalising the output again must change nothing.
import 'dart:convert';
import 'dart:io';

import 'package:atdt/ingest/code_pages.dart';
import 'package:atdt/ingest/phile_text.dart';
import 'package:flutter_test/flutter_test.dart';

PhileText _ingest(String name) =>
    PhileText.fromBytes(File('test/fixtures/$name').readAsBytesSync());

const _p = controlPlaceholder;

void main() {
  group('fixtures', () {
    test('exact_80.txt', () {
      final t = _ingest('exact_80.txt');
      expect(t.lines, hasLength(5));
      expect(t.lines.every((l) => l.length == 80), isTrue);
      expect(t.longestLineColumns, 80);
      expect(t.encoding, TextEncoding.utf8);
    });

    test('widths_79_132.txt', () {
      final t = _ingest('widths_79_132.txt');
      expect(t.lines.map((l) => l.length), [47, 79, 80, 132, 30]);
      expect(t.longestLineColumns, 132);
    });

    test('tabs_code.txt expands to 8-column stops', () {
      final t = _ingest('tabs_code.txt');
      expect(t.lines[4], '        int i;');
      expect(t.lines[7], '${' ' * 24}printf("%d\\t%s\\n", i, argv[i]);');
      expect(t.lines[9], 'x       tab stop at 8');
      expect(t.lines[10], 'xxxxxxx stop at 8');
      expect(t.lines[11], 'xxxxxxxx        stop at 16');
      expect(t.lines.any((l) => l.contains('\t')), isFalse);
    });

    const endings = ['first line', 'second line', '', 'fourth line'];
    for (final name in ['lf.txt', 'crlf.txt', 'lone_cr.txt']) {
      test(name, () => expect(_ingest(name).lines, endings));
    }

    test('box_drawing.txt', () {
      final t = _ingest('box_drawing.txt');
      expect(t.encoding, TextEncoding.utf8);
      expect(t.lines.first, '┌──────────┬──────────┐');
      expect(t.lines[6], '░░░▒▒▒▓▓▓███ shades');
    });

    test('latin1_accented.txt', () {
      final t = _ingest('latin1_accented.txt');
      expect(t.encoding, TextEncoding.latin1);
      expect(t.lines, ['Café, naïve, Zoë, señor, Ångström, ½ ¼ ¾ ©']);
    });

    test('cp1252_quotes.txt', () {
      final t = _ingest('cp1252_quotes.txt');
      expect(t.encoding, TextEncoding.windows1252);
      expect(t.lines, ['He said “don’t” – twice.']);
    });

    test('cp437_high_bytes.txt', () {
      final t = _ingest('cp437_high_bytes.txt');
      expect(t.encoding, TextEncoding.cp437);
      expect(t.lines, ['╔══════════╗', '║ CP437    ║', '╚══════════╝', '░▒▓█']);
    });

    test('cp437_glyphs.txt shows 0x03 as a heart', () {
      final t = _ingest('cp437_glyphs.txt');
      expect(t.encoding, TextEncoding.cp437);
      expect(t.lines, ['╔══╗ I ♥ DOS', '╚══╝']);
      expect(t.controls.placeholders, 0);
    });

    test('form_feed.txt', () {
      final t = _ingest('form_feed.txt');
      expect(t.lines, ['page one', '', 'page two']);
      expect(t.controls.formFeeds, 1);
    });

    test('ansi_escape.txt', () {
      final t = _ingest('ansi_escape.txt');
      expect(t.lines, ['green bold plain', 'cleared']);
      expect(t.controls.ansiSequences, 3);
    });

    test('c0_controls.txt', () {
      final t = _ingest('c0_controls.txt');
      expect(t.encoding, TextEncoding.utf8);
      expect(t.lines, ['bell$_p back${_p}space nul$_p del$_p end']);
      expect(t.controls.placeholders, 4);
    });

    test('eof_padding.txt', () {
      final t = _ingest('eof_padding.txt');
      expect(t.lines, ['last line']);
      expect(t.controls.eofPadding, 20);
    });

    test('front_matter_cp437.txt', () {
      final t = _ingest('front_matter_cp437.txt');
      expect(t.frontMatter, {'title': 'Café Box Art', 'author': 'The Mentor'});
      expect(t.encoding, TextEncoding.cp437);
      expect(t.lines, ['╔══╗', '╚══╝']);
    });

    test('not_front_matter.txt keeps its dashed rules', () {
      final t = _ingest('not_front_matter.txt');
      expect(t.frontMatter, isEmpty);
      expect(t.lines, ['---', 'This is a rule, not YAML', '---', 'Body text']);
    });

    test('ligatures.txt', () {
      expect(_ingest('ligatures.txt').lines.first, startsWith('-> != =='));
    });

    test('ten_thousand_lines.txt', () {
      final t = _ingest('ten_thousand_lines.txt');
      expect(t.lines, hasLength(10000));
      expect(t.longestLineColumns, 132);
      expect(t.lines.first, startsWith('00000 | '));
    });

    test('empty.txt', () {
      final t = _ingest('empty.txt');
      expect(t.lines, isEmpty);
      expect(t.longestLineColumns, 0);
      expect(t.inventory, isEmpty);
    });
  });

  test('every fixture has a test above', () {
    final names = Directory('test/fixtures')
        .listSync()
        .map((f) => f.uri.pathSegments.last)
        .toSet();
    final source = File('test/ingest/ingest_fixtures_test.dart')
        .readAsStringSync();
    final untested = names.where((n) => !source.contains("'$n'")).toList();
    expect(untested, isEmpty, reason: 'add a test for each new fixture');
  });

  group('idempotence', () {
    for (final file in Directory(
      'test/fixtures',
    ).listSync().whereType<File>()) {
      final name = file.uri.pathSegments.last;
      test(name, () {
        final first = PhileText.fromBytes(file.readAsBytesSync());
        final again = PhileText.fromBytes(utf8.encode(first.toText()));
        expect(again.lines, first.lines);
        expect(again.longestLineColumns, first.longestLineColumns);
        expect(again.inventory, first.inventory);
      });
    }
  });

  test('inventory lists the distinct code points', () {
    final t = _ingest('cp437_glyphs.txt');
    expect(t.inventory, containsAll('╔═╗♥'.runes));
    expect(t.inventory, isNot(contains(0x0A)));
    expect(t.inventory, orderedEquals(t.inventory.toList()..sort()));
  });
}

import 'package:atdt/search/search_query.dart';
import 'package:flutter_test/flutter_test.dart';

String _match(String input) => SearchQuery.parse(input).toMatchExpression();

List<String> _highlighted(String query, String line) => [
  for (final (start, end) in SearchQuery.parse(query).highlights(line))
    line.substring(start, end),
];

void main() {
  group('parse', () {
    test('bare words are ANDed prefixes; short words match exactly', () {
      expect(_match('Knight Lightning'), '"knight"* "lightning"*');
      expect(_match('an IBM pc'), '"an" "ibm"* "pc"');
    });

    test('quotes make a phrase, and an unclosed quote still counts', () {
      expect(_match('"blue box" plans'), '"blue box" "plans"*');
      expect(_match('"blue bo'), '"blue bo"');
      expect(_match('"hack"'), '"hack"', reason: 'quoted: exact, no prefix');
    });

    test('a word with punctuation inside is a phrase of its parts', () {
      expect(_match('AT&T'), '"at t"');
      expect(_match('11,5200'), '"11 5200"');
    });

    test('folds case and accents like unicode61', () {
      expect(_match('ÉCOLE Café'), '"ecole"* "cafe"*');
    });

    test('FTS5 syntax is never passed through', () {
      for (final input in [
        'a OR b',
        'foo" OR bar*',
        'NEAR(x y)',
        '-minus ^caret col:val',
        '*',
        '""',
      ]) {
        final match = _match(input);
        // Only quoted runs of letters/digits, an optional *, and spaces.
        expect(
          match,
          matches(RegExp(r'^("[\p{L}\p{N} ]+"\*? ?)*$', unicode: true)),
          reason: input,
        );
      }
      expect(SearchQuery.parse('* "" ^').isEmpty, isTrue);
    });
  });

  group('highlights', () {
    test('marks every match of each term, keeping original text', () {
      expect(_highlighted('hack', 'Hacking, hackers and HACKS; not a whack'), [
        'Hacking',
        'hackers',
        'HACKS',
      ]);
    });

    test('phrases need adjacent tokens, across punctuation', () {
      expect(_highlighted('"blue box"', 'a blue  box, a blue-box, blue'), [
        'blue  box',
        'blue-box',
      ]);
      expect(_highlighted('AT&T', 'Call AT&T or at t.'), ['AT&T', 'at t']);
    });

    test('exact short words do not match longer ones', () {
      expect(_highlighted('pc', 'pc pcs PC'), ['pc', 'PC']);
    });

    test('overlapping terms merge into one range', () {
      final query = SearchQuery.parse('"blue box" box');
      expect(query.highlights('blue box'), [(0, 8)]);
    });

    test('accented text keeps its UTF-16 ranges', () {
      expect(_highlighted('cafe', 'le Café crème'), ['Café']);
    });

    test('an empty query highlights nothing', () {
      expect(SearchQuery.parse('').highlights('anything'), isEmpty);
    });
  });
}

// Synthetic examples of every heading format the parser accepts, and of
// the look-alikes it must refuse. Real philes are never committed.
import 'package:atdt/sections/section_parser.dart';
import 'package:flutter_test/flutter_test.dart';

/// Lines with filler paragraphs between the given headings, so headings
/// sit where they would in a phile.
List<String> _phile(List<String> headings, {int gap = 6}) => [
  'Synthetic phile',
  '',
  for (final h in headings) ...[
    h,
    for (var i = 0; i < gap; i++) 'Body text line $i of this section.',
  ],
];

List<String> _outline(List<String> lines) => [
  for (final s in parseSections(lines))
    '${'  ' * s.level}${s.number} ${s.title}',
];

void main() {
  group('accepted formats', () {
    test('dashed headings nest by their numbers, frames trimmed', () {
      final lines = _phile([
        '--[ 1 - Introduction ]-----------------------------------------',
        '--[ 2 - The problem',
        '----[ 2.1 - A real problem ]-----------------------------------',
        '------[ 2.1.1 - The vulnerable function',
        '--[ 3. Conclusions',
        '---[4: References',
      ]);
      expect(_outline(lines), [
        '1 Introduction',
        '2 The problem',
        '  2.1 A real problem',
        '    2.1.1 The vulnerable function',
        '3 Conclusions',
        '4 References',
      ]);
      expect(parseSections(lines).first.line, 2);
    });

    test('numbers closed in the bracket', () {
      expect(
        _outline(
          _phile([
            '--[1]-- Presentation',
            '--[1.1]-- Protocol mechanism',
            '----[  2]  Overview of things',
            '--[  2.0]  First part',
            '--[  2.1]  Second part',
          ]),
        ),
        [
          '1 Presentation',
          '  1.1 Protocol mechanism',
          '2 Overview of things',
          '  2.0 First part',
          '  2.1 Second part',
        ],
      );
    });

    test('"N.0" alone is top level', () {
      expect(
        _outline(
          _phile(['--[ 1.0 - Intro', '--[ 2.0 - Body', '--[ 2.1 - Sub']),
        ),
        ['1.0 Intro', '2.0 Body', '  2.1 Sub'],
      );
    });

    test('three-digit numbers', () {
      expect(
        _outline(
          _phile([
            '--[ 001 - First',
            '--[ 001.001 - Inner',
            '--[ 002 - Second',
          ]),
        ),
        ['001 First', '  001.001 Inner', '002 Second'],
      );
    });

    test('compilation articles sit above their own numbered headings', () {
      expect(
        _outline(
          _phile([
            '|=[ 0x01 - First article ]=-------------------------------=|',
            '--[ 1 - Introduction',
            '--[ 2 - Details',
            '|=[ 0x02 ]=------------=[ Second article - author ]=------=|',
            '--[ 1 - Introduction',
            '----[ 1.1 - Background',
            '|=--------------=[ 3 - Third article ]=-----------------=|',
          ]),
        ),
        [
          '0x01 First article',
          '  1 Introduction',
          '  2 Details',
          '0x02 Second article - author',
          '  1 Introduction',
          '    1.1 Background',
          '3 Third article',
        ],
      );
    });

    test('bracketed hex articles, with an appendix inside the last', () {
      expect(
        _outline(
          _phile([
            '-[0x01] :: Table of things --------------------------------',
            '-[0x02] :: More things ------------------------------------',
            '--[ Appendix A - Source code',
          ]),
        ),
        [
          '0x01 Table of things',
          '0x02 More things',
          '  Appendix A Source code',
        ],
      );
    });
  });

  group('contents lists in heading format', () {
    test('are dropped, so entries jump to the real headings', () {
      final lines = [
        '--[ Contents',
        '',
        '--[ 0. Introduction',
        '--[ 1. The method',
        '',
        '--[ 2. Further readings', // Worded differently below.
        '',
        '--[ 3. References',
        '',
        '--[ 0. Introduction',
        'Text.',
        ...List.filled(20, 'More text.'),
        '--[ 1. The method',
        ...List.filled(20, 'More text.'),
        '--[ 2. Further reading',
        ...List.filled(20, 'More text.'),
        '--[ 3. References',
      ];
      final sections = parseSections(lines);
      expect([for (final s in sections) s.line], [9, 31, 52, 73]);
      expect(sections[2].title, 'Further reading');
    });

    test('a compilation repeating one heading per article keeps both', () {
      expect(
        _outline(
          _phile([
            '--[ 1 - Introduction',
            '--[ 2 - Body',
            '--[ 1 - Introduction',
            '--[ 2 - Method',
          ]),
        ),
        ['1 Introduction', '2 Body', '1 Introduction', '2 Method'],
      );
    });
  });

  group('refused', () {
    test('numbers running backwards (other than a restart) discard all', () {
      expect(
        parseSections(
          _phile(['--[ 4 - Four', '--[ 5 - Five', '--[ 3 - Three']),
        ),
        isEmpty,
      );
    });

    test('a single heading is not a table of contents', () {
      expect(parseSections(_phile(['--[ 1 - Only one'])), isEmpty);
    });

    test('early-era look-alikes', () {
      final lines = [
        '                    ==Phrack Inc.==',
        '1. When the operator answers, say nothing',
        '2. Hang up and call back',
        'I.   Do not intentionally damage any system',
        'II.  Do not alter any files',
        '[1] "A reference", some newsletter, 1987',
        '[2] Another reference',
        '---[  Phrack Magazine   Volume 7, Issue 51, article 01 of 17',
        '------------------------[ END OF FILE ]---------------------',
        '--[ Introduction ]--',
        '--[ 32-bit dangling pointers',
        '-[nemo@host:~/code]\$ gcc test.c',
        '|=[ 0x00 ]=--------------------------------------------------=|',
        '|=[ 0x01 ]=--------------------------------------------------=|',
        '|[1]          [2]       [3]                      [9]         |',
        '   --[ 1 - Indented, so not a heading',
        '   --[ 2 - Indented, so not a heading',
      ];
      expect(parseSections(lines), isEmpty);
    });

    test('over-long titles are prose, not headings', () {
      final long = 'x' * 80;
      expect(
        parseSections(_phile(['--[ 1 - $long', '--[ 2 - $long'])),
        isEmpty,
      );
    });
  });

  test('the current section is the last heading at or above the top', () {
    const sections = [
      Section(line: 10, level: 0, number: '1', title: 'One'),
      Section(line: 50, level: 1, number: '1.1', title: 'One one'),
      Section(line: 90, level: 0, number: '2', title: 'Two'),
    ];
    expect(currentSection(sections, 0), isNull);
    expect(currentSection(sections, 10), 0);
    expect(currentSection(sections, 89), 1);
    expect(currentSection(sections, 5000), 2);
  });
}

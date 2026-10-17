import 'package:atdt/layout/text_block.dart';
import 'package:flutter_test/flutter_test.dart';

const _lines = [
  'Title',
  '',
  '    int main(void)', // 2
  '    {',
  '        return 0;   ', // trailing spaces kept
  '    }', // 5
  '   ', // whitespace-only counts as blank
  'Last paragraph line one', // 7
  'and two',
];

void main() {
  test('selects the contiguous non-blank lines around the press', () {
    expect(blockAround(_lines, 3), const LineBlock(2, 5));
    expect(blockAround(_lines, 2), const LineBlock(2, 5));
    expect(blockAround(_lines, 5), const LineBlock(2, 5));
  });

  test('blocks at the start and end of the file', () {
    expect(blockAround(_lines, 0), const LineBlock(0, 0));
    expect(blockAround(_lines, 8), const LineBlock(7, 8));
  });

  test('a blank or whitespace-only line selects nothing', () {
    expect(blockAround(_lines, 1), isNull);
    expect(blockAround(_lines, 6), isNull);
    expect(blockAround(_lines, 99), isNull);
  });

  test('copied text is exact, including leading and trailing whitespace', () {
    expect(
      const LineBlock(2, 5).textOf(_lines),
      '    int main(void)\n    {\n        return 0;   \n    }',
    );
  });
}

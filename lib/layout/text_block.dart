/// The contiguous block of non-blank lines that a long press selects: a
/// paragraph, a code listing, a piece of ASCII art. Pure Dart.
library;

class LineBlock {
  const LineBlock(this.start, this.end) : assert(start <= end);

  /// First and last line indexes, inclusive.
  final int start;
  final int end;

  int get length => end - start + 1;

  bool contains(int line) => line >= start && line <= end;

  /// The block exactly as stored: leading and trailing whitespace kept,
  /// lines joined with `\n`.
  String textOf(List<String> lines) => lines.sublist(start, end + 1).join('\n');

  @override
  bool operator ==(Object other) =>
      other is LineBlock && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);

  @override
  String toString() => 'LineBlock($start..$end)';
}

bool _blank(String line) => line.trim().isEmpty;

/// The block of non-blank lines around [index], or null if that line is
/// blank (there is nothing to copy).
LineBlock? blockAround(List<String> lines, int index) {
  if (index < 0 || index >= lines.length || _blank(lines[index])) return null;
  var start = index;
  while (start > 0 && !_blank(lines[start - 1])) {
    start--;
  }
  var end = index;
  while (end < lines.length - 1 && !_blank(lines[end + 1])) {
    end++;
  }
  return LineBlock(start, end);
}

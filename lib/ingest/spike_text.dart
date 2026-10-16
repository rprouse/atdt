/// Minimal text loading for the Stage A spike.
///
/// UTF-8 with a Latin-1 fallback, as the spec allows for Stage A. Stage B
/// replaces this with the full decoding chain (CP437 detection, control
/// characters, front matter); do not grow it.
library;

import 'dart:convert';
import 'dart:math' as math;

const int tabStop = 8;

final _lineBreak = RegExp('\r\n|\r|\n');

class PhileText {
  const PhileText({
    required this.lines,
    required this.longestLineColumns,
    required this.encoding,
  });

  factory PhileText.fromBytes(List<int> bytes) {
    String text;
    String encoding;
    try {
      text = utf8.decode(bytes);
      encoding = 'utf-8';
    } on FormatException {
      text = latin1.decode(bytes);
      encoding = 'latin-1';
    }

    final lines = text.isEmpty ? <String>[] : text.split(_lineBreak);
    // A final line break ends the last line; it does not start a new one.
    if (lines.isNotEmpty && lines.last.isEmpty) lines.removeLast();
    final expanded = [for (final line in lines) expandTabs(line)];

    return PhileText(
      lines: List.unmodifiable(expanded),
      longestLineColumns: expanded.fold(0, (m, l) => math.max(m, l.length)),
      encoding: encoding,
    );
  }

  final List<String> lines;
  final int longestLineColumns;
  final String encoding;
}

String expandTabs(String line) {
  if (!line.contains('\t')) return line;
  final b = StringBuffer();
  var column = 0;
  for (final unit in line.codeUnits) {
    if (unit == 0x09) {
      final pad = tabStop - column % tabStop;
      b.write(' ' * pad);
      column += pad;
    } else {
      b.writeCharCode(unit);
      column++;
    }
  }
  return b.toString();
}

/// Turns decoded text into the reader's line model: line breaks, tabs,
/// form feeds, escape sequences and control characters, with counts.
library;

import 'dart:math' as math;

import 'code_pages.dart';
import 'phile_text.dart';

const int tabStop = 8;

class NormalizeResult {
  const NormalizeResult({
    required this.lines,
    required this.longestLineColumns,
    required this.inventory,
    required this.controls,
  });

  final List<String> lines;
  final int longestLineColumns;
  final List<int> inventory;
  final ControlCounts controls;
}

// CSI sequences (ESC [ params intermediates final) and two-byte Fe escapes.
final _ansi = RegExp(r'\x1B(?:\[[0-?]*[ -/]*[@-~]|[@-Z\\-_])');
final _lineBreak = RegExp('\r\n|\r|\n');
final _eofPadding = RegExp(r'[\x00\x1A]+$');

NormalizeResult normalizeText(String text, {required TextEncoding encoding}) {
  // DOS and XMODEM pad files out with ^Z (and sometimes NUL); `type` stopped
  // at the first ^Z, so trailing padding is not content.
  final padding = _eofPadding.firstMatch(text);
  final eofPadding = padding == null ? 0 : padding.end - padding.start;
  if (padding != null) text = text.substring(0, padding.start);

  var ansiSequences = 0;
  text = text.replaceAllMapped(_ansi, (_) {
    ansiSequences++;
    return '';
  });

  final rawLines = text.isEmpty ? <String>[] : text.split(_lineBreak);
  // A final line break ends the last line; it does not start a new one.
  if (rawLines.isNotEmpty && rawLines.last.isEmpty) rawLines.removeLast();

  final lines = <String>[];
  final inventory = <int>{};
  var formFeeds = 0;
  var placeholders = 0;
  var longest = 0;

  void emit(String line, int columns) {
    lines.add(line);
    longest = math.max(longest, columns);
  }

  for (final raw in rawLines) {
    final out = StringBuffer();
    var column = 0;
    for (final rune in raw.runes) {
      if (rune == 0x09) {
        final pad = tabStop - column % tabStop;
        out.write(' ' * pad);
        column += pad;
        continue;
      }
      if (rune == 0x0C) {
        // A form feed is a page break: it becomes an empty line, splitting
        // any text either side of it onto lines of their own.
        formFeeds++;
        if (column > 0) emit(out.toString(), column);
        out.clear();
        column = 0;
        emit('', 0);
        continue;
      }
      final shown = _display(rune, encoding);
      if (shown != rune && shown == _placeholderRune) placeholders++;
      out.writeCharCode(shown);
      inventory.add(shown);
      column++;
    }
    // Text after a form feed, or any line without one.
    final ffOnly = column == 0 && out.isEmpty && raw.contains('\f');
    if (!ffOnly) emit(out.toString(), column);
  }

  return NormalizeResult(
    lines: List.unmodifiable(lines),
    longestLineColumns: longest,
    inventory: List.unmodifiable(inventory.toList()..sort()),
    controls: ControlCounts(
      ansiSequences: ansiSequences,
      formFeeds: formFeeds,
      placeholders: placeholders,
      eofPadding: eofPadding,
    ),
  );
}

final int _placeholderRune = controlPlaceholder.runes.single;
final List<int> _cp437LowRunes = cp437Low.runes.toList();
final int _cp437DelRune = cp437Del.runes.single;

/// The code point to show for [rune]. In CP437 files C0 bytes are glyphs
/// (☺♥…), as DOS displayed them; elsewhere they are controls.
int _display(int rune, TextEncoding encoding) {
  final isC0 = rune < 0x20;
  final isDel = rune == 0x7F;
  final isC1 = rune >= 0x80 && rune < 0xA0;
  if (!isC0 && !isDel && !isC1) return rune;
  if (encoding == TextEncoding.cp437) {
    if (isC0) return _cp437LowRunes[rune];
    if (isDel) return _cp437DelRune;
  }
  return _placeholderRune;
}

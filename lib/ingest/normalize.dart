/// Turns decoded text into the reader's line model: line breaks, tabs,
/// form feeds, escape sequences and control characters, with counts.
library;

import 'dart:math' as math;

import 'code_pages.dart';
import 'phile_text.dart' show ControlCounts;

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

// Only CSI sequences (ESC [ params intermediates final) are stripped. In the
// archive, a bare ESC is usually art drawn with the CP437 "←" glyph
// (`ESC___/`), so two-byte escapes would eat real characters.
final _ansi = RegExp(r'\x1B\[[0-?]*[ -/]*[@-~]');
final _lineBreak = RegExp('\r\n|\r|\n');
final _eofPadding = RegExp(r'[\x00\x1A]+$');
// A ^Z ending a line is the end-of-file mark of a concatenated part.
final _eofMarkerAtLineEnd = RegExp('\x1A+(?=\r\n|\r|\n)');

NormalizeResult normalizeText(String text) {
  // DOS and XMODEM pad files out with ^Z (and sometimes NUL); `type` stopped
  // at the first ^Z, so trailing padding and line-ending ^Z marks are not
  // content.
  final padding = _eofPadding.firstMatch(text);
  var eofPadding = padding == null ? 0 : padding.end - padding.start;
  if (padding != null) text = text.substring(0, padding.start);
  text = text.replaceAllMapped(_eofMarkerAtLineEnd, (m) {
    eofPadding += m.end - m.start;
    return '';
  });

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
  var controlGlyphs = 0;
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
      final shown = _display(rune);
      if (shown == _placeholderRune && shown != rune) {
        placeholders++;
      } else if (shown != rune) {
        controlGlyphs++;
      }
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
      controlGlyphs: controlGlyphs,
      eofPadding: eofPadding,
    ),
  );
}

final int _placeholderRune = controlPlaceholder.runes.single;
final List<int> _cp437LowRunes = cp437Low.runes.toList();
final int _cp437DelRune = cp437Del.runes.single;

/// The code point to show for [rune].
///
/// C0 bytes and DEL show as their CP437 glyphs (☺♥←…), as DOS displayed
/// them, in every encoding: the archive's UTF-8 conversion kept them as
/// raw bytes, and they are often art (see docs/decisions.md). NUL, which
/// CP437 shows as blank, and C1 controls, which have no CP437 meaning once
/// decoded, become the placeholder.
int _display(int rune) {
  if (rune < 0x20) return _cp437LowRunes[rune];
  if (rune == 0x7F) return _cp437DelRune;
  if (rune >= 0x80 && rune < 0xA0) return _placeholderRune;
  return rune;
}

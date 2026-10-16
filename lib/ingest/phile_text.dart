/// The normalised line model the reader renders. The renderer never sees
/// bytes or encodings; everything here has been decoded and cleaned.
library;

import 'dart:convert';

import 'decode.dart';
import 'front_matter.dart';
import 'normalize.dart';

enum TextEncoding {
  utf8('utf-8'),
  cp437('cp437'),
  latin1('latin-1'),
  windows1252('windows-1252');

  const TextEncoding(this.label);

  final String label;
}

/// What normalisation removed or replaced, for the batch report.
class ControlCounts {
  const ControlCounts({
    this.ansiSequences = 0,
    this.formFeeds = 0,
    this.placeholders = 0,
    this.controlGlyphs = 0,
    this.eofPadding = 0,
  });

  /// ANSI/VT100 escape sequences stripped.
  final int ansiSequences;

  /// Form feeds turned into empty lines.
  final int formFeeds;

  /// NUL and C1 controls shown as the placeholder.
  final int placeholders;

  /// C0 bytes and DEL shown as their CP437 glyphs (♥ ← ¶ …).
  final int controlGlyphs;

  /// ^Z end-of-file marks and trailing ^Z/NUL padding dropped.
  final int eofPadding;
}

class PhileText {
  const PhileText({
    required this.lines,
    required this.longestLineColumns,
    required this.encoding,
    required this.inventory,
    this.encodingAmbiguous = false,
    this.controls = const ControlCounts(),
    this.frontMatter = const {},
  });

  /// Strips archive front matter, decodes, and normalises raw phile bytes.
  factory PhileText.fromBytes(List<int> bytes) {
    final split = splitFrontMatter(bytes);
    final decoded = decodeBytes(split?.body ?? bytes);
    final normalized = normalizeText(decoded.text);
    return PhileText(
      lines: normalized.lines,
      longestLineColumns: normalized.longestLineColumns,
      encoding: decoded.encoding,
      encodingAmbiguous: decoded.ambiguous,
      inventory: normalized.inventory,
      controls: normalized.controls,
      frontMatter: split?.fields ?? const {},
    );
  }

  final List<String> lines;

  /// Width of the longest line, in code points.
  final int longestLineColumns;
  final TextEncoding encoding;

  /// The encoding heuristic had evidence both ways; worth a manual look.
  final bool encodingAmbiguous;

  /// Distinct code points used, ascending (for font coverage checks).
  final List<int> inventory;
  final ControlCounts controls;

  /// Fields from the archive's YAML header (title, author), if present.
  final Map<String, String> frontMatter;

  /// The normalised text, one line per row with a trailing newline.
  /// Feeding this back through [PhileText.fromBytes] changes nothing.
  String toText() => lines.isEmpty ? '' : '${lines.join('\n')}\n';

  List<int> toBytes() => utf8.encode(toText());
}

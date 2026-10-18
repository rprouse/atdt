/// Section headings in a phile, for the reader's jump list.
///
/// Pure Dart. Conservative by design (spec Stage I): a wrong table of
/// contents is worse than none. Only numbered headings in the formats
/// modern Phrack uses are accepted, and any sign that the matches are not
/// a coherent outline discards them all. See docs/decisions.md for the
/// archive survey behind each rule.
library;

/// One heading: where it is, how deep, and what it says.
class Section {
  const Section({
    required this.line,
    required this.level,
    required this.number,
    required this.title,
  });

  final int line;

  /// 0 for a top-level heading (or an article in a compilation phile).
  final int level;

  /// As written, without trailing dots: "2.1", "0x03", "Appendix A".
  final String number;
  final String title;

  @override
  bool operator ==(Object other) =>
      other is Section &&
      other.line == line &&
      other.level == level &&
      other.number == number &&
      other.title == title;

  @override
  int get hashCode => Object.hash(line, level, number, title);

  @override
  String toString() => '$line:${'  ' * level}$number $title';
}

const _number =
    r'(?<num>\d{1,3}(?:\.\d{1,3}){0,3}\.?|0x[0-9a-fA-F]{1,2}|Appendix\s+[A-Z0-9])';

/// `--[ 1 - Title`, `----[ 2.1 - Title ]-----`, `--[ 3. Title`, and with
/// the number closed in the bracket, `--[1.1]-- Title`: the format of most
/// modern philes. Nesting comes from the number, never the dashes.
final _dashed = RegExp(
  r'^-{1,8}\[\s*' + _number + r'\s*(?:\]-*)?\s*[-:.)]?\s+(?<title>\S.*)$',
);

/// `|=[ 0x01 - Title ]=---=|` and `|=[ 0x01 ]=---=[ Title ]=---=|`:
/// articles within compilations (Linenoise, Loopback, Phrack World News).
final _piped = RegExp(
  r'^\|[-=]*\[\s*' + _number + r'\s*(?:-\s+|\][-=]*\[\s*)(?<title>[^\]]+)',
);

/// `-[0x01] :: Title -------`.
final _bracketed = RegExp(r'^-{1,8}\[' + _number + r'\]\s*::\s*(?<title>.+)$');

/// Framing around a title: brackets, rules and the `=|` box edge.
final _frame = RegExp(r'^[\s\-=\[\]|]+|[\s\-=\[\]|]+$');

const int _maxTitleLength = 72;

/// Contents lists put headings a few lines apart at most (blank lines
/// between entries); real headings have paragraphs between them.
const int _contentsGap = 4;

/// Every section heading in [lines], in order, or none at all.
List<Section> parseSections(List<String> lines) {
  final found = <_Candidate>[];
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    // Cheap first: every supported heading starts with '-' or '|'.
    if (line.isEmpty) continue;
    final first = line.codeUnitAt(0);
    if (first != 0x2D && first != 0x7C) continue;
    final candidate = _match(line, i);
    if (candidate != null) found.add(candidate);
  }

  final sections = _dropContentsCopies(found);
  if (sections.length < 2 || !_coherent(sections)) return const [];

  // Articles in a compilation sit above the numbered headings inside them.
  final articles = sections.any((s) => s.article);
  return [
    for (final (i, s) in sections.indexed)
      Section(
        line: s.line,
        level: s.article
            ? 0
            : (s.depth(after: i == 0 ? null : sections[i - 1]) +
                      (articles ? 1 : 0))
                  .clamp(0, 3),
        number: s.number,
        title: s.title,
      ),
  ];
}

/// The section being read: the last heading at or above the top line.
/// Null before the first heading.
int? currentSection(List<Section> sections, int topLine) {
  int? current;
  for (final (i, s) in sections.indexed) {
    if (s.line > topLine) break;
    current = i;
  }
  return current;
}

class _Candidate {
  _Candidate(this.line, this.number, this.title, {required this.article});

  final int line;
  final String number;
  final String title;
  final bool article;

  String get key => '$number|${title.toLowerCase()}';

  bool get isHex => number.startsWith('0x');
  bool get isAppendix => number.startsWith('Appendix');

  /// 1 → 0, 2.1 → 1, 2.2.1 → 2. A trailing ".0" is top level ("1.0
  /// Introduction", "2.0 ..."), unless it follows the plain number: "3"
  /// then "3.0 Overview" makes "3.0" its first subsection.
  int depth({_Candidate? after}) {
    if (isHex || isAppendix) return 0;
    final parts = number.split('.');
    final written = parts.length - 1;
    while (parts.length > 1 && parts.last == '0') {
      parts.removeLast();
    }
    return after?.number == parts.join('.') ? written : parts.length - 1;
  }

  /// The number that must not run backwards: the top-level part.
  int get top {
    if (isHex) return int.parse(number.substring(2), radix: 16);
    if (isAppendix) return 1 << 20;
    return int.parse(number.split('.').first);
  }
}

_Candidate? _match(String line, int index) {
  for (final (pattern, article) in [
    (_piped, true),
    (_bracketed, false),
    (_dashed, false),
  ]) {
    final m = pattern.firstMatch(line);
    if (m == null) continue;
    final title = m.namedGroup('title')!.replaceAll(_frame, '');
    if (title.isEmpty || title.length > _maxTitleLength) return null;
    var number = m.namedGroup('num')!.replaceAll(RegExp(r'\s+'), ' ');
    if (number.endsWith('.')) number = number.substring(0, number.length - 1);
    // Phrack numbers articles in hex and sections in decimal, whichever
    // frame is used.
    final hex = number.startsWith('0x');
    return _Candidate(index, number, title, article: article || hex);
  }
  return null;
}

/// Some philes open with a contents list in the heading format itself. Its
/// entries repeat later as the real headings; jump to those.
///
/// Headings within [_contentsGap] lines of each other form a run. If a run
/// starts with entries that mostly appear again later, that part of it, up
/// to its last repeated entry, is a contents list: dropped, with any entry
/// whose wording differs from the real heading. Real headings straight
/// after the list stay. Two-entry lists must repeat exactly, so that a
/// compilation repeating "1 - Introduction" per article keeps them.
List<_Candidate> _dropContentsCopies(List<_Candidate> found) {
  final lastByKey = <String, int>{};
  for (final c in found) {
    lastByKey[c.key] = c.line;
  }
  bool repeats(_Candidate c) => lastByKey[c.key]! > c.line;

  final drop = <int>{};
  var start = 0;
  while (start < found.length) {
    var end = start + 1;
    while (end < found.length &&
        found[end].line - found[end - 1].line <= _contentsGap) {
      end++;
    }
    var lastRepeat = -1;
    var repeated = 0;
    for (var i = start; i < end; i++) {
      if (repeats(found[i])) lastRepeat = i;
    }
    for (var i = start; i <= lastRepeat; i++) {
      if (repeats(found[i])) repeated++;
    }
    final listed = lastRepeat - start + 1;
    final isContents = listed == 2
        ? repeated == 2
        : listed > 2 && repeated * 2 >= listed;
    if (isContents) drop.addAll([for (var i = start; i <= lastRepeat; i++) i]);
    start = end;
  }
  return [
    for (final (i, c) in found.indexed)
      if (!drop.contains(i)) c,
  ];
}

/// Numbers only ever go forwards, except for a restart at 0 or 1 (the next
/// article in a compilation), counted separately for article markers and
/// headings. Anything else means these are not an outline.
bool _coherent(List<_Candidate> sections) {
  final last = <bool, int>{};
  for (final s in sections) {
    final previous = last[s.article];
    if (previous != null && s.top < previous && s.top > 1) return false;
    last[s.article] = s.top;
  }
  return true;
}

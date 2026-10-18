/// Search queries: what the user types, as an FTS5 match expression, and
/// where a query's terms fall in a line for highlighting.
///
/// Pure Dart. Tokenising mirrors the index's `unicode61 remove_diacritics 2`
/// tokenizer: runs of letters, digits and private-use characters, case-
/// and accent-folded. Everything else separates tokens.
library;

/// One thing a matching line must contain.
class SearchTerm {
  const SearchTerm(this.tokens, {this.prefix = false});

  /// One token is a word; several must appear adjacent and in order.
  final List<String> tokens;

  /// The last token matches any token it starts.
  final bool prefix;

  bool get isPhrase => tokens.length > 1;

  @override
  bool operator ==(Object other) {
    if (other is! SearchTerm || other.prefix != prefix) return false;
    if (other.tokens.length != tokens.length) return false;
    for (var i = 0; i < tokens.length; i++) {
      if (other.tokens[i] != tokens[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(prefix, Object.hashAll(tokens));

  @override
  String toString() => '"${tokens.join(' ')}"${prefix ? '*' : ''}';
}

/// Words shorter than this match exactly: a one- or two-letter prefix would
/// match most of the archive and make every keystroke slow.
const int minPrefixLength = 3;

class SearchQuery {
  const SearchQuery(this.terms);

  /// Bare words must all appear on the line (any order); each matches as a
  /// prefix, so "hack" finds "hacking" and "hacker". A word that splits
  /// into several tokens ("AT&T", "11,5200") and anything in double quotes
  /// is a phrase: its tokens must be adjacent.
  factory SearchQuery.parse(String input) {
    final terms = <SearchTerm>[];
    for (final m in _chunk.allMatches(input)) {
      final quoted = m.group(1);
      final tokens = tokenize(quoted ?? m.group(0)!)
          .map((t) => t.text)
          .toList();
      if (tokens.isEmpty) continue;
      final prefix =
          quoted == null &&
          tokens.length == 1 &&
          tokens.single.length >= minPrefixLength;
      terms.add(SearchTerm(tokens, prefix: prefix));
    }
    return SearchQuery(terms);
  }

  final List<SearchTerm> terms;

  bool get isEmpty => terms.isEmpty;

  /// For `MATCH`. Every token is quoted, and tokens hold only letters and
  /// digits, so nothing the user types can be read as FTS5 syntax.
  String toMatchExpression() => terms.join(' ');

  /// Where this query's terms appear in [line], as sorted, non-overlapping
  /// UTF-16 ranges `(start, end)`.
  List<(int, int)> highlights(String line) {
    if (terms.isEmpty) return const [];
    final tokens = tokenize(line);
    final ranges = <(int, int)>[];
    for (final term in terms) {
      final n = term.tokens.length;
      for (var i = 0; i + n <= tokens.length; i++) {
        var matched = true;
        for (var j = 0; j < n && matched; j++) {
          final token = tokens[i + j].text;
          final want = term.tokens[j];
          matched = term.prefix && j == n - 1
              ? token.startsWith(want)
              : token == want;
        }
        if (matched) ranges.add((tokens[i].start, tokens[i + n - 1].end));
      }
    }
    return _merge(ranges);
  }

  @override
  String toString() => toMatchExpression();
}

/// A quoted phrase (closing quote optional while typing), or a run of
/// anything else that is not space or a quote.
final _chunk = RegExp(r'"([^"]*)"?|[^\s"]+');

final _tokenChars = RegExp(r'[\p{L}\p{N}\p{Co}]+', unicode: true);

typedef Token = ({int start, int end, String text});

/// [text]'s tokens, folded, with their UTF-16 ranges in [text].
List<Token> tokenize(String text) {
  final folded = foldForSearch(text);
  return [
    for (final m in _tokenChars.allMatches(folded))
      (start: m.start, end: m.end, text: m.group(0)!),
  ];
}

/// Lower case without accents, one UTF-16 unit for one, so ranges found in
/// the folded text are ranges in the original.
String foldForSearch(String text) {
  final out = StringBuffer();
  for (final unit in text.codeUnits) {
    final char = String.fromCharCode(unit);
    final lower = char.toLowerCase();
    final c = lower.length == 1 ? lower : char;
    out.write(_unaccented[c] ?? c);
  }
  return out.toString();
}

/// Accented Latin letters SQLite's unicode61 folds (those with a canonical
/// decomposition; ø, ł, đ, ħ and ı have none and stay as they are).
final Map<String, String> _unaccented = {
  for (final (base, accented) in const [
    ('a', 'àáâãäåāăą'),
    ('c', 'çćĉċč'),
    ('d', 'ď'),
    ('e', 'èéêëēĕėęě'),
    ('g', 'ĝğġģ'),
    ('h', 'ĥ'),
    ('i', 'ìíîïĩīĭį'),
    ('j', 'ĵ'),
    ('k', 'ķ'),
    ('l', 'ĺļľ'),
    ('n', 'ñńņň'),
    ('o', 'òóôõöōŏő'),
    ('r', 'ŕŗř'),
    ('s', 'śŝşš'),
    ('t', 'ţť'),
    ('u', 'ùúûüũūŭůűų'),
    ('w', 'ŵ'),
    ('y', 'ýÿŷ'),
    ('z', 'źżž'),
  ])
    for (final char in accented.split('')) char: base,
};

List<(int, int)> _merge(List<(int, int)> ranges) {
  if (ranges.length < 2) return ranges;
  ranges.sort((a, b) => a.$1.compareTo(b.$1));
  final merged = [ranges.first];
  for (final r in ranges.skip(1)) {
    final last = merged.last;
    if (r.$1 <= last.$2) {
      if (r.$2 > last.$2) merged[merged.length - 1] = (last.$1, r.$2);
    } else {
      merged.add(r);
    }
  }
  return merged;
}

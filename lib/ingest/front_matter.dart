/// The YAML header the current Phrack archive adds to every `.txt` file.
///
/// It is not part of the original phile, so it is removed before decoding
/// (it is UTF-8 even when the body is CP437) and parsed for metadata. The
/// parser is deliberately narrow: only `key: value` lines between two `---`
/// lines at the very start of the file, so a phile that opens with a dashed
/// rule is left alone.
library;

import 'dart:convert';

class FrontMatter {
  const FrontMatter({required this.fields, required this.body});

  final Map<String, String> fields;

  /// The bytes after the closing `---` line.
  final List<int> body;
}

const _maxLines = 32;
final _field = RegExp(r'^([A-Za-z_][A-Za-z0-9_-]*):(?:\s+(.*))?$');

FrontMatter? splitFrontMatter(List<int> bytes) {
  var pos = 0;

  // Reads one line, without its terminator; null at end of input.
  String? readLine() {
    if (pos >= bytes.length) return null;
    final start = pos;
    while (pos < bytes.length && bytes[pos] != 0x0A) {
      pos++;
    }
    var end = pos;
    if (pos < bytes.length) pos++; // the \n
    if (end > start && bytes[end - 1] == 0x0D) end--;
    return utf8.decode(bytes.sublist(start, end), allowMalformed: true);
  }

  if (readLine() != '---') return null;
  final fields = <String, String>{};
  for (var i = 0; i < _maxLines; i++) {
    final line = readLine();
    if (line == null) return null;
    if (line == '---') {
      if (fields.isEmpty) return null;
      return FrontMatter(fields: fields, body: bytes.sublist(pos));
    }
    final match = _field.firstMatch(line);
    if (match == null) return null;
    fields[match.group(1)!] = _unquote((match.group(2) ?? '').trim());
  }
  return null;
}

String _unquote(String value) {
  if (value.length >= 2) {
    final q = value[0];
    if ((q == '"' || q == "'") && value.endsWith(q)) {
      final inner = value.substring(1, value.length - 1);
      return q == '"'
          ? inner.replaceAll(r'\"', '"').replaceAll(r'\\', r'\')
          : inner.replaceAll("''", "'");
    }
  }
  return value;
}

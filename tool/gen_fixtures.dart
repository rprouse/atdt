// Regenerates the byte-exact synthetic fixtures in test/fixtures/.
//
//   dart run tool/gen_fixtures.dart
//
// Output is deterministic; re-running must produce no git diff.
import 'dart:convert';
import 'dart:io';

void main() {
  final dir = Directory('test/fixtures')..createSync(recursive: true);
  void write(String name, List<int> bytes) =>
      File('${dir.path}/$name').writeAsBytesSync(bytes);
  List<int> lf(List<String> lines) => utf8.encode('${lines.join('\n')}\n');

  final ruler = _ruler(80);

  write(
    'exact_80.txt',
    lf([ruler, '1234567890' * 8, '${'-' * 78}->', '[${' ' * 78}]', ruler]),
  );

  write(
    'widths_79_132.txt',
    lf([
      'The next line is 79 columns, then 80, then 132.',
      '${'.' * 78}|',
      '${'.' * 79}|',
      '${_ruler(132).substring(0, 131)}|',
      'Short line after the long one.',
    ]),
  );

  write(
    'tabs_code.txt',
    lf([
      '#include <stdio.h>',
      '',
      'int main(int argc, char **argv)',
      '{',
      '\tint i;',
      '\tfor (i = 0; i < argc; i++) {',
      '\t\tif (argv[i] != NULL)',
      '\t\t\tprintf("%d\\t%s\\n", i, argv[i]);',
      '\t}',
      'x\ttab stop at 8',
      'xxxxxxx\tstop at 8',
      'xxxxxxxx\tstop at 16',
      '\treturn 0;',
      '}',
    ]),
  );

  const endings = ['first line', 'second line', '', 'fourth line'];
  write('lf.txt', utf8.encode('${endings.join('\n')}\n'));
  write('crlf.txt', utf8.encode('${endings.join('\r\n')}\r\n'));
  write('lone_cr.txt', utf8.encode('${endings.join('\r')}\r'));

  write(
    'box_drawing.txt',
    lf([
      '┌──────────┬──────────┐',
      '│ single   │ lines    │',
      '├──────────┼──────────┤',
      '╔══════════╦══════════╗',
      '║ double   ║ lines    ║',
      '╚══════════╩══════════╝',
      '░░░▒▒▒▓▓▓███ shades',
      'mixed │ text │ and │ bars',
    ]),
  );

  write(
    'latin1_accented.txt',
    latin1.encode('Café, naïve, Zoë, señor, Ångström, ½ ¼ ¾ ©\n'),
  );

  // CP437 box drawing (0xC9 ╔, 0xCD ═, 0xBB ╗, 0xBA ║, 0xC8 ╚, 0xBC ╝) and
  // shades (0xB0-0xB2, 0xDB), which are invalid UTF-8.
  write('cp437_high_bytes.txt', [
    0xC9, ...List.filled(10, 0xCD), 0xBB, 0x0A, //
    0xBA, ...ascii.encode(' CP437    '), 0xBA, 0x0A,
    0xC8, ...List.filled(10, 0xCD), 0xBC, 0x0A,
    0xB0, 0xB1, 0xB2, 0xDB, 0x0A,
  ]);

  write('form_feed.txt', utf8.encode('page one\n\x0C\npage two\n'));

  write(
    'ansi_escape.txt',
    utf8.encode('\x1B[1;32mgreen bold\x1B[0m plain\n\x1B[2Jcleared\n'),
  );

  write('empty.txt', const []);

  write(
    'ligatures.txt',
    lf([
      '-> != == <= >= => === !== ::',
      'www.phrack.org  /* */ // <!-- --> |> <| ->> <<-',
      '0x1F 1:2 a-->b <=> ... ;; ##',
    ]),
  );

  // Line numbers make the top line easy to read off during rotation checks.
  // Every 50th line overflows to 132 columns; every 7th is indented.
  final big = StringBuffer();
  for (var i = 0; i < 10000; i++) {
    final number = i.toString().padLeft(5, '0');
    final indent = i % 7 == 0 ? '    ' : '';
    final width = i % 50 == 0 ? 132 : 72 - (i * 13) % 40;
    final body = '$indent${_pattern(i)}';
    big.write(
      '$number | ${body.padRight(width - 8).substring(0, width - 8)}\n',
    );
  }
  write('ten_thousand_lines.txt', utf8.encode(big.toString()));
}

String _ruler(int width) {
  final b = StringBuffer();
  for (var c = 1; c <= width; c++) {
    b.write(c % 10 == 0 ? (c ~/ 10) % 10 : (c % 5 == 0 ? '+' : '.'));
  }
  return b.toString();
}

const _words = [
  'phrack',
  'kernel',
  'modem',
  'carrier',
  'packet',
  'buffer',
  'switch',
  'trunk',
  'loop',
  'stack',
  'shell',
  'daemon',
  'socket',
  'signal',
];

String _pattern(int seed) {
  final b = StringBuffer();
  var s = seed;
  while (b.length < 140) {
    s = (s * 1103515245 + 12345) & 0x7fffffff;
    b
      ..write(_words[s % _words.length])
      ..write(' ');
  }
  return b.toString();
}

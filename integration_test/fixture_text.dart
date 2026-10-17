import 'dart:convert';

import 'package:atdt/ingest/phile_text.dart';

/// 10,000 numbered lines for device tests, built in code because the app no
/// longer bundles text. Like test/fixtures/ten_thousand_lines.txt: every
/// 50th line is 132 columns, so horizontal scrolling has room to move.
PhileText tenThousandLines() {
  final b = StringBuffer();
  for (var i = 0; i < 10000; i++) {
    final width = i % 50 == 0 ? 132 : 72 - (i * 13) % 40;
    final body = '${i.toString().padLeft(5, '0')} | ';
    b.writeln(body.padRight(width, i.isEven ? '-' : '.'));
  }
  return PhileText.fromBytes(utf8.encode(b.toString()));
}

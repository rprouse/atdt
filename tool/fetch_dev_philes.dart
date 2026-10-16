// Downloads a couple of real Phrack philes into assets/dev/ for manual
// testing. That folder is git-ignored: never commit Phrack text.
//
//   dart run tool/fetch_dev_philes.dart
//
// Source and URL pattern verified 2026-10-16; see docs/decisions.md.
import 'dart:io';

const _base = 'https://archives.phrack.org/issues';
const _userAgent = 'ATDT-dev/0.1 (+https://github.com/rprouse/atdt)';

/// (issue, phile): one from the 1980s and one from the latest issue.
const _philes = [(7, 3), (72, 1)];

Future<void> main() async {
  final dir = Directory('assets/dev')..createSync(recursive: true);
  final client = HttpClient()..userAgent = _userAgent;
  try {
    for (final (index, (issue, phile)) in _philes.indexed) {
      if (index > 0) await Future<void>.delayed(const Duration(seconds: 1));
      final file = File('${dir.path}/phrack-$issue-$phile.txt');
      if (file.existsSync()) {
        stdout.writeln('skip  ${file.path} (already present)');
        continue;
      }
      final url = Uri.parse('$_base/$issue/$phile.txt');
      final request = await client.getUrl(url);
      final response = await request.close();
      if (response.statusCode != HttpStatus.ok) {
        stderr.writeln('fail  $url: HTTP ${response.statusCode}');
        exitCode = 1;
        await response.drain<void>();
        continue;
      }
      // Bytes, not a decoded string: the reader must see the original
      // encoding.
      final bytes = await response.fold<List<int>>(
        [],
        (all, chunk) => all..addAll(chunk),
      );
      file.writeAsBytesSync(bytes);
      stdout.writeln('saved ${file.path} (${bytes.length} bytes)');
    }
  } finally {
    client.close();
  }
}

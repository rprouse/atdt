// Runs ingestion over the whole Phrack archive and writes a CSV report.
//
//   dart run tool/ingest_archive.dart            # all issues
//   dart run tool/ingest_archive.dart 1 10       # issues 1 to 10
//
// Tarballs are cached in tool/out/archive/ (git-ignored; never commit
// Phrack text). Output: tool/out/ingest_report.csv. A developer tool, not a
// test: it backs the encoding-heuristic Verify item in docs/decisions.md.
import 'dart:io';

import 'package:atdt/ingest/decode.dart';
import 'package:atdt/ingest/front_matter.dart';
import 'package:atdt/ingest/phile_text.dart';

const _base = 'https://archives.phrack.org/tgz';
const _userAgent = 'ATDT-dev/0.1 (+https://github.com/rprouse/atdt)';
const _lastIssue = 72;

Future<void> main(List<String> args) async {
  final first = args.isNotEmpty ? int.parse(args[0]) : 1;
  final last = args.length > 1 ? int.parse(args[1]) : _lastIssue;
  final cache = Directory('tool/out/archive')..createSync(recursive: true);

  final client = HttpClient()..userAgent = _userAgent;
  try {
    for (var issue = first; issue <= last; issue++) {
      await _fetch(client, issue, cache);
    }
  } finally {
    client.close();
  }

  final rows = <List<Object>>[
    [
      'issue', 'phile', 'bytes', 'encoding', 'ambiguous', 'cp437_votes', //
      'latin_votes', 'lines', 'longest', 'ansi', 'form_feeds',
      'placeholders',
      'control_glyphs',
      'eof_padding',
      'front_matter',
      'title',
      'author',
      'error',
    ],
  ];
  var failures = 0;
  for (var issue = first; issue <= last; issue++) {
    final dir = Directory('${cache.path}/$issue');
    if (!dir.existsSync()) continue;
    final files =
        dir
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.toLowerCase().endsWith('.txt'))
            .toList()
          ..sort((a, b) => _phileNumber(a).compareTo(_phileNumber(b)));
    for (final file in files) {
      final bytes = file.readAsBytesSync();
      try {
        final text = PhileText.fromBytes(bytes);
        final votes = decodeBytes(splitFrontMatter(bytes)?.body ?? bytes);
        final c = text.controls;
        rows.add([
          issue, _phileNumber(file), bytes.length, text.encoding.label, //
          text.encodingAmbiguous, votes.cp437Votes, votes.latinVotes,
          text.lines.length, text.longestLineColumns, c.ansiSequences,
          c.formFeeds, c.placeholders, c.controlGlyphs, c.eofPadding,
          text.frontMatter.isNotEmpty, text.frontMatter['title'] ?? '',
          text.frontMatter['author'] ?? '', '',
        ]);
      } on Object catch (e) {
        failures++;
        rows.add([
          issue,
          _phileNumber(file),
          bytes.length,
          ...List.filled(14, ''),
          '$e',
        ]);
      }
    }
  }

  final out = File('tool/out/ingest_report.csv')
    ..writeAsStringSync(rows.map((r) => r.map(_csv).join(',')).join('\n'));
  stdout.writeln(
    '${rows.length - 1} philes, $failures exceptions -> ${out.path}',
  );
  if (failures > 0) exitCode = 1;
}

Future<void> _fetch(HttpClient client, int issue, Directory cache) async {
  final tgz = File('${cache.path}/phrack$issue.tar.gz');
  final dir = Directory('${cache.path}/$issue');
  if (!tgz.existsSync()) {
    await Future<void>.delayed(const Duration(seconds: 1));
    final response = await (await client.getUrl(
      Uri.parse('$_base/phrack$issue.tar.gz'),
    )).close();
    if (response.statusCode != HttpStatus.ok) {
      stderr.writeln('issue $issue: HTTP ${response.statusCode}');
      await response.drain<void>();
      return;
    }
    await response.pipe(tgz.openWrite());
    stdout.writeln('fetched issue $issue (${tgz.lengthSync()} bytes)');
  }
  if (!dir.existsSync()) {
    dir.createSync();
    // System tar (bsdtar on Windows 10+) refuses absolute and ".." paths.
    final result = await Process.run('tar', [
      '-xzf',
      tgz.absolute.path,
    ], workingDirectory: dir.path);
    if (result.exitCode != 0) {
      stderr.writeln('issue $issue: tar failed: ${result.stderr}');
    }
  }
}

int _phileNumber(File f) =>
    int.tryParse(f.uri.pathSegments.last.split('.').first) ?? 0;

String _csv(Object value) {
  final s = '$value';
  return s.contains(RegExp('[",\n]')) ? '"${s.replaceAll('"', '""')}"' : s;
}

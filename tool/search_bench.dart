// Builds the search index over the whole Phrack archive and times queries.
//
//   dart run tool/search_bench.dart
//
// Needs the tarballs cached by tool/ingest_archive.dart in
// tool/out/archive/. Writes tool/out/search_bench.sqlite (git-ignored;
// never commit Phrack text). A developer tool that backs the Stage H
// design and performance notes in docs/decisions.md.
import 'dart:io';

import 'package:atdt/archive/issue_import.dart';
import 'package:atdt/search/search_query.dart';
import 'package:atdt/storage/archive_database.dart';
import 'package:drift/native.dart';

const _queries = [
  'Knight Lightning',
  'phreak',
  'blue box',
  '"blue box"',
  'buffer overflow',
  'the',
  'ROLM',
  'shellcode',
  'AT&T',
  'kernel heap',
];

Future<void> main() async {
  final file = File('tool/out/search_bench.sqlite');
  if (file.existsSync()) file.deleteSync();
  final db = ArchiveDatabase(NativeDatabase(file));

  final watch = Stopwatch()..start();
  for (var issue = 1; issue <= 72; issue++) {
    final tgz = File('tool/out/archive/phrack$issue.tar.gz');
    if (!tgz.existsSync()) continue;
    await db.saveIssue(
      importIssueArchive(issue, tgz.readAsBytesSync()),
      fetchedAt: DateTime.now(),
    );
  }
  await db.customStatement('VACUUM');
  final stored = file.lengthSync();
  stdout.writeln(
    'imported in ${watch.elapsedMilliseconds} ms; '
    '${(stored / 1e6).toStringAsFixed(1)} MB',
  );

  watch.reset();
  var lines = 0;
  for (final id in await db.unindexedPhileIds()) {
    final text = await db.readAllLines(id);
    lines += text.length;
    await db.indexPhile(id, text);
  }
  final indexMs = watch.elapsedMilliseconds;
  stdout.writeln('as built (one transaction per phile, like the app):');
  await _timeQueries(db);
  watch.reset();
  await db.customStatement(
    "INSERT INTO line_fts(line_fts) VALUES ('optimize')",
  );
  stdout.writeln('optimize took ${watch.elapsedMilliseconds} ms');
  await db.customStatement('VACUUM');
  final indexed = file.lengthSync();
  stdout.writeln(
    'indexed $lines lines in $indexMs ms; database now '
    '${(indexed / 1e6).toStringAsFixed(1)} MB '
    '(+${((indexed - stored) / 1e6).toStringAsFixed(1)} MB)',
  );

  stdout.writeln('after optimize:');
  await _timeQueries(db);
  await db.close();
}

Future<void> _timeQueries(ArchiveDatabase db) async {
  final watch = Stopwatch()..start();
  for (final q in _queries) {
    final match = SearchQuery.parse(q).toMatchExpression();
    final times = <int>[];
    var hits = <SearchHit>[];
    for (var run = 0; run < 5; run++) {
      watch.reset();
      hits = await db.search(match);
      times.add(watch.elapsedMicroseconds);
    }
    times.sort();
    final lines = hits.fold(0, (n, h) => n + h.matchingLines);
    stdout.writeln(
      '${q.padRight(18)} ${match.padRight(26)} '
      '${hits.length.toString().padLeft(5)} philes '
      '${lines.toString().padLeft(7)} lines  '
      'median ${(times[2] / 1000).toStringAsFixed(1)} ms',
    );
  }
}

// Stage H acceptance: searching for a known string returns in under 300 ms
// on a device. Uses the production storage path (drift on its background
// isolate, a real file) and a synthetic archive the size of Phrack:
// 1,008 philes, 1.16 million lines, Zipf-distributed words.
//
//   flutter test integration_test/search_perf_test.dart -d <device>
//
// Debug builds only report; profile and release assert.
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:atdt/archive/issue_import.dart';
import 'package:atdt/ingest/phile_text.dart';
import 'package:atdt/search/search_query.dart';
import 'package:atdt/storage/archive_database.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';

const _issues = 72;
const _philesPerIssue = 14;
const _linesPerPhile = 1150;
const _known = 'zebra crossing protocol';

/// 2,000 pronounceable words; earlier ones are far more common.
final List<String> _words = () {
  const syllables = ['ka', 'lo', 'mi', 'ne', 'tor', 'sha', 'pex', 'du', 'ri'];
  final random = Random(1);
  return List.generate(2000, (_) {
    final n = 1 + random.nextInt(3);
    return [for (var i = 0; i < n; i++) syllables[random.nextInt(9)]].join();
  });
}();

final List<double> _cumulative = () {
  var sum = 0.0;
  return [for (var rank = 1; rank <= _words.length; rank++) sum += 1 / rank];
}();

String _word(Random random) {
  final target = random.nextDouble() * _cumulative.last;
  var lo = 0;
  var hi = _cumulative.length - 1;
  while (lo < hi) {
    final mid = (lo + hi) ~/ 2;
    if (_cumulative[mid] < target) {
      lo = mid + 1;
    } else {
      hi = mid;
    }
  }
  return _words[lo];
}

PhileText _phile(Random random, {required bool plant}) {
  final b = StringBuffer();
  for (var i = 0; i < _linesPerPhile; i++) {
    if (i % 9 == 8) {
      b.writeln(); // Paragraph breaks, like real philes.
      continue;
    }
    final line = StringBuffer();
    while (line.length < 64) {
      line.write('${_word(random)} ');
    }
    if (plant && i == 500) line.write(_known);
    b.writeln(line.toString().trimRight());
  }
  return PhileText.fromBytes(utf8.encode(b.toString()));
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('a known string is found in under 300 ms', (tester) async {
    await tester.runAsync(() async {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/search_perf.sqlite');
      if (file.existsSync()) file.deleteSync();
      final db = ArchiveDatabase(
        driftDatabase(
          name: 'search_perf',
          native: DriftNativeOptions(databasePath: () async => file.path),
        ),
      );

      final random = Random(7);
      for (var issue = 1; issue <= _issues; issue++) {
        await db.saveIssue(
          ImportedIssue(
            number: issue,
            sourceChecksum: 'perf',
            philes: [
              for (var n = 1; n <= _philesPerIssue; n++)
                ImportedPhile(
                  number: n,
                  title: 'Phile $issue/$n',
                  // The known string in three philes, far apart.
                  text: _phile(random, plant: n == 3 && issue % 30 == 1),
                ),
            ],
          ),
          fetchedAt: DateTime.now(),
        );
      }

      // The indexer's own loop (SearchIndexer), timed.
      final index = Stopwatch()..start();
      for (final id in await db.unindexedPhileIds()) {
        await db.indexPhile(id, await db.readAllLines(id));
      }
      index.stop();

      Future<(double, List<SearchHit>)> time(String input) async {
        final match = SearchQuery.parse(input).toMatchExpression();
        await db.search(match); // Warm the page cache.
        final samples = <double>[];
        var hits = <SearchHit>[];
        for (var i = 0; i < 5; i++) {
          final sw = Stopwatch()..start();
          hits = await db.search(match);
          samples.add(sw.elapsedMicroseconds / 1000);
        }
        samples.sort();
        return (samples[2], hits);
      }

      final report = StringBuffer(
        'search perf (${kReleaseMode
            ? 'release'
            : kProfileMode
            ? 'profile'
            : 'debug'}): indexed in ${index.elapsedMilliseconds} ms; '
        '${(file.lengthSync() / 1e6).toStringAsFixed(0)} MB',
      );
      final (knownMs, known) = await time(_known);
      expect(
        [for (final h in known) (h.issue, h.number, h.line)],
        [(61, 3, 500), (31, 3, 500), (1, 3, 500)],
      );
      report.write('\n  "$_known": ${knownMs.toStringAsFixed(1)} ms');
      // A phrase, a mid-frequency word, the commonest word, and the two
      // commonest together: the worst cases for the GROUP BY.
      for (final input in [
        '"$_known"',
        _words[50],
        _words[0],
        '${_words[0]} ${_words[1]}',
      ]) {
        final (ms, hits) = await time(input);
        final lines = hits.fold(0, (n, h) => n + h.matchingLines);
        report.write(
          '\n  $input: ${ms.toStringAsFixed(1)} ms, '
          '${hits.length} philes, $lines lines',
        );
      }
      // ignore: avoid_print
      print(report);

      await db.close();
      file.deleteSync();
      if (!kDebugMode) expect(knownMs, lessThan(300));
    });
  }, timeout: const Timeout(Duration(minutes: 20)));
}

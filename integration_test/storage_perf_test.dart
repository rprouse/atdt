// Stage C acceptance: reading any line of any phile from storage takes
// under 5 ms. Uses the production storage path (drift on its background
// isolate, a real file) and a synthetic phile the size of Phrack 71/7.
//
//   flutter test integration_test/storage_perf_test.dart -d <device>
//
// Debug builds on an emulator are the worst case; record release-class
// numbers from a mid-range phone in docs/decisions.md.
import 'dart:io';
import 'dart:math';

import 'package:atdt/archive/issue_import.dart';
import 'package:atdt/ingest/phile_text.dart';
import 'package:atdt/storage/archive_database.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';

const _lines = 265732; // Phrack 71/7
const _warmUp = 50;
const _samples = 500;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('any line reads in under 5 ms', (tester) async {
    await tester.runAsync(() async {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/perf.sqlite');
      if (file.existsSync()) file.deleteSync();
      final db = ArchiveDatabase(
        driftDatabase(
          name: 'perf',
          native: DriftNativeOptions(databasePath: () async => file.path),
        ),
      );

      // ~16 MB: line numbers plus filler, like a long hex/text dump.
      final text = StringBuffer();
      for (var i = 0; i < _lines; i++) {
        text.writeln('$i '.padRight(60, 'x'));
      }
      final phile = PhileText.fromBytes(text.toString().codeUnits);
      final save = Stopwatch()..start();
      await db.saveIssue(
        ImportedIssue(
          number: 71,
          sourceChecksum: 'perf',
          philes: [ImportedPhile(number: 7, title: 'big', text: phile)],
        ),
        fetchedAt: DateTime.now(),
      );
      save.stop();
      final id = (await db.phile(71, 7))!.id;

      final random = Random(7);
      final times = <double>[];
      for (var n = 0; n < _warmUp + _samples; n++) {
        final line = random.nextInt(_lines);
        final sw = Stopwatch()..start();
        final read = await db.readLine(id, line);
        sw.stop();
        expect(read, startsWith('$line '));
        if (n >= _warmUp) times.add(sw.elapsedMicroseconds / 1000);
      }
      times.sort();
      final p50 = times[_samples ~/ 2];
      final p95 = times[(_samples * 0.95).floor()];

      // The floor: a round trip to the database isolate doing nothing.
      final base = Stopwatch()..start();
      for (var i = 0; i < 100; i++) {
        await db.customSelect('SELECT 1').get();
      }
      base.stop();

      // ignore: avoid_print
      print(
        'storage perf (${kReleaseMode
            ? 'release'
            : kProfileMode
            ? 'profile'
            : 'debug'}): save ${save.elapsedMilliseconds} ms; readLine '
        'p50 ${p50.toStringAsFixed(2)} ms, p95 ${p95.toStringAsFixed(2)} ms, '
        'max ${times.last.toStringAsFixed(2)} ms over $_samples random '
        'lines; empty query ${(base.elapsedMicroseconds / 100000).toStringAsFixed(2)} ms',
      );
      await db.close();
      file.deleteSync();

      // The target is for a release-class build on a phone; debug JIT on
      // an emulator only reports.
      if (!kDebugMode) expect(p95, lessThan(5));
    });
  });
}

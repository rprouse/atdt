import 'dart:io';
import 'dart:typed_data';

import 'package:atdt/archive/issue_import.dart';
import 'package:atdt/ingest/phile_text.dart';
import 'package:atdt/storage/archive_database.dart';
import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

ArchiveDatabase _memoryDb({
  int chunkBytes = ArchiveDatabase.defaultChunkBytes,
}) => ArchiveDatabase(
  DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true),
  chunkBytes: chunkBytes,
);

ImportedIssue _fixtureIssue() => importIssueArchive(
  99,
  File('test/archive/fixtures/phrack99.tar.gz').readAsBytesSync(),
);

ImportedIssue _issueFromFixture(int number, String fixture) => ImportedIssue(
  number: number,
  sourceChecksum: 'test',
  philes: [
    ImportedPhile(
      number: 1,
      title: fixture,
      text: PhileText.fromBytes(
        File('test/fixtures/$fixture').readAsBytesSync(),
      ),
    ),
  ],
);

final _fetched = DateTime.utc(2026, 10, 16);

void main() {
  late ArchiveDatabase db;
  tearDown(() => db.close());

  group('saving issues', () {
    setUp(() => db = _memoryDb());

    test('stores an issue with its philes and reports counts', () async {
      await db.saveIssue(
        _fixtureIssue(),
        fetchedAt: _fetched,
        releaseDate: DateTime.utc(1999, 9, 9),
      );

      expect(await db.storedIssueNumbers(), {99});
      final counts = await db.counts();
      expect((counts.issues, counts.philes), (1, 3));

      final intro = (await db.phile(99, 1))!;
      expect(intro.title, 'Introduction');
      expect(intro.author, 'Synthetic Staff');
      expect(intro.lineCount, 3);
      final art = (await db.phile(99, 2))!;
      expect((art.title, art.author, art.encoding), ('Phile 2', null, 'cp437'));
      expect(unpackUint32(art.inventory), containsAll('╔═╗'.runes));
    });

    test('a failed save leaves nothing behind', () async {
      final duplicate = ImportedIssue(
        number: 5,
        sourceChecksum: 'x',
        philes: [
          for (var i = 0; i < 2; i++)
            ImportedPhile(
              number: 1, // the same number twice violates (issue, number)
              title: 't',
              text: PhileText.fromBytes(Uint8List.fromList('a\n'.codeUnits)),
            ),
        ],
      );
      await expectLater(
        db.saveIssue(duplicate, fetchedAt: _fetched),
        throwsA(anything),
      );
      expect(await db.storedIssueNumbers(), isEmpty);
      final counts = await db.counts();
      expect((counts.issues, counts.philes), (0, 0));
    });

    test('saving an issue again replaces it', () async {
      await db.saveIssue(_fixtureIssue(), fetchedAt: _fetched);
      await db.saveIssue(_fixtureIssue(), fetchedAt: _fetched);
      final counts = await db.counts();
      expect((counts.issues, counts.philes), (1, 3));
    });
  });

  group('reading text', () {
    test('reads every line exactly, across many chunks', () async {
      // Small chunks force lines onto chunk boundaries.
      db = _memoryDb(chunkBytes: 1024);
      final issue = _issueFromFixture(1, 'ten_thousand_lines.txt');
      await db.saveIssue(issue, fetchedAt: _fetched);
      final id = (await db.phile(1, 1))!.id;
      final lines = issue.philes.single.text.lines;

      for (final i in [0, 1, 13, 14, 15, 999, 5000, 9998, 9999]) {
        expect(await db.readLine(id, i), lines[i], reason: 'line $i');
      }
      expect(await db.readLine(id, 10000), isNull);
      expect(await db.readAllLines(id), lines);
    });

    test('keeps trailing whitespace, empty lines and non-ASCII', () async {
      db = _memoryDb(chunkBytes: 16);
      final issue = _issueFromFixture(2, 'box_drawing.txt');
      await db.saveIssue(issue, fetchedAt: _fetched);
      final id = (await db.phile(2, 1))!.id;
      expect(await db.readAllLines(id), issue.philes.single.text.lines);
    });

    test('an empty phile has no lines', () async {
      db = _memoryDb();
      await db.saveIssue(
        _issueFromFixture(3, 'empty.txt'),
        fetchedAt: _fetched,
      );
      final id = (await db.phile(3, 1))!.id;
      expect(await db.readAllLines(id), isEmpty);
      expect(await db.readLine(id, 0), isNull);
    });
  });

  test('settings round-trip and overwrite', () async {
    db = _memoryDb();
    expect(await db.setting('k'), isNull);
    await db.setSetting('k', 'one');
    await db.setSetting('k', 'two');
    expect(await db.setting('k'), 'two');
  });

  test('the bundled SQLite supports FTS5 (Stage H search)', () async {
    db = _memoryDb();
    await db.customStatement('CREATE VIRTUAL TABLE t USING fts5(body)');
    await db.customStatement(
      "INSERT INTO t(body) VALUES ('the conscience of a hacker')",
    );
    final hits = await db
        .customSelect("SELECT count(*) AS n FROM t WHERE t MATCH 'hacker'")
        .getSingle();
    expect(hits.read<int>('n'), 1);
  });

  group('chunkLines', () {
    test('keeps lines whole and gives an oversized line its own chunk', () {
      final chunks = chunkLines(['aa', 'b' * 50, 'cc', 'dd'], targetBytes: 8);
      expect(chunks.map((c) => (c.firstLine, c.lineCount)), [
        (0, 1),
        (1, 1),
        (2, 2),
      ]);
    });

    test('no lines, no chunks', () => expect(chunkLines(const []), isEmpty));
  });
}

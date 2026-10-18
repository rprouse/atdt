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

Future<void> _dropSearchTables(ArchiveDatabase db) async {
  for (final table in ['search_indexed', 'line_fts', 'title_fts']) {
    await db.customStatement('DROP TABLE $table');
  }
}

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

  group('library', () {
    setUp(() => db = _memoryDb());

    test('lists catalog and stored issues, newest first', () async {
      await db.saveCatalog({
        98: DateTime.utc(1998, 1, 1),
        99: DateTime.utc(1999, 9, 9),
        100: null,
      });
      await db.saveIssue(_fixtureIssue(), fetchedAt: _fetched);

      final issues = await db.watchLibraryIssues().first;
      expect(issues.map((i) => (i.number, i.downloaded, i.phileCount)), [
        (100, false, 0),
        (99, true, 3),
        (98, false, 0),
      ]);
      // A stored issue without its own date falls back to the catalog's,
      // and stays a UTC calendar date whatever the machine's timezone.
      expect(issues[1].releaseDate, DateTime.utc(1999, 9, 9));
      expect(issues[1].releaseDate!.isUtc, isTrue);
      expect(issues.first.releaseDate, isNull);
    });

    test('updates when an issue is stored or the catalog grows', () async {
      final updates = db.watchLibraryIssues();
      final seen = <List<int>>[];
      final sub = updates.listen(
        (issues) => seen.add([for (final i in issues) i.number]),
      );
      await pumpEventQueue();
      await db.saveCatalog({1: null});
      await pumpEventQueue();
      await db.saveIssue(_fixtureIssue(), fetchedAt: _fetched);
      await pumpEventQueue();
      await sub.cancel();

      expect(seen.first, isEmpty);
      expect(seen, contains(equals([1])));
      expect(seen.last, [99, 1]);
    });

    test('philes are listed in number order', () async {
      await db.saveIssue(_fixtureIssue(), fetchedAt: _fetched);
      final philes = await db.watchPhiles(99).first;
      expect(philes.map((p) => p.number), [1, 2, 10]);
      expect(await db.phileById(philes.first.id), isNotNull);
    });
  });

  test(
    'upgrading a v1 database adds the catalog and keeps the archive',
    () async {
      final dir = Directory.systemTemp.createTempSync('atdt_migration');
      // addTearDown runs before the group's tearDown, and Windows will not
      // delete an open file, so close the database first here.
      addTearDown(() async {
        await db.close();
        dir.deleteSync(recursive: true);
      });
      final file = File('${dir.path}/archive.sqlite');

      // Build a v1 database: today's schema without the catalog or search.
      final v1 = ArchiveDatabase(NativeDatabase(file));
      await v1.saveIssue(_fixtureIssue(), fetchedAt: _fetched);
      await v1.customStatement('DROP TABLE catalog');
      await _dropSearchTables(v1);
      await v1.customStatement('PRAGMA user_version = 1');
      await v1.close();

      db = ArchiveDatabase(NativeDatabase(file));
      await db.saveCatalog({100: null});
      final issues = await db.watchLibraryIssues().first;
      expect(issues.map((i) => (i.number, i.downloaded)), [
        (100, false),
        (99, true),
      ]);
      expect(await db.readAllLines((await db.phile(99, 1))!.id), hasLength(3));
    },
  );

  test('upgrading a v2 database adds search and queues every phile', () async {
    final dir = Directory.systemTemp.createTempSync('atdt_migration');
    addTearDown(() async {
      await db.close();
      dir.deleteSync(recursive: true);
    });
    final file = File('${dir.path}/archive.sqlite');

    final v2 = ArchiveDatabase(NativeDatabase(file));
    await v2.saveIssue(_fixtureIssue(), fetchedAt: _fetched);
    await _dropSearchTables(v2);
    await v2.customStatement('PRAGMA user_version = 2');
    await v2.close();

    db = ArchiveDatabase(NativeDatabase(file));
    expect(await db.unindexedPhileIds(), hasLength(3));
    final id = (await db.phile(99, 1))!.id;
    await db.indexPhile(id, await db.readAllLines(id));
    expect(await db.unindexedPhileIds(), hasLength(2));
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

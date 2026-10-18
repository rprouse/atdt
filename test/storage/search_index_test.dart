import 'package:atdt/archive/issue_import.dart';
import 'package:atdt/ingest/phile_text.dart';
import 'package:atdt/search/search_query.dart';
import 'package:atdt/storage/archive_database.dart';
import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

ImportedPhile _phile(int number, String title, String text, {String? author}) =>
    ImportedPhile(
      number: number,
      title: title,
      author: author,
      text: PhileText.fromBytes(text.codeUnits),
    );

Future<void> _save(ArchiveDatabase db, int issue, List<ImportedPhile> philes) =>
    db.saveIssue(
      ImportedIssue(number: issue, sourceChecksum: '$issue', philes: philes),
      fetchedAt: DateTime.utc(2026),
    );

Future<void> _indexAll(ArchiveDatabase db) async {
  for (final id in await db.unindexedPhileIds()) {
    await db.indexPhile(id, await db.readAllLines(id));
  }
}

Future<List<SearchHit>> _search(
  ArchiveDatabase db,
  String input, {
  int from = 0,
  int to = 1000,
  bool titlesOnly = false,
}) => db.search(
  SearchQuery.parse(input).toMatchExpression(),
  fromIssue: from,
  toIssue: to,
  titlesOnly: titlesOnly,
);

void main() {
  late ArchiveDatabase db;

  setUp(() async {
    db = ArchiveDatabase(
      DatabaseConnection(
        NativeDatabase.memory(),
        closeStreamsSynchronously: true,
      ),
    );
    await _save(db, 3, [
      _phile(1, 'Index', 'Phrack 3 index\n\nRolm systems by Monty\n'),
      _phile(
        2,
        'Rolm systems',
        'Intro\n\nROLM is a PBX\nThe CBX is ROLM\'s controller\n'
            'a blue box tone\n',
        author: 'Monty Python',
      ),
    ]);
    await _save(db, 7, [
      _phile(1, 'Blue boxing', 'blue\nbox\n\nthe blue box, built\n'),
    ]);
    await _indexAll(db);
  });

  tearDown(() => db.close());

  test(
    'a match gives the phile, its first matching line and a count',
    () async {
      final hits = await _search(db, 'rolm');
      expect(
        [for (final h in hits) (h.issue, h.number, h.line)],
        [(3, 1, 2), (3, 2, 2)],
      );
      expect(hits[1].matchingLines, 2);
      expect(hits[1].title, 'Rolm systems');
      expect(hits[1].author, 'Monty Python');
    },
  );

  test('the line number points at the text the snippet shows', () async {
    final hit = (await _search(db, 'controller')).single;
    expect(await db.readLine(hit.phileId, hit.line!), contains('controller'));
  });

  test('newest issue first; words AND on one line; phrases stay '
      'adjacent', () async {
    final words = await _search(db, 'blue box');
    expect([for (final h in words) (h.issue, h.line)], [(7, 3), (3, 4)]);
    // "blue" and "box" on separate lines (7/1, lines 0 and 1) do not match.
    expect(words.first.matchingLines, 1);

    expect(await _search(db, '"box blue"'), isEmpty);
    expect(await _search(db, '"blue box"'), hasLength(2));
  });

  test('prefixes match longer words', () async {
    final hits = await _search(db, 'contr');
    expect(hits.single.line, 3);
  });

  test('the issue range filters results', () async {
    expect(await _search(db, 'blue', from: 4, to: 10), hasLength(1));
    expect(await _search(db, 'blue', from: 1, to: 3), hasLength(1));
    expect(await _search(db, 'blue', from: 4, to: 6), isEmpty);
  });

  test('titles and authors only', () async {
    final byTitle = await _search(db, 'rolm', titlesOnly: true);
    expect(
      [for (final h in byTitle) (h.issue, h.number, h.line)],
      [(3, 2, null)],
    );
    expect(await _search(db, 'python', titlesOnly: true), hasLength(1));
    expect(await _search(db, 'controller', titlesOnly: true), isEmpty);
  });

  test('the status counts indexed philes, and new issues queue', () async {
    expect(
      await db.watchSearchIndexStatus().first,
      isA<SearchIndexStatus>()
          .having((s) => s.indexed, 'indexed', 3)
          .having((s) => s.complete, 'complete', isTrue),
    );
    await _save(db, 8, [_phile(1, 'New', 'fresh text\n')]);
    final status = await db.watchSearchIndexStatus().first;
    expect((status.indexed, status.total, status.complete), (3, 4, false));
    expect(await _search(db, 'fresh'), isEmpty, reason: 'not indexed yet');

    await _indexAll(db);
    expect(await _search(db, 'fresh'), hasLength(1));
  });

  test('indexing twice adds nothing', () async {
    final id = (await db.phile(7, 1))!.id;
    await db.indexPhile(id, await db.readAllLines(id));
    expect((await _search(db, 'built')).single.matchingLines, 1);
  });

  test('a re-imported issue leaves no stale matches', () async {
    await _save(db, 7, [_phile(1, 'Blue boxing v2', 'red box only\n')]);
    expect(await _search(db, 'built'), isEmpty);
    expect(await _search(db, 'boxing', titlesOnly: true), isEmpty);
    expect(await _search(db, 'v2', titlesOnly: true), isEmpty);

    await _indexAll(db);
    expect((await _search(db, 'red')).single.issue, 7);
    expect(await _search(db, 'v2', titlesOnly: true), hasLength(1));
    expect(await _search(db, 'built'), isEmpty);
  });
}

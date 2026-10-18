/// The on-device archive: issues, philes, their text and reading state.
///
/// Pure Dart (drift); opening the file on a device lives in
/// `database_file.dart`. Tests use `NativeDatabase.memory()`.
library;

import 'dart:convert';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:drift/drift.dart';

import '../archive/issue_import.dart';
import '../ingest/phile_text.dart' show TextEncoding;
import '../layout/reading_position.dart';

part 'archive_database.g.dart';

class Issues extends Table {
  IntColumn get number => integer()();
  DateTimeColumn get releaseDate => dateTime().nullable()();
  TextColumn get title => text().nullable()();
  DateTimeColumn get fetchedAt => dateTime()();
  TextColumn get sourceChecksum => text()();

  @override
  Set<Column> get primaryKey => {number};
}

class Philes extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get issue =>
      integer().references(Issues, #number, onDelete: KeyAction.cascade)();
  IntColumn get number => integer()();
  TextColumn get title => text()();
  TextColumn get author => text().nullable()();
  TextColumn get encoding => text()();
  IntColumn get lineCount => integer()();
  IntColumn get longestLine => integer()();

  /// Distinct code points, little-endian uint32 (font coverage, Stage E).
  BlobColumn get inventory => blob()();

  @override
  List<Set<Column>> get uniqueKeys => [
    {issue, number},
  ];
}

/// Phile text in line-aligned chunks of about 16 KiB.
///
/// SQLite reads a whole BLOB to take a substring, and package:sqlite3 has
/// no incremental blob I/O, so one blob per phile would mean reading 16 MB
/// to show one line of the largest phile. Each chunk holds whole lines and
/// knows its first line number, so any line is one indexed lookup.
@TableIndex(name: 'phile_text_by_line', columns: {#phileId, #firstLine})
class PhileTextChunks extends Table {
  @override
  String get tableName => 'phile_text';

  IntColumn get phileId =>
      integer().references(Philes, #id, onDelete: KeyAction.cascade)();
  IntColumn get chunk => integer()();
  IntColumn get firstLine => integer()();
  IntColumn get lineCount => integer()();

  /// UTF-8 lines, each followed by '\n'.
  BlobColumn get data => blob()();

  @override
  Set<Column> get primaryKey => {phileId, chunk};
}

class ReadingStates extends Table {
  @override
  String get tableName => 'reading_state';

  IntColumn get phileId =>
      integer().references(Philes, #id, onDelete: KeyAction.cascade)();
  IntColumn get topLineIndex => integer()();
  RealColumn get fractionIntoLine => real()();
  RealColumn get columnOffset => real()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {phileId};
}

/// Small app state that must survive restarts (e.g. an unfinished download).
class AppSettings extends Table {
  @override
  String get tableName => 'settings';

  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

class ArchiveCounts {
  const ArchiveCounts({required this.issues, required this.philes});

  final int issues;
  final int philes;
}

/// What the downloader needs from storage; implemented by the database and
/// by fakes in tests.
abstract interface class ArchiveStore {
  Future<Set<int>> storedIssueNumbers();

  /// Stores an issue and all its philes atomically: after a crash the issue
  /// is either complete or absent, so a restart re-downloads only it.
  Future<void> saveIssue(
    ImportedIssue issue, {
    required DateTime fetchedAt,
    DateTime? releaseDate,
  });

  Future<ArchiveCounts> counts();

  /// Records every issue the archive offers (and release dates, where
  /// known), so the library can show undownloaded issues offline.
  Future<void> saveCatalog(Map<int, DateTime?> issues);
}

/// Issues the archive offers, downloaded or not (schema v2).
class CatalogIssues extends Table {
  @override
  String get tableName => 'catalog';

  IntColumn get number => integer()();
  DateTimeColumn get releaseDate => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {number};
}

/// Philes whose text is in the search index (schema v3). The FTS tables
/// themselves are virtual and created by SQL; see [ArchiveDatabase].
class SearchIndexed extends Table {
  @override
  String get tableName => 'search_indexed';

  IntColumn get phileId =>
      integer().references(Philes, #id, onDelete: KeyAction.cascade)();

  @override
  Set<Column> get primaryKey => {phileId};
}

/// How much of the archive search covers.
class SearchIndexStatus {
  const SearchIndexStatus({required this.indexed, required this.total});

  final int indexed;
  final int total;

  bool get complete => indexed >= total;
}

/// One phile a search found.
class SearchHit {
  const SearchHit({
    required this.phileId,
    required this.issue,
    required this.number,
    required this.title,
    this.author,
    this.line,
    this.matchingLines = 0,
  });

  final int phileId;
  final int issue;
  final int number;
  final String title;
  final String? author;

  /// The first matching line; null for a title or author match.
  final int? line;
  final int matchingLines;
}

/// Bits of an FTS rowid that hold the line number: rowid is
/// `phileId << searchLineBits | line`, so a match is already a phile and a
/// line, and grouping by phile needs no text. 2^24 lines is 60 times the
/// largest phile (71/7, 265,732 lines).
const int searchLineBits = 24;
const int _searchLineMask = (1 << searchLineBits) - 1;

int searchRowId(int phileId, int line) => phileId << searchLineBits | line;

/// Where the reader last was, for "continue reading".
class LastRead {
  const LastRead({
    required this.phileId,
    required this.issue,
    required this.number,
    required this.title,
    required this.topLine,
    required this.lineCount,
  });

  final int phileId;
  final int issue;
  final int number;
  final String title;
  final int topLine;
  final int lineCount;

  /// How far through the phile, 0 to 100.
  int get percent => lineCount <= 1
      ? 100
      : (100 * topLine / (lineCount - 1)).round().clamp(0, 100);
}

/// One row of the library's issue list.
class LibraryIssue {
  const LibraryIssue({
    required this.number,
    required this.downloaded,
    this.releaseDate,
    this.phileCount = 0,
  });

  final int number;
  final bool downloaded;

  /// A calendar date, in UTC: read its year/month/day, never `.toLocal()`.
  final DateTime? releaseDate;
  final int phileCount;
}

@DriftDatabase(
  tables: [
    Issues,
    Philes,
    PhileTextChunks,
    ReadingStates,
    AppSettings,
    CatalogIssues,
    SearchIndexed,
  ],
)
class ArchiveDatabase extends _$ArchiveDatabase implements ArchiveStore {
  ArchiveDatabase(
    super.executor, {
    this.chunkBytes = defaultChunkBytes,
    this.decodeOnIsolateAbove = 256 * 1024,
  });

  static const int defaultChunkBytes = 16 * 1024;

  /// Target size of a text chunk; small values let tests force many chunks.
  final int chunkBytes;

  /// Philes larger than this are decoded on a short-lived isolate. Widget
  /// tests raise it, because real isolates never finish under fake time.
  final int decodeOnIsolateAbove;

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await _createSearchTables();
    },
    onUpgrade: (m, from, to) async {
      // v2 adds the catalog of available issues.
      if (from < 2) await m.createTable(catalogIssues);
      // v3 adds search; the indexer then indexes every stored phile.
      if (from < 3) {
        await m.createTable(searchIndexed);
        await _createSearchTables();
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  /// Search runs on two FTS5 tables.
  ///
  /// `line_fts` has one row per non-blank line. It is contentless: the text
  /// is already in `phile_text`, and a second copy would double the
  /// database. Queries return rowids only, which is all search needs;
  /// snippets are read back with [readLine]. `columnsize = 0` drops the
  /// per-row size table, which only ranking uses: 15 MB of the archive's
  /// 67 MB index. It rules out `contentless_delete`, so a re-imported
  /// phile's old rows stay behind; every search joins on `philes`, and
  /// AUTOINCREMENT never reuses an id, so they can never match.
  ///
  /// `title_fts` holds each phile's title and author (rowid = phile id) for
  /// the titles-and-authors filter.
  Future<void> _createSearchTables() async {
    const tokenizer = "tokenize = 'unicode61 remove_diacritics 2'";
    await customStatement(
      'CREATE VIRTUAL TABLE line_fts USING fts5('
      "text, content = '', columnsize = 0, $tokenizer)",
    );
    await customStatement(
      'CREATE VIRTUAL TABLE title_fts USING fts5(title, author, $tokenizer)',
    );
  }

  @override
  Future<Set<int>> storedIssueNumbers() async {
    final rows = await (selectOnly(issues)..addColumns([issues.number])).get();
    return {for (final r in rows) r.read(issues.number)!};
  }

  @override
  Future<void> saveIssue(
    ImportedIssue issue, {
    required DateTime fetchedAt,
    DateTime? releaseDate,
  }) => transaction(() async {
    // Replace any earlier copy (e.g. a re-import after an update). The FTS
    // tables have no foreign keys; old titles are removed here, and old
    // lines are orphaned (see _createSearchTables).
    final old =
        await (selectOnly(philes)
              ..addColumns([philes.id])
              ..where(philes.issue.equals(issue.number)))
            .map((r) => r.read(philes.id)!)
            .get();
    for (final id in old) {
      await customStatement('DELETE FROM title_fts WHERE rowid = ?', [id]);
    }
    await (delete(issues)..where((i) => i.number.equals(issue.number))).go();
    await into(issues).insert(
      IssuesCompanion.insert(
        number: Value(issue.number),
        releaseDate: Value(releaseDate),
        fetchedAt: fetchedAt,
        sourceChecksum: issue.sourceChecksum,
      ),
    );
    for (final phile in issue.philes) {
      final text = phile.text;
      final id = await into(philes).insert(
        PhilesCompanion.insert(
          issue: issue.number,
          number: phile.number,
          title: phile.title,
          author: Value(phile.author),
          encoding: text.encoding.label,
          lineCount: text.lines.length,
          longestLine: text.longestLineColumns,
          inventory: _packUint32(text.inventory),
        ),
      );
      await batch((b) {
        b.insertAll(phileTextChunks, [
          for (final (i, c) in chunkLines(
            text.lines,
            targetBytes: chunkBytes,
          ).indexed)
            PhileTextChunksCompanion.insert(
              phileId: id,
              chunk: i,
              firstLine: c.firstLine,
              lineCount: c.lineCount,
              data: c.data,
            ),
        ]);
      });
    }
  });

  @override
  Future<ArchiveCounts> counts() async {
    final issueCount = issues.number.count();
    final phileCount = philes.id.count();
    final i = await (selectOnly(issues)..addColumns([issueCount])).getSingle();
    final p = await (selectOnly(philes)..addColumns([phileCount])).getSingle();
    return ArchiveCounts(
      issues: i.read(issueCount)!,
      philes: p.read(phileCount)!,
    );
  }

  @override
  Future<void> saveCatalog(Map<int, DateTime?> issues) => batch((b) {
    b.insertAllOnConflictUpdate(catalogIssues, [
      for (final MapEntry(key: number, value: date) in issues.entries)
        CatalogIssuesCompanion.insert(
          number: Value(number),
          releaseDate: Value(date),
        ),
    ]);
  });

  /// Every known issue, newest first: the catalog plus anything stored,
  /// with stored dates preferred. Updates as issues are downloaded.
  Stream<List<LibraryIssue>> watchLibraryIssues() =>
      customSelect(
        'SELECT n.number AS number, '
        'COALESCE(i.release_date, c.release_date) AS release_date, '
        'i.number IS NOT NULL AS downloaded, '
        '(SELECT count(*) FROM philes p WHERE p.issue = n.number) AS phile_count '
        'FROM (SELECT number FROM catalog UNION SELECT number FROM issues) n '
        'LEFT JOIN issues i ON i.number = n.number '
        'LEFT JOIN catalog c ON c.number = n.number '
        'ORDER BY n.number DESC',
        readsFrom: {issues, philes, catalogIssues},
      ).watch().map(
        (rows) => [
          for (final r in rows)
            LibraryIssue(
              number: r.read<int>('number'),
              downloaded: r.read<bool>('downloaded'),
              // drift reads DateTime back in local time; release dates are
              // calendar dates stored at UTC midnight, so keep them in UTC or
              // they show as the previous day west of Greenwich.
              releaseDate: r.readNullable<DateTime>('release_date')?.toUtc(),
              phileCount: r.read<int>('phile_count'),
            ),
        ],
      );

  /// An issue's philes in reading order.
  Stream<List<Phile>> watchPhiles(int issue) =>
      (select(philes)
            ..where((p) => p.issue.equals(issue))
            ..orderBy([(p) => OrderingTerm.asc(p.number)]))
          .watch();

  Future<Phile?> phileById(int id) =>
      (select(philes)..where((p) => p.id.equals(id))).getSingleOrNull();

  /// Saves where the reader is in a phile (one row per phile).
  Future<void> saveReadingPosition(
    int phileId,
    ReadingPosition position, {
    required DateTime at,
  }) => into(readingStates).insertOnConflictUpdate(
    ReadingStatesCompanion.insert(
      phileId: Value(phileId),
      topLineIndex: position.topLineIndex,
      fractionIntoLine: position.fractionIntoLine,
      columnOffset: position.columnOffset,
      updatedAt: at,
    ),
  );

  Future<ReadingPosition?> readingPosition(int phileId) async {
    final row = await (select(
      readingStates,
    )..where((r) => r.phileId.equals(phileId))).getSingleOrNull();
    return row == null
        ? null
        : ReadingPosition(
            topLineIndex: row.topLineIndex,
            fractionIntoLine: row.fractionIntoLine,
            columnOffset: row.columnOffset,
          );
  }

  /// The most recently read phile, for "continue reading".
  Stream<LastRead?> watchLastRead() =>
      customSelect(
        'SELECT p.id, p.issue, p.number, p.title, p.line_count, '
        'r.top_line_index FROM reading_state r '
        'JOIN philes p ON p.id = r.phile_id '
        'ORDER BY r.updated_at DESC LIMIT 1',
        readsFrom: {readingStates, philes},
      ).watchSingleOrNull().map(
        (r) => r == null
            ? null
            : LastRead(
                phileId: r.read<int>('id'),
                issue: r.read<int>('issue'),
                number: r.read<int>('number'),
                title: r.read<String>('title'),
                topLine: r.read<int>('top_line_index'),
                lineCount: r.read<int>('line_count'),
              ),
      );

  Future<String?> setting(String key) async => (await (select(
    appSettings,
  )..where((s) => s.key.equals(key))).getSingleOrNull())?.value;

  Future<void> setSetting(String key, String value) => into(
    appSettings,
  ).insertOnConflictUpdate(AppSettingsCompanion.insert(key: key, value: value));

  Future<Phile?> phile(int issue, int number) =>
      (select(philes)
            ..where((p) => p.issue.equals(issue) & p.number.equals(number)))
          .getSingleOrNull();

  /// One line of a phile, read from a single chunk.
  ///
  /// Raw SQL on the (phile_id, first_line) index: this is the hot path the
  /// 5 ms target applies to, and the query builder costs more than the
  /// lookup itself.
  Future<String?> readLine(int phileId, int line) async {
    final row = await customSelect(
      'SELECT first_line, line_count, data FROM phile_text '
      'WHERE phile_id = ? AND first_line <= ? '
      'ORDER BY first_line DESC LIMIT 1',
      variables: [Variable.withInt(phileId), Variable.withInt(line)],
      readsFrom: {phileTextChunks},
    ).getSingleOrNull();
    if (row == null) return null;
    final first = row.read<int>('first_line');
    if (line >= first + row.read<int>('line_count')) return null;
    return _lineInChunk(row.read<Uint8List>('data'), line - first);
  }

  /// Puts a phile's lines, title and author in the search index. Does
  /// nothing if it is already there: contentless rows cannot be replaced.
  Future<void> indexPhile(int phileId, List<String> lines) =>
      transaction(() async {
        final meta = await phileById(phileId);
        if (meta == null) return; // Deleted (re-imported) since it was queued.
        final done = await (select(
          searchIndexed,
        )..where((s) => s.phileId.equals(phileId))).getSingleOrNull();
        if (done != null) return;
        await batch((b) {
          for (var i = 0; i < lines.length && i <= _searchLineMask; i++) {
            // Blank lines hold no tokens; skipping them saves a row each.
            if (lines[i].trim().isEmpty) continue;
            b.customStatement(
              'INSERT INTO line_fts(rowid, text) VALUES (?, ?)',
              [searchRowId(phileId, i), lines[i]],
            );
          }
          b.customStatement(
            'INSERT INTO title_fts(rowid, title, author) VALUES (?, ?, ?)',
            [phileId, meta.title, meta.author],
          );
          b.insert(
            searchIndexed,
            SearchIndexedCompanion.insert(phileId: Value(phileId)),
          );
        });
      });

  /// Stored philes not yet in the search index, newest issue first.
  Future<List<int>> unindexedPhileIds() => customSelect(
    'SELECT id FROM philes '
    'WHERE id NOT IN (SELECT phile_id FROM search_indexed) '
    'ORDER BY issue DESC, number',
    readsFrom: {philes, searchIndexed},
  ).map((r) => r.read<int>('id')).get();

  Stream<SearchIndexStatus> watchSearchIndexStatus() =>
      customSelect(
        'SELECT (SELECT count(*) FROM search_indexed) AS indexed, '
        '(SELECT count(*) FROM philes) AS total',
        readsFrom: {philes, searchIndexed},
      ).watchSingle().map(
        (r) => SearchIndexStatus(
          indexed: r.read<int>('indexed'),
          total: r.read<int>('total'),
        ),
      );

  /// Philes matching [match] (an FTS5 expression, from
  /// `SearchQuery.toMatchExpression`), newest issue first.
  ///
  /// Line search groups matching lines by phile from their rowids alone,
  /// so it never reads text. [titlesOnly] searches titles and authors.
  Future<List<SearchHit>> search(
    String match, {
    int fromIssue = 0,
    int toIssue = 1 << 30,
    bool titlesOnly = false,
  }) async {
    final range = [Variable.withInt(fromIssue), Variable.withInt(toIssue)];
    if (titlesOnly) {
      final rows = await customSelect(
        'SELECT p.id, p.issue, p.number, p.title, p.author '
        'FROM title_fts t JOIN philes p ON p.id = t.rowid '
        'WHERE title_fts MATCH ? AND p.issue BETWEEN ? AND ? '
        'ORDER BY p.issue DESC, p.number',
        variables: [Variable.withString(match), ...range],
        readsFrom: {philes},
      ).get();
      return [for (final r in rows) _hit(r)];
    }
    final rows = await customSelect(
      'SELECT p.id, p.issue, p.number, p.title, p.author, '
      'g.first_line, g.hits FROM ('
      '  SELECT rowid >> $searchLineBits AS phile_id, '
      '  min(rowid) & $_searchLineMask AS first_line, count(*) AS hits '
      '  FROM line_fts WHERE line_fts MATCH ? '
      '  GROUP BY rowid >> $searchLineBits'
      ') g JOIN philes p ON p.id = g.phile_id '
      'WHERE p.issue BETWEEN ? AND ? '
      'ORDER BY p.issue DESC, p.number',
      variables: [Variable.withString(match), ...range],
      readsFrom: {philes},
    ).get();
    return [
      for (final r in rows)
        _hit(
          r,
          line: r.read<int>('first_line'),
          matchingLines: r.read<int>('hits'),
        ),
    ];
  }

  SearchHit _hit(QueryRow r, {int? line, int matchingLines = 0}) => SearchHit(
    phileId: r.read<int>('id'),
    issue: r.read<int>('issue'),
    number: r.read<int>('number'),
    title: r.read<String>('title'),
    author: r.readNullable<String>('author'),
    line: line,
    matchingLines: matchingLines,
  );

  /// Every line of a phile, for the reader.
  ///
  /// Large philes are decoded on a short-lived isolate: 71/7 is 16 MB and
  /// would freeze the UI for its whole decode.
  Future<List<String>> readAllLines(int phileId) async {
    final chunks =
        await (select(phileTextChunks)
              ..where((c) => c.phileId.equals(phileId))
              ..orderBy([(c) => OrderingTerm.asc(c.chunk)]))
            .get();
    final data = [for (final c in chunks) c.data];
    final bytes = data.fold(0, (n, d) => n + d.length);
    return bytes > decodeOnIsolateAbove
        ? Isolate.run(() => _decodeChunks(data))
        : _decodeChunks(data);
  }
}

List<String> _decodeChunks(List<Uint8List> chunks) => [
  for (final c in chunks) ...const LineSplitter().convert(utf8.decode(c)),
];

typedef TextChunk = ({int firstLine, int lineCount, Uint8List data});

/// Packs lines into chunks of whole lines, each about [targetBytes] or less
/// (a single longer line gets a chunk of its own).
List<TextChunk> chunkLines(
  List<String> lines, {
  int targetBytes = ArchiveDatabase.defaultChunkBytes,
}) {
  final chunks = <TextChunk>[];
  final buffer = BytesBuilder(copy: false);
  var first = 0;
  for (var i = 0; i < lines.length; i++) {
    final encoded = utf8.encode('${lines[i]}\n');
    if (buffer.length > 0 && buffer.length + encoded.length > targetBytes) {
      chunks.add((
        firstLine: first,
        lineCount: i - first,
        data: buffer.takeBytes(),
      ));
      first = i;
    }
    buffer.add(encoded);
  }
  if (buffer.length > 0) {
    chunks.add((
      firstLine: first,
      lineCount: lines.length - first,
      data: buffer.takeBytes(),
    ));
  }
  return chunks;
}

String _lineInChunk(Uint8List data, int index) {
  var start = 0;
  for (var skipped = 0; skipped < index; skipped++) {
    start = data.indexOf(0x0A, start) + 1;
  }
  final end = data.indexOf(0x0A, start);
  return utf8.decode(Uint8List.sublistView(data, start, end));
}

Uint8List _packUint32(List<int> values) {
  final data = ByteData(values.length * 4);
  for (var i = 0; i < values.length; i++) {
    data.setUint32(i * 4, values[i], Endian.little);
  }
  return data.buffer.asUint8List();
}

List<int> unpackUint32(Uint8List bytes) {
  final data = ByteData.sublistView(bytes);
  return [
    for (var i = 0; i + 4 <= bytes.length; i += 4)
      data.getUint32(i, Endian.little),
  ];
}

/// Encoding label as stored, back to the enum.
TextEncoding encodingFromLabel(String label) =>
    TextEncoding.values.firstWhere((e) => e.label == label);

/// The on-device archive: issues, philes, their text and reading state.
///
/// Pure Dart (drift); opening the file on a device lives in
/// `database_file.dart`. Tests use `NativeDatabase.memory()`.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:drift/drift.dart';

import '../archive/issue_import.dart';
import '../ingest/phile_text.dart' show TextEncoding;

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

/// Phile text in line-aligned chunks of about 64 KiB.
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
}

@DriftDatabase(tables: [Issues, Philes, PhileTextChunks, ReadingStates])
class ArchiveDatabase extends _$ArchiveDatabase implements ArchiveStore {
  ArchiveDatabase(super.executor, {this.chunkBytes = defaultChunkBytes});

  static const int defaultChunkBytes = 64 * 1024;

  /// Target size of a text chunk; small values let tests force many chunks.
  final int chunkBytes;

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

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
    // Replace any earlier copy (e.g. a re-import after an update).
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

  Future<Phile?> phile(int issue, int number) =>
      (select(philes)
            ..where((p) => p.issue.equals(issue) & p.number.equals(number)))
          .getSingleOrNull();

  /// One line of a phile, read from a single chunk.
  Future<String?> readLine(int phileId, int line) async {
    final chunk =
        await (select(phileTextChunks)
              ..where(
                (c) =>
                    c.phileId.equals(phileId) &
                    c.firstLine.isSmallerOrEqualValue(line),
              )
              ..orderBy([(c) => OrderingTerm.desc(c.firstLine)])
              ..limit(1))
            .getSingleOrNull();
    if (chunk == null || line >= chunk.firstLine + chunk.lineCount) {
      return null;
    }
    return _lineInChunk(chunk.data, line - chunk.firstLine);
  }

  /// Every line of a phile, for the reader.
  Future<List<String>> readAllLines(int phileId) async {
    final chunks =
        await (select(phileTextChunks)
              ..where((c) => c.phileId.equals(phileId))
              ..orderBy([(c) => OrderingTerm.asc(c.chunk)]))
            .get();
    return [
      for (final c in chunks)
        ...const LineSplitter().convert(utf8.decode(c.data)),
    ];
  }
}

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
